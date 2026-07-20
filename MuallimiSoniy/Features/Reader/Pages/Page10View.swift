import SwiftUI

/// Bespoke 1:1 renderer for book page 10 — Sin (س, 23 elements) + Tsa (ث, 30
/// elements). Ported from the web `Page10` in `RenderedPage.tsx`: same row
/// groupings, sizes, gaps, dividers and section titles.
struct Page10View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 4) {  // web: flex flex-col items-center gap-1
            // Sin (س) — 23 element
            SectionTitle("حرف سین", subtitle: "سین حرفی")
            WordRow(elements: c.els(["01", "02", "03"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["04", "05", "06", "07", "08"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["09", "10", "11", "12", "13", "14"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["15", "16", "17", "18", "19"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["20", "21", "22", "23"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)

            SectionDivider()

            // Tsa (ث) — 30 element
            SectionTitle("حرف ثاء", subtitle: "ثاء حرفی")
            WordRow(elements: c.els(["24", "25", "26"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["27", "28", "29", "30", "31", "32"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["33", "34", "35", "36", "37", "38"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["39", "40", "41", "42", "43"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["44", "45", "46", "47"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)

            SectionDivider()

            WordRow(elements: c.els(["48", "49", "50", "51", "52", "53"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }
}
