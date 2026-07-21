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
/// handles via the `ended` event and we detect as `intendedPlaying && !isPlaying`.
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

    /// Whether we *intend* the player to be playing. Lets the poll detect a
    /// natural finish (`intendedPlaying && !player.isPlaying`) — the AVAudioPlayer
    /// equivalent of the web `ended` event, needed for chunks that are shorter
    /// than their declared `end`.
    private var intendedPlaying: Bool = false

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "AudioEngine"
    )

    // MARK: - Readable state

    /// Full duration of the loaded file (whole file, not the segment).
    var duration: Double { player?.duration ?? 0 }
    var currentTime: Double { player?.currentTime ?? 0 }
    var repeatIndex: Int { repeatIndexValue }

    // MARK: - Loading

    /// Loads (or reuses) the player for `url` and preloads its buffers.
    ///
    /// If the same file is already loaded, returns immediately — mirroring the
    /// web fast-path (`audio.src === resolved && readyState >= 4`). Throws
    /// `AudioEngineError` if the file cannot be opened or prepared so callers can
    /// degrade gracefully (the media pack may not be downloaded yet).
    func load(url: URL) async throws {
        if loadedURL == url, player != nil { return }
        stop()
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            // `enableRate` must be set before `prepareToPlay()` for speed control.
            newPlayer.enableRate = true
            guard newPlayer.prepareToPlay() else {
                throw AudioEngineError.prepareFailed(url)
            }
            newPlayer.rate = playbackRate
            newPlayer.volume = playbackVolume
            player = newPlayer
            loadedURL = url
        } catch let error as AudioEngineError {
            throw error
        } catch {
            logger.error("Load failed for \(url.lastPathComponent, privacy: .public): \(String(describing: error))")
            throw AudioEngineError.loadFailed(url, underlying: error)
        }
    }

    // MARK: - Playback

    /// Plays the `[start, end]` segment of the loaded file, resetting the repeat
    /// counter. Faithful to web `playSegment`: pause → seek to start → play.
    func playSegment(start: Double, end: Double) {
        guard let player else { return }
        isSegmentMode = true
        segmentStart = start
        segmentEnd = end
        repeatIndexValue = 0
        onRepeatUpdate?(0)
        // Re-arming a finished player: pause + seek before play so a second
        // tap on the same element replays reliably (web comment: some engines
        // won't restart from an ended state without this).
        if player.isPlaying { player.pause() }
        player.currentTime = start
        intendedPlaying = true
        player.play()
        player.rate = playbackRate
        onPlayStateChange?(true)
        startTimer()
    }

    /// Plays the whole loaded file from the start (full-lesson audio).
    func playFull() {
        guard let player else { return }
        isSegmentMode = false
        player.currentTime = 0
        intendedPlaying = true
        player.play()
        player.rate = playbackRate
        onPlayStateChange?(true)
        startTimer()
    }

    /// Pauses playback, keeping segment state so `resume()` continues it.
    func pause() {
        player?.pause()
        intendedPlaying = false
        stopTimer()
        onPlayStateChange?(false)
    }

    /// Resumes from the current position and restarts the poll.
    func resume() {
        guard let player else { return }
        intendedPlaying = true
        player.play()
        player.rate = playbackRate
        onPlayStateChange?(true)
        startTimer()
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

        guard isSegmentMode else {
            // Full playback: surface a natural finish as a stop (web `ended`).
            if intendedPlaying && !player.isPlaying {
                intendedPlaying = false
                stopTimer()
                onPlayStateChange?(false)
            }
            return
        }

        // Boundary: reached segmentEnd, or the file ended before segmentEnd
        // (chunk durations can be slightly shorter than declared `end`).
        let finishedEarly = intendedPlaying && !player.isPlaying
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
            // Done.
            pause()
            onSegmentComplete?()
        }
    }

    /// Seeks back to the segment start and resumes if the player has stopped.
    private func restartSegment() {
        guard let player else { return }
        player.currentTime = segmentStart
        if !player.isPlaying {
            intendedPlaying = true
            player.play()
            player.rate = playbackRate
        }
    }
}

/// Errors surfaced by `AudioEngine.load` so callers can degrade gracefully.
enum AudioEngineError: Error {
    case prepareFailed(URL)
    case loadFailed(URL, underlying: Error)
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
