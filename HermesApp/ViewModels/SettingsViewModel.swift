import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    var serverURL = ""
    var apiKey = ""
    var deepInfraKey = ""
    var model = "hermes"
    var isTestingConnection = false
    var connectionStatus: ConnectionStatus?
    var errorMessage: String?
    var isSaved = false

    // Computed properties for the view
    var isLoading: Bool { isTestingConnection }
    var saveSuccess: Bool { isSaved }
    var hasSavedConfig: Bool {
        !serverURL.isEmpty || !apiKey.isEmpty || !deepInfraKey.isEmpty
    }
    var savedServerUrl: String { serverURL }
    var savedApiKeyMask: String {
        apiKey.isEmpty ? "" : String(repeating: "•", count: min(apiKey.count, 12))
    }

    func loadSettings() {
        serverURL = UserDefaults.standard.string(forKey: "server_url") ?? ""
        apiKey = KeychainWrapper.shared.get(key: "hermes_api_key") ?? ""
        deepInfraKey = KeychainWrapper.shared.get(key: "deepinfra_api_key") ?? ""
        model = UserDefaults.standard.string(forKey: "model") ?? "hermes"
    }

    // Alias for SettingsView compatibility
    func loadFromKeychain() { loadSettings() }
    func saveConfig() { saveSettings() }
    func clearKeychain() { clearAllData() }

    func saveSettings() {
        let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDeepInfra = deepInfraKey.trimmingCharacters(in: .whitespacesAndNewlines)

        UserDefaults.standard.set(trimmedURL, forKey: "server_url")
        UserDefaults.standard.set(model, forKey: "model")

        if trimmedKey.isEmpty {
            _ = KeychainWrapper.shared.delete(key: "hermes_api_key")
        } else {
            _ = KeychainWrapper.shared.save(key: "hermes_api_key", value: trimmedKey)
        }

        if trimmedDeepInfra.isEmpty {
            _ = KeychainWrapper.shared.delete(key: "deepinfra_api_key")
        } else {
            _ = KeychainWrapper.shared.save(key: "deepinfra_api_key", value: trimmedDeepInfra)
        }

        isSaved = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isSaved = false
        }
    }

    func testConnection() async {
        isTestingConnection = true
        connectionStatus = nil
        errorMessage = nil

        do {
            let status: HealthStatus = try await APIClient.shared.get(.health)
            connectionStatus = status.status?.lowercased() == "ok" || status.status?.lowercased() == "healthy" ? .success : .failure
        } catch {
            connectionStatus = .failure
            errorMessage = error.localizedDescription
        }

        isTestingConnection = false
    }

    func clearAllData() {
        UserDefaults.standard.removeObject(forKey: "server_url")
        UserDefaults.standard.removeObject(forKey: "model")
        KeychainWrapper.shared.deleteAll()
        serverURL = ""
        apiKey = ""
        deepInfraKey = ""
        model = "hermes"
    }

    // Speech model info
    var hasSpeechConfigured: Bool { !deepInfraKey.isEmpty }
    var sttInfo: String { "Qwen3-ASR-0.6B ($0.00020/min)" }
    var ttsInfo: String { "MiMo-V2.5-tts (FREE)" }
}
