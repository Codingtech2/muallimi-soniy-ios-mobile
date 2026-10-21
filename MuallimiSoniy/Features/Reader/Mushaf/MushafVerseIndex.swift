import Foundation

/// Where one surah-page element sits in the Qur'an, for the Mushaf view of
/// book pages 36–47. It's the native stand-in for the web's `AYAH_TARJIMA`
/// lookup (`tarjima.ts`), which `MushafPage.tsx` uses to group a page into
/// banners, lines and flowing paragraphs. Built once from the bundled
/// `surah-index.json` (`ContentStore.mushafVerses`), so no extra map ships.
///
/// Surah title elements (`p37_sh_title`, …) are deliberately NOT in the index:
/// the blocks builder treats "not in the index" as "title for the next banner",
/// exactly like the web.
nonisolated struct MushafVerseRef: Sendable, Hashable {
    nonisolated enum Role: Sendable, Hashable {
        /// The isti'adha before al-Fatiha (no ayah of any surah).
        case taawwudh
        /// A bismillah that opens a surah without being one of its ayat.
        case bismillah
        /// A real ayah — al-Fatiha's bismillah included (it is ayah 1 there).
        case ayah
    }

    /// Qur'an surah number; 0 for the isti'adha (web `s: 0`).
    let surah: Int
    /// Ayah number; 0 for the isti'adha and for a plain bismillah (web `a: 0`).
    let ayah: Int
    let role: Role
    /// The sajda ayah (Alaq 19) — its number gets a `۩` in front.
    let sajda: Bool

    /// Builds the element id → verse lookup from the decoded index file.
    ///
    /// Never throws: a missing file gives an empty lookup, and every item that
    /// can't be read (unknown role, ayah without a number, an id listed twice)
    /// is skipped and reported in `problems` for the caller to log.
    static func index(from file: SurahIndexFile?) -> (verses: [String: MushafVerseRef], problems: [String]) {
        guard let file else {
            return ([:], ["mushaf verses: surah-index.json missing — the Mushaf view has no verse map"])
        }
        var verses: [String: MushafVerseRef] = [:]
        var problems: [String] = []
        for surah in file.surahs {
            for item in surah.items {
                guard let ref = ref(for: item, surah: surah.number, problems: &problems) else { continue }
                guard verses[item.elementId] == nil else {
                    problems.append("mushaf verses: \(item.elementId) listed twice, kept the first")
                    continue
                }
                verses[item.elementId] = ref
            }
        }
        return (verses, problems)
    }

    /// One index item as a verse ref, or `nil` for a title (not an error) or
    /// for an item that can't be used (reported in `problems`).
    private static func ref(for item: SurahIndexItem, surah: Int, problems: inout [String]) -> MushafVerseRef? {
        switch item.role {
        case "title":
            return nil
        case "taawwudh":
            return MushafVerseRef(surah: 0, ayah: 0, role: .taawwudh, sajda: false)
        case "bismillah":
            return MushafVerseRef(surah: surah, ayah: 0, role: .bismillah, sajda: false)
        case "ayah":
            guard let ayah = item.ayah, ayah > 0 else {
                problems.append("mushaf verses: \(item.elementId) is an ayah without a number, skipped")
                return nil
            }
            return MushafVerseRef(surah: surah, ayah: ayah, role: .ayah, sajda: item.sajda ?? false)
        default:
            problems.append("mushaf verses: \(item.elementId) has unknown role \(item.role), skipped")
            return nil
        }
    }
}
