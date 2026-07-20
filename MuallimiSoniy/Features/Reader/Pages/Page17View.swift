import SwiftUI

/// Bespoke 1:1 renderer for book page 17 — the full mad table: 28 letters ×
/// 3 mad forms (aa / ii / uu) = 84 syllables, laid out as 3 outer columns ×
/// 10 rows via `MadColumnGrid`. Topped by the `MadRule` banner (page 17 ONLY)
/// and the tappable `MadTitleBlock`, with a static `ا ي و` header row.
///
/// Every syllable renders with the mad face (`ArabicElementView(mad: true)`)
/// — the mad Unicode is already baked into `element.arabic` in `book.json`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page17`.
struct Page17View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-1` → 4 pt.
        VStack(spacing: 4) {
            MadRule(rule: c.el("intro_rule"), activeId: activeId, onTap: onTap)
            MadTitleBlock(introTitle: c.el("intro_title"), activeId: activeId, onTap: onTap)
            MadHeaderRow()                 // static ا ي و (non-tap, dotted ya)
            SectionDivider()
            MadColumnGrid(
                right: rows(Self.rightIds, c),
                middle: rows(Self.middleIds, c),
                left: rows(Self.leftIds, c),
                size: .sm,
                activeId: activeId,
                onTap: onTap
            )
        }
        .frame(maxWidth: .infinity)
    }

    /// Resolves an id-suffix column into per-row `[Element]` batches.
    private func rows(_ ids: [[String]], _ c: PageContent) -> [[Element]] {
        ids.map { c.els($0) }
    }

    // MARK: - Web column order (CLAUDE.md Mad section)
    //
    // Right column (10 rows): alef, tsa, kha, ra, sha, tho, gha, ka, na, ya
    // — the ya row (82–84) is the extra 10th row. Middle & left have 9 rows.

    private static let rightIds: [[String]] = [
        ["01", "02", "03"], ["10", "11", "12"], ["19", "20", "21"],
        ["28", "29", "30"], ["37", "38", "39"], ["46", "47", "48"],
        ["55", "56", "57"], ["64", "65", "66"], ["73", "74", "75"],
        ["82", "83", "84"]
    ]
    private static let middleIds: [[String]] = [
        ["04", "05", "06"], ["13", "14", "15"], ["22", "23", "24"],
        ["31", "32", "33"], ["40", "41", "42"], ["49", "50", "51"],
        ["58", "59", "60"], ["67", "68", "69"], ["76", "77", "78"]
    ]
    private static let leftIds: [[String]] = [
        ["07", "08", "09"], ["16", "17", "18"], ["25", "26", "27"],
        ["34", "35", "36"], ["43", "44", "45"], ["52", "53", "54"],
        ["61", "62", "63"], ["70", "71", "72"], ["79", "80", "81"]
    ]
}
