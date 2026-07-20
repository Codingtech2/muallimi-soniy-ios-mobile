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
struct TappableSurahTitle: View {
    let element: Element
    var size: ArabicSize = .md
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        HStack(spacing: 12) {  // gap-3
            ornament
            ArabicElementView(
                element: element,
                size: size,
                isActive: activeId == element.id,
                onTap: { onTap(element) }
            )
            ornament
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var ornament: some View {
        Text("❀")
            .font(.system(size: 12))  // text-xs
            .foregroundStyle(AppColor.textMuted)
    }
}
