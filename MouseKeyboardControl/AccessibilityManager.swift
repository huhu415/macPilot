import Cocoa

// 在文件顶部添加私有 API 声明
private let AXValueType_CGPoint = 1
private let AXValueType_CGSize = 2
private let AXValueType_CGRect = 3
private let AXValueType_CFRange = 4

// 声明私有 API
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(
    _ axElement: AXUIElement, _ windowId: UnsafeMutablePointer<CGWindowID>
)
    -> AXError

class AccessibilityManager: ObservableObject {
    // 发布属性用于 SwiftUI 绑定
    @Published var accessibilityInfo: String = ""
    @Published var focusedWindowID: UInt32 = 0
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

            // 接收返回的 JSON 字符串
            let jsonString = exportAccessibilityTreeToJSON(element: firstGroup)

            // 更新 UI
            DispatchQueue.main.async {
                self.accessibilityInfo = jsonString
            }

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

        // 定义要获取的属性列表
        let attributes: [(String, String)] = [
            (kAXRoleAttribute, "role"),
            (kAXSubroleAttribute, "subrole"),
            (kAXRoleDescriptionAttribute, "roleDescription"),
            (kAXTitleAttribute, "title"),
            (kAXValueAttribute, "value"),
            (kAXDescriptionAttribute, "description"),
            (kAXHelpAttribute, "help"),
            (kAXEnabledAttribute, "enabled"),
            (kAXFocusedAttribute, "focused"),
            (kAXPositionAttribute, "position"),
            (kAXSizeAttribute, "size"),
            (kAXWindowAttribute, "window"),
            (kAXSelectedAttribute, "selected"),
            (kAXExpandedAttribute, "expanded"),
            (kAXIdentifierAttribute, "identifier"),
            (kAXURLAttribute, "url"),
            (kAXIndexAttribute, "index"),
            (kAXTextAttribute, "text"),
            (kAXPlaceholderValueAttribute, "placeholder"),
            (kAXIsEditableAttribute, "isEditable"),
            (kAXMainAttribute, "isMain"),
            (kAXMinimizedAttribute, "isMinimized"),
            (kAXModalAttribute, "isModal"),
        ]

        // 获取每个属性的值
        for (attributeName, resultKey) in attributes {
            var attributeValue: AnyObject?
            let status = AXUIElementCopyAttributeValue(
                element,
                attributeName as CFString,
                &attributeValue
            )

            if status == .success {
                switch attributeValue {
                case let value as String:
                    result[resultKey] = value
                case let value as Bool:
                    result[resultKey] = value
                case let value as Int:
                    result[resultKey] = value
                case let value as CGPoint:
                    result[resultKey] = ["x": value.x, "y": value.y]
                case let value as CGSize:
                    result[resultKey] = [
                        "width": value.width, "height": value.height,
                    ]
                case let value as NSValue:
                    if String(describing: value).contains("NSPoint") {
                        let point = value.pointValue
                        result[resultKey] = ["x": point.x, "y": point.y]
                    } else if String(describing: value).contains("NSSize") {
                        let size = value.sizeValue
                        result[resultKey] = [
                            "width": size.width, "height": size.height,
                        ]
                    }
                default:
                    if let stringValue = attributeValue as? String {
                        result[resultKey] = stringValue
                    }
                }
            }
        }

