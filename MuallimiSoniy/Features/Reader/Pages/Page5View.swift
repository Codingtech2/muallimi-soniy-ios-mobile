import SwiftUI

/// Bespoke 1:1 renderer for book page 5 — Ro-continuation words, then the Nun
/// (ن) and Ya (ي) letter drills. Ported from the web `Page5` in
/// `RenderedPage.tsx`: same row groupings, sizes, gaps, dividers and section
/// titles. The active element is highlighted by the primitives; others are
/// never dimmed (project UI rule).
struct Page5View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    /// Web outer container gap-1 (0.25rem) between every stacked child.
    private let stackSpacing: CGFloat = 4

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: stackSpacing) {
            // Ro davom — 9 so'z (2 qator)
            WordRow(elements: c.els(["01", "02", "03", "04", "05"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["06", "07", "08", "09"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)

            SectionDivider()

            // Nun — 20 element
            SectionTitle("حرف نون", subtitle: "نون حرفی")
            WordRow(elements: c.els(["10", "11", "12"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["13", "14", "15", "16", "17", "18"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["19", "20", "21", "22", "23", "24"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["25", "26", "27", "28", "29"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)

            SectionDivider()

            // Ya — 18 element
            SectionTitle("حرف یاء", subtitle: "یاء حرفی")
            WordRow(elements: c.els(["30", "31", "32"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["33", "34", "35", "36", "37", "38"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["39", "40", "41", "42", "43"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["44", "45", "46", "47"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }
}
