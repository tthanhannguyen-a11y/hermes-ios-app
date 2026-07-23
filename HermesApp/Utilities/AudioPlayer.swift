import Foundation
import AVFoundation

/// Simple audio player for TTS playback
@MainActor
final class AudioPlayer: NSObject, AVAudioPlayerDelegate, ObservableObject {
    static let shared = AudioPlayer()

    @Published var isPlaying = false
    @Published var currentMessageId: String?

    private var player: AVAudioPlayer?
    private var completion: (() -> Void)?

    override private init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }

    func play(data: Data, messageId: String? = nil, completion: (() -> Void)? = nil) {
        stop()
        self.completion = completion
        self.currentMessageId = messageId

        do {
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
        } catch {
            print("AudioPlayer error: \(error)")
            isPlaying = false
            completion?()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentMessageId = nil
        completion?()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentMessageId = nil
            self.completion?()
            self.completion = nil
        }
    }
}
