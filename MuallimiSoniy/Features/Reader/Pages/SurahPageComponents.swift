import SwiftUI

/// Shared surah-page header used by pages 37 and 38 — a centred, **tappable**
/// surah title flanked by two muted `❀` ornaments. The verse rows themselves
/// reuse the shared `AyahRow` (`SurahAyahRow.swift`); only this tappable-title
/// header is specific to the Shams / Layl / Duha pages, so it lives here rather
/// than being duplicated in each page file.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → the
/// `shamsTitleHeader` / `laylTitleHeader` / `duhoTitleHeader` blocks (a tappable
/// `ArabicEl` between two `text-xs` `❀` ornaments, `gap-3`).
///
/// Distinct from the shared `SurahTitle`, whose heading is static text: here the
/// title glyph is itself an element (`sh_title`, `ll_title`, `du_title`) that
/// highlights and plays its own audio when tapped.
///
/// Inside the reader (`\.surahPlayback` set) and given its `surah`, the whole
/// framed heading is instead a banner that reads that surah in full (web: a
/// `SurahBanner` with this title as its `lead`), drawn the same way at rest.
struct TappableSurahTitle: View {
    let element: Element
    var size: ArabicSize = .md
    /// The surah this title opens, or `nil` to keep the plain element tap.
    var surah: Int?
    /// The page's first surah heading: the one-time hint shows under it.
    var carriesHint = false
    let activeId: String?
    let onTap: (Element) -> Void

    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.verseFontScale) private var verseFontScale
    @Environment(\.surahPlayback) private var surahPlayback
    /// Line spacing / bold / highlight from the "Aa" sheet.
    @Environment(\.readingAdjustments) private var adjustments
    /// System-wide Settings → Accessibility → Bold Text.
    @Environment(\.legibilityWeight) private var legibilityWeight

    /// `ArabicElementView`'s hit-box floor — kept so the banner title sits in
    /// the same 44 pt row as the element it replaces.
    private static let minRowHeight: CGFloat = 44

    private var effectiveBold: Bool { adjustments.boldText || legibilityWeight == .bold }

    var body: some View {
        Group {
            if let surah, SurahBannerQA.resolve(surahPlayback) != nil {
                banner(surah)
            } else {
                elementHeading
            }
        }
        .environment(\.arabicFontScale, verseFontScale)
    }

    /// Outside the reader: the title is its own element, tapped like any other.
    private var elementHeading: some View {
        HStack(spacing: 12) {  // gap-3
            ornament()
            ArabicElementView(
                element: element,
                size: size,
                isActive: activeId == element.id,
                onTap: { onTap(element) }
            )
            ornament()
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .rightToLeft)
        .surahHeaderFrame()
    }

    private func banner(_ surah: Int) -> some View {
        SurahBannerFrame(surah: surah, name: element.accessibilityLabelText, carriesHint: carriesHint) { isPlaying in
            HStack(spacing: 12) {  // gap-3
                ornament(isPlaying)
                titleText(isPlaying)
                ornament(isPlaying)
            }
            .frame(maxWidth: .infinity)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    /// The title drawn exactly as `ArabicElementView` draws it at rest (font,
    /// padding, row height), but as part of the banner's one button rather
    /// than a button of its own. White on the band while the surah plays.
    private func titleText(_ isPlaying: Bool) -> some View {
        Text(element.arabic)
            .font(arabicFont(size.pointSize * verseFontScale, weight: arabicWeight(bold: effectiveBold)))
            .foregroundStyle(isPlaying ? Color.white : readingTheme.textMain)
            .hifzHiddenText(element)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: Self.minRowHeight)
            // The reader's auto-follow scrolls to elements by id.
            .id(element.id)
    }

    private func ornament(_ isPlaying: Bool = false) -> some View {
        Text("❀")
            .font(.system(size: 12 * verseFontScale))  // text-xs
            .foregroundStyle(isPlaying ? Color.white.opacity(0.85) : readingTheme.textMuted)
    }
}

/// A surah heading set as the shared `SectionTitle` (name + small chig'atoy
/// note) inside the surah band — pages 40–43 (web `Title` in the surah frame).
/// Inside the reader the band reads the whole surah (`SurahBannerFrame`);
/// anywhere else it is the same static heading as before.
struct SurahSectionTitle: View {
    let text: String
    var subtitle: String?
    /// The surah this heading opens.
    let surah: Int
    /// The page's first surah heading: the one-time hint shows under it.
    var carriesHint = false

    init(_ text: String, subtitle: String? = nil, surah: Int, carriesHint: Bool = false) {
        self.text = text
        self.subtitle = subtitle
        self.surah = surah
        self.carriesHint = carriesHint
    }

    var body: some View {
        SurahBannerFrame(surah: surah, name: text, carriesHint: carriesHint) { isPlaying in
            SectionTitle(text, subtitle: subtitle, onActiveBand: isPlaying)
        }
    }
}
