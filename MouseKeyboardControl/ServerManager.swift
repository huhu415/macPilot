import AppKit
import Foundation
import Swifter

class ServerManager {
    static let shared = ServerManager()
    private var server: HttpServer?

    private init() {}

    func startServer() {
        server = HttpServer()

        // GEY 获取鼠标位置, x和y是逻辑坐标, screen里面的就是屏幕的真实分辨率和缩放比例
        server?["/cursor_position"] = { request in
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
                    withJSONObject: response),
                let jsonString = String(data: jsonData, encoding: .utf8)
            else {
                return .internalServerError
            }

            return HttpResponse.ok(.text(jsonString))
        }

        // POST 移动鼠标位置. x和y是逻辑坐标, 不是真实的屏幕分辨率坐标, 可以是int或string
        server?["/move_mouse"] = { request in
            let bodyData = Data(request.body)
            let json =
                try? JSONSerialization.jsonObject(with: bodyData)
                as? [String: Any]
            // 处理字符串或数字类型的坐标值
            let x =
                (json?["x"] as? Int)
                ?? (json?["x"] as? String).flatMap(Int.init)
            let y =
                (json?["y"] as? Int)
                ?? (json?["y"] as? String).flatMap(Int.init)

            InputControl.moveMouse(to: CGPoint(x: x ?? 0, y: y ?? 0))
            return .ok(.text("Mouse moved to \(x ?? 0), \(y ?? 0)"))
        }

        // GET 点击鼠标
        server?["/click_mouse"] = { request in
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
                    withJSONObject: response)
            else {
                return .internalServerError
            }

            print(jsonData)

            return HttpResponse.ok(
                .data(jsonData, contentType: "application/json"))
        }

        // POST 打开应用的路由, type: bundleId or appName, value: xxxx
        server?["/open_app"] = { request in
            let bodyData = Data(request.body)
            guard
                let json = try? JSONSerialization.jsonObject(
                    with: bodyData, options: []) as? [String: Any],
                let type = json["type"] as? String,
                let value = json["value"] as? String
            else {
                return .badRequest(.text("Invalid request format"))
            }

            let bundleIdValueEnd: String?

            switch type {
            case "bundleId":
                bundleIdValueEnd = value
            case "appName":
                let apps = getInstalledApplications()
                bundleIdValueEnd =
                    apps.first {
                        $0.name.lowercased() == value.lowercased()
                    }?.bundleId

                guard bundleIdValueEnd != nil else {
                    return .badRequest(.text("Application not found: \(value)"))
                }
            default:
                return .badRequest(.text("Invalid request format"))
            }

            guard
                let appUrl = NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: bundleIdValueEnd!)
            else {
                return .badRequest(
                    .text(
                        "Application URL not found for identifier: \(bundleIdValueEnd!)"
                    ))
            }

            NSWorkspace.shared.openApplication(
                at: appUrl, configuration: NSWorkspace.OpenConfiguration()
            ) { app, error in
                if let error = error {
                    print("打开应用失败: \(error.localizedDescription)")
                } else {
                    print("成功打开应用: \(app?.bundleIdentifier ?? "")")
                }
            }

            return .ok(.text("Application launch request received"))
        }

        // GET 获取应用列表
        server?["/list_apps"] = { request in
            let apps = getInstalledApplications()
            let appList = apps.map {
                ["name": $0.name, "bundleId": $0.bundleId]
            }

            guard
                let jsonData = try? JSONSerialization.data(
                    withJSONObject: appList)
            else {
                return .internalServerError
            }
            return .ok(.data(jsonData, contentType: "application/json"))
        }

        // 添加错误处理和日志
        do {
            try server?.start(8080)
            print("服务器成功启动在端口 8080")
        } catch {
            print("服务器启动失败：\(error.localizedDescription)")
        }
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
