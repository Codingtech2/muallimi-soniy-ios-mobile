import Foundation

// MARK: - Surah index file (Resources/surah-index.json)

/// One tappable item inside a surah's `items` array in the index file.
///
/// Decoding is deliberately lenient: `role` stays a raw `String` (not the
/// `HifzUnitRole` enum) because the file also carries `"title"` items, which
/// are not a playable unit role at all — `HifzCatalog.build` is the place
/// that turns a known role into `HifzUnitRole` and skips/report anything else.
nonisolated struct SurahIndexItem: Decodable, Sendable {
    let elementId: String
    let pageNumber: Int
    let globalIndex: Int
    let role: String
    let ayah: Int?
    let hasAudio: Bool
    /// The other element id this one shares one audio take with (e.g. Ma'un
    /// 4 <-> 5). Informational only — `HifzCatalog.build` decides merges by
    /// comparing resolved `audioUrl`/`start`/`end`, not this field.
    let sharedAudioWith: String?
    let basmalaAsAyah: Bool?
    let sajda: Bool?
}

/// One surah entry in the index file, before any resolution against the book.
nonisolated struct SurahIndexEntry: Decodable, Sendable {
    let number: Int
    let key: String
    let arabicName: String
    /// The surah's display name in all 4 app locales — content, not a catalog
    /// key, same as a lesson title (see `LocalizedString`).
    let name: LocalizedString
    let ayahCount: Int
    let mushafAyahCount: Int
    let isPartial: Bool
    let pages: [Int]
    let items: [SurahIndexItem]
}

/// Root of `Resources/surah-index.json`.
nonisolated struct SurahIndexFile: Decodable, Sendable {
    let schemaVersion: Int
    let contentVersion: String?
    let surahs: [SurahIndexEntry]
}

// MARK: - Resolved hifz content

/// A memorizable unit's role. `"title"` items from the index file never
/// become a unit at all (they carry no audio), so it is not a case here.
nonisolated enum HifzUnitRole: String, Sendable, Hashable {
    case taawwudh
    case bismillah
    case ayah
}

/// One playable step in a hifz session: a single ayah, an isti'adha, a
/// bismillah, or — for the two clips the qori recorded as one take (Ma'un
/// 4-5, Ikhlas 3-4) — a pair of ayat sharing one audio file.
///
/// `audioPath`/`start`/`end`/`globalIndex` always come from the resolved
/// `Element` in the book, never from the index file's own copies of those
/// numbers — the index file is only used to decide *which* elements make up
/// a unit and in what order.
nonisolated struct HifzUnit: Identifiable, Sendable, Hashable {
    /// The first element's id. Stable identity for `Identifiable` and for
    /// `HifzScope.ayah(unitID:)` / `HifzScope.continuous(fromUnitID:)`.
    let id: String
    /// One id normally, two for a merged shared-audio pair.
    let elementIds: [String]
    let surahNumber: Int
    let role: HifzUnitRole
    let ayahFrom: Int?
    let ayahTo: Int?
    let globalIndex: Int
    let audioPath: String
    let start: Double
    let end: Double

    var duration: Double { max(0, end - start) }
}

/// A surah's memorizable units, in Qur'an order, plus the display facts the
/// UI needs (name, ayah count, whether the book only carries an excerpt).
nonisolated struct HifzSurah: Identifiable, Sendable, Hashable {
    let number: Int
    let key: String
    let arabicName: String
    let name: LocalizedString
    let ayahCount: Int
    let isPartial: Bool
    let units: [HifzUnit]

    var id: Int { number }

    /// The global page of this surah's first unit, or nil if it somehow has
    /// no units (should never happen — `HifzCatalog.build` drops surahs with
    /// zero playable units instead of keeping them empty).
    var startGlobalIndex: Int? { units.first?.globalIndex }
}

// MARK: - Repeat / scope / plan

/// How many times something should play: a fixed count, or until the user
/// stops it.
nonisolated enum HifzRepeat: Sendable, Hashable {
    case times(Int)
    case forever

    /// Safe constructor for a fixed count coming from somewhere untrusted
    /// (a DEBUG launch argument, a stray UI value) — clamps into the 1...10
    /// range the chips (1/3/5/10) and controller math are designed for, so a
    /// typo like `-MSHifzRepeat 999` can never blow up the sequence.
    static func count(_ raw: Int) -> HifzRepeat {
        .times(min(max(raw, 1), 10))
    }

    /// Whether one more repeat should play after `completed` repeats already
    /// happened.
    func allowsAnother(afterCompleted completed: Int) -> Bool {
        switch self {
        case .times(let total): return completed < total
        case .forever: return true
        }
    }
}

/// What a hifz session plays: one ayah forever/N times, a whole surah for N
/// rounds, or the book's Qur'an-order content starting at some unit.
nonisolated enum HifzScope: Sendable, Hashable {
    case ayah(unitID: String)
    case surah(number: Int)
    case continuous(fromUnitID: String)
}

