//
//  MouseKeyboardControlApp.swift
//  MouseKeyboardControl
//
//  Created by 张重言 on 2025/1/27.
//

import SwiftUI
import ApplicationServices

@main
struct MouseKeyboardControlApp: App {
    @State private var hasPermission = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasPermission {
                    ContentView()
                } else {
                    VStack {
                        Text("需要辅助功能权限才能控制鼠标和键盘")
                        Button("请求权限") {
                            requestPermission()
                        }
                    }
                    .padding()
                }
            }
            .onAppear {
                checkPermission()
            }
        }
    }
    
    private func checkPermission() {
        let trusted = AXIsProcessTrusted()
        print("当前权限状态：\(trusted)")
        hasPermission = trusted
    }
    
    private func requestPermission() {
        print("开始请求权限")
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        // 延迟检查权限状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let trusted = AXIsProcessTrusted()
            print("权限检查结果：\(trusted)")
            hasPermission = trusted
        }
    }
}
