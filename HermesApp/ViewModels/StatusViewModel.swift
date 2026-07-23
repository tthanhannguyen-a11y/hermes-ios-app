import Foundation
import Observation

@MainActor
@Observable
final class StatusViewModel {
    var healthStatus: HealthStatus?
    var skills: [Skill] = []
    var toolsets: [Toolset] = []
    var isLoading = false
    var healthIsLoading = false
    var skillsIsLoading = false
    var toolsetsIsLoading = false
    var errorMessage: String?

    var isConfigured: Bool {
        APIClient.shared.isConfigured
    }

    func loadAll() async {
        isLoading = true
        async let healthTask: () = loadHealth()
        async let skillsTask: () = loadSkills()
        async let toolsetsTask: () = loadToolsets()

        _ = await (healthTask, skillsTask, toolsetsTask)
        isLoading = false
    }

    func loadHealth() async {
        healthIsLoading = true
        do {
            healthStatus = try await APIClient.shared.get(.health)
        } catch {
            errorMessage = error.localizedDescription
        }
        healthIsLoading = false
    }

    func loadSkills() async {
        skillsIsLoading = true
        do {
            let data = try await APIClient.shared.rawGet(.skills)
            let decoded = try JSONDecoder().decode([Skill].self, from: data)
            skills = decoded
        } catch {
            do {
                let data = try await APIClient.shared.rawGet(.skills)
                let decoded = try JSONDecoder().decode(PaginatedResponse<Skill>.self, from: data)
                skills = decoded.items ?? []
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        skillsIsLoading = false
    }

    func loadToolsets() async {
        toolsetsIsLoading = true
        do {
            let data = try await APIClient.shared.rawGet(.toolsets)
            let decoded = try JSONDecoder().decode([Toolset].self, from: data)
            toolsets = decoded
        } catch {
            do {
                let data = try await APIClient.shared.rawGet(.toolsets)
                let decoded = try JSONDecoder().decode(PaginatedResponse<Toolset>.self, from: data)
                toolsets = decoded.items ?? []
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        toolsetsIsLoading = false
    }
}
