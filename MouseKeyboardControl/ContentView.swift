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
}

struct ContentView: View {
    @State private var mousePosition: CGPoint = .zero
    @State private var stream: SCStream?
    @State private var screenCaptureManager = ScreenCaptureManager()
    @State private var screenshotImage: NSImage?  // 新增状态用于存储截图
    @State private var errorMessage = ""         // 新增状态用于错误信息
    private let serialQueue = DispatchQueue(label: "com.screenshot.serial")

    var body: some View {
        VStack(spacing: 20) {
            Text("当前鼠标位置: \(Int(mousePosition.x)), \(Int(mousePosition.y))")

            Button("移动鼠标到屏幕中心") {
                let screenFrame = NSScreen.main?.frame ?? .zero
                let centerPoint = CGPoint(
                    x: screenFrame.width / 2, y: screenFrame.height / 2)
                InputControl.moveMouse(to: centerPoint)
            }

            Button("模拟鼠标点击") {
                InputControl.mouseClick(at: mousePosition)
            }

            Button("按下空格键") {
                InputControl.pressKey(keyCode: 49)  // 49是空格键的键码
            }

            Button("截取屏幕") {
                takeScreenshot()
            }

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
            ServerManager.shared.startServer()

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
}

// 添加 ScreenCaptureManager 类
class ScreenCaptureManager: NSObject, SCStreamDelegate, SCStreamOutput {
    private var stream: SCStream?  // 这是一个可选类型的属性
    private var hasProcessedFrame = false  // 添加标志位来追踪是否已处理过帧
    private var completionHandler: ((NSImage?) -> Void)?

    // 捕获全屏截图
    func captureFullScreen(completion: @escaping (NSImage?) -> Void) {
        self.completionHandler = completion
        
        SCShareableContent.getWithCompletionHandler {
            [weak self] content, error in
            guard let self = self else { return }

            if let error = error {
                print("获取共享内容失败: \(error.localizedDescription)")
                self.completionHandler?(nil)
                return
            }

            guard let content = content, !content.displays.isEmpty else {
                print("未找到可用的显示器")
                self.completionHandler?(nil)
                return
            }

            let primaryDisplay = content.displays[0]
            let filter = SCContentFilter(
                display: primaryDisplay, excludingWindows: [])

            // 获取主屏幕缩放因子
            let scaleFactor = NSScreen.main?.backingScaleFactor ?? 1.0

            // 计算实际像素尺寸
            let pixelWidth = Int(CGFloat(primaryDisplay.width) * scaleFactor)
            let pixelHeight = Int(CGFloat(primaryDisplay.height) * scaleFactor)

            let config = SCStreamConfiguration()
            config.capturesAudio = false
            config.width = pixelWidth  // 设置物理像素宽度
            config.height = pixelHeight  // 设置物理像素高度

            do {
                self.stream = SCStream(
                    filter: filter, configuration: config, delegate: self)
                try self.stream?.addStreamOutput(
                    self, type: .screen,
                    sampleHandlerQueue: .global(qos: .userInteractive))
                self.stream?.startCapture()
            } catch {
                print("创建流失败: \(error.localizedDescription)")
                self.stream = nil
                self.completionHandler?(nil)
            }
        }
    }

    // 处理捕获到的帧, 这是回调
    func stream(
        _ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen && !hasProcessedFrame else { return }

        if let image = NSImage(from: sampleBuffer) {
            hasProcessedFrame = true
            self.completionHandler?(image)
            stream.stopCapture { [weak self] error in
                if let error = error {
                    print("停止捕获失败: \(error)")
                }
                self?.stream = nil
                self?.hasProcessedFrame = false
                self?.completionHandler = nil
            }
        }
    }
}

// 处理CMSampleBuffer
extension NSImage {
    convenience init?(from sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return nil }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)

        // 使用高质量渲染选项
        let context = CIContext(options: [
            .highQualityDownsample: true,
            .useSoftwareRenderer: false,
        ])

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        else { return nil }
        self.init(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

#Preview {
    ContentView()
}
