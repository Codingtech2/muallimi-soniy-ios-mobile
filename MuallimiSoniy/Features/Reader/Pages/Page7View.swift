import SwiftUI

/// Bespoke 1:1 renderer for book page 7 — the Lam (ل) and Vav (و) letter drills.
/// Ported from the web `Page7` in `RenderedPage.tsx`: same row groupings, sizes,
/// gaps, dividers and section titles. The active element is highlighted by the
/// primitives; others are never dimmed (project UI rule).
struct Page7View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    /// Web outer container gap-1 (0.25rem) between every stacked child.
    private let stackSpacing: CGFloat = 4

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: stackSpacing) {
            // Lam — 26 element
            SectionTitle("حرف لام", subtitle: "لام حرفی")
            WordRow(elements: c.els(["01", "02", "03"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["04", "05", "06", "07", "08", "09"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["10", "11", "12", "13", "14", "15"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["16", "17", "18", "19", "20", "21"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["22", "23", "24", "25", "26"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)

            SectionDivider()

            // Vav — 23 element
            SectionTitle("حرف واو", subtitle: "واو حرفی")
            WordRow(elements: c.els(["27", "28", "29"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["30", "31", "32", "33"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["34", "35", "36", "37", "38", "39"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["40", "41", "42", "43", "44", "45"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["46", "47", "48", "49"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }
}
