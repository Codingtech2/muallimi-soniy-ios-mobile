import SwiftUI

/// Bespoke 1:1 renderer for book page 42 — Surah Az-Zalzalah (bismillah + 8
/// ayat) then Surah Al-'Adiyat (bismillah + 11 ayat), split by a dotted divider.
///
/// Titles are static (`SectionTitle`, web `Title`); bismillah lines are plain
/// wrapping rows (`WordRow`, web `Row`); ayat lines trail each token with a `❀`
/// (`AyahRow`, web `AyahRow`). Every glyph's Unicode comes straight from
/// `element.arabic`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page42`.
struct Page42View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 2) {  // outer flex-col gap-0.5
            zalzalah(c)
            SectionDivider()
            adiyat(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Surahs

    /// Az-Zalzalah — bismillah + 8 ayat (rows 1+2, 3+4, 5, 6, 7+8).
    @ViewBuilder
    private func zalzalah(_ c: PageContent) -> some View {
        SectionTitle("سورة الزلزلة", subtitle: "زلزله سوره‌سی")
        bism(c, "zz_bism")
        ayah(c, ["zz_a1", "zz_a2"], .gap1_5)
        ayah(c, ["zz_a3", "zz_a4"], .gap1_5)
        ayah(c, ["zz_a5"], .gap2)
        ayah(c, ["zz_a6"], .gap2)
        ayah(c, ["zz_a7", "zz_a8"], .gap1_5)
    }

    /// Al-'Adiyat — bismillah + 11 ayat (rows 1+2+3, 4+5, 6+7, 8+9, 10+11).
    @ViewBuilder
    private func adiyat(_ c: PageContent) -> some View {
        SectionTitle("سورة العاديات", subtitle: "عادیات سوره‌سی")
        bism(c, "ad_bism")
        ayah(c, ["ad_a1", "ad_a2", "ad_a3"], .gap1)
        ayah(c, ["ad_a4", "ad_a5"], .gap1_5)
        ayah(c, ["ad_a6", "ad_a7"], .gap1_5)
        ayah(c, ["ad_a8", "ad_a9"], .gap1_5)
        ayah(c, ["ad_a10", "ad_a11"], .gap1_5)
    }

    // MARK: - Row helpers

    /// Bismillah line — web `Row` (`size="sm" gap="gap-2"`, no separators).
    private func bism(_ c: PageContent, _ id: String) -> some View {
        WordRow(elements: c.els([id]), size: .sm, spacing: .gap2,
                activeId: activeId, onTap: onTap)
    }

    /// Ayah line — shared `AyahRow` (web `AyahRow`: `size="sm"`, a `❀` after
    /// each token).
    private func ayah(_ c: PageContent, _ ids: [String], _ spacing: RowSpacing) -> some View {
        AyahRow(elements: c.els(ids), spacing: spacing,
                activeId: activeId, onTap: onTap)
    }
}
