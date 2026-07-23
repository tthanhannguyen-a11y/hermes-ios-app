import SwiftUI

struct JobDetailView: View {
    let job: CronJob
    let viewModel: JobViewModel

    @State private var showDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Name", value: job.name)
                LabeledContent("Schedule") {
                    Text(job.schedule)
                        .monospaced()
                        .foregroundStyle(.primary)
                }
                if let task = job.task {
                    LabeledContent("Task") {
                        Text(task)
                            .monospaced()
                            .font(.caption)
                    }
                }
                if let description = job.description {
                    LabeledContent("Description", value: description)
                }
            }

            Section("Status") {
                LabeledContent("Enabled") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(job.enabled == true ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(job.enabled == true ? "Active" : "Paused")
                    }
                }

                if let lastRun = job.lastRun {
                    LabeledContent("Last Run", value: lastRun.displayFormatted)
                }

                if let nextRun = job.nextRun {
                    LabeledContent("Next Run", value: nextRun.displayFormatted)
                }

                if let createdAt = job.createdAt {
                    LabeledContent("Created", value: createdAt.displayFormatted)
                }
            }

            Section("Actions") {
                Button {
                    Task {
                        await viewModel.toggleJob(job)
                    }
                } label: {
                    Label(
                        job.enabled == true ? "Pause Job" : "Resume Job",
                        systemImage: job.enabled == true ? "pause.circle" : "play.circle"
                    )
                }

                Button {
                    Task {
                        await viewModel.runJobNow(job)
                    }
                } label: {
                    Label("Run Now", systemImage: "forward.circle")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Job", systemImage: "trash")
                }
            }
        }
        .navigationTitle(job.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Job", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    let success = await viewModel.deleteJob(job)
                    if success { dismiss() }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(job.name)\"? This action cannot be undone.")
        }
    }
}
