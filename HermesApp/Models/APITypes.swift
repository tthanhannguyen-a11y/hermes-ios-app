import Foundation

enum MessageRole: String, Codable, CaseIterable {
    case system
    case user
    case assistant
    case tool
}

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: String
    let role: String
    let content: String
    let timestamp: Date?

    init(id: String = UUID().uuidString, role: MessageRole, content: String, timestamp: Date? = nil) {
        self.id = id
        self.role = role.rawValue
        self.content = content
        self.timestamp = timestamp
    }

    var messageRole: MessageRole {
        MessageRole(rawValue: role) ?? .user
    }

    var isUser: Bool { messageRole == .user }
    var isAssistant: Bool { messageRole == .assistant }
}

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatCompletionRequestMessage]
    let stream: Bool
    let temperature: Double?
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case maxTokens = "max_tokens"
    }

    init(model: String = "hermes-default", messages: [ChatCompletionRequestMessage], stream: Bool = true, temperature: Double? = nil, maxTokens: Int? = nil) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

struct ChatCompletionRequestMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let id: String?
    let choices: [Choice]
    let model: String?
    let usage: Usage?

    struct Choice: Codable {
        let index: Int
        let message: MessageContent
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, message
            case finishReason = "finish_reason"
        }
    }

    struct MessageContent: Codable {
        let role: String?
        let content: String?
    }

    struct Usage: Codable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}

struct ChatCompletionChunk: Codable {
    let id: String?
    let model: String?
    let choices: [Choice]

    struct Choice: Codable {
        let index: Int
        let delta: Delta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }

    struct Delta: Codable {
        let role: String?
        let content: String?
    }
}

struct HermesResponse: Codable, Identifiable {
    let id: String
    let status: String?
    let output: [ResponseOutput]?
    let usage: ChatCompletionResponse.Usage?

    var outputText: String {
        output?.compactMap { item in
            item.content?.compactMap { $0.text }.joined()
        }.joined() ?? ""
    }
}

struct ResponseOutput: Codable {
    let type: String?
    let content: [ResponseContent]?
}

struct ResponseContent: Codable {
    let type: String?
    let text: String?
}

struct ResponseInput: Codable {
    let input: String
    let previousResponseId: String?
    let instructions: String?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case input, instructions, stream
        case previousResponseId = "previous_response_id"
    }
}

struct RunRequest: Codable {
    let assistantId: String?
    let input: String
    let instructions: String?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case input, instructions, stream
        case assistantId = "assistant_id"
    }
}

struct RunEvent: Codable, Identifiable {
    let id: String?
    let event: String?
    let data: SSEEventData?

    struct SSEEventData: Codable {
        let id: String?
        let status: String?
        let type: String?
        let content: String?
        let delta: String?
        let toolCall: ToolCall?
        let toolResult: ToolResult?

        enum CodingKeys: String, CodingKey {
            case id, status, type, content, delta
            case toolCall = "tool_call"
            case toolResult = "tool_result"
        }
    }

    struct ToolCall: Codable {
        let id: String?
        let name: String?
        let arguments: String?
    }

    struct ToolResult: Codable {
        let id: String?
        let content: String?
    }
}

struct RunStatusInfo: Codable, Identifiable {
    let id: String
    let status: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Session: Codable, Identifiable, Equatable {
    let id: String
    var title: String?
    let createdAt: Date?
    let updatedAt: Date?
    let messageCount: Int?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case messageCount = "message_count"
    }

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
}

struct SessionCreateRequest: Codable {
    let title: String
}

struct SessionUpdateRequest: Codable {
    let title: String
}

struct SessionMessage: Codable, Identifiable {
    let id: String
    let sessionId: String?
    let role: String
    let content: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, role, content
        case sessionId = "session_id"
        case createdAt = "created_at"
    }
}

struct HealthStatus: Codable {
    let status: String
    let version: String?
    let uptime: TimeInterval?
    let details: HealthDetails?

    struct HealthDetails: Codable {
        let database: String?
        let redis: String?
        let memory: String?
    }
}

struct CapabilityInfo: Codable, Identifiable {
    var id: String { name }
    let name: String
    let enabled: Bool
    let description: String?
}

struct CapabilitiesResponse: Codable {
    let capabilities: [CapabilityInfo]
    let version: String?
}

struct SkillInfo: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String?
    let enabled: Bool?
    let category: String?
}

struct SkillsResponse: Codable {
    let skills: [SkillInfo]
}

struct ToolsetInfo: Codable, Identifiable {
    var id: String { name }
    let name: String
    let description: String?
    let enabled: Bool?
    let toolCount: Int?

    enum CodingKeys: String, CodingKey {
        case name, description, enabled
        case toolCount = "tool_count"
    }
}

struct ToolsetsResponse: Codable {
    let toolsets: [ToolsetInfo]
}

struct ServerConfig: Codable {
    var serverUrl: String
    var apiKey: String
    var model: String
    var name: String?

    static let `default` = ServerConfig(
        serverUrl: "http://100.115.248.107:8642",
        apiKey: "",
        model: "hermes-default",
        name: "Hermes Agent"
    )

    enum CodingKeys: String, CodingKey {
        case serverUrl = "server_url"
        case apiKey = "api_key"
        case model
        case name
    }
}

struct DeleteResponse: Codable {
    let success: Bool
    let message: String?
}
