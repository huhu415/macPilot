import JSONSchemaBuilder
import MCPServer

@Schemable
struct ToolInput {
    let text: String
}

class MCPServerManager {
    static let shared = MCPServerManager()
    private var server: MCPServer?
    private var roots: [String]?

    private init() {}

    func startServer() async throws {
        let capabilities = ServerCapabilityHandlers(tools: [
            Tool(name: "repeat") { (input: ToolInput) in
                [.text(.init(text: input.text))]
            }
        ])

        server = try await MCPServer(
            info: Implementation(name: "test-server", version: "1.0.0"),
            capabilities: capabilities,
            transport: .stdio())

        // The client's roots, if available.
        roots = await server?.roots.value as? [String]

        // Keep the process running until the client disconnects.
        try await server?.waitForDisconnection()
    }
}
