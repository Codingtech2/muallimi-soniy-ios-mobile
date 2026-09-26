import Foundation

/// Which translation of the meanings shows under the ayat on the surah pages
/// (whether it shows at all is `AppSettings.showTranslation`). The raw values of
/// the three languages (`uz` / `ru` / `en`) match the `id`s in
/// `Resources/translations.json`.
nonisolated enum TranslationChoice: String, Codable, CaseIterable, Sendable, Hashable {
    /// Follows the app language — the default until the reader picks one.
    case automatic
    /// Sheikh Muhammad Sadiq Muhammad Yusuf, Cyrillic script (QuranEnc.com).
    case uzbek = "uz"
    /// Rowwad Translation Center (QuranEnc.com).
    case russian = "ru"
    /// Talal Itani, ClearQuran (CC BY-ND 4.0).
    case english = "en"

    /// The choices the reader can actually pick, in picker order.
    static let pickable: [TranslationChoice] = [.uzbek, .russian, .english]

    /// The language named in its own script — deliberately not localized, so
    /// an Uzbek-Latin reader also sees that the Uzbek text is Cyrillic.
    var languageName: String? {
        switch self {
        case .automatic: return nil
        case .uzbek: return "Ўзбекча"
        case .russian: return "Русский"
        case .english: return "English"
        }
    }

    /// Catalog key of the localized "Translated by …" line.
    var translatorKey: String? {
        switch self {
        case .automatic: return nil
        case .uzbek: return "translation_by_uz"
        case .russian: return "translation_by_ru"
        case .english: return "translation_by_en"
        }
    }

    /// `automatic` resolved against the app language; every other case as is.
    /// There is no Latin-script Uzbek translation yet, so both Uzbek locales
    /// get the Cyrillic one.
    func resolved(for locale: AppLocale) -> TranslationChoice {
        guard self == .automatic else { return self }
        switch locale {
        case .uzLatn, .uzCyrl: return .uzbek
        case .ru: return .russian
        case .en: return .english
        }
    }
}

// MARK: - Bundle file (Resources/translations.json)

/// One ayah's translation, word for word from its source. `notes` holds the
/// source's footnotes (`[1] …`), which the text points to with `[1]` markers.
nonisolated struct TranslatedAyah: Decodable, Sendable, Hashable {
    let text: String
    let notes: String?
}

/// One translation and where it comes from. Built by
/// `tools/translations/build_translations.py`.
nonisolated struct TranslationEdition: Decodable, Sendable {
    /// `uz` / `ru` / `en` — a `TranslationChoice` raw value.
    let id: String
    let translator: String
    let source: String
    let version: String?
    /// The attribution line the source asks for, in its own wording.
    let credit: String
    let license: String
    let url: String
    /// Keyed by `"surah:ayah"`, e.g. `"112:1"`.
    let ayahs: [String: TranslatedAyah]
}

/// Root of `Resources/translations.json`.
nonisolated struct TranslationsFile: Decodable, Sendable {
    let schemaVersion: Int
    let translations: [TranslationEdition]
}

// MARK: - Resolved for the reader

/// A translated ayah ready to draw under its element.
nonisolated struct AyahTranslationLine: Sendable, Hashable {
    let ayah: Int
    let text: String
    let notes: String?
}

/// One translation, keyed by the book's ayah element ids (`p47_fq_a1` …) so
/// a page can look its lines up by the elements it already has.
nonisolated struct AyahTranslationLookup: Sendable, Equatable {
    private let linesByElementId: [String: AyahTranslationLine]

    init(linesByElementId: [String: AyahTranslationLine]) {
        self.linesByElementId = linesByElementId
    }

    /// The lines for these elements, in the given order; ids that are not an
    /// ayah of the book's surahs are skipped.
    func lines(for elementIds: [String]) -> [AyahTranslationLine] {
        elementIds.compactMap { linesByElementId[$0] }
    }
}
