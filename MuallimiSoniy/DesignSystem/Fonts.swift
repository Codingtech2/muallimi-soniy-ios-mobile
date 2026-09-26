import SwiftUI
import UIKit
import CoreText
import OSLog
import os

/// Canonical family names of the bundled Arabic fonts, as read from each
/// file's `name` table (name IDs verified with fontTools):
///
/// | File                                 | family (ID 1)                 | PostScript (ID 6)                 |
/// |--------------------------------------|-------------------------------|-----------------------------------|
/// | NotoNaskhArabic-MuallimiSoniy.ttf    | Noto Naskh Arabic Muallimi    | NotoNaskhArabicMuallimi-Variable  |
/// | AmiriQuran.ttf                       | Amiri Quran                   | AmiriQuran-Regular                |
///
/// (Amiri-Regular / stock Noto Naskh / UthmanicHafs were bundled early on but
/// never referenced by any view — removed to keep the app bundle small.)
nonisolated enum AppFontFamily {
    /// THE universal Arabic body font — custom Noto Naskh with the
    /// shadda+kasra / shadda+kasratan ligatures stripped (mirrors web
    /// `--font-arabic`). Used everywhere except mad pages.
    static let muallimi = "Noto Naskh Arabic Muallimi"
    static let muallimiPostScript = "NotoNaskhArabicMuallimi-Variable"

    /// Amiri Quran — large, prominent damma (U+064F) for mad pages.
    static let amiriQuran = "Amiri Quran"
    static let amiriQuranPostScript = "AmiriQuran-Regular"

    /// SIL Scheherazade New 4.500 (OFL, files unmodified) — the optional
    /// `ArabicTypeface.scheherazade`. Static weights, picked by PostScript name.
    static let scheherazadeRegular = "ScheherazadeNew-Regular"
    static let scheherazadeSemiBold = "ScheherazadeNew-SemiBold"
    static let scheherazadeBold = "ScheherazadeNew-Bold"
}

/// Registers the bundled Arabic fonts with CoreText at launch and resolves the
/// concrete font names SwiftUI should use. Idempotent and thread-safe.
nonisolated enum FontRegistrar {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "Fonts"
    )

    /// `kCTFontManagerErrorAlreadyRegistered` — a benign result if the font is
    /// declared in `UIAppFonts` or `register()` is somehow invoked twice.
    private static let alreadyRegisteredCode: CFIndex = 105

    private static let bundledFonts: [(name: String, ext: String)] = [
        ("NotoNaskhArabic-MuallimiSoniy", "ttf"),
        ("AmiriQuran", "ttf"),
        ("ScheherazadeNew-Regular", "ttf"),
        ("ScheherazadeNew-SemiBold", "ttf"),
        ("ScheherazadeNew-Bold", "ttf")
    ]

    /// Registers every bundled font. Call once at app launch, before any view
    /// renders. Missing files and "already registered" errors are logged and
    /// skipped — registration never crashes launch.
    static func register() {
        for font in bundledFonts {
            registerOne(name: font.name, ext: font.ext)
        }
        #if DEBUG
        logAvailableFamilies()
        #endif
    }

    private static func registerOne(name: String, ext: String) {
        guard let url = fontURL(name: name, ext: ext) else {
            logger.error("Font missing from bundle: \(name, privacy: .public).\(ext, privacy: .public)")
            return
        }
        var errorRef: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &errorRef)
        if ok {
            logger.info("Registered font \(name, privacy: .public).\(ext, privacy: .public)")
            return
        }
        guard let error = errorRef?.takeRetainedValue() else { return }
        if CFErrorGetCode(error) == alreadyRegisteredCode {
            logger.debug("Font already registered (ignored): \(name, privacy: .public)")
        } else {
            let description = CFErrorCopyDescription(error) as String? ?? "unknown error"
            logger.error("Font register failed \(name, privacy: .public): \(description, privacy: .public)")
        }
    }

    /// Locates a bundled font whether Xcode copied it flat into the bundle root
    /// or preserved the `Fonts/` subdirectory.
    private static func fontURL(name: String, ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext)
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources/Fonts")
    }

    /// Resolves the concrete font name to hand to `Font.custom`. Prefers the
    /// registered PostScript member of `family` (guaranteed usable once
    /// registered); falls back to a known PostScript name, then the family
    /// name itself so text still renders even if lookup fails.
    static func resolvedName(family: String, postScriptFallback: String) -> String {
        if let member = UIFont.fontNames(forFamilyName: family).first {
            return member
        }
        if UIFont(name: postScriptFallback, size: 12) != nil {
            return postScriptFallback
        }
        return family
    }

    #if DEBUG
    /// One-time confirmation that our Arabic families landed in the font
    /// registry, with their concrete member (PostScript) names.
    private static func logAvailableFamilies() {
        let families = UIFont.familyNames.filter {
            $0.localizedCaseInsensitiveContains("naskh")
                || $0.localizedCaseInsensitiveContains("amiri")
                || $0.localizedCaseInsensitiveContains("uthmanic")
        }
        for family in families.sorted() {
            let members = UIFont.fontNames(forFamilyName: family)
            logger.debug("Arabic family '\(family, privacy: .public)' → \(members, privacy: .public)")
        }
    }
    #endif
}

