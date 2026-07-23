import Foundation

struct SSEParser {
    static func parse(lines: AsyncThrowingStream<String, Error>) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var buffer = ""
                do {
                    for try await line in lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))
                            if data == "[DONE]" {
                                continuation.finish()
                                return
                            }
                            buffer += data
                        } else if line.isEmpty && !buffer.isEmpty {
                            if let chunk = extractContent(from: buffer) {
                                continuation.yield(chunk)
                            }
                            buffer = ""
                        }
                    }
                    if !buffer.isEmpty {
                        if let chunk = extractContent(from: buffer) {
                            continuation.yield(chunk)
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

    private static func extractContent(from json: String) -> String? {
        guard let data = json.data(using: .utf8) else { return nil }
        do {
            let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            if let delta = response.choices?.first?.delta {
                return delta.content
            }
            return nil
        } catch {
            return nil
        }
    }
}
