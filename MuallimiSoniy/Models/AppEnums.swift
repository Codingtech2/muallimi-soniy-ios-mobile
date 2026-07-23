import Foundation

/// The UI / content language. Raw values match the JSON locale keys.
nonisolated enum AppLocale: String, Codable, CaseIterable, Sendable, Hashable {
    case uzLatn = "uz-latn"
    case uzCyrl = "uz-cyrl"
    case ru
    case en

    /// The iOS language code — a project `knownRegions` / `Localizable.xcstrings`
    /// entry — this locale maps to. `SettingsStore.setLocale` writes this to
    /// `AppleLanguages` so the system + String Catalog follow the in-app picker.
    var appleLanguageCode: String {
        switch self {
        case .uzLatn: return "uz-UZ"
        case .uzCyrl: return "uz-Cyrl"
        case .ru: return "ru"
        case .en: return "en"
        }
    }
}

/// Appearance preference. `system` follows the device setting.
nonisolated enum AppTheme: String, Codable, CaseIterable, Sendable, Hashable {
    case light
    case dark
    case system
}

/// Legacy reading font-size preference (small/medium/large).
///
/// Superseded by `AppSettings.textScale`, a continuous 0.8…2.5 slider.
/// Kept **only** so `SettingsStore`'s decode migration can read an old
/// persisted `fontSize` value and convert it forward — nothing else should
/// reference this type.
nonisolated enum FontSize: String, Codable, CaseIterable, Sendable, Hashable {
    case small
    case medium
    case large
}

/// Kind of a page element, drives colour + label in the reader.
nonisolated enum ElementType: String, Codable, CaseIterable, Sendable, Hashable {
    case harf
    case bogin
    case soz
    case jumla
}
