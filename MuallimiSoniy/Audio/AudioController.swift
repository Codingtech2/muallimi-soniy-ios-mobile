import Foundation
import OSLog

/// Main-actor, observable playback controller — the native port of the web
/// `useAudio` hook.
///
/// Owns a single `AudioEngine`, exposes observable `isPlaying` / `currentTime` /
/// `duration` (+ `repeatIndex` for parity), and forwards segment / full-file
/// playback plus repeat / loop configuration. Loading resolves before playback,
/// mirroring `useAudio.playSegment` (`await loadAudio` then `playSegment`).
@MainActor
@Observable
final class AudioController {

    // MARK: - Observable state

    private(set) var isPlaying: Bool = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    /// 0-based repeat index of the active segment (web parity).
    private(set) var repeatIndex: Int = 0

    /// Invoked when the active segment finishes all its repeats with loop off.
    /// The reader assigns this to advance to the next element in sequential mode
    /// (mirrors `setOnSegmentComplete`).
    var onSegmentComplete: (() -> Void)?

    // MARK: - Engine

    private let engine = AudioEngine()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "AudioController"
    )

    init() {
        engine.onTimeUpdate = { [weak self] time in
            guard let self else { return }
            self.currentTime = time
            self.duration = self.engine.duration
        }
        engine.onPlayStateChange = { [weak self] playing in
            self?.isPlaying = playing
        }
        engine.onRepeatUpdate = { [weak self] index in
            self?.repeatIndex = index
        }
        engine.onSegmentComplete = { [weak self] in
            self?.onSegmentComplete?()
        }
    }

    // MARK: - Playback

    /// Loads `url` then plays the `[start, end]` segment with repeat / loop.
    /// Failures are logged and swallowed so a missing file never crashes the UI.
    func playSegment(url: URL, start: Double, end: Double) async {
        AudioSession.shared.activate()
        do {
            try await engine.load(url: url)
            duration = engine.duration
            engine.playSegment(start: start, end: end)
        } catch {
            logger.error("playSegment failed: \(String(describing: error))")
        }
    }

    /// Loads `url` then plays the whole file (full-lesson audio).
    func playFull(url: URL) async {
        AudioSession.shared.activate()
        do {
            try await engine.load(url: url)
            duration = engine.duration
            engine.playFull()
        } catch {
            logger.error("playFull failed: \(String(describing: error))")
        }
    }

    func pause() { engine.pause() }
    func resume() { engine.resume() }
    func togglePlayPause() { engine.togglePlayPause() }

    /// Stops playback and clears segment state. The engine fires its play-state
    /// callback, which resets `isPlaying`.
    func stop() { engine.stop() }

    func seek(_ time: Double) {
        engine.seek(time)
        currentTime = time
    }

    // MARK: - Configuration

    func setRepeatCount(_ count: Int) { engine.setRepeatCount(count) }
    func setLoopMode(_ on: Bool) { engine.setLoopMode(on) }
    /// Playback speed (0.5×…2×) — clamped in the engine.
    func setSpeed(_ speed: Double) { engine.setSpeed(Float(speed)) }
    /// Output volume (0…1) — clamped in the engine.
    func setVolume(_ volume: Double) { engine.setVolume(Float(volume)) }
}