// MARK: - Typeface choice

extension ArabicTypeface {
    /// The typeface `arabicFont(_:weight:)` draws with when a call site doesn't
    /// name one. `SettingsStore` keeps it in step with the setting; the views
    /// that must redraw on a change read `\.arabicTypeface` (the reader's page
    /// cards rebuild their content when it changes).
    nonisolated static var current: ArabicTypeface {
        get { currentStorage.withLock { $0 } }
        set { currentStorage.withLock { $0 = newValue } }
    }

    private nonisolated static let currentStorage = OSAllocatedUnfairLock(initialState: ArabicTypeface.naskh)
}

private struct ArabicTypefaceKey: EnvironmentKey {
    static let defaultValue: ArabicTypeface = .naskh
}

extension EnvironmentValues {
    /// The picked Arabic typeface, injected at the app root so views that draw
    /// Arabic can redraw when it changes.
    var arabicTypeface: ArabicTypeface {
        get { self[ArabicTypefaceKey.self] }
        set { self[ArabicTypefaceKey.self] = newValue }
    }
}

// MARK: - Font helpers

/// Universal Arabic text font: custom Noto Naskh Muallimi, or Scheherazade New
/// when that is picked. Fixed size — the reader scales via discrete size
/// buckets in the primitives, not Dynamic Type.
nonisolated func arabicFont(
    _ size: CGFloat,
    weight: Font.Weight = .bold,
    typeface: ArabicTypeface = .current
) -> Font {
    switch typeface {
    case .naskh:
        let name = FontRegistrar.resolvedName(
            family: AppFontFamily.muallimi,
            postScriptFallback: AppFontFamily.muallimiPostScript
        )
        return Font.custom(name, fixedSize: size).weight(weight)
    case .scheherazade:
        return scheherazadeFont(size, weight: weight)
    }
}

/// Scheherazade New at the static weight nearest `weight`.
///
/// Its kasra under a shadda sits raised, under the shadda, as in most printed
/// mushafs — not below the letter like the primer (and the Noto build, which
/// had that ligature stripped). The font's `cv62=1` would lower it, but SwiftUI
/// drops OpenType feature settings from a `Font` built from a CTFont/UIFont
/// (checked: CoreText alone renders the lowered kasra, SwiftUI `Text` does not).
private nonisolated func scheherazadeFont(_ size: CGFloat, weight: Font.Weight) -> Font {
    let name: String
    switch weight {
    case .ultraLight, .thin, .light, .regular:
        name = AppFontFamily.scheherazadeRegular
    case .medium, .semibold, .bold:
        name = AppFontFamily.scheherazadeSemiBold
    default:  // .heavy / .black — the "bold text" reading option
        name = AppFontFamily.scheherazadeBold
    }
    return Font.custom(name, fixedSize: size)
}

/// Mad-page Arabic font (Amiri Quran — large, prominent U+064F damma; also
/// renders the vertical superscript/subscript alef mad marks). The per-glyph
/// Noto-Naskh-base + Amiri-Quran-damma composition (web `.mad-arabic-text`)
/// is applied in the mad primitive using `AppFontFamily` names.
nonisolated func madArabicFont(_ size: CGFloat) -> Font {
    let name = FontRegistrar.resolvedName(
        family: AppFontFamily.amiriQuran,
        postScriptFallback: AppFontFamily.amiriQuranPostScript
    )
    return Font.custom(name, fixedSize: size)
}

/// Resolves the weight to hand `arabicFont(_:weight:)` for the reader's
/// "bold text" low-vision preference: `.bold` is today's unaffected
/// baseline, `.heavy` is the extra-weight step when the setting (or the
/// system-wide Bold Text accessibility setting) is on.
nonisolated func arabicWeight(bold: Bool) -> Font.Weight {
    bold ? .heavy : .bold
}
