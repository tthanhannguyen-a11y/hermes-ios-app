import Foundation
import Observation

@MainActor
@Observable
final class JobViewModel {
    var jobs: [CronJob] = []
    var isLoading = false
    var isPerformingAction = false
    var errorMessage: String?

    var isConfigured: Bool {
        APIClient.shared.isConfigured
    }

    func loadJobs() async {
        isLoading = true
        errorMessage = nil

        do {
            jobs = try await APIClient.shared.get(.jobs)
        } catch {
            errorMessage = error.localizedDescription
            jobs = []
        }

        isLoading = false
    }

    func createJob(name: String, schedule: String, task: String, description: String? = nil) async -> Bool {
        guard !name.isEmpty, !schedule.isEmpty, !task.isEmpty else {
            errorMessage = "Name, schedule, and task are required."
            return false
        }

        isPerformingAction = true
        errorMessage = nil

        do {
            let body = CreateJobRequest(name: name, schedule: schedule, task: task, description: description)
            let _: CronJob = try await APIClient.shared.post(.jobs, body: body)
            await loadJobs()
            isPerformingAction = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isPerformingAction = false
            return false
        }
    }

    func toggleJob(_ job: CronJob) async {
        isPerformingAction = true
        errorMessage = nil

        do {
            let body = UpdateJobRequest(enabled: !(job.enabled ?? false), schedule: nil, name: nil, task: nil)
            let _: CronJob = try await APIClient.shared.put(.job(id: job.id), body: body)
            await loadJobs()
        } catch {
            errorMessage = error.localizedDescription
        }

        isPerformingAction = false
    }

    func runJobNow(_ job: CronJob) async {
        isPerformingAction = true
        errorMessage = nil

        do {
            let _: JobRunResponse = try await APIClient.shared.post(.runJob(id: job.id), body: EmptyBody())
        } catch {
            errorMessage = error.localizedDescription
        }

        isPerformingAction = false
    }

    func deleteJob(_ job: CronJob) async -> Bool {
        isPerformingAction = true
        errorMessage = nil

        do {
            try await APIClient.shared.delete(.job(id: job.id))
            await loadJobs()
            isPerformingAction = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isPerformingAction = false
            return false
        }
    }
}

struct EmptyBody: Codable {}
