import SwiftUI

/// The reader's page/text palette. Persisted as `AppSettings.readingBackground`
/// and read via `\.readingTheme` — everything the reader paints (page fill,
/// page card, Arabic text, captions, dividers) pulls its color from one of
/// these four cases instead of reaching into `AppColor` directly.
///
/// `.paper` is the **only** case that stays dynamic — it reproduces `AppColor`
/// 1:1, so it still follows system light/dark exactly like today (default
/// appearance is unchanged). `.sepia`, `.gray` and `.night` are deliberately
/// **fixed** palettes: like Books/Kindle reading themes, picking "Sepia"
/// should look the same regardless of the system appearance — that's the
/// whole point of offering it as a choice distinct from `.paper`.
///
/// Contrast: `textMain` against `pageFill` is 11:1+ for every case (well past
/// WCAG AAA). `textSecondary`/`textMuted` are chosen to stay ≥4.5:1 (WCAG AA
/// for text) against their own `pageFill` — see the ratio noted on each case
/// below. `divider`/`cardFill` are structural, non-text surfaces (WCAG's own
/// 4.5:1 rule only applies to text), so they follow this app's existing
/// hairline-divider / near-opaque-card convention instead — the same low,
/// intentionally-subtle contrast `.paper` already ships with today.
nonisolated enum ReadingBackground: String, Codable, CaseIterable, Sendable, Hashable {
    case paper
    case sepia
    case gray
    case night

    /// The reader's outer page background.
    var pageFill: Color {
        switch self {
        case .paper: return AppColor.background
        case .sepia: return Color(hex: "f4ecd8")
        case .gray: return Color(hex: "e8e8e4")
        case .night: return Color(hex: "1a1a1a")
        }
    }

    /// The page-card fill behind the rendered book page (`PageHostView`).
    var cardFill: Color {
        switch self {
        case .paper: return AppColor.glass
        case .sepia: return Color(hex: "faf4e8")
        case .gray: return Color(hex: "f5f5f3")
        case .night: return Color(hex: "242424")
        }
    }

    /// Primary reading text (Arabic elements, verse text). ~11–14:1 against
    /// `pageFill` in every case.
    var textMain: Color {
        switch self {
        case .paper: return AppColor.textMain
        case .sepia: return Color(hex: "3a2f1e")
        case .gray: return Color(hex: "1f1f1f")
        case .night: return Color(hex: "e8e8e8")
        }
    }

    /// Titles / accented labels. Reuses the app's signature green accent
    /// (light `#0d6b30`, dark `#86efac` — the same hexes as `AppColor`'s own
    /// light/dark `textSecondary`) so the brand thread survives every reading
    /// background. ~5.4–12.4:1 against `pageFill`.
    var textSecondary: Color {
        switch self {
        case .paper: return AppColor.textSecondary
        case .sepia, .gray: return Color(hex: "0d6b30")
        case .night: return Color(hex: "86efac")
        }
    }

    /// Captions / hints. ~5.3–9.2:1 against `pageFill`.
    var textMuted: Color {
        switch self {
        case .paper: return AppColor.textMuted
        case .sepia, .gray: return Color(hex: "4a6355")
        case .night: return Color(hex: "a3c4b0")
        }
    }

    /// Hairline separators — deliberately subtle (see the type-level doc).
    var divider: Color {
        switch self {
        case .paper: return AppColor.divider
        case .sepia: return Color(hex: "3a2f1e", opacity: 0.15)
        case .gray: return Color(hex: "1f1f1f", opacity: 0.12)
        case .night: return Color(white: 1, opacity: 0.12)
        }
    }
}

private struct ReadingThemeKey: EnvironmentKey {
    static let defaultValue: ReadingBackground = .paper
}

extension EnvironmentValues {
    /// The active reading palette. Defaults to `.paper` (today's exact look)
    /// until the reader root injects the live value from
    /// `SettingsStore.settings.readingBackground`.
    var readingTheme: ReadingBackground {
        get { self[ReadingThemeKey.self] }
        set { self[ReadingThemeKey.self] = newValue }
    }
}
