import SwiftUI

struct JobCreateView: View {
    let viewModel: JobViewModel

    @State private var name = ""
    @State private var schedule = ""
    @State private var task = ""
    @State private var description = ""
    @State private var isCreating = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Job Configuration") {
                    TextField("Name", text: $name)
                        .textContentType(.none)

                    TextField("Schedule (cron expression)", text: $schedule)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .monospaced()

                    TextField("Task / Command", text: $task, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .monospaced()

                    TextField("Description (optional)", text: $description)
                        .textContentType(.none)
                }

                Section("Cron Help") {
                    Text("Use standard cron syntax:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("`* * * * *` — every minute")
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.secondary)
                    Text("`0 * * * *` — every hour")
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.secondary)
                    Text("`0 0 * * *` — every day at midnight")
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Create") {
                        isCreating = true
                        Task {
                            let success = await viewModel.createJob(
                                name: name,
                                schedule: schedule,
                                task: task,
                                description: description.isEmpty ? nil : description
                            )
                            if success { dismiss() }
                            isCreating = false
                        }
                    }
                    .disabled(name.isEmpty || schedule.isEmpty || task.isEmpty || isCreating)
                }
            }
            .overlay {
                if isCreating {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView("Creating...")
                }
            }
        }
    }
}
