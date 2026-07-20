import SwiftUI

/// Bespoke 1:1 renderer for book page 8 — Ha (ه, 21 elements) + Fa (ف, 25
/// elements). Ported from the web `Page8` in `RenderedPage.tsx`: same row
/// groupings, sizes, gaps, dividers and section titles.
struct Page8View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 4) {  // web: flex flex-col items-center gap-1
            // Ha (ه) — 21 element
            SectionTitle("حرف هاء", subtitle: "هاء حرفی")
            WordRow(elements: c.els(["01", "02", "03"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["04", "05", "06", "07", "08", "09", "10"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["11", "12", "13", "14", "15", "16"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["17", "18", "19", "20", "21"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)

            SectionDivider()

            // Fa (ف) — 25 element
            SectionTitle("حرف فاء", subtitle: "فاء حرفی")
            WordRow(elements: c.els(["22", "23", "24"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["25", "26", "27", "28", "29", "30"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["31", "32", "33", "34", "35", "36"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["37", "38", "39", "40", "41", "42"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["43", "44", "45", "46"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }
}
