import SwiftUI

/// Bespoke 1:1 renderer for book page 15 — Dod (ض, 25 elements: header + rows +
/// comparison pairs) then Zal (ذ, 29 elements). Ports the web `Page15`
/// row-for-row.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page15`.
/// Note: the web `gap-0.5` rows map to the nearest `RowSpacing` bucket, `.gap1`
/// (the shared enum has no half-step); the row groupings are preserved exactly.
struct Page15View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-1` → 4 pt.
        VStack(spacing: 4) {
            // Dod (ض) — 25 element: 3 header + 6 + 6 + 4 + 6 taqqoslash
            SectionTitle("حرف ضاد", subtitle: "ضاد حرفی")
            WordRow(elements: c.els(["01", "02", "03"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["04", "05", "06", "07", "08", "09"]),
                    size: .sm, spacing: .gap1, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["10", "11", "12", "13", "14", "15"]),
                    size: .sm, spacing: .gap1, activeId: activeId, onTap: onTap)  // web gap-0.5
            WordRow(elements: c.els(["16", "17", "18", "19"]),
                    size: .sm, spacing: .gap1, activeId: activeId, onTap: onTap)
            SectionDivider()
            // Taqqoslash: دَرْسُ-ضَرْسُ، وَدْعُ-وَضْعُ، بَعْدُ-بَعْضُ
            WordRow(elements: c.els(["20", "21", "22", "23", "24", "25"]),
                    size: .sm, spacing: .gap1, activeId: activeId, onTap: onTap)
            SectionDivider()

            // Zal (ذ) — 29 element: 3 header + 8 + 6 + 6 + 6 taqqoslash
            SectionTitle("حرف ذال", subtitle: "ذال حرفی")
            WordRow(elements: c.els(["26", "27", "28"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["29", "30", "31", "32", "33", "34", "35", "36"]),
                    size: .sm, spacing: .gap1, activeId: activeId, onTap: onTap)  // web gap-0.5
            WordRow(elements: c.els(["37", "38", "39", "40", "41", "42"]),
                    size: .sm, spacing: .gap1, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["43", "44", "45", "46", "47", "48"]),
                    size: .sm, spacing: .gap1, activeId: activeId, onTap: onTap)
            SectionDivider()
            // Taqqoslash: ذِفْرُ-زِفْرُ، بَذْلُ-بَزْلُ، اَبْذَلُ-اَبْزَلُ
            WordRow(elements: c.els(["49", "50", "51", "52", "53", "54"]),
                    size: .sm, spacing: .gap1, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }
}
