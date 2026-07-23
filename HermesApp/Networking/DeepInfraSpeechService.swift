import Foundation
import AVFoundation

/// Service for DeepInfra Speech-to-Text (STT) and Text-to-Speech (TTS)
/// STT: Qwen/Qwen3-ASR-0.6B — $0.00020/min
/// TTS: XiaomiMiMo/MiMo-V2.5-tts — FREE
final class DeepInfraSpeechService {
    static let shared = DeepInfraSpeechService()

    private let baseURL = "https://api.deepinfra.com/v1/inference"
    private let sttModel = "Qwen/Qwen3-ASR-0.6B"
    private let ttsModel = "XiaomiMiMo/MiMo-V2.5-tts"

    private var apiKey: String {
        KeychainWrapper.shared.get(key: "deepinfra_api_key") ?? ""
    }

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    // MARK: - STT (Speech-to-Text)

    /// Transcribe audio data to text
    func transcribe(audioData: Data, mimeType: String = "audio/m4a") async throws -> STTResponse {
        let url = URL(string: "\(baseURL)/\(sttModel)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let filename = "recording.\(mimeType.contains("mp4") || mimeType.contains("m4a") ? "m4a" : "wav")"

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network(NSError(domain: "DeepInfra", code: -1))
        }

        if httpResponse.statusCode == 401 {
            throw AppError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.server("DeepInfra STT error (\(httpResponse.statusCode)): \(body)")
        }

        return try decoder.decode(STTResponse.self, from: data)
    }

    // MARK: - TTS (Text-to-Speech)

    /// Generate speech from text
    func synthesize(text: String, voice: String = "default") async throws -> Data {
        let url = URL(string: "\(baseURL)/\(ttsModel)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": text,
            "voice": voice
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network(NSError(domain: "DeepInfra", code: -1))
        }

        if httpResponse.statusCode == 401 {
            throw AppError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.server("DeepInfra TTS error (\(httpResponse.statusCode)): \(body)")
        }

        // Check if response is JSON (error) or raw audio
        if let contentType = httpResponse.allHeaderFields["Content-Type"] as? String,
           contentType.contains("application/json") {
            throw AppError.server("TTS returned JSON instead of audio")
        }

        return data
    }
}

// MARK: - STT Response Models

struct STTResponse: Codable {
    let text: String
    let segments: [STTSegment]?
    let language: String?
    let words: [STTWord]?
}

struct STTSegment: Codable {
    let id: Int
    let start: Double
    let end: Double
    let text: String
}

struct STTWord: Codable {
    let start: Double
    let end: Double
    let text: String
}
