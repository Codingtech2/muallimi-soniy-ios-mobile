import Foundation
import OSLog

/// Drives one memorization (hifz) session: feeds `AudioController` one unit at
/// a time following a `HifzSequence`, optionally inserting a silent "your
/// turn" gap between plays, until the sequence ends or the reader stops it.
///
/// Request identity mirrors `AudioController`'s own "last requested wins"
/// rule: every `playUnit`/`startGap` call bumps `playToken`, and a `stop()` or
/// `start()` restart bumps `sessionID` too, so a stale `await audio.playSegment`
/// result from a superseded unit can never be mistaken for a real failure.
@MainActor
@Observable
final class HifzController {

    enum Phase: Sendable {
        case idle
        case playing
        case gap
    }

    enum EndReason: Sendable {
        case completed
        case stopped
        case failed
    }

    // MARK: - Observable state

    private(set) var phase: Phase = .idle
    private(set) var plan: HifzPlan?
    private(set) var session: HifzSession?
    private(set) var cursor: HifzCursor?
    private(set) var sequence: HifzSequence?
    private(set) var currentUnit: HifzUnit?
    /// The current gap's wall-clock length, valid while `phase == .gap`.
    private(set) var gapSeconds: Double = 0
    /// True when a unit (or the gap) failed to start and there is nothing
    /// pending to resume — the UI should offer a manual retry instead of
    /// looking permanently stuck.
    private(set) var isStalled = false
    /// When the sleep timer ends this session, `nil` while it's off. Plain
    /// wall-clock time, checked only as a unit or gap finishes — so it works
    /// with the screen locked and the app in the background, where no UI
    /// timer would fire.
    private(set) var sleepDeadline: Date?

    var isActive: Bool { phase != .idle }

    // MARK: - Hooks (assigned by the reader before `start`, cleared by `finish`)

    var onUnitStart: ((HifzUnit, HifzCursor) -> Void)?
    var onGapStart: ((HifzUnit, Double) -> Void)?
    var onEnd: ((EndReason) -> Void)?

    // MARK: - Dependencies & session bookkeeping

    /// Borrowed for the duration of a session — owned by the app, not by us.
    private weak var audio: AudioController?

    /// Bumped by `start()` (fresh session) and `finish()`. A stale async
    /// continuation compares its captured value and bails out if it no longer
    /// matches, instead of touching state that belongs to a different session.
    private var sessionID = 0
    /// Bumped by every `playUnit`/`startGap` call and by `finish()`. Same idea
    /// as `sessionID` but at unit granularity, so a `skip()` or replay within
    /// the *same* session still supersedes an older in-flight play correctly.
    private var playToken = 0

    /// The unit to play once the running gap finishes.
    private var pendingCursor: HifzCursor?

    /// Tap defaults saved by `start()` and restored by `finish()`, so a hifz
    /// session never leaves the reader's own repeat/loop settings changed.
    private var savedTapRepeatCount = 1
    private var savedTapLoop = false
    /// Current playback rate, used only to convert a wall-clock gap length
    /// into the matching silence-segment length (see `startGap`).
    private var playbackRate: Double = 1

