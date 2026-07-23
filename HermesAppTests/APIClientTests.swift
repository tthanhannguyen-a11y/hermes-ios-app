import XCTest
import Foundation

@testable import HermesApp

final class APIClientTests: XCTestCase {
    var client: APIClient!
    var mockSession: MockURLSession!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        client = APIClient.shared
    }

    override func tearDown() {
        mockSession = nil
        client = nil
        super.tearDown()
    }

    func testBuildRequest_addsAuthorizationHeaderWhenKeyPresent() throws {
        KeychainWrapper.shared.save(key: "hermes_api_key", value: "test-key-123")

        UserDefaults.standard.set("http://localhost:8642", forKey: "server_url")
        let request = try client.buildRequest("GET", path: "/health")

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key-123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        KeychainWrapper.shared.delete(key: "hermes_api_key")
    }

    func testBuildRequest_skipsAuthorizationWhenKeyEmpty() throws {
        KeychainWrapper.shared.delete(key: "hermes_api_key")
        UserDefaults.standard.set("http://localhost:8642", forKey: "server_url")

        let request = try client.buildRequest("POST", path: "/v1/chat/completions", body: Data())

        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testBuildRequest_throwsOnInvalidURL() {
        UserDefaults.standard.set("", forKey: "server_url")
        XCTAssertThrowsError(try client.buildRequest("GET", path: "/test")) { error in
            XCTAssertTrue(error is AppError)
        }
    }

    func testHandleResponse_200ReturnsData() throws {
        let data = Data("\"ok\"".utf8)
        let response = HTTPURLResponse(url: URL(string: "http://localhost:8642/health")!,
                                        statusCode: 200,
                                        httpVersion: nil,
                                        headerFields: nil)!
        let result = try client.handleResponse(data: data, response: response)
        XCTAssertEqual(result, data)
    }

    func testHandleResponse_401ThrowsUnauthorized() {
        let response = HTTPURLResponse(url: URL(string: "http://localhost:8642/health")!,
                                        statusCode: 401,
                                        httpVersion: nil,
                                        headerFields: nil)!
        XCTAssertThrowsError(try client.handleResponse(data: Data(), response: response)) { error in
            XCTAssertTrue(error is AppError)
            if case AppError.unauthorized = error { } else {
                XCTFail("Expected unauthorized error")
            }
        }
    }

    func testIsConfigured_returnsFalseWhenEmpty() {
        KeychainWrapper.shared.delete(key: "hermes_api_key")
        UserDefaults.standard.removeObject(forKey: "server_url")
        XCTAssertFalse(client.isConfigured)
    }

    func testIsConfigured_returnsTrueWhenConfigured() {
        KeychainWrapper.shared.save(key: "hermes_api_key", value: "key")
        UserDefaults.standard.set("http://localhost:8642", forKey: "server_url")
        XCTAssertTrue(client.isConfigured)
        KeychainWrapper.shared.delete(key: "hermes_api_key")
    }

    func testExtractStreamContent_parsesDeltaContent() {
        let json = """
        {"id":"1","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}
        """
        let result = client.extractStreamContent(from: json)
        XCTAssertEqual(result, "Hello")
    }

    func testExtractStreamContent_returnsNilForInvalidJSON() {
        let result = client.extractStreamContent(from: "not json")
        XCTAssertNil(result)
    }
}
