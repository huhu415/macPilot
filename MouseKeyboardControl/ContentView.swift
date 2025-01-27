//
//  ContentView.swift
//  MouseKeyboardControl
//
//  Created by 张重言 on 2025/1/27.
//

import SwiftUI

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
            // 创建一个定时器来更新鼠标位置
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                mousePosition = InputControl.getCurrentMousePosition()
            }
        }
    }
}

#Preview {
    ContentView()
}