/// The user's chosen settings for one hifz run — what `HifzSheet` builds and
/// `HifzController.start` consumes. Fields are `var` so a sheet can bind
/// chips directly to `$plan.eachAyah` etc.
nonisolated struct HifzPlan: Sendable, Hashable {
    var scope: HifzScope
    var eachAyah: HifzRepeat
    var rounds: HifzRepeat
    var pauseToRepeat: Bool
    /// How long the session may run before the sleep timer ends it (right
    /// after the unit playing at that moment), or `nil` while the timer is
    /// off. Session-only, never saved: the sheet sets it, a resume carries
    /// over the time that was left, and every other way in starts it off.
    var sleepAfter: TimeInterval?
    /// Self-test: while the session runs, the ayat of its surah(s) are
    /// blurred on the page, and a press and hold peeks at one. Off unless
    /// the sheet turns it on — a resume keeps it, every other way in
    /// starts with it off.
    var hideText = false

    /// Product defaults from the feature matrix: ayah = 5x/1 round, surah =
    /// 1x-each/3 rounds, continuous = 1x/1 round. Pause-to-repeat always
    /// starts off (the qori's own tartil pace is already slow for a start).
    static func defaults(for scope: HifzScope) -> HifzPlan {
        switch scope {
        case .ayah:
            HifzPlan(scope: scope, eachAyah: .times(5), rounds: .times(1), pauseToRepeat: false)
        case .surah:
            HifzPlan(scope: scope, eachAyah: .times(1), rounds: .times(3), pauseToRepeat: false)
        case .continuous:
            HifzPlan(scope: scope, eachAyah: .times(1), rounds: .times(1), pauseToRepeat: false)
        }
    }
}

/// Value passed through a `NavigationLink` to open the reader already running
/// a hifz session (surah list "play" button, DEBUG `-MSHifz`).
nonisolated struct HifzLaunch: Sendable, Hashable {
    let plan: HifzPlan
    let startGlobalIndex: Int
}

// MARK: - Sequencing

/// Position within a `HifzSequence`: which unit, which repeat of that unit,
/// which round.
nonisolated struct HifzCursor: Sendable, Hashable {
    let unitIndex: Int
    let playIndex: Int
    let roundIndex: Int
}

/// Pure step function over an ordered list of units — no audio, no timers,
/// just "what plays next". `HifzController` drives playback by calling
/// `next(after:)` each time a unit's audio finishes.
///
/// `firstRoundOnlyCount` is for surahs like Fatiha whose first unit
/// (isti'adha) should only play in round 1: every round after the first
/// restarts at unit index `firstRoundOnlyCount` instead of 0.
nonisolated struct HifzSequence: Sendable, Hashable {
    let unitCount: Int
    let eachAyah: HifzRepeat
    let rounds: HifzRepeat
    let firstRoundOnlyCount: Int

    /// The cursor for the very first play, or nil if there is nothing to play.
    func first() -> HifzCursor? {
        guard unitCount > 0 else { return nil }
        return HifzCursor(unitIndex: 0, playIndex: 0, roundIndex: 0)
    }

    /// The cursor for the play after `cursor`, or nil once every round is done.
    ///
    /// Priority: repeat the same unit again while `eachAyah` allows it, else
    /// move to the next unit in this round, else start the next round (from
    /// `firstRoundOnlyCount`, skipping isti'adha-only units) if `rounds`
    /// allows it, else stop.
    func next(after cursor: HifzCursor) -> HifzCursor? {
        guard unitCount > 0 else { return nil }

        let playsDoneForUnit = cursor.playIndex + 1
        if eachAyah.allowsAnother(afterCompleted: playsDoneForUnit) {
            return HifzCursor(unitIndex: cursor.unitIndex, playIndex: playsDoneForUnit, roundIndex: cursor.roundIndex)
        }

        if cursor.unitIndex + 1 < unitCount {
            return HifzCursor(unitIndex: cursor.unitIndex + 1, playIndex: 0, roundIndex: cursor.roundIndex)
        }

        let nextRound = cursor.roundIndex + 1
        guard rounds.allowsAnother(afterCompleted: nextRound) else { return nil }
        let restartUnit = min(max(firstRoundOnlyCount, 0), unitCount - 1)
        return HifzCursor(unitIndex: restartUnit, playIndex: 0, roundIndex: nextRound)
    }

    /// Jumps `delta` units away from `cursor.unitIndex` (remote-control
    /// prev/next during an active session), clamped to the valid unit range
    /// and always restarting the repeat count on the landed unit.
    func skip(from cursor: HifzCursor, by delta: Int) -> HifzCursor {
        guard unitCount > 0 else { return HifzCursor(unitIndex: 0, playIndex: 0, roundIndex: cursor.roundIndex) }
        let target = min(max(cursor.unitIndex + delta, 0), unitCount - 1)
        return HifzCursor(unitIndex: target, playIndex: 0, roundIndex: cursor.roundIndex)
    }
}

/// Timing helpers that don't belong to any one type.
nonisolated enum HifzTiming: Sendable {
    private static let minGapSeconds: Double = 2
    private static let maxGapSeconds: Double = 10
    private static let secondsPerMinute: Double = 60

    /// How long the "your turn" silence should last after a unit finishes:
    /// roughly the unit's own duration adjusted for playback speed, clamped
    /// to [2, 10]s regardless of how short or long the unit is (short ayat
    /// still give a reactable pause, very long ones don't run forever).
    static func gapSeconds(unitSeconds: Double, playbackRate: Double) -> Double {
        let rate = playbackRate > 0 ? playbackRate : 1
        let raw = unitSeconds / rate
        return min(max(raw, minGapSeconds), maxGapSeconds)
    }

    /// When a sleep timer of `length` seconds started at `start` runs out, or
    /// `nil` while the timer is off. A negative length runs out at once.
    static func sleepDeadline(length: TimeInterval?, from start: Date) -> Date? {
        length.map { start.addingTimeInterval(max($0, 0)) }
    }

    /// Seconds the sleep timer has left at `now` — never negative.
    static func sleepTimeLeft(until deadline: Date, now: Date) -> TimeInterval {
        max(deadline.timeIntervalSince(now), 0)
    }

    /// Whole minutes left, rounded up, so it never reads 0 while time is left.
    static func sleepMinutesLeft(until deadline: Date, now: Date) -> Int {
        Int((sleepTimeLeft(until: deadline, now: now) / secondsPerMinute).rounded(.up))
    }
}
