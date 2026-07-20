import SwiftUI

/// Bespoke 1:1 renderer for book page 47 — Surah al-Falaq (bismillah + 5 ayat)
/// and Surah an-Nas (bismillah + 6 ayat). (al-Ikhlas finished on page 46, so
/// this page opens straight into al-Falaq.) Every line is a tappable `Verse`
/// (ayah number `﴿N﴾` + trailing `❀`) under a static `SurahTitle`, the two
/// surahs split by a dotted `SectionDivider`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page47`.
struct Page47View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0` → 0 pt.
        VStack(spacing: 0) {
            falaq(c)
            SectionDivider()
            nas(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Surahs

    /// سُورَةُ الْفَلَقِ — bismillah + ayat 1–5.
    @ViewBuilder
    private func falaq(_ c: PageContent) -> some View {
        SurahTitle("سُورَةُ الْفَلَقِ")
        verse(c, "fq_bism")
        verse(c, "fq_a1", ayah: 1)
        verse(c, "fq_a2", ayah: 2)
        verse(c, "fq_a3", ayah: 3)
        verse(c, "fq_a4", ayah: 4)
        verse(c, "fq_a5", ayah: 5)
    }

    /// سُورَةُ النَّاسِ — bismillah + ayat 1–6.
    @ViewBuilder
    private func nas(_ c: PageContent) -> some View {
        SurahTitle("سُورَةُ النَّاسِ")
        verse(c, "ns_bism")
        verse(c, "ns_a1", ayah: 1)
        verse(c, "ns_a2", ayah: 2)
        verse(c, "ns_a3", ayah: 3)
        verse(c, "ns_a4", ayah: 4)
        verse(c, "ns_a5", ayah: 5)
        verse(c, "ns_a6", ayah: 6)
    }

    // MARK: - Row helper

    /// Resolves an id suffix and renders it as a full-width `Verse` (skipped if
    /// absent). Bismillah lines pass no `ayah`.
    @ViewBuilder
    private func verse(_ c: PageContent, _ suffix: String, ayah: Int? = nil) -> some View {
        if let element = c.el(suffix) {
            Verse(element: element, ayah: ayah, size: .sm, activeId: activeId, onTap: onTap)
        }
    }
}
