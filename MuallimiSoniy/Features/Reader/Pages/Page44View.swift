import SwiftUI

/// Bespoke 1:1 renderer for book page 44 — the last three ayat of Surah Al-'Asr
/// (its title + bismillah are on page 43), then Surah Al-Humazah (title +
/// bismillah + 9 ayat) and Surah Al-Fil (title + bismillah + 5 ayat), each split
/// by a dotted divider.
///
/// Unlike pages 42–43 the Humazah/Fil headings are *tappable* surah-name
/// elements flanked by `❀` ornaments (shared `TappableSurahTitle`, web page-local
/// title header), because those titles carry their own audio. Bismillah lines use
/// `WordRow`; ayat lines use the shared `AyahRow`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page44`.
struct Page44View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 2) {  // outer flex-col gap-0.5
            asrTail(c)
            SectionDivider()
            humazah(c)
            SectionDivider()
            fil(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Surahs

    /// Al-'Asr — continuation only: ayat 1+2 then 3 (title/bismillah on p43).
    @ViewBuilder
    private func asrTail(_ c: PageContent) -> some View {
        ayah(c, ["as_a1", "as_a2"], .gap1_5)
        ayah(c, ["as_a3"], .gap2)
    }

    /// Al-Humazah — tappable title + bismillah + 9 ayat (rows 1, 2+3, 4+5, 6+7,
    /// 8+9).
    @ViewBuilder
    private func humazah(_ c: PageContent) -> some View {
        flowerTitle(c, "hu_title")
        bism(c, "hu_bism")
        ayah(c, ["hu_a1"], .gap2)
        ayah(c, ["hu_a2", "hu_a3"], .gap1_5)
        ayah(c, ["hu_a4", "hu_a5"], .gap1_5)
        ayah(c, ["hu_a6", "hu_a7"], .gap1_5)
        ayah(c, ["hu_a8", "hu_a9"], .gap1_5)
    }

    /// Al-Fil — tappable title + bismillah + 5 ayat (rows 1, 2+3, 4+5).
    @ViewBuilder
    private func fil(_ c: PageContent) -> some View {
        flowerTitle(c, "fi_title")
        bism(c, "fi_bism")
        ayah(c, ["fi_a1"], .gap2)
        ayah(c, ["fi_a2", "fi_a3"], .gap1_5)
        ayah(c, ["fi_a4", "fi_a5"], .gap1_5)
    }

    // MARK: - Row helpers

    /// Tappable surah heading flanked by `❀` ornaments (shared
    /// `TappableSurahTitle`, `size="md"`). Renders nothing if the element is
    /// absent.
    @ViewBuilder
    private func flowerTitle(_ c: PageContent, _ id: String) -> some View {
        if let title = c.el(id) {
            TappableSurahTitle(element: title, activeId: activeId, onTap: onTap)
        }
    }

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
