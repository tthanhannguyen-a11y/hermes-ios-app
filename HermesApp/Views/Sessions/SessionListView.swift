import SwiftUI

struct SessionListView: View {
    @State private var viewModel = SessionViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading sessions...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionList
                }
            }
            .navigationTitle("Sessions")
            .refreshable {
                await viewModel.loadSessions()
            }
            .task {
                await viewModel.loadSessions()
            }
        }
        .errorToast($viewModel.errorMessage)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No sessions")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Sessions from past conversations will appear here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sessionList: some View {
        List {
            ForEach(viewModel.sessions) { session in
                NavigationLink {
                    SessionDetailView(sessionId: session.id, sessionName: session.name)
                } label: {
                    SessionRowView(session: session)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct SessionRowView: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.name)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)

            HStack(spacing: 8) {
                if let count = session.messageCount {
                    Label("\(count) messages", systemImage: "message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let updated = session.updatedAt {
                    Text(updated.displayFormatted)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
