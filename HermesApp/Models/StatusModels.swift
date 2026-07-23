import Foundation

struct Skill: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let version: String?
    let enabled: Bool?
}

struct Toolset: Identifiable, Codable {
    let id: String?
    let name: String
    let description: String?
    let tools: [Tool]?

    var identifier: String { id ?? name }
}

struct Tool: Identifiable, Codable {
    let name: String
    let description: String?

    var id: String { name }
}
