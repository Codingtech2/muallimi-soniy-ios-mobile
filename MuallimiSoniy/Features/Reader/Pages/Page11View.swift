import SwiftUI

/// Bespoke 1:1 renderer for book page 11 — **Sod (ص)** then **Tho (ط)**.
///
/// Ported directly from the web `Page11` (`RenderedPage.tsx`): same row order,
/// element grouping, sizes, gaps, dividers and section titles. The active token
/// is highlighted by the primitives; other elements are never dimmed.
struct Page11View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    /// Web outer container `gap-1` (0.25rem) between rows / titles / dividers.
    private let stackSpacing: CGFloat = 4

    private var content: PageContent { PageContent(elements: page.elements) }

    var body: some View {
        VStack(spacing: stackSpacing) {
            // Sod (ص) — 20 element
            SectionTitle("حرف صاد", subtitle: "صاد حرفی")
            row(["01", "02", "03"], .xxl, .gap5)
            row(["04", "05", "06", "07", "08", "09", "10"], .sm, .gap1_5)
            row(["11", "12", "13", "14"], .md, .gap1_5)
            SectionDivider()
            row(["15", "16", "17", "18", "19", "20"], .md, .gap1_5)
            SectionDivider()

            // Tho (ط) — 29 element
            SectionTitle("حرف طاء", subtitle: "طاء حرفی")
            row(["21", "22", "23"], .xxl, .gap5)
            row(["24", "25", "26", "27", "28", "29"], .md, .gap1_5)
            row(["30", "31", "32", "33", "34", "35"], .md, .gap1_5)
            row(["36", "37", "38", "39"], .md, .gap1_5)
            row(["40", "41", "42", "43"], .md, .gap1_5)
            SectionDivider()
            row(["44", "45", "46", "47", "48", "49"], .md, .gap1_5)
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
