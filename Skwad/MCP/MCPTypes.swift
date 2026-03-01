import Foundation

// MARK: - Message

struct MCPMessage: Codable, Identifiable {
    let id: UUID
    let from: String       // Agent ID or name
    let to: String         // Agent ID or name
    let content: String
    let timestamp: Date
    var isRead: Bool

    init(from: String, to: String, content: String) {
        self.id = UUID()
        self.from = from
        self.to = to
        self.content = content
        self.timestamp = Date()
        self.isRead = false
    }
}

// MARK: - Agent Info (for list-agents response)

struct AgentInfo: Codable {
    let id: String
    let name: String
    let folder: String
    let status: String
    let isRegistered: Bool
}

// MARK: - Tool Responses

struct ListAgentsResponse: Codable {
    let agents: [AgentInfo]
}

struct SendMessageResponse: Codable {
    let success: Bool
    let message: String
}

struct CheckMessagesResponse: Codable {
    let messages: [MessageInfo]
}

struct MessageInfo: Codable {
    let id: String
    let from: String
    let content: String
    let timestamp: String
}

struct BroadcastResponse: Codable {
    let success: Bool
    let recipientCount: Int
}

struct RepoInfoResponse: Codable {
    let name: String
    let worktrees: [WorktreeInfoResponse]
}

struct ListReposResponse: Codable {
    let repos: [RepoInfoResponse]
}

struct WorktreeInfoResponse: Codable {
    let name: String
    let path: String
}

struct ListWorktreesResponse: Codable {
    let repoPath: String
    let worktrees: [WorktreeInfoResponse]
}

struct CreateAgentResponse: Codable {
    let success: Bool
    let agentId: String?
    let message: String
}

struct CloseAgentResponse: Codable {
    let success: Bool
    let message: String
}

struct RegisterAgentResponse: Codable {
    let success: Bool
    let message: String
    let unreadMessageCount: Int
    let skwadMembers: [AgentInfo]
}

struct CreateWorktreeResponse: Codable {
    let success: Bool
    let path: String?
    let message: String
}

struct ShowMarkdownResponse: Codable {
    let success: Bool
    let message: String
}

struct ShowMermaidResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - JSON-RPC Types

struct JSONRPCRequest: Codable {
    let jsonrpc: String
    let id: JSONRPCId?
    let method: String
    let params: JSONRPCParams?

    init(method: String, params: JSONRPCParams? = nil, id: JSONRPCId? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }
}

struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: JSONRPCId?
    let result: AnyCodable?
    let error: JSONRPCError?

    init(id: JSONRPCId?, result: AnyCodable? = nil, error: JSONRPCError? = nil) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = error
    }

    static func success(id: JSONRPCId?, result: some Codable) -> JSONRPCResponse {
        JSONRPCResponse(id: id, result: AnyCodable(result))
    }

    static func error(id: JSONRPCId?, code: Int, message: String) -> JSONRPCResponse {
        JSONRPCResponse(id: id, error: JSONRPCError(code: code, message: message))
    }
}

struct JSONRPCError: Codable {
    let code: Int
    let message: String
    let data: AnyCodable?

    init(code: Int, message: String, data: AnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

enum JSONRPCId: Codable, Equatable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else {
            throw DecodingError.typeMismatch(JSONRPCId.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        }
    }
}

enum JSONRPCParams: Codable {
    case dictionary([String: AnyCodable])
    case array([AnyCodable])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            self = .dictionary(dict)
        } else if let arr = try? container.decode([AnyCodable].self) {
            self = .array(arr)
        } else {
            throw DecodingError.typeMismatch(JSONRPCParams.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected dictionary or array"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .dictionary(let dict):
            try container.encode(dict)
        case .array(let arr):
            try container.encode(arr)
        }
    }

    subscript(key: String) -> AnyCodable? {
        if case .dictionary(let dict) = self {
            return dict[key]
        }
        return nil
    }
}

// MARK: - AnyCodable for dynamic JSON

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(_ codable: some Codable) {
        self.value = codable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        case let codable as Codable:
            // For Codable types, encode them directly
            try codable.encode(to: encoder)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type: \(type(of: value))"))
        }
    }

    var stringValue: String? {
        value as? String
    }

    var intValue: Int? {
        value as? Int
    }

    var boolValue: Bool? {
        value as? Bool
    }

    var arrayValue: [Any]? {
        value as? [Any]
    }

    var dictionaryValue: [String: Any]? {
        value as? [String: Any]
    }
}

// MARK: - MCP Protocol Constants

enum MCPMethod: String {
    // Lifecycle
    case initialize = "initialize"
    case initialized = "notifications/initialized"
    case shutdown = "shutdown"

    // Tools
    case listTools = "tools/list"
    case callTool = "tools/call"

    // Resources (not used but defined for completeness)
    case listResources = "resources/list"
    case readResource = "resources/read"
}

// MARK: - Tool Definitions

struct ToolDefinition: Codable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema
}

struct ToolInputSchema: Codable {
    let type: String
    let properties: [String: PropertySchema]
    let required: [String]

    init(properties: [String: PropertySchema] = [:], required: [String] = []) {
        self.type = "object"
        self.properties = properties
        self.required = required
    }
}

struct PropertySchema: Codable {
    let type: String
    let description: String
}

// MARK: - MCP Tool Names

enum MCPToolName: String {
    case registerAgent = "register-agent"
    case listAgents = "list-agents"
    case sendMessage = "send-message"
    case checkMessages = "check-messages"
    case broadcastMessage = "broadcast-message"
    case listRepos = "list-repos"
    case listWorktrees = "list-worktrees"
    case createAgent = "create-agent"
    case closeAgent = "close-agent"
    case createWorktree = "create-worktree"
    case displayMarkdown = "display-markdown"
    case viewMermaid = "view-mermaid"
}

// MARK: - Tool Results

struct ToolCallResult: Codable {
    let content: [ToolContent]
    let isError: Bool?
}

struct ToolContent: Codable {
    let type: String
    let text: String

    init(text: String) {
        self.type = "text"
        self.text = text
    }
}
