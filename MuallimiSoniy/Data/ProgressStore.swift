import Foundation
import OSLog

/// Persistent reading progress: the last page the user viewed (for the home
/// "Davom eting" resume button) and the set of completed lessons (for the ✓ in
/// the contents list).
///
/// Native analogue of the web `ProgressProvider` (localStorage `muallimi-progress`).
/// The whole thing is persisted as one JSON blob in `UserDefaults`. The web
/// stores a lesson-local `lastPageIndex`; here we keep the book-wide
/// `lastGlobalIndex` directly, so resuming is a plain index with no lesson lookup.
@MainActor
@Observable
final class ProgressStore {
    /// Chapter id of the last viewed page (`nil` before anything is opened).
    private(set) var lastChapterId: String?
    /// Lesson id of the last viewed page (`nil` before anything is opened).
    private(set) var lastLessonId: String?
    /// 0-based global page index of the last viewed page.
    private(set) var lastGlobalIndex: Int
    /// Ids of lessons whose final page has been reached.
    private(set) var completedLessons: Set<String>
    /// Qur'an surah numbers (1...114) the user has marked as fully memorized
    /// ("Yodladim"), driving the hifz surah-list checkmark and the `X/26` badge.
    private(set) var memorizedSurahs: Set<Int>

    /// 0-based global page to resume from; `0` when there is no saved progress.
    var resumeGlobalIndex: Int { lastGlobalIndex }
    /// How many surahs are currently marked memorized.
    var memorizedCount: Int { memorizedSurahs.count }

    private static let defaultsKey = "muallimi-progress"
    private let defaults: UserDefaults
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "ProgressStore"
    )

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = Self.load(from: defaults)
        lastChapterId = saved.lastChapterId
        lastLessonId = saved.lastLessonId
        lastGlobalIndex = saved.lastGlobalIndex
        completedLessons = saved.completedLessons
        memorizedSurahs = saved.memorizedSurahs ?? []
    }

    // MARK: - API

    /// Records the page the user is currently on. Skips the write when nothing
    /// changed, so a swipe through unchanged state doesn't thrash UserDefaults.
    func setLastViewed(chapterId: String, lessonId: String, globalIndex: Int) {
        guard lastChapterId != chapterId
            || lastLessonId != lessonId
            || lastGlobalIndex != globalIndex else { return }
        lastChapterId = chapterId
        lastLessonId = lessonId
        lastGlobalIndex = globalIndex
        persist()
    }

    /// Marks a lesson complete (idempotent) — drives the contents-list ✓.
    func markLessonComplete(_ lessonId: String) {
        guard !completedLessons.contains(lessonId) else { return }
        completedLessons.insert(lessonId)
        persist()
    }

    /// Whether `lessonId` has been completed.
    func isLessonComplete(_ lessonId: String) -> Bool {
        completedLessons.contains(lessonId)
    }

    /// Marks (or unmarks) a surah as memorized — drives the hifz "Yodladim" toggle.
    func setMemorized(_ number: Int, _ isOn: Bool) {
        guard isOn != memorizedSurahs.contains(number) else { return }
        if isOn {
            memorizedSurahs.insert(number)
        } else {
            memorizedSurahs.remove(number)
        }
        persist()
    }

    /// Whether surah `number` has been marked memorized.
    func isMemorized(_ number: Int) -> Bool {
        memorizedSurahs.contains(number)
    }

    #if DEBUG
    /// QA-only: injects a demo progress state in-memory (no persistence), so the
    /// `-MSScreen home|contents` screenshot hosts can show the resume CTA and the
    /// completed-lesson checkmarks without depending on cross-launch UserDefaults
    /// (which `simctl terminate`'s SIGKILL can drop before it flushes).
    func debugSeed(resumeGlobalIndex: Int, completedLessons: [String]) {
        lastGlobalIndex = resumeGlobalIndex
        self.completedLessons = Set(completedLessons)
    }
    #endif

    // MARK: - Persistence

    private func persist() {
        let snapshot = Snapshot(
            lastChapterId: lastChapterId,
            lastLessonId: lastLessonId,
            lastGlobalIndex: lastGlobalIndex,
            completedLessons: completedLessons,
            memorizedSurahs: memorizedSurahs
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: Self.defaultsKey)
        } catch {
            logger.error("Failed to persist progress: \(String(describing: error))")
        }
    }

    private static func load(from defaults: UserDefaults) -> Snapshot {
        guard let data = defaults.data(forKey: defaultsKey) else { return .empty }
        return (try? JSONDecoder().decode(Snapshot.self, from: data)) ?? .empty
    }

    /// Codable JSON shape persisted in UserDefaults.
    private struct Snapshot: Codable {
        var lastChapterId: String?
        var lastLessonId: String?
        var lastGlobalIndex: Int
        var completedLessons: Set<String>
        /// Optional so an older saved blob without this key still decodes instead of
        /// throwing — `load(from:)` falls back to `.empty` on ANY decode error,
        /// which would otherwise silently wipe out all existing progress.
        var memorizedSurahs: Set<Int>?

        static let empty = Snapshot(
            lastChapterId: nil,
            lastLessonId: nil,
            lastGlobalIndex: 0,
            completedLessons: [],
            memorizedSurahs: nil
        )
    }
}
