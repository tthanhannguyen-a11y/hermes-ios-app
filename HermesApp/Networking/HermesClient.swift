import Foundation

final class HermesClient: Sendable {
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: String = ServerConfig.default.serverUrl,
         apiKey: String = ServerConfig.default.apiKey) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.apiKey = apiKey

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }

    private func buildRequest(path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw AppError.invalidURL("\(baseURL)\(path)")
        }
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        return request
    }

    private func makeRequest<T: Decodable>(_ request: URLRequest, type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse(statusCode: -1)
        }
        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw AppError.unauthorized
        case 404:
            throw AppError.notFound
        default:
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.serverError(body)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppError.decodingError(error)
        }
    }

    private func makeRequestNoContent(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse(statusCode: -1)
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw AppError.unauthorized
        case 404:
            throw AppError.notFound
        default:
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.serverError(body)
        }
    }

    func get<T: Decodable>(_ path: String, type: T.Type) async throws -> T {
        let request = try buildRequest(path: path)
        return try await makeRequest(request, type: type)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B, type: T.Type) async throws -> T {
        let bodyData = try encoder.encode(body)
        let request = try buildRequest(path: path, method: "POST", body: bodyData)
        return try await makeRequest(request, type: type)
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B, type: T.Type) async throws -> T {
        let bodyData = try encoder.encode(body)
        let request = try buildRequest(path: path, method: "PATCH", body: bodyData)
        return try await makeRequest(request, type: type)
    }

    func delete(_ path: String) async throws {
        let request = try buildRequest(path: path, method: "DELETE")
        try await makeRequestNoContent(request)
    }

    func delete<T: Decodable>(_ path: String, type: T.Type) async throws -> T {
        let request = try buildRequest(path: path, method: "DELETE")
        return try await makeRequest(request, type: type)
    }

    func rawPost<B: Encodable>(_ path: String, body: B) async throws -> Data {
        let bodyData = try encoder.encode(body)
        let request = try buildRequest(path: path, method: "POST", body: bodyData)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse(statusCode: -1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw AppError.serverError(msg)
        }
        return data
    }

    func rawGet(_ path: String) async throws -> Data {
        let request = try buildRequest(path: path)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse(statusCode: -1)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw AppError.serverError(msg)
        }
        return data
    }

    func streamRequest<B: Encodable>(path: String, body: B) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        let bodyData = try encoder.encode(body)
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw AppError.invalidURL("\(baseURL)\(path)")
        }
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = bodyData

        return AsyncThrowingStream { continuation in
            let streamer = SSEStreamer(url: url, bodyData: bodyData)
            streamer.onEvent = { event in
                continuation.yield(event)
                if let data = event.dataAsData,
                   let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: data),
                   chunk.choices.first?.finishReason == "stop" {
                    continuation.finish()
                } else if event.type == "done" || event.data == "[DONE]" {
                    continuation.finish()
                }
            }
            streamer.onError = { error in
                continuation.finish(throwing: error)
            }
            streamer.onComplete = {
                continuation.finish()
            }
            streamer.start()

            continuation.onTermination = { _ in
                streamer.stop()
            }
        }
    }

    func chatCompletionStream(request: ChatCompletionRequest) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        return try await streamRequest(path: "/v1/chat/completions", body: request)
    }

    func chatCompletionStream(sessionId: String, message: String) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        let body = ChatCompletionRequest(
            model: "hermes-default",
            messages: [ChatCompletionRequestMessage(role: "user", content: message)],
            stream: true
        )
        return try await streamRequest(path: "/api/sessions/\(sessionId)/chat/stream", body: body)
    }

    func sessionStreamMessage(sessionId: String, message: String) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        struct StreamBody: Codable {
            let message: String
            let stream: Bool
        }
        return try await streamRequest(path: "/api/sessions/\(sessionId)/chat/stream", body: StreamBody(message: message, stream: true))
    }

    func runStream(request: RunRequest) async throws -> AsyncThrowingStream<SSEEvent, Error> {
        let response = try await post("/v1/runs", body: request, type: RunStatusInfo.self)
        return try await streamRequest(path: "/v1/runs/\(response.id)/events", body: EmptyBody())
    }

    struct EmptyBody: Codable {}

    func updateConfig(serverUrl: String, apiKey: String) {
        return
    }

    func health() async throws -> HealthStatus {
        try await get("/health", type: HealthStatus.self)
    }

    func capabilities() async throws -> CapabilitiesResponse {
        try await get("/v1/capabilities", type: CapabilitiesResponse.self)
    }

    func skills() async throws -> SkillsResponse {
        try await get("/v1/skills", type: SkillsResponse.self)
    }

    func toolsets() async throws -> ToolsetsResponse {
        try await get("/v1/toolsets", type: ToolsetsResponse.self)
    }

    func listSessions() async throws -> [Session] {
        try await get("/api/sessions", type: [Session].self)
    }

    func getSession(id: String) async throws -> Session {
        try await get("/api/sessions/\(id)", type: Session.self)
    }

    func createSession(title: String) async throws -> Session {
        try await post("/api/sessions", body: SessionCreateRequest(title: title), type: Session.self)
    }

    func updateSession(id: String, title: String) async throws -> Session {
        try await patch("/api/sessions/\(id)", body: SessionUpdateRequest(title: title), type: Session.self)
    }

    func deleteSession(id: String) async throws {
        try await delete("/api/sessions/\(id)")
    }

    func getSessionMessages(sessionId: String) async throws -> [SessionMessage] {
        try await get("/api/sessions/\(sessionId)/messages", type: [SessionMessage].self)
    }
}
