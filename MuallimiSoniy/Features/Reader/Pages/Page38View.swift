import SwiftUI

/// Bespoke 1:1 renderer for book page 38 — the rest of Surah al-Layl (ayahs
/// 8–21, continuing from page 37) then, after a dotted `SectionDivider`, the
/// Surah ad-Duha header (tappable title + bismillah) and ayahs 1–10 (ayah 11 is
/// on page 39). Verses render as `AyahRow`s (verse + `❀`); the tighter
/// `gap-1.5` spacing matches the web.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page38`.
struct Page38View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            layl(c)
            SectionDivider()
            duha(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    /// سُورَةُ اللَّيْل (davomi) — ayahs 8–21 grouped two per line.
    @ViewBuilder
    private func layl(_ c: PageContent) -> some View {
        ayah(c, ["ll_a8", "ll_a9"])
        ayah(c, ["ll_a10", "ll_a11"])
        ayah(c, ["ll_a12", "ll_a13"])
        ayah(c, ["ll_a14", "ll_a15"])
        ayah(c, ["ll_a16", "ll_a17"])
        ayah(c, ["ll_a18", "ll_a19"])
        ayah(c, ["ll_a20", "ll_a21"])
    }

    /// سُورَةُ الضُّحٰى — title + bismillah then ayahs 1–10 grouped 3/2/2/1/2 per line.
    @ViewBuilder
    private func duha(_ c: PageContent) -> some View {
        title(c, "du_title")
        bismillah(c, "du_bism")
        ayah(c, ["du_a1", "du_a2", "du_a3"])
        ayah(c, ["du_a4", "du_a5"])
        ayah(c, ["du_a6", "du_a7"])
        ayah(c, ["du_a8"])
        ayah(c, ["du_a9", "du_a10"])
    }

    // MARK: - Row builders (web `ArabicEl` title / `Row` gap-2 / `AyahRow` gap-1.5)

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
        AyahRow(elements: c.els(ids), size: .sm, spacing: .gap1_5, activeId: activeId, onTap: onTap)
    }
}
