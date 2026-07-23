import Foundation

enum APIEndpoint {
    case chatCompletions
    case sessions
    case session(id: String)
    case forkSession(id: String)
    case jobs
    case job(id: String)
    case runJob(id: String)
    case skills
    case toolsets
    case health

    var path: String {
        switch self {
        case .chatCompletions:
            return "/v1/chat/completions"
        case .sessions:
            return "/api/sessions"
        case .session(let id):
            return "/api/sessions/\(id)"
        case .forkSession(let id):
            return "/api/sessions/\(id)/fork"
        case .jobs:
            return "/api/jobs"
        case .job(let id):
            return "/api/jobs/\(id)"
        case .runJob(let id):
            return "/api/jobs/\(id)/run"
        case .skills:
            return "/v1/skills"
        case .toolsets:
            return "/v1/toolsets"
        case .health:
            return "/health"
        }
    }
}
