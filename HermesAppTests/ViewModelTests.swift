import XCTest
import Observation

@testable import HermesApp

@MainActor
final class ChatViewModelTests: XCTestCase {
    var viewModel: ChatViewModel!

    override func setUp() {
        super.setUp()
        viewModel = ChatViewModel()
        _ = KeychainWrapper.shared.save(key: "hermes_api_key", value: "test-key")
        UserDefaults.standard.set("http://localhost:8642", forKey: "server_url")
    }

    override func tearDown() {
        viewModel = nil
        KeychainWrapper.shared.delete(key: "hermes_api_key")
        UserDefaults.standard.removeObject(forKey: "server_url")
        super.tearDown()
    }

    func testClearChat_removesAllMessages() {
        viewModel.messages = [
            ChatMessage(role: .user, content: "Hi"),
            ChatMessage(role: .assistant, content: "Hello")
        ]
        viewModel.errorMessage = "Some error"

        viewModel.clearChat()

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertTrue(viewModel.streamingContent.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testCancelStreaming_setsIsStreamingFalse() {
        viewModel.isStreaming = true
        viewModel.cancelStreaming()
        XCTAssertFalse(viewModel.isStreaming)
    }

    func testInitialState_isNotStreaming() {
        XCTAssertFalse(viewModel.isStreaming)
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.selectedModel, "hermes")
    }

    func testIsConfigured_returnsTrueWhenKeyAndURLSet() {
        XCTAssertTrue(viewModel.isConfigured)
    }

    func testIsConfigured_returnsFalseWhenMissingKey() {
        KeychainWrapper.shared.delete(key: "hermes_api_key")
        XCTAssertFalse(viewModel.isConfigured)
    }
}

@MainActor
final class StatusViewModelTests: XCTestCase {
    var viewModel: StatusViewModel!

    override func setUp() {
        super.setUp()
        viewModel = StatusViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertNil(viewModel.healthStatus)
        XCTAssertTrue(viewModel.skills.isEmpty)
        XCTAssertTrue(viewModel.toolsets.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
}

@MainActor
final class JobViewModelTests: XCTestCase {
    var viewModel: JobViewModel!

    override func setUp() {
        super.setUp()
        viewModel = JobViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(viewModel.jobs.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testIsConfigured_returnsFalseWhenNotConfigured() {
        KeychainWrapper.shared.delete(key: "hermes_api_key")
        UserDefaults.standard.removeObject(forKey: "server_url")
        XCTAssertFalse(viewModel.isConfigured)
    }
}

@MainActor
final class SessionsViewModelTests: XCTestCase {
    var viewModel: SessionsViewModel!

    override func setUp() {
        super.setUp()
        viewModel = SessionsViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(viewModel.sessions.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.isEmpty)
    }
}

@MainActor
final class SessionViewModelTests: XCTestCase {
    var viewModel: SessionViewModel!

    override func setUp() {
        super.setUp()
        viewModel = SessionViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertTrue(viewModel.sessions.isEmpty)
        XCTAssertNil(viewModel.selectedSession)
        XCTAssertTrue(viewModel.sessionMessages.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
}

@MainActor
final class SettingsViewModelTests: XCTestCase {
    var viewModel: SettingsViewModel!

    override func setUp() {
        super.setUp()
        viewModel = SettingsViewModel()
    }

    override func tearDown() {
        viewModel = nil
        KeychainWrapper.shared.deleteAll()
        UserDefaults.standard.removeObject(forKey: "server_url")
        super.tearDown()
    }

    func testLoadSettings_loadsFromUserDefaultsAndKeychain() {
        UserDefaults.standard.set("http://localhost:8642", forKey: "server_url")
        _ = KeychainWrapper.shared.save(key: "hermes_api_key", value: "saved-key")

        viewModel.loadSettings()

        XCTAssertEqual(viewModel.serverURL, "http://localhost:8642")
        XCTAssertEqual(viewModel.apiKey, "saved-key")
    }

    func testSaveSettings_persistsToUserDefaultsAndKeychain() {
        viewModel.serverURL = "http://server.tailscale.ts.net:8642"
        viewModel.apiKey = "my-api-key"

        viewModel.saveSettings()

        XCTAssertEqual(UserDefaults.standard.string(forKey: "server_url"), "http://server.tailscale.ts.net:8642")
        XCTAssertEqual(KeychainWrapper.shared.get(key: "hermes_api_key"), "my-api-key")
    }

    func testClearAllData_removesAllStorage() {
        UserDefaults.standard.set("http://localhost:8642", forKey: "server_url")
        _ = KeychainWrapper.shared.save(key: "hermes_api_key", value: "key")

        viewModel.clearAllData()

        XCTAssertNil(UserDefaults.standard.string(forKey: "server_url"))
        XCTAssertNil(KeychainWrapper.shared.get(key: "hermes_api_key"))
        XCTAssertTrue(viewModel.serverURL.isEmpty)
        XCTAssertTrue(viewModel.apiKey.isEmpty)
    }
}