    /// Length of `hifz-silence.wav`. Speed tops out at 2× (settings and
    /// engine), so the clip covers the longest 10 s gap in full at any speed.
    private static let maxSilenceSeconds: Double = 20
    private static let silenceURL: URL? = Bundle.main.url(forResource: "hifz-silence", withExtension: "wav")

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "Hifz"
    )

    init() {}

    // MARK: - Start / stop

    // These params are a fixed entry-point contract the reader calls directly —
    // a config struct would just move the same values one level out.
    // swiftlint:disable function_parameter_count

    /// Starts a new session. If one is already active, it is finished as
    /// `.stopped` first — callers that just did their own `stop()` (the normal
    /// reader flow) see this as a no-op since `phase` is already `.idle`.
    ///
    /// Rebuilds the real sequence from `session.sequence` (which only carries
    /// the resolved `unitCount`/`firstRoundOnlyCount`) combined with the
    /// user's `plan.eachAyah`/`plan.rounds`. `resumeCursor` — a cursor this
    /// same plan reached before it was interrupted — starts there instead of
    /// at the first unit.
    func start(
        plan: HifzPlan,
        session: HifzSession,
        audio: AudioController,
        tapRepeatCount: Int,
        tapLoop: Bool,
        playbackRate: Double,
        resumingAt resumeCursor: HifzCursor? = nil
    ) {
        // swiftlint:enable function_parameter_count
        if isActive {
            finish(.stopped)
        }

        self.audio = audio
        self.plan = plan
        self.session = session
        self.savedTapRepeatCount = tapRepeatCount
        self.savedTapLoop = tapLoop
        self.playbackRate = playbackRate
        sleepDeadline = HifzTiming.sleepDeadline(length: plan.sleepAfter, from: Date())
        pendingCursor = nil
        isStalled = false

        // The controller counts repeats itself, so the engine plays each
        // segment exactly once per request.
        audio.setRepeatCount(1)
        audio.setLoopMode(false)
        audio.onSegmentComplete = { [weak self] in self?.segmentDidComplete() }
        audio.onPlaybackStarted = { [weak self] in self?.playbackDidStart() }
        sessionID &+= 1

        let realSequence = HifzSequence(
            unitCount: session.sequence.unitCount,
            eachAyah: plan.eachAyah,
            rounds: plan.rounds,
            firstRoundOnlyCount: session.sequence.firstRoundOnlyCount
        )
        sequence = realSequence
        logStart(plan: plan, unitCount: realSequence.unitCount)

        guard let first = resumeCursor ?? realSequence.first() else {
            finish(.completed)
            return
        }
        playUnit(at: first)
    }

    /// Idempotent — a no-op while idle. Ends the session as `.stopped` and
    /// stops the underlying audio controller (cancelling any in-flight load).
    func stop() {
        guard isActive else { return }
        finish(.stopped)
        audio?.stop()
    }

    // MARK: - Transport

    /// The reader's play/pause button while a session is active.
    func togglePlayPause() {
        guard isActive, let audio else { return }
        if audio.isPlaying {
            audio.pause()
        } else if audio.canResume {
            audio.resume()
        } else {
            replayCurrent()
        }
    }

    /// Jumps `delta` units from the current cursor (always relative to the
    /// last unit that started — mid-gap this is still the just-finished unit,
    /// so skipping cancels the gap and plays the landed-on unit from its own
    /// start).
    func skip(by delta: Int) {
        guard isActive, let sequence, let cursor else { return }
        let target = sequence.skip(from: cursor, by: delta)
        playUnit(at: target)
    }

    /// Updates the wall-clock-to-segment conversion used by `startGap`, e.g.
    /// when the reader's global speed setting changes mid-session.
    func setPlaybackRate(_ rate: Double) {
        playbackRate = rate
    }

    // MARK: - Playback

    /// Replays the current unit from its start, or restarts the current gap —
    /// used when the engine is idle/stalled rather than genuinely paused.
    private func replayCurrent() {
        isStalled = false
        if phase == .gap, let currentUnit {
            startGap(afterUnit: currentUnit, nextCursor: pendingCursor)
            return
        }
        guard let cursor else { return }
        playUnit(at: cursor)
    }

    /// Plays the unit at `cursor`. Never crashes on an out-of-range cursor —
    /// treats it as the sequence being finished.
    private func playUnit(at cursor: HifzCursor) {
        guard let session, cursor.unitIndex >= 0, cursor.unitIndex < session.units.count else {
            finish(.completed)
            return
        }
        let unit = session.units[cursor.unitIndex]

        playToken &+= 1
        let myToken = playToken
        let mySessionID = sessionID

        self.cursor = cursor
        currentUnit = unit
        pendingCursor = nil
        isStalled = false

        let url = MediaLocator.url(forRelativePath: unit.audioPath)
        guard MediaLocator.exists(url) else {
            logger.error("hifz unit audio missing on disk: \(unit.audioPath, privacy: .public)")
            finish(.failed)
            return
        }

        phase = .playing
        onUnitStart?(unit, cursor)
        logPlay(unit: unit, cursor: cursor)

        Task { @MainActor [weak self] in
            guard let self, let audio = self.audio else { return }
            let started = await audio.playSegment(url: url, start: unit.start, end: unit.end)
            // A newer play (skip / replay / restart / stop) already took over.
            guard self.sessionID == mySessionID, self.playToken == myToken else { return }
            guard !started else { return }
            if audio.canResume {
                // Paused mid-load by the user — resume() will re-issue it.
                return
            }
            self.isStalled = true
            self.logger.error("hifz unit failed to start: \(unit.id, privacy: .public)")
        }
    }

    /// Starts the "your turn" silence gap after `unit`, then plays
    /// `nextCursor` once it finishes — or completes the session when there is
    /// nothing left (the learner's turn after the last listen).
    /// Highlight/current-unit stay pointed at `unit` while the gap runs — only
    /// `phase`/`gapSeconds` change.
    private func startGap(afterUnit unit: HifzUnit, nextCursor: HifzCursor?) {
        guard let silenceURL = Self.silenceURL else {
            logger.error("hifz gap silence file missing from bundle, skipping pause")
            if let nextCursor {
                playUnit(at: nextCursor)
            } else {
                finish(.completed)
            }
            return
        }

        let safeRate = playbackRate > 0 ? playbackRate : 1
        let gap = HifzTiming.gapSeconds(unitSeconds: unit.duration, playbackRate: safeRate)
        let segmentEnd = min(gap * safeRate, Self.maxSilenceSeconds)
        // The silence plays at the current speed, so this is how long it
        // really lasts — what the strip counts down and Now Playing reports.
        let silenceSeconds = segmentEnd / safeRate

        playToken &+= 1
        let myToken = playToken
        let mySessionID = sessionID

        pendingCursor = nextCursor
        phase = .gap
        gapSeconds = silenceSeconds
        isStalled = false
        onGapStart?(unit, silenceSeconds)
        logGap(seconds: silenceSeconds, after: unit)

        Task { @MainActor [weak self] in
            guard let self, let audio = self.audio else { return }
            let started = await audio.playSegment(url: silenceURL, start: 0, end: segmentEnd)
            guard self.sessionID == mySessionID, self.playToken == myToken else { return }
            guard !started else { return }
            if audio.canResume {
                return
            }
            self.isStalled = true
            self.logger.error("hifz gap failed to start after unit: \(unit.id, privacy: .public)")
        }
    }

    // MARK: - Segment completion

    /// Wired to `audio.onSegmentComplete` by `start()`.
    private func segmentDidComplete() {
        guard isActive else { return }
        if sleepTimerHasRunOut {
            endForSleepTimer()
            return
        }
        if phase == .gap {
            guard let next = pendingCursor else {
                finish(.completed)
                return
            }
            pendingCursor = nil
            playUnit(at: next)
            return
        }
        guard let unit = currentUnit else {
            finish(.completed)
            return
        }
        advance(after: unit)
    }

    /// Decides what plays after `unit` finishes: a gap then the next step (the
    /// last listen gets its gap too, then the session ends), the next step
    /// immediately, or the sequence's end.
    private func advance(after unit: HifzUnit) {
        guard let sequence, let cursor else {
            finish(.completed)
            return
        }
        let next = sequence.next(after: cursor)
        if plan?.pauseToRepeat == true {
            startGap(afterUnit: unit, nextCursor: next)
        } else if let next {
            playUnit(at: next)
        } else {
            finish(.completed)
        }
    }

    /// Wired to `audio.onPlaybackStarted` by `start()`: audio is moving again
    /// (e.g. resumed from the lock screen after a call), so a retry prompt from
    /// an earlier refused start is stale.
    private func playbackDidStart() {
        guard isActive else { return }
        isStalled = false
    }

    // MARK: - Finish

    /// Restores the reader's own tap repeat/loop settings, tears down the
    /// session, and notifies the reader. `plan`/`session`/`cursor`/
    /// `currentUnit` are deliberately left as-is so the UI can keep showing
    /// where the session ended.
    private func finish(_ reason: EndReason) {
        audio?.setRepeatCount(savedTapRepeatCount)
        audio?.setLoopMode(savedTapLoop)
        audio?.onSegmentComplete = nil
        audio?.onPlaybackStarted = nil
        if reason != .stopped {
            // Ended on its own, so nothing plays next: clear the lock-screen
            // entry and progress line, and hand the audio session back so
            // other apps may resume. A stop (user, reader, restart) leaves the
            // session to its caller, so a restart never bounces it.
            audio?.stop()
            AudioSession.shared.deactivate()
        }
        sessionID &+= 1
        playToken &+= 1
        phase = .idle
        isStalled = false
        pendingCursor = nil
        logEnd(reason)

        let endHandler = onEnd
        endHandler?(reason)
        onUnitStart = nil
        onGapStart = nil
        onEnd = nil
    }

    // MARK: - Logging

    private func logStart(plan: HifzPlan, unitCount: Int) {
        let (scopeName, target) = Self.scopeDescription(plan.scope)
        let each = Self.repeatDescription(plan.eachAyah)
        let rounds = Self.repeatDescription(plan.rounds)
        let pause = plan.pauseToRepeat ? 1 : 0
        let sleep = plan.sleepAfter.map { String(format: "%.0fs", $0) } ?? "off"
        let message = "hifz start scope=\(scopeName) target=\(target) units=\(unitCount) "
            + "each=\(each) rounds=\(rounds) pause=\(pause) sleep=\(sleep)"
        logger.info("\(message, privacy: .public)")
    }

    private func logPlay(unit: HifzUnit, cursor: HifzCursor) {
        let each = plan.map { Self.repeatDescription($0.eachAyah) } ?? "1"
        let rounds = plan.map { Self.repeatDescription($0.rounds) } ?? "1"
        let message = "hifz play unit=\(unit.id) page=\(unit.globalIndex) "
            + "play=\(cursor.playIndex + 1)/\(each) round=\(cursor.roundIndex + 1)/\(rounds)"
        logger.info("\(message, privacy: .public)")
    }

    private func logGap(seconds: Double, after unit: HifzUnit) {
        let formatted = String(format: "%.1f", seconds)
        let message = "hifz gap seconds=\(formatted) after=\(unit.id)"
        logger.info("\(message, privacy: .public)")
    }

    private func logEnd(_ reason: EndReason) {
        logger.info("\(Self.endReasonMessage(reason), privacy: .public)")
    }
}

