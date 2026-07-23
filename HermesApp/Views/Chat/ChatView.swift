import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.messages.isEmpty && !viewModel.isStreaming {
                    emptyStateView
                } else {
                    messageListView
                }

                inputBarView
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Picker("Model", selection: $viewModel.selectedModel) {
                        Text("Hermes").tag("hermes")
                    }
                    .pickerStyle(.menu)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.messages.isEmpty {
                        Button("Clear") {
                            viewModel.clearChat()
                        }
                    }
                }
            }
        }
        .errorToast($viewModel.errorMessage)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "message.badge")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No messages yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Start a conversation with Hermes\nTap the mic to speak, or type below")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var messageListView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.messages) { message in
                        VStack(alignment: .trailing, spacing: 2) {
                            ChatBubbleView(message: message)
                                .id(message.id)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)

                            // TTS button on assistant messages
                            if message.messageRole == .assistant && viewModel.isSTTConfigured {
                                HStack(spacing: 8) {
                                    Spacer()
                                    Button {
                                        viewModel.speakMessage(message)
                                    } label: {
                                        Image(systemName: viewModel.isSpeaking && viewModel.speakingMessageId == message.id
                                              ? "speaker.wave.3.fill"
                                              : "speaker.wave.2")
                                            .font(.caption)
                                            .foregroundStyle(viewModel.isSpeaking && viewModel.speakingMessageId == message.id ? .blue : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 16)
                                }
                            }
                        }
                    }

                    // Streaming indicator
                    if viewModel.isStreaming, let lastMessage = viewModel.messages.last, lastMessage.messageRole == .assistant {
                        HStack {
                            ProgressView()
                                .padding(.leading, 16)
                            Text("Streaming...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .id("streaming-indicator")
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation {
                        scrollProxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.streamingContent) { _, _ in
                if let last = viewModel.messages.last {
                    scrollProxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var inputBarView: some View {
        VStack(spacing: 0) {
            Divider()

            // Recording indicator
            if viewModel.isRecording {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.red)
                        .font(.title3)
                    Text("Recording...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") {
                        viewModel.cancelRecording()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.red.opacity(0.1))
            }

            // Transcribing indicator
            if viewModel.isTranscribing {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Transcribing...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            HStack(alignment: .bottom, spacing: 8) {
                // Mic button
                if viewModel.isSTTConfigured {
                    Button {
                        if viewModel.isRecording {
                            viewModel.stopRecordingAndTranscribe()
                        } else {
                            viewModel.startRecording()
                        }
                    } label: {
                        Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title2)
                            .foregroundStyle(viewModel.isRecording ? .red : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isTranscribing)
                }

                // Text input
                TextField("Type a message...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))

                // Send/Stop button
                if viewModel.isStreaming {
                    Button {
                        viewModel.cancelStreaming()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        isInputFocused = false
                        Task {
                            await viewModel.sendMessage()
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }
}
