import SwiftUI

/// Bespoke 1:1 renderer for book page 43 — Surah Al-Qari'ah (bismillah + 11
/// ayat) then Surah At-Takathur (bismillah + 8 ayat), then just the Al-'Asr
/// title + bismillah (its ayat continue on page 44). Sections are split by
/// dotted dividers.
///
/// Titles are static (`SectionTitle`); bismillah lines use `WordRow`; ayat lines
/// use the shared `AyahRow` (each token trailed by `❀`). Glyph Unicode comes
/// from `element.arabic`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page43`.
struct Page43View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 2) {  // outer flex-col gap-0.5
            qariah(c)
            SectionDivider()
            takathur(c)
            SectionDivider()
            asrHeader(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Surahs

    /// Al-Qari'ah — bismillah + 11 ayat (rows 1+2+3, 4, 5, 6+7, 8+9, 10+11).
    @ViewBuilder
    private func qariah(_ c: PageContent) -> some View {
        SectionTitle("سورة القارعة", subtitle: "قارعه سوره‌سی")
        bism(c, "qr_bism")
        ayah(c, ["qr_a1", "qr_a2", "qr_a3"], .gap1)
        ayah(c, ["qr_a4"], .gap2)
        ayah(c, ["qr_a5"], .gap2)
        ayah(c, ["qr_a6", "qr_a7"], .gap1_5)
        ayah(c, ["qr_a8", "qr_a9"], .gap1_5)
        ayah(c, ["qr_a10", "qr_a11"], .gap1_5)
    }

    /// At-Takathur — bismillah + 8 ayat (rows 1+2+3, 4+5, 6+7, 8).
    @ViewBuilder
    private func takathur(_ c: PageContent) -> some View {
        SectionTitle("سورة التكاثر", subtitle: "تکاثر سوره‌سی")
        bism(c, "tk_bism")
        ayah(c, ["tk_a1", "tk_a2", "tk_a3"], .gap1)
        ayah(c, ["tk_a4", "tk_a5"], .gap1_5)
        ayah(c, ["tk_a6", "tk_a7"], .gap1_5)
        ayah(c, ["tk_a8"], .gap2)
    }

    /// Al-'Asr — title + bismillah only (the three ayat render on page 44).
    @ViewBuilder
    private func asrHeader(_ c: PageContent) -> some View {
        SectionTitle("سورة العصر", subtitle: "عصر سوره‌سی")
        bism(c, "as_bism")
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
