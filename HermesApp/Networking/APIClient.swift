import Foundation

final class APIClient {
    static let shared = APIClient()

    var baseURL: String {
        UserDefaults.standard.string(forKey: "server_url") ?? "http://100.0.0.1:8642"
    }

    var apiKey: String {
        KeychainWrapper.shared.get(key: "hermes_api_key") ?? ""
    }

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    var isConfigured: Bool {
        let url = UserDefaults.standard.string(forKey: "server_url") ?? ""
        let key = KeychainWrapper.shared.get(key: "hermes_api_key") ?? ""
        return !url.isEmpty && !key.isEmpty
    }

    private func buildRequest(_ method: String, path: String, body: Data? = nil) throws -> URLRequest {
        let trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmedBase)\(path)") else {
            throw AppError.badRequest("Invalid URL: \(trimmedBase)\(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = body
        }

        return request
    }

    func get<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        try await request("GET", endpoint: endpoint)
    }

    func post<T: Decodable, B: Encodable>(_ endpoint: APIEndpoint, body: B) async throws -> T {
        let data = try encoder.encode(body)
        return try await request("POST", endpoint: endpoint, body: data)
    }

    func put<T: Decodable, B: Encodable>(_ endpoint: APIEndpoint, body: B) async throws -> T {
        let data = try encoder.encode(body)
        return try await request("PUT", endpoint: endpoint, body: data)
    }

    func delete(_ endpoint: APIEndpoint) async throws {
        _ = try await requestData("DELETE", endpoint: endpoint)
    }

    func streamChatCompletion(model: String, messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let requestMessages = messages.map { ChatCompletionRequestMessage(role: $0.role.rawValue, content: $0.content) }
                    let requestBody = ChatCompletionRequest(
                        model: model,
                        messages: requestMessages,
                        stream: true,
                        temperature: 0.7,
                        maxTokens: 4096
                    )
                    let request = try buildRequest(
                        "POST",
                        path: APIEndpoint.chatCompletions.path,
                        body: encoder.encode(requestBody)
                    )

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: AppError.network(NSError(domain: "APIClient", code: -1)))
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: AppError.server("Server returned status \(httpResponse.statusCode)"))
                        return
                    }

                    var buffer = ""
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            if data == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            buffer += data
                        } else if line.isEmpty && !buffer.isEmpty {
                            if let content = extractStreamContent(from: buffer) {
                                continuation.yield(content)
                            }
                            buffer = ""
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func rawGet(_ endpoint: APIEndpoint) async throws -> Data {
        try await requestRaw("GET", endpoint: endpoint)
    }

    func rawPost<B: Encodable>(_ endpoint: APIEndpoint, body: B) async throws -> Data {
        try await requestRaw("POST", endpoint: endpoint, body: try encoder.encode(body))
    }

    private func request<T: Decodable>(_ method: String, endpoint: APIEndpoint, body: Data? = nil) async throws -> T {
        let data = try await requestData(method, endpoint: endpoint, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data),
               let message = errorResponse.error?.message {
                throw AppError.server(message)
            }
            throw AppError.decoding(error)
        }
    }

    private func requestData(_ method: String, endpoint: APIEndpoint, body: Data? = nil) async throws -> Data {
        let request = try buildRequest(method, path: endpoint.path, body: body)
        let (data, response) = try await session.data(for: request)
        return try handleResponse(data: data, response: response)
    }

    private func requestRaw(_ method: String, endpoint: APIEndpoint, body: Data? = nil) async throws -> Data {
        let request = try buildRequest(method, path: endpoint.path, body: body)
        let (data, response) = try await session.data(for: request)
        _ = try handleResponse(data: data, response: response)
        return data
    }

    private func handleResponse(data: Data, response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network(NSError(domain: "APIClient", code: -1))
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw AppError.unauthorized
        case 404:
            throw AppError.notFound
        case 400:
            let message = (try? decoder.decode(APIErrorResponse.self, from: data))?.error?.message ?? "Bad request"
            throw AppError.badRequest(message)
        case 500...599:
            let message = (try? decoder.decode(APIErrorResponse.self, from: data))?.error?.message ?? "Server error"
            throw AppError.server(message)
        default:
            throw AppError.server("HTTP \(httpResponse.statusCode)")
        }
    }

    private func extractStreamContent(from json: String) -> String? {
        guard let data = json.data(using: .utf8) else { return nil }
        do {
            let response = try decoder.decode(ChatCompletionResponse.self, from: data)
            if let delta = response.choices?.first?.delta {
                return delta.content
            }
            return nil
        } catch {
            return nil
        }
    }
}
