import SwiftUI

/// Bespoke 1:1 renderer for book page 36 — the isti'adha, Surah al-Fatiha
/// (bismillah + 7 ayahs) and the opening of Surah al-Baqarah (bismillah + 5
/// ayahs). Every line is a tappable `Verse` (ayah number appended as `﴿N﴾` plus a
/// trailing `❀`), grouped under static `SurahTitle` headings and split by a
/// dotted `SectionDivider`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page36`.
struct Page36View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            verse(c, "taawwudh", size: .md)          // isti'adha (no ayah marker)
            fatiha(c)
            SectionDivider()
            baqarah(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    /// سُورَةُ الْفَاتِحَة — bismillah (md) then ayahs 2–7 (sm). Ayah 1 marker sits on
    /// the bismillah (web `fa_bismi num="١"`).
    @ViewBuilder
    private func fatiha(_ c: PageContent) -> some View {
        SurahTitle("سُورَةُ الْفَاتِحَة")
        verse(c, "fa_bismi", size: .md, ayah: 1)
        verse(c, "fa_v2", size: .sm, ayah: 2)
        verse(c, "fa_v3", size: .sm, ayah: 3)
        verse(c, "fa_v4", size: .sm, ayah: 4)
        verse(c, "fa_v5", size: .sm, ayah: 5)
        verse(c, "fa_v6", size: .sm, ayah: 6)
        verse(c, "fa_v7", size: .sm, ayah: 7)
    }

    /// اَوَّلُ سُورَةِ الْبَقَرَة — bismillah (md, no marker) then ayahs 1–5
    /// (ayah 1 md, 2–5 sm).
    @ViewBuilder
    private func baqarah(_ c: PageContent) -> some View {
        SurahTitle("اَوَّلُ سُورَةِ الْبَقَرَة")
        verse(c, "bq_bismi", size: .md)
        verse(c, "bq_v1", size: .md, ayah: 1)
        verse(c, "bq_v2", size: .sm, ayah: 2)
        verse(c, "bq_v3", size: .sm, ayah: 3)
        verse(c, "bq_v4", size: .sm, ayah: 4)
        verse(c, "bq_v5", size: .sm, ayah: 5)
    }

    /// Resolves an id suffix and renders it as a `Verse` (skipped if absent).
    @ViewBuilder
    private func verse(_ c: PageContent, _ suffix: String, size: VerseSize, ayah: Int? = nil) -> some View {
        if let element = c.el(suffix) {
            Verse(element: element, ayah: ayah, size: size, activeId: activeId, onTap: onTap)
        }
    }
}
