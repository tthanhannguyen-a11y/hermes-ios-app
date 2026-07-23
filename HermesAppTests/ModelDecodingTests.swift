import XCTest
import Foundation

@testable import HermesApp

final class ModelDecodingTests: XCTestCase {
    let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - HealthStatus

    func testHealthStatusDecoding_full() throws {
        let json = """
        {"status":"ok","version":"1.2.3","uptime":3600,"uptime_formatted":"1h 0m","capabilities":["chat","tools"]}
        """
        let status = try decoder.decode(HealthStatus.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(status.status, "ok")
        XCTAssertEqual(status.version, "1.2.3")
        XCTAssertEqual(status.uptime, 3600)
        XCTAssertEqual(status.uptimeFormatted, "1h 0m")
        XCTAssertEqual(status.capabilities, ["chat", "tools"])
    }

    func testHealthStatusDecoding_partial() throws {
        let json = """
        {"status":"degraded"}
        """
        let status = try decoder.decode(HealthStatus.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(status.status, "degraded")
        XCTAssertNil(status.version)
        XCTAssertNil(status.uptime)
    }

    // MARK: - ChatCompletionChunk

    func testChatCompletionChunkDecoding() throws {
        let json = """
        {"id":"chunk-1","model":"hermes-default","choices":[{"index":0,"delta":{"role":"assistant","content":"Hello"},"finish_reason":null}]}
        """
        let chunk = try decoder.decode(ChatCompletionChunk.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(chunk.id, "chunk-1")
        XCTAssertEqual(chunk.choices.first?.delta.content, "Hello")
        XCTAssertNil(chunk.choices.first?.finishReason)
    }

    func testChatCompletionChunk_finishReason() throws {
        let json = """
        {"id":"chunk-2","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}
        """
        let chunk = try decoder.decode(ChatCompletionChunk.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(chunk.choices.first?.finishReason, "stop")
    }

    // MARK: - Session models (APITypes version)

    func testSessionDecoding() throws {
        let json = """
        {"id":"sess_1","title":"Test","created_at":"2026-01-15T10:00:00Z","updated_at":"2026-01-15T12:00:00Z","message_count":5,"status":"active"}
        """
        let session = try decoder.decode(Session.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(session.id, "sess_1")
        XCTAssertEqual(session.title, "Test")
        XCTAssertEqual(session.messageCount, 5)
    }

    func testSessionsArrayDecoding() throws {
        let json = """
        [{"id":"s1","title":"First"},{"id":"s2","title":"Second"}]
        """
        let sessions = try decoder.decode([Session].self, from: json.data(using: .utf8)!)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions.first?.title, "First")
    }

    // MARK: - CronJob

    func testCronJobDecoding() throws {
        let json = """
        {"id":"job_1","name":"Daily Report","schedule":"0 8 * * *","task":"generate report","enabled":true,"last_run":"2026-01-14T08:00:00Z","next_run":"2026-01-15T08:00:00Z"}
        """
        let job = try decoder.decode(CronJob.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(job.name, "Daily Report")
        XCTAssertEqual(job.schedule, "0 8 * * *")
        XCTAssertEqual(job.enabled, true)
    }

    // MARK: - ChatMessage (ChatModels version)

    func testChatMessageEncodingDecoding() throws {
        let message = ChatMessage(role: .user, content: "Hello, Hermes!")
        let encoded = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: encoded)
        XCTAssertEqual(decoded.role, .user)
        XCTAssertEqual(decoded.content, "Hello, Hermes!")
    }

    // MARK: - APIErrorResponse

    func testAPIErrorResponseDecoding() throws {
        let json = """
        {"error":{"message":"Invalid API key","type":"auth_error","code":"unauthorized"}}
        """
        let errorResponse = try decoder.decode(APIErrorResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(errorResponse.error?.message, "Invalid API key")
        XCTAssertEqual(errorResponse.error?.type, "auth_error")
    }

    // MARK: - ServerConfig

    func testServerConfigEncodingDecoding() throws {
        let config = ServerConfig(serverUrl: "http://localhost:8642", apiKey: "key123", model: "hermes-default", name: "Local")
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ServerConfig.self, from: encoded)
        XCTAssertEqual(decoded.serverUrl, "http://localhost:8642")
        XCTAssertEqual(decoded.apiKey, "key123")
        XCTAssertEqual(decoded.model, "hermes-default")
        XCTAssertEqual(decoded.name, "Local")
    }

    func testServerConfigCodingKeys_mapCorrectly() throws {
        let json = """
        {"server_url":"http://localhost:8642","api_key":"key123","model":"m1","name":"Test"}
        """
        let config = try decoder.decode(ServerConfig.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(config.serverUrl, "http://localhost:8642")
        XCTAssertEqual(config.apiKey, "key123")
    }
}
