import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()

    private let serviceName = "com.hermes.dashboard"
    private let apiKeyAccount = "hermes_api_key"
    private let serverUrlAccount = "hermes_server_url"

    private init() {}

    func save(key: String, data: Data) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key,
            kSecValueData: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.keychainError("Failed to save to Keychain (status: \(status))")
        }
    }

    func read(key: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw AppError.keychainError("Failed to read from Keychain (status: \(status))")
        }
        return result as? Data
    }

    func delete(key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppError.keychainError("Failed to delete from Keychain (status: \(status))")
        }
    }

    func saveAPIKey(_ apiKey: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw AppError.keychainError("Failed to encode API key")
        }
        try save(key: apiKeyAccount, data: data)
    }

    func readAPIKey() throws -> String? {
        guard let data = try read(key: apiKeyAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey() throws {
        try delete(key: apiKeyAccount)
    }

    func saveServerURL(_ url: String) throws {
        guard let data = url.data(using: .utf8) else {
            throw AppError.keychainError("Failed to encode server URL")
        }
        try save(key: serverUrlAccount, data: data)
    }

    func readServerURL() throws -> String? {
        guard let data = try read(key: serverUrlAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteServerURL() throws {
        try delete(key: serverUrlAccount)
    }
}
