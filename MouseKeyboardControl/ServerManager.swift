import AppKit
import Foundation
import Swifter

class ServerManager {
    static let shared: ServerManager = ServerManager()
    private var server: HttpServer?

    private init() {}

    func serverInit() -> HttpServer? {
        server = HttpServer()

        // GET ping-pong
        server?["/ping"] = { request in
            return .ok(.text("pong\n"))
        }

        // GEY 获取鼠标位置, x和y是逻辑坐标, screen里面的就是屏幕的真实分辨率和缩放比例
        server?["/cursor"] = { request in
            let position = InputControl.getCurrentMousePosition()
            let mainScreen = NSScreen.main
            let response: [String: Any] = [
                "x": position.x,
                "y": position.y,
                "screen": [
                    "width": mainScreen?.frame.width as Any,
                    "height": mainScreen?.frame.height as Any,
                    "scale": mainScreen?.backingScaleFactor as Any,
                ],
            ]

            guard
                let jsonData = try? JSONSerialization.data(
                    withJSONObject: response,
                    options: [.prettyPrinted, .sortedKeys]
                    ),
                let jsonString = String(data: jsonData, encoding: .utf8)
            else {
                return .internalServerError
            }

            return HttpResponse.ok(.text(jsonString))
        }

        // GET 移动鼠标位置. x和y是逻辑坐标, 不是真实的屏幕分辨率坐标 
        // 左上角为原点, 向右为x轴, 向下为y轴
        server?["/cursor/move"] = { request in
            // 从查询参数中获取x和y坐标
            let x = Double(request.queryParams.first { $0.0 == "x" }?.1 ?? "0") ?? 0
            let y = Double(request.queryParams.first { $0.0 == "y" }?.1 ?? "0") ?? 0
            
            InputControl.moveMouse(to: CGPoint(x: x, y: y))
            return .ok(.text("Mouse moved to \(x), \(y)"))
        }

        // GET 点击鼠标
        server?["/cursor/click"] = { request in
            InputControl.mouseClick(at: InputControl.getCurrentMousePosition())
            return .ok(.text("Mouse clicked"))
        }

        // POST 把json中text字段的内容粘贴到光标位置
        server?["/paste"] = { request in
            let bodyData = Data(request.body)
            guard
                let json =
                    (try? JSONSerialization.jsonObject(with: bodyData)
                        as? [String: String]),
                let text = json["text"]
            else {
                return .badRequest(
                    .text("Invalid request format or missing 'text' field"))
            }

            print("粘贴内容: \(text)")
            sleep(2)

            // 把文本放到剪贴板
            let pasteboard = NSPasteboard.general
            pasteboard.declareTypes([.string], owner: nil)
            pasteboard.setString(text, forType: .string)

            // 粘贴到光标位置
            InputControl.pressKeys(
                modifiers: .maskCommand,
                keyCodes: KeyCode.v.rawValue
            )

            return .ok(.text("Pasted"))
        }

        // GET 截图
        server?["/screenshot"] = { request in
            let semaphore = DispatchSemaphore(value: 0)
            var screenshotData: Data?
            var response: HttpResponse = .internalServerError

            let screenCaptureManager = ScreenCaptureManager()
            screenCaptureManager.captureFullScreen { image in
                defer { semaphore.signal() }

                guard let image = image else {
                    return
                }

                // 将NSImage转换为JPEG数据
                if let tiffData = image.tiffRepresentation,
                    let bitmapImage = NSBitmapImageRep(data: tiffData)
                {
                    screenshotData = bitmapImage.representation(
                        using: .jpeg,
                        properties: [.compressionFactor: 0.9]
                    )
                }
            }

            // 等待最多3秒
            _ = semaphore.wait(timeout: .now() + 3)

            if let data = screenshotData {
                response = .ok(.data(data, contentType: "image/jpeg"))
            }

            return response
        }

        // POST 里面command字段的命令, args是可选的参数数组
        server?["/execute"] = { request in
            let bodyData = Data(request.body)
            guard
                let json =
                    (try? JSONSerialization.jsonObject(
                        with: bodyData, options: [.allowFragments]))
                    as? [String: Any],
                let command = json["command"] as? String
            else {
                return .badRequest(.text("Invalid request body"))
            }

            let args = json["args"] as? [String] ?? []
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + args
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            var response: [String: Any] = [:]

            do {
                try process.run()

                process.waitUntilExit()
                let outputData = outputPipe.fileHandleForReading
                    .readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading
                    .readDataToEndOfFile()

                response["exitStatus"] = process.terminationStatus
                response["output"] = String(data: outputData, encoding: .utf8)
                response["error"] = String(data: errorData, encoding: .utf8)

            } catch {
                response["error"] = error.localizedDescription
            }

            guard
                let jsonData = try? JSONSerialization.data(
                    withJSONObject: response,
                    options: [.prettyPrinted, .sortedKeys]
                )
            else {
                return .internalServerError
            }

            print(jsonData)

            return HttpResponse.ok(
                .data(jsonData, contentType: "application/json"))
        }

        // GET /apps/launch?bundleId=xxx 或 /apps/launch?appName=xxx
        server?["/apps/launch"] = { request in
            // 获取查询参数
            let bundleId = request.queryParams.first { $0.0 == "bundleId" }?.1
            let appName = request.queryParams.first { $0.0 == "appName" }?.1
            
            guard bundleId != nil || appName != nil else {
                return .badRequest(.text("Missing required parameter: either 'bundleId' or 'appName' must be provided"))
            }
            
            let finalBundleId: String?
            
            if let bundleId = bundleId {
                finalBundleId = bundleId
            } else if let appName = appName {
                let apps = getInstalledApplications()
                finalBundleId = apps.first {
                    $0.name.lowercased() == appName.lowercased()
                }?.bundleId
                
                guard finalBundleId != nil else {
                    return .notFound
                }
            } else {
                return .badRequest(.text("Invalid parameters"))
            }
            
            guard
                let appUrl = NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: finalBundleId!)
            else {
                return .notFound
            }
            
            NSWorkspace.shared.openApplication(
                at: appUrl, configuration: NSWorkspace.OpenConfiguration()
            ) { app, error in
                if let error = error {
                    print("Failed to launch application: \(error.localizedDescription)")
                } else {
                    print("Successfully launched application: \(app?.bundleIdentifier ?? "")")
                }
            }
            
            return .ok(.text("Application launch initiated"))
        }

