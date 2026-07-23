import Foundation

enum AppError: LocalizedError {
    case network(Error)
    case server(String)
    case decoding(Error)
    case unauthorized
    case notConfigured
    case notFound
    case badRequest(String)
    case unknown
    case invalidURL(String)
    case invalidResponse(statusCode: Int)
    case serverError(String)
    case decodingError(Error)
    case keychainError(String)

    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .server(let message):
            return message
        case .decoding(let error):
            return "Data error: \(error.localizedDescription)"
        case .unauthorized:
            return "Invalid API key. Please check your settings."
        case .notConfigured:
            return "Server not configured. Please set the server URL and API key in Settings."
        case .notFound:
            return "Resource not found."
        case .badRequest(let message):
            return message
        case .unknown:
            return "An unexpected error occurred."
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse(let statusCode):
            return "Invalid response (status \(statusCode))"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .network:
            return "Check that your iOS device is connected to Tailscale and can reach the server."
        case .unauthorized:
            return "Verify your API key in Settings matches the key configured on the Hermes server."
        case .notConfigured:
            return "Go to Settings and enter your server URL and API key."
        case .invalidURL:
            return "Check the server URL in Settings."
        default:
            return nil
        }
    }
}
