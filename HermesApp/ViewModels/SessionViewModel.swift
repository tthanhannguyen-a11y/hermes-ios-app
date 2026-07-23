import Foundation
import Observation

@MainActor
@Observable
final class SessionViewModel {
    var sessions: [Session] = []
    var selectedSession: SessionDetail?
    var sessionMessages: [SessionMessage] = []
    var isLoading = false
    var isLoadingDetail = false
    var errorMessage: String?

    var isConfigured: Bool {
        APIClient.shared.isConfigured
    }

    func loadSessions() async {
        isLoading = true
        errorMessage = nil

        do {
            let data = try await APIClient.shared.rawGet(.sessions)
            let decoded = try JSONDecoder().decode([Session].self, from: data)
            sessions = decoded
        } catch {
            do {
                let data = try await APIClient.shared.rawGet(.sessions)
                let decoded = try JSONDecoder().decode(SessionListResponse.self, from: data)
                sessions = decoded.sessions ?? []
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func loadSessionDetail(id: String) async {
        isLoadingDetail = true
        errorMessage = nil

        do {
            selectedSession = try await APIClient.shared.get(.session(id: id))
            sessionMessages = selectedSession?.messages ?? []
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingDetail = false
    }

    func forkSession(id: String, newName: String) async -> Bool {
        errorMessage = nil

        do {
            let body = ForkSessionRequest(name: newName)
            let _: Session = try await APIClient.shared.post(.forkSession(id: id), body: body)
            await loadSessions()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
