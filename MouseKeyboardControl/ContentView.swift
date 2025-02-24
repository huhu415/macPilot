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
    @State private var accessibilityInfo: String = ""  // 新增状态变量
    @State private var inputPID: String = ""  // 新增状态变量用于存储输入的PID
    @StateObject private var accessibilityManager = AccessibilityManager()

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

            Button("获取窗口信息") {
                let options = CGWindowListOption(
                    arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
                let windowList =
                    CGWindowListCopyWindowInfo(options, kCGNullWindowID) as! [[String: Any]]

                for window in windowList {
                    let windowNumber = window[kCGWindowNumber as String] as! Int
                    let windowOwnerName = window[kCGWindowOwnerName as String] as? String
                    let windowOwnerPID = window[kCGWindowOwnerPID as String] as! Int
                    let windowName = window[kCGWindowName as String] as? String ?? "未知窗口"

                    print("窗口名称: \(windowName)")
                    print("Window Number: \(windowNumber)")
                    print("进程 PID: \(windowOwnerPID)")
                    print("进程名称: \(windowOwnerName ?? "未知")")
                    print("-------------------")
                }
            }

            HStack {
                TextField("输入进程 PID", text: $inputPID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 120)

                Button("根据PID获取窗口信息") {
                    if let pid = pid_t(inputPID) {
                        accessibilityManager.getWindowInfoByPID(pid)
                    }
                }
            }

            VStack {
                Text("当前应用: \(accessibilityManager.focusedAppName)")
                Text("PID: \(accessibilityManager.focusedWindowPID)")
                Text("Window ID: \(accessibilityManager.focusedWindowID)")
                Text(accessibilityManager.accessibilityInfo)
            }
            .padding()

            // 显示 Accessibility 信息
            VStack {
                HStack {
                    Text("Accessibility 信息")
                    Spacer()
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(
                            accessibilityInfo, forType: .string)
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
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                mousePosition = InputControl.getCurrentMousePosition()
                accessibilityManager.getFocusedWindowInfo()
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
}

#Preview {
    ContentView()
}
