import SwiftUI

/// Bespoke 1:1 renderer for book page 6 — the Ba (ب) and Kaf (ك) letter drills.
/// Ported from the web `Page6` in `RenderedPage.tsx`: same row groupings, sizes,
/// gaps, dividers and section titles. The active element is highlighted by the
/// primitives; others are never dimmed (project UI rule).
struct Page6View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    /// Web outer container gap-1 (0.25rem) between every stacked child.
    private let stackSpacing: CGFloat = 4

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: stackSpacing) {
            // Ba — 18 element
            SectionTitle("حرف باء", subtitle: "باء حرفی")
            WordRow(elements: c.els(["01", "02", "03"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["04", "05", "06", "07", "08", "09"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["10", "11", "12", "13", "14"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["15", "16", "17", "18"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)

            SectionDivider()

            // Kaf — 21 element
            SectionTitle("حرف كاف", subtitle: "کاف حرفی")
            WordRow(elements: c.els(["19", "20", "21"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["22", "23", "24", "25"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["26", "27", "28", "29", "30"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["31", "32", "33", "34", "35"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["36", "37", "38", "39"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }
}
