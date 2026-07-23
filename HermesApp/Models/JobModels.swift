import Foundation

struct CronJob: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let schedule: String
    let task: String?
    let description: String?
    let enabled: Bool?
    let lastRun: String?
    let nextRun: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, schedule, task, description, enabled
        case lastRun = "last_run"
        case nextRun = "next_run"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateJobRequest: Codable {
    let name: String
    let schedule: String
    let task: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case name, schedule, task, description
    }
}

struct UpdateJobRequest: Codable {
    let enabled: Bool?
    let schedule: String?
    let name: String?
    let task: String?

    enum CodingKeys: String, CodingKey {
        case enabled, schedule, name, task
    }
}

struct JobRunResponse: Codable {
    let id: String?
    let status: String?
    let message: String?
}
