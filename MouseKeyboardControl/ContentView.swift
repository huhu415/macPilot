//
//  ContentView.swift
//  MouseKeyboardControl
//
//  Created by 张重言 on 2025/1/27.
//

import SwiftUI
import Swifter

enum KeyCode: CGKeyCode {
    case space = 49
    case returnKey = 36
    case delete = 51
    case escape = 53
    case leftArrow = 123
    case rightArrow = 124
    case upArrow = 126
    case downArrow = 125
}

struct ContentView: View {
    @State private var mousePosition: CGPoint = .zero
    @State private var server: HttpServer?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("当前鼠标位置: \(Int(mousePosition.x)), \(Int(mousePosition.y))")
            
            Button("移动鼠标到屏幕中心") {
                let screenFrame = NSScreen.main?.frame ?? .zero
                let centerPoint = CGPoint(x: screenFrame.width/2, y: screenFrame.height/2)
                InputControl.moveMouse(to: centerPoint)
            }
            
            Button("模拟鼠标点击") {
                InputControl.mouseClick(at: mousePosition)
            }
            
            Button("按下空格键") {
                InputControl.pressKey(keyCode: 49) // 49是空格键的键码
            }
        }
        .padding()
        .onAppear {
            // 启动 HTTP 服务器
            startServer()
            
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                mousePosition = InputControl.getCurrentMousePosition()
            }
        }
    }
    
    private func startServer() {
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

#Preview {
    ContentView()
}
