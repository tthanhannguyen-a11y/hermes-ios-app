import Foundation
import Observation
import SwiftUI
import AVFoundation

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var streamingContent = ""
    var errorMessage: String?
    var inputText = ""
    var selectedModel = "hermes"

    // Voice / STT state
    var isRecording = false
    var isTranscribing = false
    var isSTTConfigured: Bool {
        DeepInfraSpeechService.shared.isConfigured
    }

    // TTS state
    var isSpeaking = false
    var speakingMessageId: String?

    var isConfigured: Bool {
        APIClient.shared.isConfigured
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        inputText = ""
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1

        isStreaming = true
        streamingContent = ""

        let stream = APIClient.shared.streamChatCompletion(model: selectedModel, messages: messages.dropLast())
        do {
            for try await content in stream {
                streamingContent += content
                messages[assistantIndex] = ChatMessage(
                    id: messages[assistantIndex].id,
                    role: .assistant,
                    content: streamingContent,
                    timestamp: messages[assistantIndex].timestamp
                )
            }
        } catch {
            if streamingContent.isEmpty {
                messages.removeLast()
            }
            errorMessage = error.localizedDescription
        }

        isStreaming = false
        streamingContent = ""
    }

    // MARK: - STT (Voice Recording → Transcription)

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    func startRecording() {
        guard isSTTConfigured else {
            errorMessage = "DeepInfra API key not configured."
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)

            let tempDir = FileManager.default.temporaryDirectory
            recordingURL = tempDir.appendingPathComponent("hermes_recording.m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    func stopRecordingAndTranscribe() {
        audioRecorder?.stop()
        isRecording = false

        guard let url = recordingURL, let audioData = try? Data(contentsOf: url) else {
            errorMessage = "Failed to read recording."
            return
        }

        isTranscribing = true
        Task {
            do {
                let response = try await DeepInfraSpeechService.shared.transcribe(audioData: audioData)
                if !response.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    inputText = response.text
                } else {
                    errorMessage = "No speech detected."
                }
            } catch {
                errorMessage = "Transcription failed: \(error.localizedDescription)"
            }
            isTranscribing = false
        }
    }

    func cancelRecording() {
        audioRecorder?.stop()
        isRecording = false
        audioRecorder = nil
        recordingURL = nil
    }

    // MARK: - TTS (Text-to-Speech)

    func speakMessage(_ message: ChatMessage) {
        guard isSTTConfigured, !message.content.isEmpty else { return }

        // Toggle: stop if already speaking this message
        if isSpeaking && speakingMessageId == message.id {
            AudioPlayer.shared.stop()
            isSpeaking = false
            speakingMessageId = nil
            return
        }

        speakingMessageId = message.id
        isSpeaking = true

        Task {
            do {
                let audioData = try await DeepInfraSpeechService.shared.synthesize(text: message.content)
                AudioPlayer.shared.play(data: audioData, messageId: message.id) { [weak self] in
                    Task { @MainActor in
                        self?.isSpeaking = false
                        self?.speakingMessageId = nil
                    }
                }
            } catch {
                errorMessage = "TTS failed: \(error.localizedDescription)"
                isSpeaking = false
                speakingMessageId = nil
            }
        }
    }

    func stopSpeaking() {
        AudioPlayer.shared.stop()
        isSpeaking = false
        speakingMessageId = nil
    }

    // MARK: - Actions

    func clearChat() {
        messages.removeAll()
        streamingContent = ""
        errorMessage = nil
    }

    func cancelStreaming() {
        isStreaming = false
    }
}
