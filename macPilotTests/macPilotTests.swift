//
//  macPilotTests.swift
//  macPilotTests
//
//  Created by 张重言 on 2025/3/3.
//

import Testing
import Foundation

struct macPilotTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func testCursorEndpoint() async throws {
        // 发送请求获取鼠标位置
        let url = URL(string: "http://localhost:8080/cursor")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // 验证响应状态码
        let httpResponse = response as! HTTPURLResponse
        #expect(httpResponse.statusCode == 200)
        
        // 验证返回的JSON数据
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let x = json["x"] as! Double
        let y = json["y"] as! Double
        
        // 验证屏幕信息
        let screen = json["screen"] as! [String: Any]
        let width = screen["width"] as! Double
        let height = screen["height"] as! Double
        let scale = screen["scale"] as! Double
        
        // 打印具体数值
        print("鼠标位置: x=\(x), y=\(y)")
        print("屏幕信息: 宽度=\(width), 高度=\(height), 缩放比例=\(scale)")
        
        // 验证数据存在
        #expect(json["x"] != nil)
        #expect(json["y"] != nil)
        #expect(screen["width"] != nil)
        #expect(screen["height"] != nil)
        #expect(screen["scale"] != nil)
    }

    @Test func testExecutePwdCommand() async throws {
        // 准备请求URL和数据
        let url = URL(string: "http://localhost:8080/execute")!
        let requestData: [String: Any] = [
            "command": "ls",
            "args": ["-a", "-l"]
        ]
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 验证响应状态码
        let httpResponse = response as! HTTPURLResponse
        #expect(httpResponse.statusCode == 200)
        
        // 解析响应数据
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        // 验证响应格式
        #expect(json["exitStatus"] != nil)
        #expect(json["output"] != nil)
        #expect(json["error"] != nil)
        
        // 验证命令执行结果
        #expect(json["exitStatus"] as! Int == 0)
        #expect((json["output"] as! String).isEmpty == false)
        #expect(json["error"] as! String == "")
        
        // 打印结果
        print("命令执行结果:")
        print("退出状态: \(json["exitStatus"] as! Int)")
        print("输出: \(json["output"] as! String)")
        print("错误: \(json["error"] as! String)")
    }

}
