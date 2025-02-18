//
//  ContentView.swift
//  MouseKeyboardControl
//
//  Created by 张重言 on 2025/1/27.
//

import AVFoundation
import ScreenCaptureKit
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
    case c = 8
    case v = 9
}

struct ContentView: View {
    @State private var mousePosition: CGPoint = .zero
    @State private var stream: SCStream?
    @State private var screenCaptureManager = ScreenCaptureManager()
    @State private var screenshotImage: NSImage?  // 新增状态用于存储截图
    @State private var errorMessage: String = ""  // 新增状态用于错误信息
    @State private var isServerHealthy: Bool = false
    @State private var showServerAlert: Bool = false
    @State private var accessibilityInfo: String = "" // 新增状态变量

    var body: some View {
        VStack(spacing: 20) {
            Text("当前鼠标位置: \(Int(mousePosition.x)), \(Int(mousePosition.y))")

            Button("移动鼠标到屏幕中心") {
                let screenFrame = NSScreen.main?.frame ?? .zero
                let centerPoint = CGPoint(
                    x: screenFrame.width / 2, y: screenFrame.height / 2)
                print("移动鼠标到屏幕中心: \(centerPoint)")
                InputControl.moveMouse(to: centerPoint)
            }

            Button("鼠标点击屏幕中心(延迟1s)") {
                sleep(1)
                let screenFrame = NSScreen.main?.frame ?? .zero
                let centerPoint = CGPoint(
                    x: screenFrame.width / 2, y: screenFrame.height / 2)
                InputControl.mouseClick(at: centerPoint)
            }

            Button("检查服务器状态") {
                checkServerStatus()
            }.alert(isPresented: $showServerAlert) {
                Alert(
                    title: Text(verbatim: ""),
                    message: Text(isServerHealthy ? "✅ 服务正常" : "❌ 服务异常"),
                    dismissButton: .default(Text("知道了"))
                )
            }

            Button("截取屏幕") {
                takeScreenshot()
            }

            Button("获取当前窗口信息") {
                getCurrentWindowInfo()
            }

            // 显示 Accessibility 信息
            ScrollView {
                Text(accessibilityInfo)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(height: 200)

            // 新增截图显示区域
            Group {
                if let screenshotImage = screenshotImage {
                    Image(nsImage: screenshotImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300)
                } else if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
        .padding()
        .onAppear {
            // 启动 HTTP 服务器
            let server = ServerManager.shared.serverInit()
            do {
                try server?.start(8080)
                print("✅ 服务器启动成功")
            } catch {
                print("❌ 服务器启动失败: \(error.localizedDescription)")
            }

            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                mousePosition = InputControl.getCurrentMousePosition()
            }
        }
    }

    func takeScreenshot() {
        screenCaptureManager.captureFullScreen { image in
            DispatchQueue.main.async {
                if let image = image {
                    screenshotImage = image
                    errorMessage = ""
                    print("截图成功，尺寸: \(image.size)")
                } else {
                    screenshotImage = nil
                    errorMessage = "截图失败，请检查权限设置"
                    print("截图失败: 无法获取有效图像")
                }
            }
        }
    }

    // 新增服务器状态检查方法
    func checkServerStatus() {
        guard let url = URL(string: "http://localhost:8080/ping") else {
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                // 在请求完成后设置弹窗触发状态
                self.showServerAlert = true

                if let error: any Error = error {
                    print("服务器检查失败: \(error.localizedDescription)")
                    self.isServerHealthy = false
                    return
                }

                if let httpResponse: HTTPURLResponse = response
                    as? HTTPURLResponse, httpResponse.statusCode == 200
                {
                    self.isServerHealthy = true
                } else {
                    self.isServerHealthy = false
                }
            }
        }.resume()
    }

    // 新增获取窗口信息的方法
    private func getCurrentWindowInfo() {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        if result == .success {
            // // 获取焦点元素的标题
            // var title: AnyObject?
            // AXUIElementCopyAttributeNames(
            //     focusedElement as! AXUIElement,
            //     kAXTitleAttribute as CFString,
            //     &title
            // )
            
            // 获取所有可用的属性名称
            var attributeNames: CFArray?
            AXUIElementCopyAttributeNames(focusedElement as! AXUIElement, &attributeNames)

            for attributeName in attributeNames as? [CFString] ?? [] {
                var value: AnyObject?
                let result = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, attributeName, &value)
                if result == .success {
                    print("属性名称: \(attributeName), 值: \(value)")
                }
            }

            var children: AnyObject?
            AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXChildrenAttribute as CFString, &children)
            if let childrenArray = children as? [AXUIElement] {
                for (index, child) in childrenArray.enumerated() {
                    print("\n--- 子元素 #\(index + 1) ---")
                    
                    // 获取角色
                    var role: AnyObject?
                    AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                    print("角色: \(role)")
                    
                    // 获取标题
                    var title: AnyObject?
                    AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
                    print("标题: \(title)")
                    
                    // 获取描述
                    var description: AnyObject?
                    AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &description)
                    // 使用可选绑定来安全地解包
                    if let descriptionString = description as? String {
                        print("描述: \(descriptionString)")
                    } else {
                        print("描述: 无")
                    }
                    
                    // 获取值
                    var value: AnyObject?
                    AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &value)
                    print("值: \(value)")
                    
                    // 获取所有属性名称
                    var attributeNames: CFArray?
                    AXUIElementCopyAttributeNames(child, &attributeNames)
                    print("所有属性: \(attributeNames ?? [] as CFArray)")
                }

             // 获取第一个 AXGroup 元素
            let firstGroup = childrenArray[0]
            
            // 获取 AXGroup 的子元素
            var groupChildren: AnyObject?
            AXUIElementCopyAttributeValue(firstGroup, kAXChildrenAttribute as CFString, &groupChildren)
            
            if let groupChildrenArray = groupChildren as? [AXUIElement] {
                print("\n=== AXGroup 的子元素 ===")
                for (index, groupChild) in groupChildrenArray.enumerated() {
                    print("\n--- 子元素 #\(index + 1) ---")
                    
                    // 获取角色
                    var role: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXRoleAttribute as CFString, &role)
                    print("角色: \(role)")

                    // 获取 label 
                    var label: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXLabelValueAttribute as CFString, &label)
                    print("label值: \(label)")
                    
                    // 获取标题
                    var title: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXTitleAttribute as CFString, &title)
                    print("标题: \(title)")
                    
                    // 获取值
                    var value: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXValueAttribute as CFString, &value)
                    print("值: \(value)")
                    
                    // 获取所有属性名称
                    var attributeNames: CFArray?
                    AXUIElementCopyAttributeNames(groupChild, &attributeNames)
                    print("所有属性: \(attributeNames ?? [] as CFArray)")

                    // 获取更多可能的属性
                    var description: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXDescriptionAttribute as CFString, &description)
                    // 使用可选绑定来安全地解包
                    if let descriptionString = description as? String {
                        print("描述: \(descriptionString)")
                    } else {
                        print("描述: 无")
                    }
                    
                    var identifier: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXIdentifierAttribute as CFString, &identifier)
                    print("标识符: \(identifier)")
                }
            } else {
                print("AXGroup 没有子元素")
            }
            }

        } else {
            print("获取聚焦元素失败")
        }
    }
}

#Preview {
    ContentView()
}