        // GET 获取应用列表
        server?["/apps"] = { request in
            let apps = getInstalledApplications()
            let appList = apps.map {
                ["appName": $0.name, "bundleId": $0.bundleId]
            }

            guard
                let jsonData = try? JSONSerialization.data(
                    withJSONObject: appList,
                    options: [.prettyPrinted, .sortedKeys]
                    )
            else {
                return .internalServerError
            }
            return .ok(.data(jsonData, contentType: "application/json"))
        }

        // GET 获取窗口列表
        server?["/windows"] = { request in
            let accessibilityManager = AccessibilityManager()
            let jsonString = accessibilityManager.getWindowsListInfo()
            return .ok(.data(jsonString.data(using: .utf8)!, contentType: "application/json"))
        }

        // GET 获取窗口信息
        server?["/windows/info"] = { request in
            let accessibilityManager = AccessibilityManager()
            
            if let pidString = request.queryParams.first(where: { $0.0 == "pid" })?.1,
               let pid = pid_t(pidString) {
                print("获取指定进程窗口信息: \(pid)")
                let jsonString = accessibilityManager.getWindowInfoByPID(pid)
                return .ok(.data(jsonString.data(using: .utf8)!, contentType: "application/json"))
            }
            
            // 获取当前焦点窗口信息
            let jsonString = accessibilityManager.getWindowStructure()
            return .ok(.data(jsonString.data(using: .utf8)!, contentType: "application/json"))
        }

        return server
    }
}

// 新增应用信息结构体和获取方法
private struct AppInfo {
    let name: String
    let bundleId: String
}

private func getInstalledApplications() -> [AppInfo] {
    var apps = [AppInfo]()

    // 搜索系统应用目录和用户应用目录
    let searchPaths = [
        "/Applications",
        "/System/Applications",
        NSHomeDirectory() + "/Applications",
    ]

    for path in searchPaths {
        guard
            let contents = try? FileManager.default.contentsOfDirectory(
                atPath: path)
        else { continue }

        for item in contents where item.hasSuffix(".app") {
            let appPath = URL(fileURLWithPath: path).appendingPathComponent(
                item)
            let plistPath = appPath.appendingPathComponent(
                "Contents/Info.plist")

            guard let plistData = try? Data(contentsOf: plistPath),
                let plist = try? PropertyListSerialization.propertyList(
                    from: plistData, options: [], format: nil)
                    as? [String: Any],
                let bundleId = plist["CFBundleIdentifier"] as? String,
                let name = plist["CFBundleName"] as? String ?? plist[
                    "CFBundleExecutable"] as? String
            else { continue }

            apps.append(AppInfo(name: name, bundleId: bundleId))
        }
    }

    return apps.sorted { $0.name < $1.name }
}
