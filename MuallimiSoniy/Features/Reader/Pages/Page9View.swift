import SwiftUI

/// Bespoke 1:1 renderer for book page 9 — Qof (ق, 26 elements) + Shin (ش, 24
/// elements). Ported from the web `Page9` in `RenderedPage.tsx`: same row
/// groupings, sizes, gaps, dividers and section titles.
struct Page9View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 4) {  // web: flex flex-col items-center gap-1
            // Qof (ق) — 26 element
            SectionTitle("حرف قاف", subtitle: "قاف حرفی")
            WordRow(elements: c.els(["01", "02", "03"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["04", "05", "06", "07", "08", "09"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["10", "11", "12", "13", "14", "15", "16"]),
                    size: .sm, spacing: .gap1, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["17", "18", "19", "20"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)

            SectionDivider()

            WordRow(elements: c.els(["21", "22", "23", "24", "25", "26"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)

            SectionDivider()

            // Shin (ش) — 24 element
            SectionTitle("حرف شین", subtitle: "شین حرفی")
            WordRow(elements: c.els(["27", "28", "29"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["30", "31", "32", "33", "34", "35"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["36", "37", "38", "39", "40", "41"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["42", "43", "44", "45", "46"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["47", "48", "49", "50"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }
}
