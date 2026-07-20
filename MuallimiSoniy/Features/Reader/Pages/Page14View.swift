import SwiftUI

/// Bespoke 1:1 renderer for book page 14 — Ayn (ع, 27 elements) then Dal
/// (د, 23 elements). Ports the web `Page14` row-for-row: the same element
/// groupings, `WordRow` sizes/gaps, `SectionTitle`s and `SectionDivider`s.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page14`.
struct Page14View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-1` → 4 pt.
        VStack(spacing: 4) {
            // Ayn (ع) — 27 element
            SectionTitle("حرف عین", subtitle: "عین حرفی")
            WordRow(elements: c.els(["01", "02", "03"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["04", "05", "06", "07", "08", "09", "10"]),
                    size: .sm, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["11", "12", "13", "14", "15", "16"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["17", "18", "19", "20", "21"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            SectionDivider()
            WordRow(elements: c.els(["22", "23", "24", "25", "26", "27"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            SectionDivider()

            // Dal (د) — 23 element
            SectionTitle("حرف دال", subtitle: "دال حرفی")
            WordRow(elements: c.els(["28", "29", "30"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["31", "32", "33", "34", "35", "36"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["37", "38", "39", "40", "41", "42"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["43", "44", "45", "46"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["47", "48", "49", "50"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }
}
