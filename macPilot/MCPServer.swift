import MCPServer
import JSONSchemaBuilder


@Schemable
struct ToolInput {
  let text: String
}

let capabilities = ServerCapabilityHandlers(tools: [
  Tool(name: "repeat") { (input: ToolInput) in
    [.text(.init(text: input.text))]
  },
])

let server = try await MCPServer(
  info: Implementation(name: "test-server", version: "1.0.0"),
  capabilities: capabilities,
  transport: .stdio())

// The client's roots, if available.  
let roots = await server.roots.value

// Keep the process running until the client disconnects.
try await server.waitForDisconnection()
