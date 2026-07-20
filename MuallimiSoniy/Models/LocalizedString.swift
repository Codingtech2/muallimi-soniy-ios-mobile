import Foundation

/// A string translated into every locale the book ships with.
///
/// JSON keys are hyphenated (`uz-latn`, `uz-cyrl`) which are not valid Swift
/// identifiers, so `CodingKeys` maps them onto camelCase properties.
///
/// Marked `nonisolated` so it opts out of the project-wide default MainActor
/// isolation and stays a plain Sendable value type (decodable off the main actor).
nonisolated struct LocalizedString: Codable, Sendable, Hashable {
    let uzLatn: String
    let uzCyrl: String
    let ru: String
    let en: String

    enum CodingKeys: String, CodingKey {
        case uzLatn = "uz-latn"
        case uzCyrl = "uz-cyrl"
        case ru
        case en
    }

    /// The translation for the given locale.
    func text(_ locale: AppLocale) -> String {
        switch locale {
        case .uzLatn: return uzLatn
        case .uzCyrl: return uzCyrl
        case .ru: return ru
        case .en: return en
        }
    }
}
