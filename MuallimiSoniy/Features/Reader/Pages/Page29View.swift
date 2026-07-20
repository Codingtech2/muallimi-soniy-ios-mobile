import SwiftUI

/// Bespoke 1:1 renderer for book page 29 — Shamsiya letters (the middle
/// alif / lam / alif+lam stays silent). Three sections, each a clickable
/// chig'atoy narration title followed by wrapping `size="sm"` word rows,
/// separated by compact dotted rules. Every token / title carries its own tap +
/// active highlight; nothing is dimmed.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page29`
/// (page-local `SectionTitle` → `TappableTextLabel(fullWidth:)`; `Sep` → `sep`).
struct Page29View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0` → 0 pt.
        VStack(spacing: 0) {
            section1(c)   // O'rta alif o'qilmaydi
            sep
            section2(c)   // O'rta lam o'qilmaydi
            sep
            section3(c)   // "huva al-X" — alif+lam ikkalasi ham o'qilmaydi
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    /// Section 1 — o'rta alif: title + 4 rows (5/3/3/3).
    @ViewBuilder
    private func section1(_ c: PageContent) -> some View {
        sectionTitle(c.el("s1_title"))
        row(c, ["s1_r1_w1", "s1_r1_w2", "s1_r1_w3", "s1_r1_w4", "s1_r1_w5"], .gap1)
        row(c, ["s1_r2_w1", "s1_r2_w2", "s1_r2_w3"], .gap1_5)
        row(c, ["s1_r3_w1", "s1_r3_w2", "s1_r3_w3"], .gap1_5)
        row(c, ["s1_r4_w1", "s1_r4_w2", "s1_r4_w3"], .gap1_5)
    }

    /// Section 2 — o'rta lam: title + 3 rows (5/5/4).
    @ViewBuilder
    private func section2(_ c: PageContent) -> some View {
        sectionTitle(c.el("s2_title"))
        row(c, ["s2_r1_w1", "s2_r1_w2", "s2_r1_w3", "s2_r1_w4", "s2_r1_w5"], .gap1)
        row(c, ["s2_r2_w1", "s2_r2_w2", "s2_r2_w3", "s2_r2_w4", "s2_r2_w5"], .gap1)
        row(c, ["s2_r3_w1", "s2_r3_w2", "s2_r3_w3", "s2_r3_w4"], .gap1_5)
    }

    /// Section 3 — "huva al-X": title + 4 rows (4/4/3/3).
    @ViewBuilder
    private func section3(_ c: PageContent) -> some View {
        sectionTitle(c.el("s3_title"))
        row(c, ["s3_r1_w1", "s3_r1_w2", "s3_r1_w3", "s3_r1_w4"], .gap1)
        row(c, ["s3_r2_w1", "s3_r2_w2", "s3_r2_w3", "s3_r2_w4"], .gap1)
        row(c, ["s3_r3_w1", "s3_r3_w2", "s3_r3_w3"], .gap1_5)
        row(c, ["s3_r4_w1", "s3_r4_w2", "s3_r4_w3"], .gap1_5)
    }

    // MARK: - Primitives

    /// A page-29 word row (all rows are `size="sm"`).
    private func row(_ c: PageContent, _ ids: [String], _ spacing: RowSpacing) -> some View {
        WordRow(elements: c.els(ids), size: .sm, spacing: spacing,
                activeId: activeId, onTap: onTap)
    }

    /// Clickable narration title (web page-29 `SectionTitle`: `w-full`,
    /// `text-[clamp(…,0.78rem)]`, muted). Full-width so it centres over the grid.
    private func sectionTitle(_ element: Element?) -> some View {
        TappableTextLabel(element: element, font: arabicFont(12.5, weight: .regular),
                          inactiveColor: AppColor.textMuted,
                          glowRadius: 10, glowY: 6, horizontalPadding: 8,
                          fullWidth: true, activeId: activeId, onTap: onTap)
    }

    /// Web `Sep` (`border-b-2 border-dotted my-0.5`): the shared dotted rule with
    /// its `my-2` padding pulled back to `my-0.5` (8 − 6 = 2 pt each side).
    private var sep: some View {
        SectionDivider().padding(.vertical, -6)
    }
}
