import Foundation
import Observation

@MainActor
@Observable
final class SessionsViewModel {
    var sessions: [Session] = []
    var isLoading = false
    var errorMessage: String?
    var selectedSessionMessages: [SessionMessage] = []
    var isLoadingMessages = false

    private var client = HermesClient()

    var isEmpty: Bool { sessions.isEmpty && !isLoading }

    func configure(serverUrl: String, apiKey: String) {
        client = HermesClient(baseURL: serverUrl, apiKey: apiKey)
    }

    func loadSessions() async {
        isLoading = true
        errorMessage = nil
        do {
            sessions = try await client.listSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createSession(title: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await client.createSession(title: title)
            sessions.insert(session, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func updateSession(id: String, title: String) async {
        errorMessage = nil
        do {
            let updated = try await client.updateSession(id: id, title: title)
            if let index = sessions.firstIndex(where: { $0.id == id }) {
                sessions[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSession(id: String) async {
        errorMessage = nil
        do {
            try await client.deleteSession(id: id)
            sessions.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMessages(for sessionId: String) async {
        isLoadingMessages = true
        errorMessage = nil
        do {
            selectedSessionMessages = try await client.getSessionMessages(sessionId: sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMessages = false
    }
}
