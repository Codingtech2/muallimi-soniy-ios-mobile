import SwiftUI

/// Bespoke 1:1 renderer for book page 13 — **Ha (ح)** then **G'ayn (غ)**.
///
/// Ported directly from the web `Page13` (`RenderedPage.tsx`): same row order,
/// element grouping, sizes, gaps, dividers and section titles. Row 23–28 is the
/// kha/ha comparison set sitting between two dividers. The active token is
/// highlighted by the primitives; other elements are never dimmed.
struct Page13View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    /// Web outer container `gap-1` (0.25rem) between rows / titles / dividers.
    private let stackSpacing: CGFloat = 4

    private var content: PageContent { PageContent(elements: page.elements) }

    var body: some View {
        VStack(spacing: stackSpacing) {
            // Ha (ح) — 28 element: 3 header + 6 + 5 + 4 + 4 + 6 taqqoslash
            SectionTitle("حرف حاء", subtitle: "حاء حرفی")
            row(["01", "02", "03"], .xxl, .gap5)
            row(["04", "05", "06", "07", "08", "09"], .md, .gap1_5)
            row(["10", "11", "12", "13", "14"], .md, .gap1_5)
            row(["15", "16", "17", "18"], .md, .gap1_5)
            row(["19", "20", "21", "22"], .md, .gap1_5)
            SectionDivider()

            // Taqqoslash: خَلْقُ-حَلْقُ، خَتْمُ-حَتْمُ، اَرْخَمْ-اَرْحَمْ
            row(["23", "24", "25", "26", "27", "28"], .md, .gap1_5)
            SectionDivider()

            // G'ayn (غ) — 18 element: 3 header + 6 + 5 + 4
            SectionTitle("حرف غین", subtitle: "غین حرفی")
            row(["29", "30", "31"], .xxl, .gap5)
            row(["32", "33", "34", "35", "36", "37"], .md, .gap1_5)
            row(["38", "39", "40", "41", "42"], .md, .gap1_5)
            row(["43", "44", "45", "46"], .md, .gap1_5)
        }
        .frame(maxWidth: .infinity)
    }

    /// One RTL wrapping row of the elements matching `ids` (by id suffix).
    private func row(_ ids: [String], _ size: ArabicSize, _ spacing: RowSpacing) -> some View {
        WordRow(
            elements: content.els(ids),
            size: size,
            spacing: spacing,
            activeId: activeId,
            onTap: onTap
        )
    }
}
