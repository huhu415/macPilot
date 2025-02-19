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
            var children: AnyObject?
            AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXChildrenAttribute as CFString, &children)
            let childrenArray = children as? [AXUIElement]
            if childrenArray!.count <= 0 {
                print("获取聚焦元素的子元素失败")
                return
            }
            // 获取第一个 children
            let firstGroup = childrenArray![0]
            
            // 获取 AXGroup 的子元素
            var groupChildren: AnyObject?
            AXUIElementCopyAttributeValue(firstGroup, kAXChildrenAttribute as CFString, &groupChildren)
            
            if let groupChildrenArray = groupChildren as? [AXUIElement] {
                var infoText = "\n=== AXGroup 的子元素 ===\n"
                
                for (index, groupChild) in groupChildrenArray.enumerated() {
                    infoText += "\n--- 子元素 #\(index + 1) ---\n"
                    
                    // 获取角色
                    var role: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXRoleAttribute as CFString, &role)
                    infoText += "角色: \(role)\n"

                    // 获取 label 
                    var label: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXLabelValueAttribute as CFString, &label)
                    infoText += "label值: \(label)\n"
                    
                    // 获取标题
                    var title: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXTitleAttribute as CFString, &title)
                    infoText += "标题: \(title)\n"
                    
                    // 获取值
                    var value: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXValueAttribute as CFString, &value)
                    infoText += "值: \(value)\n"
                    
                    // 获取更多可能的属性
                    var description: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXDescriptionAttribute as CFString, &description)
                    if let descriptionString = description as? String {
                        infoText += "描述: \(descriptionString)\n"
                    } else {
                        infoText += "描述: 无\n"
                    }
                    
                    var identifier: AnyObject?
                    AXUIElementCopyAttributeValue(groupChild, kAXIdentifierAttribute as CFString, &identifier)
                    infoText += "标识符: \(identifier)\n"

                    // 获取所有属性名称
                    var attributeNames: CFArray?
                    AXUIElementCopyAttributeNames(groupChild, &attributeNames)
                    infoText += "所有属性: \(attributeNames ?? [] as CFArray)\n"
                }
                
                // 更新 UI 需要在主线程进行
                DispatchQueue.main.async {
                    self.accessibilityInfo = infoText
                }
            } else {
                DispatchQueue.main.async {
                    self.accessibilityInfo = "AXGroup 没有子元素"
                }
            }
        } else {
            DispatchQueue.main.async {
                self.accessibilityInfo = "获取聚焦元素失败"
            }
        }
    }
}

#Preview {
    ContentView()
}
