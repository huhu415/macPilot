import AppKit
import ApplicationServices
import Foundation

class InputControl {
    // 移动鼠标到指定位置
    static func moveMouse(to point: CGPoint) {
        let moveEvent = CGEvent(
            mouseEventSource: nil, mouseType: .mouseMoved,
            mouseCursorPosition: point, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
    }

    // 模拟鼠标点击
    static func mouseClick(at point: CGPoint) {
        let clickDown = CGEvent(
            mouseEventSource: nil, mouseType: .leftMouseDown,
            mouseCursorPosition: point, mouseButton: .left)
        let clickUp = CGEvent(
            mouseEventSource: nil, mouseType: .leftMouseUp,
            mouseCursorPosition: point, mouseButton: .left)

        clickDown?.post(tap: .cghidEventTap)
        clickUp?.post(tap: .cghidEventTap)
    }

    // 模拟键盘按键
    static func pressKey(keyCode: CGKeyCode) {
        let keyDown = CGEvent(
            keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(
            keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // 获取当前鼠标位置
    static func getCurrentMousePosition() -> CGPoint {
        return NSEvent.mouseLocation
    }

    // 模拟组合按键（如 Command + C）
    static func pressKeys(modifiers: CGEventFlags, keyCodes: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)

        // 创建按键事件，并设置修饰键
        let keyDown = CGEvent(
            keyboardEventSource: source, virtualKey: keyCodes, keyDown: true)
        let keyUp = CGEvent(
            keyboardEventSource: source, virtualKey: keyCodes, keyDown: false)

        // 设置修饰键标志
        keyDown?.flags = modifiers
        keyUp?.flags = modifiers

        // 发送事件
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