// MARK: - Sleep timer

extension HifzController {
    /// Whether the sleep timer is on and its time is up. Asked only when a
    /// unit or gap finishes, so the unit playing when time runs out is always
    /// heard to its end.
    private var sleepTimerHasRunOut: Bool {
        guard let sleepDeadline else { return false }
        return HifzTiming.sleepTimeLeft(until: sleepDeadline, now: Date()) <= 0
    }

    /// Time is up: ends the session as a stop, the same way the strip's Stop
    /// button does — the lock-screen entry goes, a stray PLAY stays a no-op,
    /// and other apps get the audio session back.
    private func endForSleepTimer() {
        let message = "hifz sleep timer ran out after unit=\(currentUnit?.id ?? "-")"
        logger.info("\(message, privacy: .public)")
        stop()
        AudioSession.shared.deactivate()
    }
}

// MARK: - Log formatting helpers (pure, file-private — kept out of the class body)

extension HifzController {
    fileprivate static func scopeDescription(_ scope: HifzScope) -> (name: String, target: String) {
        switch scope {
        case .ayah(let unitID): return ("ayah", unitID)
        case .surah(let number): return ("surah", String(number))
        case .continuous(let fromUnitID): return ("continuous", fromUnitID)
        }
    }

    fileprivate static func repeatDescription(_ value: HifzRepeat) -> String {
        switch value {
        case .times(let count): return String(count)
        case .forever: return "inf"
        }
    }

    fileprivate static func endReasonMessage(_ reason: EndReason) -> String {
        let name: String
        switch reason {
        case .completed: name = "completed"
        case .stopped: name = "stopped"
        case .failed: name = "failed"
        }
        return "hifz end reason=\(name)"
    }
}
