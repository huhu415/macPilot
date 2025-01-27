import Foundation
import Swifter
import AppKit

class ServerManager {
    static let shared = ServerManager()
    private var server: HttpServer?
    
    private init() {}
    
    func startServer() {
        server = HttpServer()
        
        // 添加获取鼠标位置的路由
        server?["/mouse-position"] = { request in
            let position = InputControl.getCurrentMousePosition()
            let mainScreen = NSScreen.main
            let response: [String: Any] = [
                "x": position.x,
                "y": position.y,
                "screen": [
                    "width": mainScreen?.frame.width as Any,
                    "height": mainScreen?.frame.height as Any,
                    "scale": mainScreen?.backingScaleFactor as Any
                ]
            ]
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: response),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return .internalServerError
            }
            
            return HttpResponse.ok(.text(jsonString))
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
