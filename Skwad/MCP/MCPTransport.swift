import Foundation

// MARK: - MCP Transport Protocol

protocol MCPTransportProtocol {
    func start() async throws
    func stop() async
}

// MARK: - SSE Event

struct SSEEvent {
    let event: String?
    let data: String
    let id: String?

    func formatted() -> String {
        var result = ""
        if let event = event {
            result += "event: \(event)\n"
        }
        if let id = id {
            result += "id: \(id)\n"
        }
        result += "data: \(data)\n\n"
        return result
    }
}
