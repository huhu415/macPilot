import Cocoa

class AccessibilityManager: ObservableObject {
    // 发布属性用于 SwiftUI 绑定
    @Published var accessibilityInfo: String = ""
    @Published var focusedWindowPID: pid_t = 0
    @Published var focusedAppName: String = ""

    init() {
        // 检查辅助功能权限
        checkAccessibilityPermissions()
    }

    // 检查辅助功能权限
    public func checkAccessibilityPermissions() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(
            options as CFDictionary)

        if !accessibilityEnabled {
            DispatchQueue.main.async {
                self.accessibilityInfo = "请在系统偏好设置中启用辅助功能权限"
            }
        }
    }

    // 新增获取窗口信息的方法
    public func getCurrentWindowInfo() {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement, kAXFocusedUIElementAttribute as CFString,
            &focusedElement)
        if result == .success {
            var children: AnyObject?
            AXUIElementCopyAttributeValue(
                focusedElement as! AXUIElement,
                kAXChildrenAttribute as CFString, &children)
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
            AXUIElementCopyAttributeValue(
                firstGroup, kAXChildrenAttribute as CFString, &groupChildren)

            if let groupChildrenArray = groupChildren as? [AXUIElement] {
                var infoText = "\n=== AXGroup 的子元素 ===\n"

                for (index, groupChild) in groupChildrenArray.enumerated() {
                    infoText += "\n--- 子元素 #\(index + 1) ---\n"

                    // 获取角色
                    var role: AnyObject?
                    AXUIElementCopyAttributeValue(
                        groupChild, kAXRoleAttribute as CFString, &role)
                    infoText += "角色: \(role)\n"

                    // 获取 label
                    var label: AnyObject?
                    AXUIElementCopyAttributeValue(
                        groupChild, kAXLabelValueAttribute as CFString, &label)
                    infoText += "label值: \(label)\n"

                    // 获取标题
                    var title: AnyObject?
                    AXUIElementCopyAttributeValue(
                        groupChild, kAXTitleAttribute as CFString, &title)
                    infoText += "标题: \(title)\n"

                    // 获取值
                    var value: AnyObject?
                    AXUIElementCopyAttributeValue(
                        groupChild, kAXValueAttribute as CFString, &value)
                    infoText += "值: \(value)\n"

                    // 获取更多可能的属性
                    var description: AnyObject?
                    AXUIElementCopyAttributeValue(
                        groupChild, kAXDescriptionAttribute as CFString,
                        &description)
                    if let descriptionString = description as? String {
                        infoText += "描述: \(descriptionString)\n"
                    } else {
                        infoText += "描述: 无\n"
                    }

                    var identifier: AnyObject?
                    AXUIElementCopyAttributeValue(
                        groupChild, kAXIdentifierAttribute as CFString,
                        &identifier)
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
        AXUIElementCopyAttributeValue(
            element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(
            element, kAXTitleAttribute as CFString, &title)
        AXUIElementCopyAttributeValue(
            element, kAXValueAttribute as CFString, &value)
        AXUIElementCopyAttributeValue(
            element, kAXDescriptionAttribute as CFString, &description)

        // 添加属性到结果字典
        result["role"] = (role as? String) ?? "unknown"
        result["title"] = (title as? String) ?? ""
        result["value"] = (value as? String) ?? ""
        result["description"] = (description as? String) ?? ""

        // 处理子元素
        var children: AnyObject?
        AXUIElementCopyAttributeValue(
            element, kAXChildrenAttribute as CFString, &children)
        if let childrenArray = children as? [AXUIElement],
            !childrenArray.isEmpty
        {
            var transformedArray: [[String: Any]] = []
            for element in childrenArray {
                transformedArray.append(dfs(element: element))
            }
            result["children"] = transformedArray
        }

        return result
    }

    // 新增用于导出 JSON 的辅助方法
    public func exportAccessibilityTreeToJSON(element: AXUIElement) {
        let tree = dfs(element: element)

        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: tree, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                // 显示在界面上
                DispatchQueue.main.async {
                    self.accessibilityInfo = jsonString
                }
            }
        } catch {
            print("JSON 序列化错误: \(error.localizedDescription)")
        }
    }

    // 获取焦点窗口信息的方法
    public func getFocusedWindowInfo() {
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement, kAXFocusedUIElementAttribute as CFString,
            &focusedElement)

        // 添加详细的错误信息记录
        if result != .success {
            print("获取焦点窗口失败 - 错误代码: \(result.rawValue)")
            DispatchQueue.main.async {
                self.focusedWindowPID = 0
                self.focusedAppName = "未知"
                // self.accessibilityInfo = "获取焦点失败: \(result.rawValue)"
            }
            return
        }

        let focusedUIElement = focusedElement as! AXUIElement
        var pid: pid_t = 0
        let pidResult = AXUIElementGetPid(focusedUIElement, &pid)
        
        if pidResult != .success {
            print("获取PID失败 - 错误代码: \(pidResult.rawValue)")
            return
        }
        
        // 使用 pid 获取应用名称
        if let app = NSRunningApplication(processIdentifier: pid) {
            DispatchQueue.main.async {
                self.focusedWindowPID = pid
                self.focusedAppName = app.localizedName ?? "未知"

                // print("获取到焦点窗口 - PID: \(pid), 应用名称: \(self.focusedAppName)")
            }
        }
    }

    // 新增根据PID获取窗口信息的方法
    public func getWindowInfoByPID(_ pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)
        var windowList: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXWindowsAttribute as CFString, &windowList)

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
