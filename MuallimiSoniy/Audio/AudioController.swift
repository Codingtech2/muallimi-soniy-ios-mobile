import Foundation
import AVFoundation
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

    /// Reader-supplied handlers for the lock-screen / Control-Centre next &
    /// previous track buttons. The reader assigns them while it is on screen and
    /// clears them on exit; the Now Playing controller forwards its remote
    /// `onNext` / `onPrev` here. Never captured strongly by the controller.
    var onRemoteNext: (() -> Void)?
    var onRemotePrev: (() -> Void)?

    // MARK: - Engine

    private let engine = AudioEngine()
    /// Drives the lock-screen / Control-Centre Now Playing UI and remote commands.
    let nowPlaying = NowPlayingController()
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
            guard let self else { return }
            self.isPlaying = playing
            self.nowPlaying.setPlaybackRate(playing ? 1 : 0)
        }
        engine.onRepeatUpdate = { [weak self] index in
            self?.repeatIndex = index
        }
        engine.onSegmentComplete = { [weak self] in
            self?.onSegmentComplete?()
        }
        wireNowPlayingCommands()
        observeSessionEvents()
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

    /// Resumes playback. Reactivates the audio session first: after a system
    /// interruption the OS may have deactivated it, so a bare `play()` would be
    /// silent. `activate()` is a cheap no-op when the session is already live.
    func resume() {
        AudioSession.shared.activate()
        engine.resume()
    }

    func togglePlayPause() { engine.togglePlayPause() }

    /// Stops playback, clears segment state and tears down the Now Playing info.
    /// The engine fires its play-state callback, which resets `isPlaying`.
    func stop() {
        engine.stop()
        nowPlaying.clear()
    }

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

    // MARK: - Now Playing metadata

    /// Sets the lock-screen metadata for the active element. Called by the reader
    /// as each segment starts. Rate follows current playback so the transport
    /// button is correct even if the file then fails to load.
    func setNowPlaying(title: String, artist: String, album: String) {
        nowPlaying.update(title: title, artist: artist, album: album, rate: isPlaying ? 1 : 0)
    }

    /// Wires the remote play/pause to this controller and forwards remote
    /// next/previous to the reader-supplied handlers. `[weak self]` throughout, so
    /// the Now Playing controller never keeps the controller alive.
    private func wireNowPlayingCommands() {
        nowPlaying.onPlay = { [weak self] in self?.resume() }
        nowPlaying.onPause = { [weak self] in self?.pause() }
        nowPlaying.onNext = { [weak self] in self?.onRemoteNext?() }
        nowPlaying.onPrev = { [weak self] in self?.onRemotePrev?() }
    }

    // MARK: - Session interruptions & route changes

    /// Observes audio-session interruptions (calls, Siri) and route changes
    /// (headphones unplugged). Handlers hop to the main actor and only ever read
    /// `Sendable` primitives out of the notification — never a crash.
    private func observeSessionEvents() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) ?? 0
            Task { @MainActor [weak self] in self?.handleInterruption(typeRaw: raw) }
        }
        center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
            Task { @MainActor [weak self] in self?.handleRouteChange(reasonRaw: raw) }
        }
    }

    /// Interruption began → pause and mark the session inactive so a later manual
    /// resume reactivates it. Interruption ended → stay paused (never auto-resume
    /// mid-lesson, per product mandate). Unknown values are ignored.
    private func handleInterruption(typeRaw: UInt) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        switch type {
        case .began:
            pause()
            AudioSession.shared.invalidateActivation()
        case .ended:
            break
        @unknown default:
            break
        }
    }

    /// The previous output vanished (e.g. headphones unplugged) → pause instead of
    /// abruptly playing out loud. Other route-change reasons are ignored.
    private func handleRouteChange(reasonRaw: UInt) {
        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }
        if reason == .oldDeviceUnavailable {
            pause()
        }
    }
}
