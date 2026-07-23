import SwiftUI

struct JobListView: View {
    @State private var viewModel = JobViewModel()
    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading jobs...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.jobs.isEmpty {
                    emptyStateView
                } else {
                    jobList
                }
            }
            .navigationTitle("Jobs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await viewModel.loadJobs()
            }
            .task {
                await viewModel.loadJobs()
            }
        }
        .errorToast($viewModel.errorMessage)
        .sheet(isPresented: $showCreateSheet) {
            JobCreateView(viewModel: viewModel)
        }
        .overlay {
            if viewModel.isPerformingAction {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                ProgressView()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No cron jobs")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Create scheduled tasks for recurring operations")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                showCreateSheet = true
            } label: {
                Label("Create Job", systemImage: "plus.circle.fill")
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var jobList: some View {
        List {
            ForEach(viewModel.jobs) { job in
                NavigationLink {
                    JobDetailView(job: job, viewModel: viewModel)
                } label: {
                    JobRowView(job: job)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct JobRowView: View {
    let job: CronJob

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: job.enabled == true ? "clock.arrow.circlepath" : "clock.badge.xmark")
                .font(.title3)
                .foregroundStyle(job.enabled == true ? .green : .secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(job.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(job.schedule)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()

                if let nextRun = job.nextRun {
                    Text("Next: \(nextRun.displayFormatted)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Text(job.enabled == true ? "Active" : "Paused")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(job.enabled == true ? .green : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    (job.enabled == true ? Color.green : Color.secondary)
                        .opacity(0.12),
                    in: Capsule()
                )
        }
        .padding(.vertical, 2)
    }
}
