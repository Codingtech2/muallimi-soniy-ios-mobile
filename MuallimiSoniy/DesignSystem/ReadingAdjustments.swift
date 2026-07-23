import SwiftUI

/// Reader-only rendering + accessibility context driven by the "Aa" reading-
/// options sheet — injected once at the reader root (`ReaderView`, alongside
/// `\.readingTheme`) and consumed by the tappable reading primitives
/// (`ArabicElementView`, `Verse`, `TappableTextLabel`, `WordRow`).
///
/// Defaults reproduce today's baseline (1.0x spacing, no extra bold, no extra
/// highlight, empty strings) for any non-injected context (previews, other
/// screens) so nothing renders or announces differently until `ReaderView`
/// sets the live value from `SettingsStore`.
nonisolated struct ReadingAdjustments: Equatable, Sendable {
    /// Multiplies `FlowLayout`'s inter-line gap and `Text.lineSpacing` in the
    /// reading primitives. Mirrors `AppSettings.lineSpacingScale` (1.0…2.0).
    var lineSpacingScale: Double = 1.0
    /// Renders reader Arabic text at a heavier weight for low-vision users.
    /// Mirrors `AppSettings.boldText`. Consumers additionally OR this with the
    /// system-wide `\.legibilityWeight` (Settings → Accessibility → Bold
    /// Text) themselves, since that environment value is already ambient and
    /// needs no plumbing here.
    var boldText: Bool = false
    /// Renders the active tap-highlight pill with stronger contrast and a
    /// thicker border. Mirrors `AppSettings.strongHighlight`.
    var strongHighlight: Bool = false
    /// Localized "double-tap to play its audio" accessibility hint, resolved
    /// once from the `a11y_play_hint` catalog key. Handing the ready string
    /// down via the environment keeps `ArabicElementView` / `Verse` /
    /// `TappableTextLabel` free of a direct `ContentStore` dependency.
    var playHint: String = ""
    /// Localized "Play", reused as the active element's `.accessibilityValue`
    /// so a VoiceOver user hears which token the highlight currently sits on.
    var activeValueLabel: String = ""
}

private struct ReadingAdjustmentsKey: EnvironmentKey {
    static let defaultValue = ReadingAdjustments()
}

extension EnvironmentValues {
    /// The active reading adjustments. Defaults to the no-op baseline until
    /// the reader root injects the live value from `SettingsStore.settings`.
    var readingAdjustments: ReadingAdjustments {
        get { self[ReadingAdjustmentsKey.self] }
        set { self[ReadingAdjustmentsKey.self] = newValue }
    }
}
