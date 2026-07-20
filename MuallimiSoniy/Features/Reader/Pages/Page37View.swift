import SwiftUI

/// Bespoke 1:1 renderer for book page 37 — Surah ash-Shams (bismillah + ayahs
/// 1–15) and the start of Surah al-Layl (bismillah + ayahs 1–7; ayah 8 continues
/// on page 38). Each surah opens with a tappable `TappableSurahTitle`, a
/// bismillah `WordRow`, then `AyahRow`s (verse + `❀`), the two split by a
/// dotted `SectionDivider`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page37`.
struct Page37View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            shams(c)
            SectionDivider()
            layl(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    /// سُورَةُ الشَّمْس — bismillah then ayahs 1–15 grouped 3/2/3/3/2/1/1 per line.
    @ViewBuilder
    private func shams(_ c: PageContent) -> some View {
        title(c, "sh_title")
        bismillah(c, "sh_bismillah")
        ayah(c, ["sh_a1", "sh_a2", "sh_a3"])
        ayah(c, ["sh_a4", "sh_a5"])
        ayah(c, ["sh_a6", "sh_a7", "sh_a8"])
        ayah(c, ["sh_a9", "sh_a10", "sh_a11"])
        ayah(c, ["sh_a12", "sh_a13"])
        ayah(c, ["sh_a14"])
        ayah(c, ["sh_a15"])
    }

    /// سُورَةُ اللَّيْل (boshi) — bismillah then ayahs 1–7 grouped 3/2/2 per line.
    @ViewBuilder
    private func layl(_ c: PageContent) -> some View {
        title(c, "ll_title")
        bismillah(c, "ll_bismillah")
        ayah(c, ["ll_a1", "ll_a2", "ll_a3"])
        ayah(c, ["ll_a4", "ll_a5"])
        ayah(c, ["ll_a6", "ll_a7"])
    }

    // MARK: - Row builders (web `ArabicEl` title / `Row` / `AyahRow`, size sm, gap-2)

    @ViewBuilder
    private func title(_ c: PageContent, _ suffix: String) -> some View {
        if let element = c.el(suffix) {
            TappableSurahTitle(element: element, size: .md, activeId: activeId, onTap: onTap)
        }
    }

    private func bismillah(_ c: PageContent, _ suffix: String) -> some View {
        WordRow(elements: c.els([suffix]), size: .md, spacing: .gap2, activeId: activeId, onTap: onTap)
    }

    private func ayah(_ c: PageContent, _ ids: [String]) -> some View {
        AyahRow(elements: c.els(ids), size: .sm, spacing: .gap2, activeId: activeId, onTap: onTap)
    }
}
