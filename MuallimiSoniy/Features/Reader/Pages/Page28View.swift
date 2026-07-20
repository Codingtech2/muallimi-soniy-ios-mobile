import SwiftUI

/// Bespoke 1:1 renderer for book page 28 — Yaa Alifiyya + Vav Alifiyya +
/// "yozilsa o'qilmaydigan harflar". Three blocks, each a clickable narration
/// title, a clickable chig'atoy subtitle and one-or-more wrapping `size="sm"`
/// word rows, separated by compact dotted rules. Every token / label carries its
/// own tap + active highlight; nothing is dimmed.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page28`
/// (`BlockTitle` / `ClickableSubText` → `TappableTextLabel`; `Sep` → `sep`).
struct Page28View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0` → 0 pt.
        VStack(spacing: 0) {
            block1(c)   // Yaa Alifiyya
            sep
            block2(c)   // Vav Alifiyya
            sep
            block3(c)   // Yozilsada o'qilmaydigan harflar
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Blocks

    /// Block 1 — Yaa Alifiyya: title + sub1 + 3 rows (6/5/4) + sub2 + 1 row (5).
    @ViewBuilder
    private func block1(_ c: PageContent) -> some View {
        blockTitle(c.el("b1_intro"))
        subLabel(c.el("b1_sub1"))
        row(c, ["r1_w1", "r1_w2", "r1_w3", "r1_w4", "r1_w5", "r1_w6"], .gap1_5)
        row(c, ["r2_w1", "r2_w2", "r2_w3", "r2_w4", "r2_w5"], .gap1_5)
        row(c, ["r3_w1", "r3_w2", "r3_w3", "r3_w4"], .gap2)
        subLabel(c.el("b1_sub2"))
        row(c, ["r4_w1", "r4_w2", "r4_w3", "r4_w4", "r4_w5"], .gap1)
    }

    /// Block 2 — Vav Alifiyya: title + sub + 1 row (6).
    @ViewBuilder
    private func block2(_ c: PageContent) -> some View {
        blockTitle(c.el("b2_intro"))
        subLabel(c.el("b2_sub"))
        row(c, ["r5_w1", "r5_w2", "r5_w3", "r5_w4", "r5_w5", "r5_w6"], .gap1_5)
    }

    /// Block 3 — yozilsa o'qilmaydigan harflar: title + sub1 + row (5) + sub2 + row (5).
    @ViewBuilder
    private func block3(_ c: PageContent) -> some View {
        blockTitle(c.el("b3_title"))
        subLabel(c.el("b3_sub1"))
        row(c, ["r6_w1", "r6_w2", "r6_w3", "r6_w4", "r6_w5"], .gap1_5)
        subLabel(c.el("b3_sub2"))
        row(c, ["r7_w1", "r7_w2", "r7_w3", "r7_w4", "r7_w5"], .gap1_5)
    }

    // MARK: - Primitives

    /// A page-28 word row (all rows are `size="sm"`).
    private func row(_ c: PageContent, _ ids: [String], _ spacing: RowSpacing) -> some View {
        WordRow(elements: c.els(ids), size: .sm, spacing: spacing,
                activeId: activeId, onTap: onTap)
    }

    /// Clickable block title (web `BlockTitle`: `text-sm font-bold`, `px-3`).
    private func blockTitle(_ element: Element?) -> some View {
        TappableTextLabel(element: element, font: arabicFont(14),
                          inactiveColor: AppColor.textSecondary,
                          glowRadius: 10, glowY: 6, horizontalPadding: 12,
                          activeId: activeId, onTap: onTap)
    }

    /// Clickable chig'atoy subtitle (web `ClickableSubText`: `text-[0.59rem]`, `px-2`).
    private func subLabel(_ element: Element?) -> some View {
        TappableTextLabel(element: element, font: arabicFont(9.5, weight: .regular),
                          inactiveColor: AppColor.textMuted,
                          glowRadius: 7, glowY: 4, horizontalPadding: 8,
                          activeId: activeId, onTap: onTap)
    }

    /// Web `Sep` (`border-b-2 border-dotted my-0.5`): the shared dotted rule with
    /// its `my-2` padding pulled back to `my-0.5` (8 − 6 = 2 pt each side).
    private var sep: some View {
        SectionDivider().padding(.vertical, -6)
    }
}
