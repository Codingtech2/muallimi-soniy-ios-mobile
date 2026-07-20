import SwiftUI
import UIKit

/// Color tokens mirroring the web `globals.css` palette 1:1.
///
/// LIGHT is the app's default appearance (user decision 2026-06-10). Every
/// token carries both a light and a dark value; the dark value applies only
/// when the environment resolves to the dark trait (e.g. via a forced
/// `.preferredColorScheme(.dark)` at the root, or system dark when the user
/// picks "system"). Colors are asset-independent — pure code, no `.xcassets`.
nonisolated enum AppColor {

    // MARK: Accent (green)

    /// `--color-primary` — light `#16a34a`, dark `#22c55e`.
    static let primary = Color(light: Color(hex: "16a34a"), dark: Color(hex: "22c55e"))
    /// `--color-primary-dark`.
    static let primaryDark = Color(light: Color(hex: "15803d"), dark: Color(hex: "16a34a"))
    /// `--color-primary-light`.
    static let primaryLight = Color(light: Color(hex: "22c55e"), dark: Color(hex: "4ade80"))
    /// `--color-primary-glow` — the soft shadow behind an active element.
    static let primaryGlow = Color(
        light: Color(hex: "16a34a").opacity(0.25),
        dark: Color(hex: "22c55e").opacity(0.40)
    )

    // MARK: Surfaces

    /// `--color-bg-dark` — the page background (misnamed in CSS; light `#f0f7f2`).
    static let background = Color(light: Color(hex: "f0f7f2"), dark: Color(hex: "071a0e"))
    /// `--color-bg-card` — translucent card fill (`rgba(0,0,0,0.05)` light).
    static let surface = Color(
        light: Color(white: 0, opacity: 0.05),
        dark: Color(white: 1, opacity: 0.07)
    )
    /// `--color-border-card` — hairline card border (`rgba(0,0,0,0.12)` light).
    static let divider = Color(
        light: Color(white: 0, opacity: 0.12),
        dark: Color(white: 1, opacity: 0.12)
    )

    // MARK: Text

    /// `--color-text-main` — primary reading text.
    static let textMain = Color(light: Color(hex: "0f1f17"), dark: Color(hex: "f0fdf4"))
    /// `--color-text-secondary` — titles / accented labels (green-ish).
    static let textSecondary = Color(light: Color(hex: "0d6b30"), dark: Color(hex: "86efac"))
    /// `--color-text-muted` — captions / hints.
    static let textMuted = Color(light: Color(hex: "4a6355"), dark: Color(hex: "a3c4b0"))

    // MARK: Glass fills (match `.glass` / `.glass-green` backgrounds)

    /// Neutral glass card fill.
    static let glass = Color(
        light: Color(white: 1, opacity: 0.90),
        dark: Color(hex: "0a2312").opacity(0.80)
    )
    /// Accent glass fill (for the resume / hero cards).
    static let glassGreen = Color(
        light: Color(hex: "22c55e").opacity(0.08),
        dark: Color(hex: "22c55e").opacity(0.10)
    )

    // MARK: Element-type accents (legend / future use; reader uses `primary`)

    static let elHarf = Color(hex: "a78bfa")
    static let elBogin = Color(hex: "38bdf8")
    static let elSoz = Color(hex: "34d399")
    static let elJumla = Color(hex: "fbbf24")
}

// MARK: - Color helpers

nonisolated extension Color {

    /// Builds a color that resolves differently in light vs dark appearance.
    /// Light is the default; the dark value is used only when the resolved
    /// `UITraitCollection` is dark. Both inputs are pre-flattened to `UIColor`
    /// so the dynamic provider only picks between two cached instances.
    init(light: Color, dark: Color) {
        let lightUI = UIColor(light)
        let darkUI = UIColor(dark)
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkUI : lightUI
        })
    }

    /// Parses a hex string (`RRGGBB` or `RRGGBBAA`, optional leading `#`).
    /// Falls back to opaque black on a malformed string — never crashes.
    init(hex: String, opacity: Double = 1) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).lowercased()
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red, green, blue, alpha: Double
        if cleaned.count == 8 {
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        } else {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = opacity
        }
        self = Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
