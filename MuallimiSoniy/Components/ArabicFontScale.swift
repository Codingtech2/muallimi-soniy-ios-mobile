import SwiftUI

/// Maps the legacy small/medium/large font-size preference to the numeric
/// scale multiplier it used to drive (`--font-scale`: small 0.875 / medium
/// 1.0 / large 1.125). `AppSettings.textScale` is now the live source of
/// truth (see `SettingsStore.arabicScale`) — this extension survives only so
/// `SettingsStore`'s decode migration can convert an old persisted `fontSize`
/// value into a `textScale` on first launch after the upgrade. Nothing else
/// should read this.
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