        // 处理子元素
        var children: AnyObject?
        AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &children
        )
        if let childrenArray = children as? [AXUIElement],
            !childrenArray.isEmpty
        {
            var transformedArray: [[String: Any]] = []
            for childElement in childrenArray {
                transformedArray.append(dfs(element: childElement))
            }
            result["children"] = transformedArray
        }

        return result
    }

    // 修改用于导出 JSON 的辅助方法，返回 JSON 字符串
    private func exportAccessibilityTreeToJSON(element: AXUIElement) -> String {
        let tree = dfs(element: element)
        var jsonString = ""

        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: tree, options: .prettyPrinted)
            if let jsonStr = String(data: jsonData, encoding: .utf8) {
                jsonString = jsonStr
            }
        } catch {
            print("JSON 序列化错误: \(error.localizedDescription)")
            jsonString = "{\"error\": \"JSON 序列化失败\"}"
        }

        return jsonString
    }

    // 获取焦点窗口信息的方法
    public func getFocusedWindowInfo() {
        let systemWideElement = AXUIElementCreateSystemWide()

        // 获取聚焦元素
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement, kAXFocusedUIElementAttribute as CFString,
            &focusedElement)

        // 添加错误处理
        if result != .success {
            print("获取焦点窗口失败: \(result)")
            return
        }

        guard result == .success,
            let focusedUIElement = focusedElement
        else {
            print("获取焦点窗口失败 - 错误代码: \(result.rawValue)")
            DispatchQueue.main.async {
                self.focusedAppName = "未知"
                self.focusedWindowID = 0
                self.focusedWindowPID = 0
            }
            return
        }

        // 通过聚焦元素获取PID
        var pid: pid_t = 0
        let pidResult = AXUIElementGetPid(
            focusedUIElement as! AXUIElement, &pid)

        if pidResult != .success {
            print("获取PID失败 - 错误代码: \(pidResult.rawValue)")
            DispatchQueue.main.async {
                self.focusedAppName = "未知"
                self.focusedWindowID = 0
                self.focusedWindowPID = 0
            }
            return
        }

        let appElement = AXUIElementCreateApplication(pid)

        // 获取应用名称
        var appName: AnyObject?
        let appNameResult = AXUIElementCopyAttributeValue(
            appElement, kAXTitleAttribute as CFString, &appName)

        // 获取窗口信息
        var windowList: CFTypeRef?
        let windowListResult = AXUIElementCopyAttributeValue(
            appElement, kAXWindowsAttribute as CFString, &windowList)

        // 获取窗口
        var window: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(
            focusedUIElement as! AXUIElement,
            kAXWindowAttribute as CFString, &window)

        DispatchQueue.main.async {
            self.focusedWindowPID = pid
            self.focusedAppName = "未知"
            self.focusedWindowID = 0

            // 更新应用名称
            if appNameResult == .success {
                self.focusedAppName = appName as! String
            }

            // 获取窗口列表
            if windowListResult == .success,
                let windows = windowList as? [AXUIElement]
            {
                print("窗口列表: \(windows)")
            }

            // 更新窗口ID
            if windowResult == .success {
                print("windowResult success")
                let windowUIElement = window as! AXUIElement
                var windowRef: CGWindowID = 0
                let windowsNum = _AXUIElementGetWindow(
                    windowUIElement, &windowRef)

                if windowsNum == .success {
                    self.focusedWindowID = windowRef
                } else {
                    print("获取窗口ID失败 - 错误代码: \(windowsNum.rawValue)")
                    self.focusedWindowID = 0
                }
            }
        }
    }

    // 根据聚焦窗口获取窗口结构
    public func getWindowStructure() -> String {
        let systemWideElement = AXUIElementCreateSystemWide()

        // 获取聚焦元素
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement, kAXFocusedUIElementAttribute as CFString,
            &focusedElement)

        guard result == .success, let focusedUIElement = focusedElement else {
            print("获取焦点窗口失败 - 错误代码: \(result.rawValue)")
            DispatchQueue.main.async {
                self.accessibilityInfo = "无法获取焦点窗口"
            }
            return "获取焦点窗口失败"
        }

        // 获取窗口
        var window: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(
            focusedUIElement as! AXUIElement, kAXWindowAttribute as CFString,
            &window)

        guard windowResult == .success, let windowUIElement = window else {
            print("获取窗口失败 - 错误代码: \(windowResult.rawValue)")
            DispatchQueue.main.async {
                self.accessibilityInfo = "无法获取当前焦点元素的窗口"
            }
            return "获取窗口失败"
        }

        // 导出窗口的辅助功能树结构为JSON
        return exportAccessibilityTreeToJSON(
            element: windowUIElement as! AXUIElement)
    }

    // 新增根据PID获取窗口信息的方法
    public func getWindowInfoByPID(_ pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)
        var windowList: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXWindowsAttribute as CFString, &windowList)

        if result == .success, let windows = windowList as? [AXUIElement] {
            for window in windows {
                let jsonString = exportAccessibilityTreeToJSON(element: window)

                // 更新 UI
                DispatchQueue.main.async {
                    self.accessibilityInfo = jsonString
                }

                return  // 只处理第一个窗口
            }
        } else {
            DispatchQueue.main.async {
                self.accessibilityInfo = "无法获取PID \(pid) 的窗口信息"
            }
        }
    }
}
