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
    @Published var focusedWindowID: UInt32 = 0
    @Published var focusedWindowPID: pid_t = 0
    @Published var focusedAppName: String = ""

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
                withJSONObject: tree,
                options: [.prettyPrinted, .sortedKeys]
            )
            if let jsonStr = String(data: jsonData, encoding: .utf8) {
                jsonString = jsonStr
            }
        } catch {
            print("JSON 序列化错误: \(error.localizedDescription)")
            jsonString = "{\"error\": \"JSON 序列化失败\"}"
        }

        return jsonString
    }

    // 获取焦点窗口PID NAME windowID
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
            return "获取焦点窗口失败"
        }

        // 获取窗口
        var window: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(
            focusedUIElement as! AXUIElement, kAXWindowAttribute as CFString,
            &window)

        guard windowResult == .success, let windowUIElement = window else {
            return "获取窗口失败"
        }

        // 导出窗口的辅助功能树结构为JSON
        return exportAccessibilityTreeToJSON(
            element: windowUIElement as! AXUIElement)
    }

    // 根据PID获取窗口结构
    public func getWindowInfoByPID(_ pid: pid_t) -> String {
        let appElement = AXUIElementCreateApplication(pid)
        var windowList: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXWindowsAttribute as CFString, &windowList)

        if result == .success, let windows = windowList as? [AXUIElement] {
            for window in windows {
                let jsonString = exportAccessibilityTreeToJSON(element: window)
                return jsonString  // 只处理第一个窗口
            }
        }
        return "获取窗口信息失败"
    }

    // 获取pid为1500以上的窗口信息列表
    public func getWindowsListInfo() -> String {
        var windowsArray: [[String: Any]] = []
        let options = CGWindowListOption(
            arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        let windowList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID)
            as! [[String: Any]]

        for window in windowList {
            let windowOwnerPID = window[kCGWindowOwnerPID as String] as! Int
            if windowOwnerPID < 1500 {
                continue
            }
            windowsArray.append(window)
        }

        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: windowsArray,
                options: .prettyPrinted
            )
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            print("JSON 序列化错误: \(error.localizedDescription)")
        }

        return "{\"error\": \"JSON 序列化失败\"}"
    }
}
