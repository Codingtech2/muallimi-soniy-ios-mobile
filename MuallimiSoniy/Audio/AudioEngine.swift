import Foundation
import AVFoundation
import OSLog

/// Segment-accurate audio playback engine — the native port of the web
/// `AudioEngine.ts`.
///
/// Wraps a single `AVAudioPlayer` and drives the repeat / loop / segment-complete
/// logic from a ~40 ms `Timer` poll (no `CADisplayLink`), exactly like the web
/// version which polls `HTMLAudioElement.currentTime` every 40 ms. A "boundary"
/// is reached when `currentTime >= segmentEnd` **or** the player finished early —
/// chunk files can be a few ms shorter than the declared `end`, which the web
/// handles via the `ended` event and we detect through the player's
/// end-of-file delegate callback. A player the system stopped mid-file (a call,
/// Siri) never counts as finished; it just pauses.
///
/// Isolated to the main actor: it is created and driven from `AudioController`
/// (also main-actor) and its `Timer` fires on the main run loop.
@MainActor
final class AudioEngine {

    // MARK: - Tuning

    /// Poll cadence, mirroring the web engine's 40 ms `setInterval`.
    private static let pollInterval: TimeInterval = 0.04

    /// Default repeat count, matching the web engine (`repeatTarget = 3`).
    private static let defaultRepeatTarget = 3

    /// How many polls (~0.5 s) the player may sit stopped mid-file while we
    /// meant it to play before the engine treats that as a pause from outside.
    /// The interruption observer normally pauses us long before this.
    private static let externalStopGraceTicks = 12

    /// Playback-rate bounds (AVAudioPlayer handles 0.5×–2× cleanly).
    private static let rateRange: ClosedRange<Float> = 0.5...2.0
    /// Volume bounds.
    private static let volumeRange: ClosedRange<Float> = 0...1

    // MARK: - Callbacks (assigned by the owner)

    /// Fires every poll tick with the player's current time, in seconds.
    var onTimeUpdate: ((Double) -> Void)?
    /// Fires when playback starts (`true`) or stops / pauses / finishes (`false`).
    var onPlayStateChange: ((Bool) -> Void)?
    /// Fires once a segment has played its full repeat count with loop off.
    var onSegmentComplete: (() -> Void)?
    /// Fires with the current repeat index (0-based) — web parity.
    var onRepeatUpdate: ((Int) -> Void)?
    /// Fires when the engine pauses itself because the player was stopped
    /// mid-file from outside and no `pause()` followed (see `pollTick`).
    var onExternalPause: (() -> Void)?

    // MARK: - State

    private var player: AVAudioPlayer?
    private var loadedURL: URL?
    private var timer: Timer?

    private var segmentStart: Double = 0
    private var segmentEnd: Double = 0
    private var repeatTarget: Int = AudioEngine.defaultRepeatTarget
    private var repeatIndexValue: Int = 0
    private var loopMode: Bool = false
    private var isSegmentMode: Bool = false

    /// Desired playback rate / volume, retained so they re-apply to every newly
    /// loaded file (a fresh `AVAudioPlayer` resets to 1.0 / 1.0 otherwise).
    private var playbackRate: Float = 1.0
    private var playbackVolume: Float = 1.0

    /// Whether we *intend* the player to be playing. Lets the poll notice the
    /// player stopping on its own (`intendedPlaying && !player.isPlaying`).
    private var intendedPlaying: Bool = false

    /// Set by the player's end-of-file callback — the AVAudioPlayer equivalent
    /// of the web `ended` event, needed for chunks that are shorter than their
    /// declared `end` — and cleared whenever playback (re)starts. A stopped
    /// player only counts as finished when this is set.
    private var reachedEndOfFile = false
    /// Consecutive polls that found the player stopped mid-file while we
    /// meant it to play (see `externalStopGraceTicks`).
    private var externalStopTicks = 0

    /// True while the loaded player holds a started (or refused) segment /
    /// full play that has neither finished nor been stopped — the only audio
    /// `resume()` may continue.
    private(set) var isArmed = false
    /// True once the last segment / full play ran to its natural end, until
    /// `stop()` or the next play — `replayFinished()` can then play it again.
    private(set) var canReplayFinished = false

    /// Receives the player's end-of-file callback (a player only holds its
    /// delegate weakly, so the engine keeps it alive).
    private let playerDelegate = PlayerDelegateProxy()

