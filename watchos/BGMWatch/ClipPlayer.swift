import AVFoundation
import Combine
import Foundation

/// Plays one bundled clip through the Apple Watch built-in speaker.
///
/// Speaker routing: the session uses category `.playback` with the DEFAULT
/// route-sharing policy. Apple's guidance is that `.longFormAudio` on watchOS
/// requires a Bluetooth route and shows the headphone route picker, while
/// not using `.longFormAudio` lets the app use the watch speaker:
///   https://developer.apple.com/documentation/watchkit/playing-background-audio
///   https://developer.apple.com/forums/thread/764292 (Apple engineer reply)
///
/// Volume: apps cannot read or set the system volume on watchOS. The player's
/// own gain is left at 1.0 (maximum relative level); the user changes loudness
/// with the system volume control shown in ContentView (Digital Crown).
final class ClipPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {

    enum State: String {
        case stopped = "STOPPED"
        case playing = "PLAYING"
        case error = "ERROR"
    }

    private enum ClipError: LocalizedError {
        case missingFile(String)
        case playFailed

        var errorDescription: String? {
            switch self {
            case .missingFile(let name):
                return "Clip not found in app bundle: \(name)"
            case .playFailed:
                return "AVAudioPlayer.play() returned false"
            }
        }
    }

    // Swap the clip: replace Resources/dude_emotional.m4a, or change these two values.
    static let clipTitle = "Dude - emotional"
    private let resourceName = "dude_emotional"
    private let resourceExtension = "m4a"

    @Published private(set) var state: State = .stopped
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var errorText: String?

    private var player: AVAudioPlayer?
    private var timer: Timer?

    var isPlaying: Bool { state == .playing }

    /// Play from the start, or stop if already playing.
    func toggle() {
        if isPlaying {
            stop()
        } else {
            play()
        }
    }

    func play() {
        stopPlayerOnly()
        errorText = nil
        elapsedSeconds = 0

        do {
            guard let url = Bundle.main.url(forResource: resourceName,
                                            withExtension: resourceExtension) else {
                throw ClipError.missingFile("\(resourceName).\(resourceExtension)")
            }

            let session = AVAudioSession.sharedInstance()
            // Default policy (NOT .longFormAudio) => watch speaker allowed,
            // no Bluetooth route picker.
            try session.setCategory(.playback, mode: .default, policy: .default, options: [])
            try session.setActive(true)

            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.volume = 1.0
            newPlayer.currentTime = 0
            _ = newPlayer.prepareToPlay()

            guard newPlayer.play() else {
                throw ClipError.playFailed
            }

            player = newPlayer
            state = .playing
            startTimer()
        } catch {
            fail(error.localizedDescription)
        }
    }

    func stop() {
        stopPlayerOnly()
        deactivateSession()
        state = .stopped
        elapsedSeconds = 0
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            if flag {
                self.stop()
            } else {
                self.fail("Playback ended unsuccessfully")
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async {
            self.fail("Decode error: \(error?.localizedDescription ?? "unknown")")
        }
    }

    // MARK: - Private

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.player else { return }
            self.elapsedSeconds = Int(player.currentTime)
        }
    }

    private func stopPlayerOnly() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func fail(_ message: String) {
        stopPlayerOnly()
        deactivateSession()
        errorText = message
        state = .error
    }
}
