import AVFoundation
import OSLog

/// Configures and activates the shared `AVAudioSession` for playback.
///
/// The `.playback` category keeps audio playing with the silent switch on and
/// while the app is backgrounded (the target's `Info.plist` declares the
/// `audio` background mode). Activation is lazy — on first play — so the app
/// does not claim the audio session before the user actually plays anything.
@MainActor
final class AudioSession {
    static let shared = AudioSession()

    private var isConfigured = false
    private var isActive = false
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "AudioSession"
    )

    private init() {}

    /// Sets the `.playback` category once. Safe to call repeatedly.
    func configure() {
        guard !isConfigured else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            isConfigured = true
        } catch {
            logger.error("Category setup failed: \(String(describing: error))")
        }
    }

    /// Activates the session (configuring first if needed). Call on first play.
    func activate() {
        configure()
        guard !isActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            isActive = true
        } catch {
            logger.error("Activation failed: \(String(describing: error))")
        }
    }

    /// Deactivates the session (e.g. when leaving the reader), letting other
    /// apps resume their audio.
    func deactivate() {
        guard isActive else { return }
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            isActive = false
        } catch {
            logger.error("Deactivation failed: \(String(describing: error))")
        }
    }
}
