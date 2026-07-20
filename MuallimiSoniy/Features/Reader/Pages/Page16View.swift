import SwiftUI

/// Bespoke 1:1 renderer for book page 16 — Zo (ظ, 49 elements: header + six
/// practice rows + two comparison rows). Ports the web `Page16` row-for-row.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page16`.
struct Page16View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-1` → 4 pt.
        VStack(spacing: 4) {
            // Zo (ظ) — 49 element
            SectionTitle("حرف ظاء", subtitle: "ظاء حرفی")
            WordRow(elements: c.els(["01", "02", "03"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["04", "05", "06", "07", "08", "09"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["10", "11", "12", "13", "14", "15"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["16", "17", "18", "19", "20", "21"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["22", "23", "24", "25", "26", "27"]),
                    size: .sm, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["28", "29", "30", "31", "32", "33"]),
                    size: .sm, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["34", "35", "36", "37"]),
                    size: .sm, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            SectionDivider()
            // Taqqoslash qatori — 12 so'z, 6 juftlik (ذ/ظ, ح-ظ/ح-ض, ظ/ض va ز/ظ)
            WordRow(elements: c.els(["38", "39", "40", "41", "42", "43"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["44", "45", "46", "47", "48", "49"]),
                    size: .md, spacing: .gap1_5, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }
}
