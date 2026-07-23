import SwiftUI

struct SessionDetailView: View {
    let sessionId: String
    let sessionName: String

    @State private var viewModel = SessionViewModel()
    @State private var showForkSheet = false
    @State private var forkName = ""

    var body: some View {
        Group {
            if viewModel.isLoadingDetail {
                ProgressView("Loading messages...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sessionMessages.isEmpty {
                emptyStateView
            } else {
                messageList
            }
        }
        .navigationTitle(sessionName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    forkName = "\(sessionName) (fork)"
                    showForkSheet = true
                } label: {
                    Image(systemName: "arrow.triangle.branch")
                }
            }
        }
        .task {
            await viewModel.loadSessionDetail(id: sessionId)
        }
        .errorToast($viewModel.errorMessage)
        .alert("Fork Session", isPresented: $showForkSheet) {
            TextField("New session name", text: $forkName)
            Button("Cancel", role: .cancel) {}
            Button("Fork") {
                Task {
                    _ = await viewModel.forkSession(id: sessionId, newName: forkName)
                }
            }
        } message: {
            Text("Create a copy of this session with a new name.")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No messages in this session")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.sessionMessages) { message in
                    SessionMessageRowView(message: message)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
    }
}

struct SessionMessageRowView: View {
    let message: SessionMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: message.role == "user" ? "person.circle.fill" : "brain.head.profile")
                .font(.title3)
                .foregroundStyle(message.role == "user" ? .blue : .purple)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.role.capitalized)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(message.role == "user" ? .blue : .purple)

                Text(message.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                if let timestamp = message.timestamp {
                    Text(timestamp.displayFormatted)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
