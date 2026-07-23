import SwiftUI

struct SettingsView: View {
    @State var viewModel = SettingsViewModel()
    @State private var showClearConfirmation = false
    @FocusState private var focusedField: Field?

    enum Field {
        case serverUrl, apiKey, deepInfraKey, model
    }

    var body: some View {
        Form {
            // MARK: - Server Connection
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. http://100.115.248.107:8642", text: $viewModel.serverURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .serverUrl)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("Bearer token", text: $viewModel.apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .apiKey)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Model")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Model name", text: $viewModel.model)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .model)
                }
                .padding(.vertical, 4)

                Button {
                    Task { await viewModel.testConnection() }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isTestingConnection {
                            ProgressView()
                        } else if let status = viewModel.connectionStatus {
                            Label(
                                status == .success ? "Connected ✓" : "Connection Failed",
                                systemImage: status == .success ? "checkmark.circle.fill" : "xmark.circle.fill"
                            )
                            .foregroundColor(status == .success ? .green : .red)
                        } else {
                            Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        Spacer()
                    }
                }
            } header: {
                Label("Hermes Server", systemImage: "server.rack")
            }

            // MARK: - Speech (DeepInfra)
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DeepInfra API Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("DeepInfra API key for speech", text: $viewModel.deepInfraKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .deepInfraKey)
                }
                .padding(.vertical, 4)

                if viewModel.hasSpeechConfigured {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Speech configured")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Speech-to-Text", systemImage: "mic.fill")
                        .font(.subheadline)
                    Text(viewModel.sttInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Text-to-Speech", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline)
                    Text(viewModel.ttsInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
            } header: {
                Label("Speech (DeepInfra)", systemImage: "waveform")
            } footer: {
                Text("STT and TTS use DeepInfra's cheapest models. Get a free API key at deepinfra.com/dash/api_keys")
            }

            // MARK: - Save
            Section {
                Button {
                    viewModel.saveConfig()
                    focusedField = nil
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Label("Save Configuration", systemImage: "square.and.arrow.down.fill")
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isLoading)
                .listRowBackground(Color.blue.opacity(0.15))

                if viewModel.saveSuccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Configuration saved")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            // MARK: - Danger Zone
            Section {
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Clear Saved Configuration", systemImage: "trash")
                        Spacer()
                    }
                }
                .disabled(!viewModel.hasSavedConfig)
            } header: {
                Label("Danger Zone", systemImage: "exclamationmark.shield.fill")
            }

            // MARK: - About
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "App", value: "Hermes Dashboard")
                    InfoRow(label: "iOS", value: UIDevice.current.systemVersion)
                    InfoRow(label: "Target", value: "iOS 17+")
                    if !viewModel.savedServerUrl.isEmpty {
                        InfoRow(label: "Server", value: viewModel.savedServerUrl)
                    }
                    if !viewModel.savedApiKeyMask.isEmpty {
                        InfoRow(label: "Key", value: viewModel.savedApiKeyMask)
                    }
                }
            } header: {
                Label("About", systemImage: "info.circle.fill")
            }
        }
        .navigationTitle("Settings")
        .alert("Clear Configuration", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) {
                viewModel.clearKeychain()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all saved configuration from the Keychain.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .task {
            viewModel.loadSettings()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .monospaced()
                .foregroundColor(.primary)
        }
    }
}
