import SwiftUI

/// Bespoke 1:1 renderer for book page 12 — **Jim (ج)** then **Xo (خ)**.
///
/// Ported directly from the web `Page12` (`RenderedPage.tsx`): same row order,
/// element grouping, sizes, gaps, divider and section titles. The active token
/// is highlighted by the primitives; other elements are never dimmed.
struct Page12View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    /// Web outer container `gap-1` (0.25rem) between rows / titles / dividers.
    private let stackSpacing: CGFloat = 4

    private var content: PageContent { PageContent(elements: page.elements) }

    var body: some View {
        VStack(spacing: stackSpacing) {
            // Jim (ج) — 18 element
            SectionTitle("حرف جیم", subtitle: "جیم حرفی")
            row(["01", "02", "03"], .xxl, .gap5)
            row(["04", "05", "06", "07", "08"], .md, .gap1_5)
            row(["09", "10", "11", "12", "13", "14"], .md, .gap1_5)
            row(["15", "16", "17", "18"], .md, .gap1_5)
            SectionDivider()

            // Xo (خ) — 23 element
            SectionTitle("حرف خاء", subtitle: "خاء حرفی")
            row(["19", "20", "21"], .xxl, .gap5)
            row(["22", "23", "24", "25", "26", "27"], .md, .gap1_5)
            row(["28", "29", "30", "31", "32", "33"], .md, .gap1_5)
            row(["34", "35", "36", "37"], .md, .gap1_5)
            row(["38", "39", "40", "41"], .md, .gap1_5)
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