    /// Bumped by every `load()` call and by `invalidatePendingLoads()`. A
    /// suspended `load()` compares its captured value after its async file read
    /// resumes; a mismatch means a newer request (or a cancellation) arrived
    /// first, so it must not install a player or start playback.
    private var loadGeneration: Int = 0

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "AudioEngine"
    )

    // MARK: - Readable state

    /// Full duration of the loaded file (whole file, not the segment).
    var duration: Double { player?.duration ?? 0 }
    var currentTime: Double { player?.currentTime ?? 0 }
    var repeatIndex: Int { repeatIndexValue }

    init() {
        playerDelegate.engine = self
    }

    // MARK: - Loading

    /// Loads (or reuses) the player for `url` and preloads its buffers.
    ///
    /// If the same file is already loaded, returns immediately — mirroring the
    /// web fast-path (`audio.src === resolved && readyState >= 4`). Throws
    /// `AudioEngineError` if the file cannot be opened or prepared so callers can
    /// degrade gracefully (the media pack may not be downloaded yet).
    ///
    /// Every call (fast path included) bumps `loadGeneration` first, so a newer
    /// `load()` always supersedes an older one still awaiting its file read —
    /// the last *requested* file wins, not the last one that happened to finish
    /// reading first.
    func load(url: URL) async throws {
        loadGeneration &+= 1
        let generation = loadGeneration
        if loadedURL == url, player != nil { return }
        stop()
        // Read the file OFF the main actor so disk I/O never blocks the UI; the
        // decoder is then built on the main actor from the in-memory bytes. A
        // missing / unreadable file throws here and is surfaced as `loadFailed`,
        // which the controller swallows — a bad chunk never crashes the app.
        let data: Data
        do {
            data = try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url)
            }.value
        } catch {
            logger.error("Read failed for \(url.lastPathComponent, privacy: .public): \(String(describing: error))")
            throw AudioEngineError.loadFailed(url, underlying: error)
        }
        guard generation == loadGeneration else {
            logger.debug("load(\(url.lastPathComponent, privacy: .public)) superseded by a newer request")
            throw AudioEngineError.superseded
        }
        do {
            let newPlayer = try AVAudioPlayer(data: data)
            // `enableRate` must be set before `prepareToPlay()` for speed control.
            newPlayer.enableRate = true
            guard newPlayer.prepareToPlay() else {
                throw AudioEngineError.prepareFailed(url)
            }
            newPlayer.rate = playbackRate
            newPlayer.volume = playbackVolume
            newPlayer.delegate = playerDelegate
            player = newPlayer
            loadedURL = url
        } catch let error as AudioEngineError {
            throw error
        } catch {
            logger.error("Decode failed for \(url.lastPathComponent, privacy: .public): \(String(describing: error))")
            throw AudioEngineError.loadFailed(url, underlying: error)
        }
    }

    /// Cancels any `load()` currently awaiting its file read, so it resolves to
    /// `.superseded` instead of installing a stale player. Called only by
    /// `AudioController.stop()` — `load()` already bumps `loadGeneration` on
    /// every call, which is enough for a *newer request* to supersede an older
    /// one; this covers the other case, where playback is cancelled with no new
    /// request following it (Back / swipe / stop while a load is in flight).
    func invalidatePendingLoads() {
        loadGeneration &+= 1
    }

    // MARK: - Playback

    /// Plays the `[start, end]` segment of the loaded file, resetting the repeat
    /// counter. Faithful to web `playSegment`: pause → seek to start → play.
    /// Returns `true` only if playback actually started — `player.play()` can
    /// return `false` when the audio session is interrupted/inactive, in
    /// which case the poll must never mistake this for a finished repeat.
    @discardableResult
    func playSegment(start: Double, end: Double) -> Bool {
        guard let player else { return false }
        isSegmentMode = true
        segmentStart = start
        segmentEnd = end
        repeatIndexValue = 0
        onRepeatUpdate?(0)
        isArmed = true
        canReplayFinished = false
        // Re-arming a finished player: pause + seek before play so a second
        // tap on the same element replays reliably (web comment: some engines
        // won't restart from an ended state without this).
        if player.isPlaying { player.pause() }
        player.currentTime = start
        resetEndDetection()
        guard player.play() else {
            intendedPlaying = false
            stopTimer()
            onPlayStateChange?(false)
            return false
        }
        intendedPlaying = true
        player.rate = playbackRate
        onPlayStateChange?(true)
        startTimer()
        return true
    }

    /// Plays the whole loaded file from the start (full-lesson audio). Returns
    /// `true` only if playback actually started (see `playSegment`).
    @discardableResult
    func playFull() -> Bool {
        guard let player else { return false }
        isSegmentMode = false
        isArmed = true
        canReplayFinished = false
        player.currentTime = 0
        resetEndDetection()
        guard player.play() else {
            intendedPlaying = false
            stopTimer()
            onPlayStateChange?(false)
            return false
        }
        intendedPlaying = true
        player.rate = playbackRate
        onPlayStateChange?(true)
        startTimer()
        return true
    }

    /// Pauses playback, keeping segment state so `resume()` continues it.
    func pause() {
        player?.pause()
        intendedPlaying = false
        stopTimer()
        onPlayStateChange?(false)
    }

    /// Resumes from the current position and restarts the poll. Only continues
    /// audio the engine can really resume (`isArmed`) — after `stop()` or a
    /// natural finish this is a no-op. Returns `true` only if playback actually
    /// resumed (see `playSegment`).
    @discardableResult
    func resume() -> Bool {
        guard let player, isArmed else { return false }
        resetEndDetection()
        guard player.play() else {
            intendedPlaying = false
            stopTimer()
            onPlayStateChange?(false)
            return false
        }
        intendedPlaying = true
        player.rate = playbackRate
        onPlayStateChange?(true)
        startTimer()
        return true
    }

    /// Plays the segment (or whole file) that last ran to its natural end once
    /// more — what a lock-screen PLAY does after a tapped ayah has finished (the
    /// web replays an ended `<audio>` the same way). Returns `true` only if
    /// playback actually started (see `playSegment`).
    @discardableResult
    func replayFinished() -> Bool {
        guard let player, canReplayFinished else { return false }
        canReplayFinished = false
        isArmed = true
        if isSegmentMode {
            // One short of the target, so a single pass completes it again.
            repeatIndexValue = max(0, repeatTarget - 1)
            onRepeatUpdate?(repeatIndexValue)
            player.currentTime = segmentStart
        } else {
            player.currentTime = 0
        }
        resetEndDetection()
        guard player.play() else {
            intendedPlaying = false
            stopTimer()
            onPlayStateChange?(false)
            return false
        }
        intendedPlaying = true
        player.rate = playbackRate
        onPlayStateChange?(true)
        startTimer()
        return true
    }

    func togglePlayPause() {
        if player?.isPlaying == true { pause() } else { resume() }
    }

    func seek(_ time: Double) {
        player?.currentTime = time
    }

    func setRepeatCount(_ count: Int) {
        repeatTarget = max(1, count)
    }

    func setLoopMode(_ on: Bool) {
        loopMode = on
    }

    /// Sets playback speed (clamped 0.5×…2×), retained across file loads and
    /// applied to the live player immediately. `enableRate` is turned on at load.
    func setSpeed(_ speed: Float) {
        playbackRate = min(Self.rateRange.upperBound, max(Self.rateRange.lowerBound, speed))
        player?.rate = playbackRate
    }

    /// Sets output volume (clamped 0…1), retained across file loads and applied
    /// to the live player immediately.
    func setVolume(_ v: Float) {
        playbackVolume = min(Self.volumeRange.upperBound, max(Self.volumeRange.lowerBound, v))
        player?.volume = playbackVolume
    }

    /// Stops playback and clears segment state (does not seek), mirroring web
    /// `stop()` (which calls `pause()` then resets the segment fields).
    func stop() {
        pause()
        isSegmentMode = false
        segmentStart = 0
        segmentEnd = 0
        repeatIndexValue = 0
        isArmed = false
        canReplayFinished = false
    }

    // MARK: - Poll

    private func startTimer() {
        stopTimer()
        // A weak proxy target keeps the timer from retaining the engine, and
        // `.common` mode keeps the poll alive while a scroll / gesture tracks.
        let proxy = WeakTimerTarget(self)
        let newTimer = Timer(
            timeInterval: Self.pollInterval,
            target: proxy,
            selector: #selector(WeakTimerTarget.tick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// One poll tick — the faithful port of the web `startPolling` body.
    fileprivate func pollTick() {
        guard let player else { return }
        onTimeUpdate?(player.currentTime)

        // The player stopped although we meant it to play. Only a real end of
        // file counts as finishing. The system also stops the player for a call
        // or Siri — that waits for the interruption pause, and becomes a pause
        // of its own if none arrives within the grace period.
        let stoppedOnItsOwn = intendedPlaying && !player.isPlaying
        guard !stoppedOnItsOwn || reachedEndOfFile else {
            externalStopTicks += 1
            if externalStopTicks >= Self.externalStopGraceTicks {
                pauseAfterExternalStop()
            }
            return
        }
        externalStopTicks = 0

        guard isSegmentMode else {
            // Full playback: surface a natural finish as a stop (web `ended`).
            if stoppedOnItsOwn {
                intendedPlaying = false
                stopTimer()
                markFinished()
                onPlayStateChange?(false)
            }
            return
        }

        // Boundary: reached segmentEnd, or the file ended before segmentEnd
        // (chunk durations can be slightly shorter than declared `end`).
        let finishedEarly = stoppedOnItsOwn
        let atBoundary = player.currentTime >= segmentEnd || finishedEarly
        guard atBoundary else { return }

        repeatIndexValue += 1
        onRepeatUpdate?(repeatIndexValue)

        if repeatIndexValue < repeatTarget {
            // Repeat: seek back to start and continue.
            restartSegment()
        } else if loopMode {
            // Loop: reset counter and replay.
            repeatIndexValue = 0
            onRepeatUpdate?(0)
            restartSegment()
        } else {
            // Done. Marked finished before the callback, so a `stop()` or a
            // new play started from inside it wins over this state.
            pause()
            markFinished()
            onSegmentComplete?()
        }
    }

    /// A segment / full play ran to its natural end: nothing is left to resume,
    /// but `replayFinished()` may play it once more.
    private func markFinished() {
        isArmed = false
        canReplayFinished = true
    }

    /// Clears the end-of-file bookkeeping whenever playback (re)starts.
    private func resetEndDetection() {
        reachedEndOfFile = false
        externalStopTicks = 0
    }

    /// The player was stopped mid-file from outside and nobody paused us:
    /// settle into a normal, resumable pause instead of polling a silent
    /// player forever.
    private func pauseAfterExternalStop() {
        logger.debug("player stopped mid-file from outside, treating it as a pause")
        pause()
        onExternalPause?()
    }

    /// End-of-file callback, forwarded by `PlayerDelegateProxy`. Ignored for a
    /// player that has since been replaced, or one we no longer meant to play.
    fileprivate func playerDidReachEnd(_ playerID: ObjectIdentifier) {
        guard let player, ObjectIdentifier(player) == playerID, intendedPlaying else { return }
        reachedEndOfFile = true
    }

    /// Seeks back to the segment start and resumes if the player has stopped.
    /// If `play()` is refused, stops polling instead of retrying every
    /// ~40 ms tick, and surfaces the state change once.
    private func restartSegment() {
        guard let player else { return }
        player.currentTime = segmentStart
        resetEndDetection()
        if !player.isPlaying {
            guard player.play() else {
                intendedPlaying = false
                stopTimer()
                onPlayStateChange?(false)
                return
            }
            intendedPlaying = true
            player.rate = playbackRate
        }
    }
}

/// Errors surfaced by `AudioEngine.load` so callers can degrade gracefully.
enum AudioEngineError: Error {
    case prepareFailed(URL)
    case loadFailed(URL, underlying: Error)
    /// A newer `load()` request (or an explicit cancellation) arrived before
    /// this one's file read resumed — it must not install a player or play.
    case superseded
}

/// Receives `AVAudioPlayer`'s end-of-file callback for the engine. The system
/// pauses a player for an interruption without calling it, which is how the
/// engine tells a real finish apart from a call or Siri.
private nonisolated final class PlayerDelegateProxy: NSObject, AVAudioPlayerDelegate {
    weak var engine: AudioEngine?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let playerID = ObjectIdentifier(player)
        let engine = engine
        // AVAudioPlayer calls this on the main thread; hop there if it ever doesn't.
        if Thread.isMainThread {
            MainActor.assumeIsolated { engine?.playerDidReachEnd(playerID) }
        } else {
            Task { @MainActor in engine?.playerDidReachEnd(playerID) }
        }
    }
}

/// Forwards `Timer` ticks to the engine without the timer retaining it, so the
/// engine can deinit normally even if `stop()` is never called. The `Timer`
/// fires on the main run loop, so `tick()` runs on the main actor.
private final class WeakTimerTarget {
    private weak var engine: AudioEngine?

    init(_ engine: AudioEngine) {
        self.engine = engine
    }

    @objc func tick() {
        engine?.pollTick()
    }
}
