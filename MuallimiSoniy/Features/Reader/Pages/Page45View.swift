import SwiftUI

/// Bespoke 1:1 renderer for book page 45 — three complete surahs (Quraysh,
/// al-Ma'un, al-Kawthar) plus the title + bismillah of al-Kafirun (whose ayat
/// continue on page 46). Every line is a tappable `Verse` (ayah number `﴿N﴾`
/// plus a trailing `❀`) under a static `SurahTitle`, split by dotted
/// `SectionDivider`s.
///
/// al-Ma'un ayat 4+5 share one audio clip, so they render as a linked in-row
/// pair — tapping either highlights both (web `linkedIds` group).
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page45`.
struct Page45View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0` → 0 pt (SurahTitle and
        // SectionDivider carry their own vertical margins).
        VStack(spacing: 0) {
            quraysh(c)
            SectionDivider()
            maun(c)
            SectionDivider()
            kawthar(c)
            SectionDivider()
            kafirunHeader(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Surahs

    /// سُورَةُ قُرَيْشٍ — bismillah + ayat 1–4.
    @ViewBuilder
    private func quraysh(_ c: PageContent) -> some View {
        SurahTitle("سُورَةُ قُرَيْشٍ")
        verse(c, "qu_bism")
        verse(c, "qu_a1", ayah: 1)
        verse(c, "qu_a2", ayah: 2)
        verse(c, "qu_a3", ayah: 3)
        verse(c, "qu_a4", ayah: 4)
    }

    /// سُورَةُ الْمَاعُونِ — bismillah + ayat 1–7 (4+5 a linked in-row pair).
    @ViewBuilder
    private func maun(_ c: PageContent) -> some View {
        SurahTitle("سُورَةُ الْمَاعُونِ")
        verse(c, "ma_bism")
        verse(c, "ma_a1", ayah: 1)
        verse(c, "ma_a2", ayah: 2)
        verse(c, "ma_a3", ayah: 3)
        linkedPair(c, ("ma_a4", 4), ("ma_a5", 5))
        verse(c, "ma_a6", ayah: 6)
        verse(c, "ma_a7", ayah: 7)
    }

    /// سُورَةُ الْكَوْثَرِ — bismillah + ayat 1–3.
    @ViewBuilder
    private func kawthar(_ c: PageContent) -> some View {
        SurahTitle("سُورَةُ الْكَوْثَرِ")
        verse(c, "ka_bism")
        verse(c, "ka_a1", ayah: 1)
        verse(c, "ka_a2", ayah: 2)
        verse(c, "ka_a3", ayah: 3)
    }

    /// سُورَةُ الْكَافِرُونَ — title + bismillah only (ayat begin on page 46).
    @ViewBuilder
    private func kafirunHeader(_ c: PageContent) -> some View {
        SurahTitle("سُورَةُ الْكَافِرُونَ")
        verse(c, "kf_bism")
    }

    // MARK: - Row helpers

    /// Resolves an id suffix and renders it as a full-width `Verse` (skipped if
    /// absent). Bismillah lines pass no `ayah`.
    @ViewBuilder
    private func verse(_ c: PageContent, _ suffix: String, ayah: Int? = nil) -> some View {
        if let element = c.el(suffix) {
            Verse(element: element, ayah: ayah, size: .sm, activeId: activeId, onTap: onTap)
        }
    }

    /// Two verses sharing one audio clip: laid out side-by-side RTL and centred
    /// (web linked in-row pair, `dir="rtl" gap-2 items-baseline`). Each carries
    /// the other's id as `linkedIds`, so either tap highlights both.
    @ViewBuilder
    private func linkedPair(
        _ c: PageContent,
        _ first: (String, Int),
        _ second: (String, Int)
    ) -> some View {
        let e1 = c.el(first.0)
        let e2 = c.el(second.0)
        HStack(alignment: .firstTextBaseline, spacing: 8) {  // gap-2
            if let e1 {
                Verse(element: e1, ayah: first.1, size: .sm, inRow: true,
                      activeId: activeId, linkedIds: [e2?.id].compactMap { $0 }, onTap: onTap)
            }
            if let e2 {
                Verse(element: e2, ayah: second.1, size: .sm, inRow: true,
                      activeId: activeId, linkedIds: [e1?.id].compactMap { $0 }, onTap: onTap)
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
