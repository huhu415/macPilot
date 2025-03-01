# MouseKeyboardControl for macOS

A macOS application with HTTP that provides APIs for mouse/keyboard control and system information.

## Endpoints

### Mouse Control
- `GET /cursor` - Get current mouse position and screen info
- `GET /cursor/move?x=100&y=200` - Move mouse to specified coordinates
- `GET /cursor/click` - Click at current mouse position

### Keyboard Control
- `POST /paste` - Paste text at current cursor position
  ```json
  { "text": "content to paste" }
  ```

### System Operations
- `GET /screenshot` - Capture full screen (returns JPEG image)
- `POST /execute` - Execute shell command
  ```json
  {
    "command": "ls",
    "args": ["-l"]  // optional
  }
  ```

### Application Management
- `GET /apps` - List all installed applications
- `GET /apps/launch` - Launch application
  - Query params: `bundleId` or `appName` (one required)
  - Example: `/apps/launch?bundleId=com.apple.Safari`

### Window Management
- `GET /windows` - List all windows
- `GET /windows/info` - Get window information
  - Query params: `pid` (optional, get specific window info)
  - Without pid: returns focused window info

### Utils
- `GET /ping` - Health check endpoint

## System Requirements

- macOS 14.0 or higher
- Xcode 16.2 or higher (for development)

## Acknowledgments

Special thanks to MillanK from the osWorld team - this project wouldn't exist without his inspiration and guidance. 
