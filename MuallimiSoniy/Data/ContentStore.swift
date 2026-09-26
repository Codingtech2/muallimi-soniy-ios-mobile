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
/// table-of-contents outline, and localized-string lookup.
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
    /// Legal documents: locale key -> (document key -> body text).
    private(set) var legal: [String: [String: String]] = [:]
    /// Factory defaults from `settings.json` → `defaults`.
    private(set) var defaultSettings: AppSettings = .default

    /// Every page in reading order, with global + lesson indices assigned.
    private(set) var allBookPages: [BookPage] = []
    /// Chapter → lesson outline with 1-based global page spans (for the TOC).
    private(set) var outline: [OutlineChapter] = []
    /// Resolved memorization (hifz) content, built from `surah-index.json`
    /// against `allBookPages`. Empty when the index is missing or unresolvable
    /// — the hifz UI hides itself rather than crashing.
    private(set) var hifzCatalog: HifzCatalog = .empty
    /// Translations of the meanings, keyed by the surah pages' ayah element
    /// ids. Empty when `translations.json` is missing or unreadable — the
    /// reader then just shows no translation.
    private(set) var ayahTranslations: [TranslationChoice: AyahTranslationLookup] = [:]
    /// Where each translation comes from, in file order (credits page).
    private(set) var translationEditions: [TranslationEdition] = []

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
        legal = decodeBundled("legal", as: [String: [String: String]].self) ?? [:]
        warmLocalizedBundles()
        // Factory defaults come from the same lenient settings.json decoder the
        // SettingsStore uses for fresh installs, so the two never diverge — and a
        // missing `volume` / unknown enum degrades to the compiled default rather
        // than silently discarding the JSON block (the old strict decode threw on
        // the absent `volume` key, leaving this stuck on `.default`).
        defaultSettings = SettingsStore.bundledDefaultSettings()
        rebuild()
        let surahIndex = decodeBundled("surah-index", as: SurahIndexFile.self)
        buildHifzCatalog(from: surahIndex)
        buildAyahTranslations(from: surahIndex)
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

    // MARK: - Hifz catalog

    /// Resolves `Resources/surah-index.json` against `allBookPages` into
    /// `hifzCatalog`. Never crashes on a missing or malformed index — degrades
    /// to `.empty` and logs every problem, so the hifz UI just hides itself.
    private func buildHifzCatalog(from indexFile: SurahIndexFile?) {
        // Pages 25 and 30 each belong to two lessons, so the same element id
        // shows up twice in allBookPages (once per occurrence). Keep the first
        // one — a plain Dictionary(uniqueKeysWithValues:) would trap here.
        var lookup: [String: HifzElementRef] = [:]
        for page in allBookPages {
            for element in page.elements where lookup[element.id] == nil {
                lookup[element.id] = HifzElementRef(element: element, globalIndex: page.globalIndex)
            }
        }

        let (catalog, problems) = HifzCatalog.build(from: indexFile, lookup: lookup)
        for problem in problems {
            logger.error("\(problem, privacy: .public)")
        }
        hifzCatalog = catalog

        let surahCount = catalog.surahs.count
        let unitCount = catalog.surahs.reduce(0) { $0 + $1.units.count }
        logger.info("hifz catalog: \(surahCount, privacy: .public) surahs, \(unitCount, privacy: .public) units")
    }

    // MARK: - Translations of the meanings

    /// Bundle format this build reads (`tools/translations` writes it).
    private static let translationsSchemaVersion = 1

    /// Keys every translation in `Resources/translations.json` by the book's
    /// ayah element ids — the surah index says which surah and ayah each
    /// element is. A missing or unreadable file leaves translations empty.
    private func buildAyahTranslations(from indexFile: SurahIndexFile?) {
        ayahTranslations = [:]
        translationEditions = []
        guard let file = decodeBundled("translations", as: TranslationsFile.self) else { return }
        guard file.schemaVersion == Self.translationsSchemaVersion else {
            logger.error("translations.json: schema \(file.schemaVersion, privacy: .public) is not supported")
            return
        }

        var ayahByElementId: [String: (key: String, ayah: Int)] = [:]
        for surah in indexFile?.surahs ?? [] {
            for item in surah.items where item.role == "ayah" {
                guard let ayah = item.ayah else { continue }
                ayahByElementId[item.elementId] = ("\(surah.number):\(ayah)", ayah)
            }
        }

        for edition in file.translations {
            guard let choice = TranslationChoice(rawValue: edition.id), choice != .automatic, choice != .off else {
                logger.error("translations.json: unknown translation id \(edition.id, privacy: .public), skipped")
                continue
            }
            var lines: [String: AyahTranslationLine] = [:]
            for (elementId, ref) in ayahByElementId {
                guard let translated = edition.ayahs[ref.key] else { continue }
                lines[elementId] = AyahTranslationLine(ayah: ref.ayah, text: translated.text, notes: translated.notes)
            }
            let missing = ayahByElementId.count - lines.count
            if missing > 0 {
                let name = edition.id
                logger.error("translations.json: \(name, privacy: .public) lacks \(missing, privacy: .public) ayat")
            }
            ayahTranslations[choice] = AyahTranslationLookup(linesByElementId: lines)
            translationEditions.append(edition)
        }
        logger.info("translations: \(self.translationEditions.count, privacy: .public) loaded")
    }

    // MARK: - Localization (native String Catalog)

    /// Per-language `.lproj` bundle cache, warmed once at load. Reading strings
    /// from an explicit language bundle — rather than `Bundle.main`, which only
    /// follows `AppleLanguages` and updates on relaunch — is what lets the in-app
    /// picker switch language **live**: every `t(_:_:)` call passes the current
    /// `locale`, so a change just resolves a different bundle and views re-render.
    @ObservationIgnored private var localizedBundles: [String: Bundle] = [:]

    /// Sentinel handed to `localizedString(forKey:value:table:)` so a missing key
    /// (which echoes the sentinel back) can be told apart from a real translation.
    private static let missingSentinel = "\u{1}__ms_missing__\u{1}"

    /// Localized string for `key` in `locale`, read from the compiled
    /// `Localizable.xcstrings`. Falls back to Uzbek-Latin, then the raw key — so a
    /// missing translation surfaces visibly, never crashes.
    func t(_ key: String, _ locale: AppLocale) -> String {
        localized(key, code: locale.appleLanguageCode)
            ?? localized(key, code: AppLocale.uzLatn.appleLanguageCode)
            ?? key
    }

    /// Looks `key` up in the `code` language bundle, returning `nil` when absent.
    private func localized(_ key: String, code: String) -> String? {
        guard let bundle = localizedBundles[code] else { return nil }
        let value = bundle.localizedString(forKey: key, value: Self.missingSentinel, table: nil)
        return value == Self.missingSentinel ? nil : value
    }

    /// Resolves and caches the `.lproj` bundle for every known language once, so
    /// `t(_:_:)` only ever reads the cache (no mutation during a view update).
    private func warmLocalizedBundles() {
        for locale in AppLocale.allCases {
            let code = locale.appleLanguageCode
            guard localizedBundles[code] == nil else { continue }
            if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                localizedBundles[code] = bundle
            } else {
                localizedBundles[code] = .main
            }
        }
    }
}
