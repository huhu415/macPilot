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
    @State private var focusedWindowPID: pid_t = 0
    @State private var focusedAppName: String = "未知"  // 新增状态变量
    @State private var inputPID: String = ""  // 新增状态变量用于存储输入的PID

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

            HStack {
                TextField("输入进程 PID", text: $inputPID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 120)
                
                Button("根据PID获取窗口信息") {
                    if let pid = pid_t(inputPID) {
                        getWindowInfoByPID(pid)
                    }
                }
            }

            Text("当前窗口PID: \(focusedWindowPID)")
                .padding()
            Text("当前应用名称: \(focusedAppName)")
                .padding()

            // 显示 Accessibility 信息
            VStack {
                HStack {
                    Text("Accessibility 信息")
                    Spacer()
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(accessibilityInfo, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                        Text("复制")
                    }
                }
                .padding(.horizontal)
                
                ScrollView {
                    Text(accessibilityInfo)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
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

            // 添加定时器获取焦点窗口信息
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                mousePosition = InputControl.getCurrentMousePosition()
                updateFocusedWindowInfo()
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

            exportAccessibilityTreeToJSON(element: firstGroup)
            
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

    private func dfs(element: AXUIElement) -> [String: Any] {
        var result: [String: Any] = [:]
        
        // 获取当前元素的基本属性
        var role: AnyObject?
        var title: AnyObject?
        var value: AnyObject?
        var description: AnyObject?
        
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        
        // 添加属性到结果字典
        result["role"] = (role as? String) ?? "unknown"
        result["title"] = (title as? String) ?? ""
        result["value"] = (value as? String) ?? ""
        result["description"] = (description as? String) ?? ""
        
        // 处理子元素
        var children: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        if let childrenArray = children as? [AXUIElement], !childrenArray.isEmpty {
            result["children"] = childrenArray.map { dfs(element: $0) }
        }
        
        return result
    }
    
    // 新增用于导出 JSON 的辅助方法
    private func exportAccessibilityTreeToJSON(element: AXUIElement) {
        let tree = dfs(element: element)
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: tree, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                // 可以选择将 JSON 保存到文件或显示在界面上
                print(jsonString)
                DispatchQueue.main.async {
                    self.accessibilityInfo = jsonString
                }
            }
        } catch {
            print("JSON 序列化错误: \(error.localizedDescription)")
        }
    }

    // 新增获取当前焦点窗口PID的方法
    private func getFocusedWindowPID() {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if result == .success {
            let focusedUIElement = focusedElement as! AXUIElement
            var pid: pid_t = 0
            AXUIElementGetPid(focusedUIElement, &pid)
            
            DispatchQueue.main.async {
                self.focusedWindowPID = pid
                print("获取到焦点窗口PID: \(pid)")
            }
        } else {
            print("获取焦点窗口失败")
            DispatchQueue.main.async {
                self.focusedWindowPID = 0
            }
        }
    }

    // 新增更新焦点窗口信息的方法
    private func updateFocusedWindowInfo() {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if result == .success {
            let focusedUIElement = focusedElement as! AXUIElement
            var pid: pid_t = 0
            AXUIElementGetPid(focusedUIElement, &pid)
            
            // 使用 pid 获取应用名称
            if let app = NSRunningApplication(processIdentifier: pid) {
                DispatchQueue.main.async {
                    self.focusedWindowPID = pid
                    self.focusedAppName = app.localizedName ?? "未知"
                }
            }
        }
    }

    // 新增根据PID获取窗口信息的方法
    private func getWindowInfoByPID(_ pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)
        var windowList: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList)
        
        if result == .success, let windows = windowList as? [AXUIElement] {
            for window in windows {
                exportAccessibilityTreeToJSON(element: window)
                return  // 只处理第一个窗口
            }
        } else {
            DispatchQueue.main.async {
                self.accessibilityInfo = "无法获取PID \(pid) 的窗口信息"
            }
        }
    }
}

#Preview {
    ContentView()
}
