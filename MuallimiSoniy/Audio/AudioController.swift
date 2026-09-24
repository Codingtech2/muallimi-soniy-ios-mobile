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
    var onRemoteNext: (() -> Void)? { didSet { refreshRemoteTrackCommands() } }
    var onRemotePrev: (() -> Void)? { didSet { refreshRemoteTrackCommands() } }
    /// Reader-supplied check whether remote next (+1) / previous (-1) would do
    /// anything right now. Those buttons are only enabled when a handler is
    /// set and this agrees (no check = the handler alone decides).
    var canRemoteSkip: ((Int) -> Bool)? { didSet { refreshRemoteTrackCommands() } }
    /// Reader-supplied play / pause for the headset / EarPods centre click,
    /// so it does exactly what the reader's own play button does. Without a
    /// reader on screen the click falls back to `togglePlayPause()`.
    var onRemoteTogglePlayPause: (() -> Void)?

    /// Invoked whenever playback actually starts or resumes, from any path
    /// (in-app button, lock screen, a queue's next item). A playback queue uses
    /// it to drop a stale "stalled" state once audio is moving again.
    var onPlaybackStarted: (() -> Void)?

    // MARK: - Engine

    private let engine = AudioEngine()
    /// Drives the lock-screen / Control-Centre Now Playing UI and remote commands.
    let nowPlaying = NowPlayingController()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "AudioController"
    )

    // MARK: - Request tracking

    /// A `playSegment`/`playFull` request, remembered so `pause()` can snapshot
    /// it if it lands while the request is still awaiting its file load, and
    /// `resume()` can re-issue it later.
    private enum PlaybackRequest {
        case segment(url: URL, start: Double, end: Double)
        case full(url: URL)
    }

    /// Bumped by every `playSegment`/`playFull` call and by `pause()`/`stop()`
    /// when they cancel a request still awaiting its load. A request compares
    /// its captured id after `await engine.load` resolves; a mismatch means it
    /// was superseded or cancelled, so it must never reach `engine.playSegment`/
    /// `playFull` — the last *requested* segment always wins, not the last one
    /// whose file happened to finish reading first.
    private var requestID: Int = 0
    /// The request currently between `await engine.load` and the matching
    /// `engine.playSegment`/`playFull` call, if any.
    private var inFlightRequest: PlaybackRequest?
    /// A request cancelled mid-load by `pause()`. `resume()` re-issues it since
    /// the engine never actually loaded it, so there is nothing there to resume.
    private var pendingResumable: PlaybackRequest?
    /// True once a `pause()` lands on audio the engine can really continue
    /// (`engine.isArmed`); cleared by `stop()`. Lets `resume()` tell "was
    /// paused" apart from "was stopped", so a stray lock-screen/AirPods/car PLAY
    /// after `stop()` is a no-op instead of replaying a stale player in
    /// full-file mode — even if an interruption or route change paused the
    /// already-stopped engine in between.
    private var isPaused: Bool = false

    /// Whether `resume()` would restart anything right now — a live pause or a
    /// request `pause()` cancelled mid-load. Lets a playback queue tell "paused"
    /// apart from "idle" without reaching into the bookkeeping above.
    var canResume: Bool { pendingResumable != nil || isPaused }

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
            if playing { self.onPlaybackStarted?() }
        }
        engine.onRepeatUpdate = { [weak self] index in
            self?.repeatIndex = index
        }
        engine.onSegmentComplete = { [weak self] in
            self?.onSegmentComplete?()
        }
        engine.onExternalPause = { [weak self] in
            // The system stopped the player mid-file (e.g. a call) and no
            // interruption pause reached us — keep it resumable like a pause.
            self?.isPaused = true
        }
        wireNowPlayingCommands()
        observeSessionEvents()
    }

    // MARK: - Playback

    /// Loads `url` then plays the `[start, end]` segment with repeat / loop.
    /// Failures are logged and swallowed so a missing file never crashes the UI.
    ///
    /// Returns `true` only if playback actually started **for this request**.
    /// The last *requested* segment always wins: if a newer `playSegment`/
    /// `playFull` call arrives, or `stop()`/`pause()` cancels this one, while
    /// its file is still loading, this returns `false` without ever touching
    /// the engine.
    @discardableResult
    func playSegment(url: URL, start: Double, end: Double) async -> Bool {
        requestID &+= 1
        let myID = requestID
        isPaused = false
        pendingResumable = nil
        inFlightRequest = .segment(url: url, start: start, end: end)
        AudioSession.shared.activate()
        do {
            try await engine.load(url: url)
        } catch AudioEngineError.superseded {
            if myID == requestID { inFlightRequest = nil }
            logger.debug("playSegment(\(url.lastPathComponent, privacy: .public)) superseded while loading")
            return false
        } catch {
            if myID == requestID { inFlightRequest = nil }
            logger.error("playSegment failed: \(String(describing: error))")
            return false
        }
        guard myID == requestID else {
            logger.debug("playSegment(\(url.lastPathComponent, privacy: .public)) cancelled before playback started")
            return false
        }
        inFlightRequest = nil
        duration = engine.duration
        let started = engine.playSegment(start: start, end: end)
        if !started {
            logger.debug("playSegment(\(url.lastPathComponent, privacy: .public)) refused by engine")
        }
        return started
    }

    /// Loads `url` then plays the whole file (full-lesson audio). Same request
    /// semantics as `playSegment` (see above).
    @discardableResult
    func playFull(url: URL) async -> Bool {
        requestID &+= 1
        let myID = requestID
        isPaused = false
        pendingResumable = nil
        inFlightRequest = .full(url: url)
        AudioSession.shared.activate()
        do {
            try await engine.load(url: url)
        } catch AudioEngineError.superseded {
            if myID == requestID { inFlightRequest = nil }
            logger.debug("playFull(\(url.lastPathComponent, privacy: .public)) superseded while loading")
            return false
        } catch {
            if myID == requestID { inFlightRequest = nil }
            logger.error("playFull failed: \(String(describing: error))")
            return false
        }
        guard myID == requestID else {
            logger.debug("playFull(\(url.lastPathComponent, privacy: .public)) cancelled before playback started")
            return false
        }
        inFlightRequest = nil
        duration = engine.duration
        let started = engine.playFull()
        if !started {
            logger.debug("playFull(\(url.lastPathComponent, privacy: .public)) refused by engine")
        }
        return started
    }

    /// Pauses playback. If a request is still awaiting its file load, the
    /// engine never started it — cancel that request (so its `await engine.load`
    /// never results in a late `playSegment`/`playFull` call) and remember it so
    /// `resume()` can re-issue it. Otherwise pauses the engine as before, and
    /// only counts as "paused" if the engine holds audio it can continue — an
    /// interruption, route change or remote PAUSE after `stop()` or a natural
    /// finish must not make a later PLAY resume a stale player.
    func pause() {
        if let pending = inFlightRequest {
            requestID &+= 1
            inFlightRequest = nil
            pendingResumable = pending
            logger.debug("pause: cancelled in-flight load, saved as pending resumable")
            return
        }
        engine.pause()
        isPaused = engine.isArmed
    }

    /// Resumes playback. Reactivates the audio session first: after a system
    /// interruption the OS may have deactivated it, so a bare `play()` would be
    /// silent. `activate()` is a cheap no-op when the session is already live.
    ///
    /// If `pause()` cancelled a request mid-load, re-issues it here instead —
    /// the engine never actually loaded it. Otherwise only resumes the engine
    /// if the last state-changing call was a `pause()` on live playback: after
    /// `stop()`, a stray lock-screen/AirPods/car PLAY must be a no-op instead of
    /// replaying a stale player in full-file mode. After a natural finish
    /// (never after `stop()`), PLAY replays that segment once, as the web does
    /// for an ended `<audio>`.
    func resume() {
        if let pending = pendingResumable {
            pendingResumable = nil
            switch pending {
            case .segment(let url, let start, let end):
                Task { @MainActor [weak self] in await self?.playSegment(url: url, start: start, end: end) }
            case .full(let url):
                Task { @MainActor [weak self] in await self?.playFull(url: url) }
            }
            return
        }
        guard isPaused else {
            if engine.canReplayFinished {
                AudioSession.shared.activate()
                engine.replayFinished()
            } else {
                logger.debug("resume: ignored — nothing paused")
            }
            return
        }
        AudioSession.shared.activate()
        if engine.resume() {
            isPaused = false
        }
    }

    /// Pauses if playing, otherwise resumes — through `pause()` / `resume()`,
    /// so after `stop()` it stays the same no-op a lock-screen PLAY is.
    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    /// Stops playback, cancels any request still awaiting its file load, clears
    /// segment state and tears down the Now Playing info. Also resets the
    /// mirrored progress fields so a stale progress line never freezes on the
    /// next page. The engine fires its play-state callback, which
    /// resets `isPlaying`.
    func stop() {
        if inFlightRequest != nil {
            logger.debug("stop: cancelled in-flight load")
        }
        requestID &+= 1
        inFlightRequest = nil
        pendingResumable = nil
        isPaused = false
        engine.invalidatePendingLoads()
        engine.stop()
        clearNowPlaying()
        currentTime = 0
        duration = 0
        repeatIndex = 0
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
        refreshRemoteTrackCommands()
    }

    /// Wires the remote play/pause to this controller and forwards remote
    /// next/previous to the reader-supplied handlers. `[weak self]` throughout, so
    /// the Now Playing controller never keeps the controller alive.
    private func wireNowPlayingCommands() {
        nowPlaying.onPlay = { [weak self] in self?.resume() }
        nowPlaying.onPause = { [weak self] in self?.pause() }
        nowPlaying.onTogglePlayPause = { [weak self] in self?.performRemoteTogglePlayPause() }
        nowPlaying.onNext = { [weak self] in self?.performRemoteSkip(by: 1) ?? false }
        nowPlaying.onPrev = { [weak self] in self?.performRemoteSkip(by: -1) ?? false }
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
        center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleMediaServicesReset() }
        }
    }

    /// The system's media services restarted (a Bluetooth / AirPods fault, or
    /// Settings › Developer › Reset Media Services): the session is back to its
    /// defaults and the loaded player is dead. Re-apply the session on the
    /// next play and drop the player so it is never reused. Audio that was
    /// playing or paused becomes a resumable request — the next play / resume
    /// starts that segment over on a fresh player, instead of doing nothing.
    private func handleMediaServicesReset() {
        logger.error("media services were reset, rebuilding the audio session and player")
        AudioSession.shared.resetAfterMediaServicesReset()
        if inFlightRequest != nil {
            // Its file is still loading and it plays in a moment: bring the
            // session back first, the way `playSegment` / `playFull` began.
            AudioSession.shared.activate()
        }
        guard let unfinished = engine.discardPlayer() else { return }
        isPaused = false
        if pendingResumable == nil {
            if let segment = unfinished.segment {
                pendingResumable = .segment(url: unfinished.url, start: segment.start, end: segment.end)
            } else {
                pendingResumable = .full(url: unfinished.url)
            }
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
