import SwiftUI

/// Maps the user's reading font-size preference to a global Arabic type
/// multiplier, mirroring the web root font-scale (`--font-scale`:
/// small 0.875 / medium 1.0 / large 1.125). Applied once per Arabic primitive
/// so every reader glyph scales from a single source.
extension FontSize {
    var arabicScale: CGFloat {
        switch self {
        case .small: return 0.875
        case .medium: return 1.0
        case .large: return 1.125
        }
    }
}

/// Environment value carrying the current Arabic font-size multiplier. Injected
/// once at the app root from `SettingsStore.arabicScale`; read by
/// `ArabicElementView` and `Verse` to scale their point sizes. Default `1.0`
/// keeps previews and any non-injected context at the medium size.
private struct ArabicFontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

extension EnvironmentValues {
    var arabicFontScale: CGFloat {
        get { self[ArabicFontScaleKey.self] }
        set { self[ArabicFontScaleKey.self] = newValue }
    }
}
