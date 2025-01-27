import Foundation
import ApplicationServices
import AppKit

class InputControl {
    // 移动鼠标到指定位置
    static func moveMouse(to point: CGPoint) {
        let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                              mouseCursorPosition: point, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
    }
    
    // 模拟鼠标点击
    static func mouseClick(at point: CGPoint) {
        let clickDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                              mouseCursorPosition: point, mouseButton: .left)
        let clickUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                            mouseCursorPosition: point, mouseButton: .left)
        
        clickDown?.post(tap: .cghidEventTap)
        clickUp?.post(tap: .cghidEventTap)
    }
    
    // 模拟键盘按键
    static func pressKey(keyCode: CGKeyCode) {
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    // 获取当前鼠标位置
    static func getCurrentMousePosition() -> CGPoint {
        return NSEvent.mouseLocation
    }
} 