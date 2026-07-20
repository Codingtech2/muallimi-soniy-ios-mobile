import SwiftUI

/// Bespoke 1:1 renderer for book page 46 — the continuation of al-Kafirun
/// (ayat 1–6; its title + bismillah are on page 45), then Surah an-Nasr,
/// Surah al-Masad, and the opening of Surah al-Ikhlas (bismillah + ayat 1–2 +
/// the 3+4 linked pair). Every line is a tappable `Verse` (`﴿N﴾` + trailing
/// `❀`) under a static `SurahTitle`, split by dotted `SectionDivider`s.
///
/// al-Ikhlas ayat 3+4 share one audio clip (reciter joined them), so they
/// render as a linked in-row pair — tapping either highlights both.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page46`.
struct Page46View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0` → 0 pt.
        VStack(spacing: 0) {
            kafirunTail(c)
            SectionDivider()
            nasr(c)
            SectionDivider()
            masad(c)
            SectionDivider()
            ikhlas(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Surahs

    /// سُورَةُ الْكَافِرُونَ tail — ayat 1–6 only (title + bismillah on page 45).
    @ViewBuilder
    private func kafirunTail(_ c: PageContent) -> some View {
        verse(c, "kf_a1", ayah: 1)
        verse(c, "kf_a2", ayah: 2)
        verse(c, "kf_a3", ayah: 3)
        verse(c, "kf_a4", ayah: 4)
        verse(c, "kf_a5", ayah: 5)
        verse(c, "kf_a6", ayah: 6)
    }

    /// سُورَةُ النَّصْرِ — bismillah + ayat 1–3.
    @ViewBuilder
    private func nasr(_ c: PageContent) -> some View {
        SurahTitle("سُورَةُ النَّصْرِ")
        verse(c, "ns_bism")
        verse(c, "ns_a1", ayah: 1)
        verse(c, "ns_a2", ayah: 2)
        verse(c, "ns_a3", ayah: 3)
    }

    /// سُورَةُ الْمَسَدِ — bismillah + ayat 1–5.
    @ViewBuilder
    private func masad(_ c: PageContent) -> some View {
        SurahTitle("سُورَةُ الْمَسَدِ")
        verse(c, "ms_bism")
        verse(c, "ms_a1", ayah: 1)
        verse(c, "ms_a2", ayah: 2)
        verse(c, "ms_a3", ayah: 3)
        verse(c, "ms_a4", ayah: 4)
        verse(c, "ms_a5", ayah: 5)
    }

    /// سُورَةُ الْإِخْلَاصِ — bismillah + ayat 1–2 + the 3+4 linked pair (ayat 3–4
    /// begin here; ayah 4's tail continues on page 47).
    @ViewBuilder
    private func ikhlas(_ c: PageContent) -> some View {
        SurahTitle("سُورَةُ الْإِخْلَاصِ")
        verse(c, "ix_bism")
        verse(c, "ix_a1", ayah: 1)
        verse(c, "ix_a2", ayah: 2)
        linkedPair(c, ("ix_a3", 3), ("ix_a4", 4))
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
