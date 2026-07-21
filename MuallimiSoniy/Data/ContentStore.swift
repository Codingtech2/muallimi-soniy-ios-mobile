import Foundation
import OSLog

/// A fully-resolved page in the flattened book.
///
/// `pageNumber` is the book page label (the key used in `Book.pages`), while
/// `globalIndex` is the 0-based position across the whole book (0..<totalPages)
/// and `lessonPageIndex` is the 0-based position within its lesson. Mirrors the
/// web `BookPage` produced by `getAllBookPages()`.
nonisolated struct BookPage: Identifiable, Sendable, Hashable {
    let id: String
    let lessonId: String
    /// 1-based position within the lesson (== `lessonPageIndex + 1`).
    let order: Int
    /// The book page label (key into `Book.pages`); may repeat across lessons.
    let pageNumber: Int
    let chapter: Chapter
    let lesson: Lesson
    /// 0-based index across the whole book.
    let globalIndex: Int
    /// 0-based index within the lesson.
    let lessonPageIndex: Int
    let elements: [Element]
}

/// One lesson row in the table-of-contents outline, with 1-based global page span.
nonisolated struct OutlineLesson: Identifiable, Sendable, Hashable {
    let lesson: Lesson
    /// First global page number (1..totalPages).
    let globalStart: Int
    /// Last global page number (1..totalPages).
    var globalEnd: Int

    var id: String { lesson.id }
}

/// One chapter group in the outline, holding its lessons and 1-based global span.
nonisolated struct OutlineChapter: Identifiable, Sendable, Hashable {
    let chapter: Chapter
    var lessons: [OutlineLesson]
    let globalStart: Int
    var globalEnd: Int

    var id: String { chapter.id }
}

/// Loads the bundled content package and exposes the flattened book, the
/// table-of-contents outline, and i18n lookup.
///
/// All files are small and bundled, so loading is synchronous in `init`: the
/// whole decode + flatten measures ~6 ms in Release for 52 pages / ~1970
/// elements (book.json is 389 KB) — a one-shot launch cost well under a frame,
/// not a scroll hitch — so it deliberately stays on the main actor to keep the
/// content ready before first paint (no transient empty state in any consumer).
/// Decoding failures are logged and degrade to empty defaults — never a crash.
@MainActor
@Observable
final class ContentStore {
    /// Raw decoded book (chapters / lessons / pageMap / pages / extras).
    private(set) var book: Book?
    /// i18n table: locale key -> (string key -> translation).
    private(set) var i18n: [String: [String: String]] = [:]
    /// Legal documents: locale key -> (document key -> body text).
    private(set) var legal: [String: [String: String]] = [:]
    /// Factory defaults from `settings.json` → `defaults`.
    private(set) var defaultSettings: AppSettings = .default

    /// Every page in reading order, with global + lesson indices assigned.
    private(set) var allBookPages: [BookPage] = []
    /// Chapter → lesson outline with 1-based global page spans (for the TOC).
    private(set) var outline: [OutlineChapter] = []

    /// Introduction prose that lives outside the page/element structure.
    var muqaddimaParagraphs: [String] { book?.extras.muqaddimaParagraphs ?? [] }
    /// Total number of pages across the whole book (expected: 52).
    var totalPages: Int { allBookPages.count }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "ContentStore"
    )

    init() {
        load()
    }

    // MARK: - Loading

    /// Fills every property from the bundled JSON once. Safe to call again.
    func load() {
        book = decodeBundled("book", as: Book.self)
        i18n = decodeBundled("i18n", as: [String: [String: String]].self) ?? [:]
        legal = decodeBundled("legal", as: [String: [String: String]].self) ?? [:]
        // Factory defaults come from the same lenient settings.json decoder the
        // SettingsStore uses for fresh installs, so the two never diverge — and a
        // missing `volume` / unknown enum degrades to the compiled default rather
        // than silently discarding the JSON block (the old strict decode threw on
        // the absent `volume` key, leaving this stuck on `.default`).
        defaultSettings = SettingsStore.bundledDefaultSettings()
        rebuild()
    }

    /// Decodes a bundled `<name>.json` resource, returning `nil` (and logging)
    /// on any failure so a missing or malformed file never crashes launch.
    private func decodeBundled<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            logger.error("Missing bundled resource: \(name, privacy: .public).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("Failed to decode \(name, privacy: .public).json: \(String(describing: error))")
            return nil
        }
    }

    // MARK: - Flattening

    /// Rebuilds `allBookPages` and `outline` from `book`.
    ///
    /// Mirrors the web `getAllBookPages()`: iterate chapters (by `order`) →
    /// lessons (by `order`) → `pageMap[lessonId]` page numbers, assigning a
    /// book-wide 0-based `globalIndex` and a lesson-local 0-based `lessonPageIndex`.
    private func rebuild() {
        guard let book else {
            allBookPages = []
            outline = []
            return
        }
        var pages: [BookPage] = []
        var globalIndex = 0
        for chapter in book.chapters.sorted(by: { $0.order < $1.order }) {
            let chapterLessons = (book.lessons[chapter.id] ?? []).sorted { $0.order < $1.order }
            for lesson in chapterLessons {
                let pageNumbers = book.pageMap[lesson.id] ?? []
                for (lessonPageIndex, pageNumber) in pageNumbers.enumerated() {
                    let elements = book.pages[String(pageNumber)] ?? []
                    pages.append(
                        BookPage(
                            id: "pg_\(lesson.id)_\(pageNumber)",
                            lessonId: lesson.id,
                            order: lessonPageIndex + 1,
                            pageNumber: pageNumber,
                            chapter: chapter,
                            lesson: lesson,
                            globalIndex: globalIndex,
                            lessonPageIndex: lessonPageIndex,
                            elements: elements
                        )
                    )
                    globalIndex += 1
                }
            }
        }
        allBookPages = pages
        outline = Self.buildOutline(from: pages)
    }

    /// Groups the flattened pages into the TOC outline, mirroring `getBookOutline()`.
    /// Global page numbers are 1-based (reader shows "X / 52").
    private static func buildOutline(from pages: [BookPage]) -> [OutlineChapter] {
        var chapters: [OutlineChapter] = []
        for page in pages {
            let globalPage = page.globalIndex + 1
            if chapters.last?.chapter.id != page.chapter.id {
                chapters.append(
                    OutlineChapter(chapter: page.chapter, lessons: [], globalStart: globalPage, globalEnd: globalPage)
                )
            }
            let chapterIndex = chapters.count - 1
            if chapters[chapterIndex].lessons.last?.lesson.id != page.lesson.id {
                chapters[chapterIndex].lessons.append(
                    OutlineLesson(lesson: page.lesson, globalStart: globalPage, globalEnd: globalPage)
                )
            }
            let lessonIndex = chapters[chapterIndex].lessons.count - 1
            chapters[chapterIndex].lessons[lessonIndex].globalEnd = globalPage
            chapters[chapterIndex].globalEnd = globalPage
        }
        return chapters
    }

    // MARK: - i18n

    /// Localized string for `key` in `locale`, falling back to `uz-latn`, then
    /// the raw key itself (so missing translations surface visibly, never crash).
    func t(_ key: String, _ locale: AppLocale) -> String {
        i18n[locale.rawValue]?[key]
            ?? i18n[AppLocale.uzLatn.rawValue]?[key]
            ?? key
    }
}
