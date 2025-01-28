import AppKit
import Foundation
import Swifter

class ServerManager {
    static let shared = ServerManager()
    private var server: HttpServer?

    private init() {}

    func startServer() {
        server = HttpServer()

        // 添加获取鼠标位置的路由
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

        // 添加截图路由
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

        // 添加执行命令的POST接口
        server?["/execute"] = { request in
            let bodyData = Data(request.body)
            guard
                let json =
                    (try? JSONSerialization.jsonObject(
                        with: bodyData, options: [.allowFragments])) as? [String: Any],
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

            guard let jsonData = try? JSONSerialization.data(withJSONObject: response) else {
                return .internalServerError
            }

            print(jsonData)

            return HttpResponse.ok(.data(jsonData, contentType: "application/json"))
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
