# MouseKeyboardControl for macOS

这是一个为osWorld项目开发的macOS适配器，用于在macOS系统上实现鼠标和键盘控制、屏幕截图等功能。

## 功能特性

- 鼠标控制
  - 获取鼠标位置
  - 移动鼠标到指定位置
  - 模拟鼠标点击
- 键盘控制
  - 模拟按键输入
  - 支持组合键操作
- 屏幕操作
  - 全屏截图
  - 高质量图像捕获
- HTTP API接口
  - RESTful API设计
  - JSON数据交互
  - 支持远程控制

## API 端点

服务器默认运行在 `8080` 端口

### 鼠标控制
- `GET /cursor_position` - 获取当前鼠标位置和屏幕信息
- `GET /click_mouse` - 点击鼠标
- `POST /move_mouse` - 移动鼠标到指定位置
  ```json
  {
    "x": 100,  // 整数或字符串
    "y": 200   // 整数或字符串
  }
  ```

### 文本操作
- `POST /paste` - 在当前位置粘贴文本
  ```json
  {
    "text": "要粘贴的文本内容"
  }
  ```

### 命令执行
- `POST /execute` - 执行系统命令
  ```json
  {
    "command": "命令名称",
    "args": ["参数1", "参数2"]  // 可选
  }
  ```

### 应用控制
- `POST /open_app` - 打开指定应用
  ```json
  {
    "type": "bundleId",  // 或 "appName"
    "value": "com.apple.Safari"  // bundleId或应用名称
  }
  ```
- `GET /list_apps` - 获取已安装应用列表
- `GET /screenshot` - 获取全屏截图

## 系统要求

- macOS 14.0 或更高版本
- Xcode 16.2 或更高版本（用于开发）

## 安装说明

1. 克隆项目到本地
2. 使用Xcode打开项目
3. 构建并运行项目
4. 授予必要的系统权限：
   - 辅助功能权限（用于鼠标和键盘控制）
   - 屏幕录制权限（用于截图功能）
   - 网络访问权限（用于HTTP服务器）
5. 注意在可信任的网络环境中使用

## TODO

- [ ] 增加鼠标滚动
- [ ] 增加accessibility结构
- [ ] 增加对于文件的操作, 比如上传, 下载, 打开等
- [ ] 完全适配osWorld项目

## 贡献

欢迎提交问题和改进建议！

## 致谢

感谢osWorld项目团队的支持。
