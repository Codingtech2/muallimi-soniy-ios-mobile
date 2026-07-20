import SwiftUI
import UIKit
import CoreText
import OSLog

/// Canonical family names of the bundled Arabic fonts, as read from each
/// file's `name` table (name IDs verified with fontTools):
///
/// | File                                 | family (ID 1)                 | PostScript (ID 6)                 |
/// |--------------------------------------|-------------------------------|-----------------------------------|
/// | NotoNaskhArabic-MuallimiSoniy.ttf    | Noto Naskh Arabic Muallimi    | NotoNaskhArabicMuallimi-Variable  |
/// | NotoNaskhArabic-VariableFont_wght.ttf| Noto Naskh Arabic             | NotoNaskhArabic-Regular           |
/// | AmiriQuran.ttf                       | Amiri Quran                   | AmiriQuran-Regular                |
/// | Amiri-Regular.ttf                    | Amiri                         | Amiri-Regular                     |
/// | UthmanicHafs.otf                     | KFGQPC Uthmanic Script HAFS   | KFGQPCUthmanicScriptHAFS          |
nonisolated enum AppFontFamily {
    /// THE universal Arabic body font — custom Noto Naskh with the
    /// shadda+kasra / shadda+kasratan ligatures stripped (mirrors web
    /// `--font-arabic`). Used everywhere except mad pages.
    static let muallimi = "Noto Naskh Arabic Muallimi"
    static let muallimiPostScript = "NotoNaskhArabicMuallimi-Variable"

    /// Original Noto Naskh — mad-page base letterforms + generic fallback.
    static let notoNaskh = "Noto Naskh Arabic"
    static let notoNaskhPostScript = "NotoNaskhArabic-Regular"

    /// Amiri Quran — large, prominent damma (U+064F) for mad pages.
    static let amiriQuran = "Amiri Quran"
    static let amiriQuranPostScript = "AmiriQuran-Regular"

    /// Amiri — decorative bismillah / calligraphic ligatures.
    static let amiri = "Amiri"
    static let amiriPostScript = "Amiri-Regular"

    /// KFGQPC Uthmanic Script HAFS — official Madina Mushaf face.
    static let uthmanicHafs = "KFGQPC Uthmanic Script HAFS"
    static let uthmanicHafsPostScript = "KFGQPCUthmanicScriptHAFS"
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
        ("NotoNaskhArabic-VariableFont_wght", "ttf"),
        ("AmiriQuran", "ttf"),
        ("Amiri-Regular", "ttf"),
        ("UthmanicHafs", "otf")
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

// MARK: - Font helpers

/// Universal Arabic text font (custom Noto Naskh Muallimi). Fixed size — the
/// reader scales via discrete size buckets in the primitives, not Dynamic Type.
nonisolated func arabicFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
    let name = FontRegistrar.resolvedName(
        family: AppFontFamily.muallimi,
        postScriptFallback: AppFontFamily.muallimiPostScript
    )
    return Font.custom(name, fixedSize: size).weight(weight)
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
