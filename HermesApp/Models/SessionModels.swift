import Foundation

struct SessionDetail: Identifiable, Codable {
    let id: String
    let name: String
    let messages: [SessionMessage]?
    let createdAt: String?
    let updatedAt: String?
    let messageCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, messages
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case messageCount = "message_count"
    }
}

struct ForkSessionRequest: Codable {
    let name: String
}

struct SessionListResponse: Codable {
    let sessions: [Session]?
}
