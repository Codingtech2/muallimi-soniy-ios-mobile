import SwiftUI

/// Bespoke 1:1 renderer for book page 20 — "Madli so'zlar (davomi)": long verb
/// forms up top, past-verb / noun forms in the middle, and dot-less-ya (ى) mad
/// words at the bottom, split by the `YaNuqtasizRule` banner. Ports the web
/// `Page20` row-for-row; every content row renders with the mad face
/// (`mad: true`) since the syllable text already carries the mad Unicode.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page20`.
struct Page20View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-1` → 4 pt.
        VStack(spacing: 4) {
            SectionTitle("مدّی سوزلر (دوام)", subtitle: "مدلی سوزلر دوامی")
            topBlock(c)          // uzun fe'l shakllari (15)
            SectionDivider()
            midBlock(c)          // past fe'l + ism shakllari (18)
            YaNuqtasizRule()
            bottomBlock(c)       // ya-mad so'zlari (15)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Blocks

    /// Top: long verb forms ending in mad + waw (15).
    @ViewBuilder private func topBlock(_ c: PageContent) -> some View {
        madRow(c, ["01", "02", "03", "04"], .md, .gap2)
        madRow(c, ["05", "06", "07", "08"], .md, .gap2)
        madRow(c, ["09", "10", "11", "12"], .md, .gap2)
        madRow(c, ["13", "14", "15"], .md, .gap2)
    }

    /// Mid: past-verb + noun forms (dual / plural) (18).
    @ViewBuilder private func midBlock(_ c: PageContent) -> some View {
        madRow(c, ["16", "17", "18", "19", "20", "21"], .sm, .gap1_5)
        madRow(c, ["22", "23", "24", "25"], .md, .gap2)
        madRow(c, ["26", "27", "28", "29"], .md, .gap2)
        madRow(c, ["30", "31", "32", "33"], .md, .gap2)
    }

    /// Bottom: dot-less-ya mad words, below the `YaNuqtasizRule` banner (15).
    @ViewBuilder private func bottomBlock(_ c: PageContent) -> some View {
        madRow(c, ["34", "35", "36", "37", "38", "39"], .md, .gap1_5)
        madRow(c, ["40", "41", "42", "43", "44"], .md, .gap2)
        madRow(c, ["45", "46", "47", "48"], .md, .gap2)
    }

    /// One mad word row — every page-20 content row uses the mad face.
    private func madRow(_ c: PageContent, _ ids: [String],
                        _ size: ArabicSize, _ spacing: RowSpacing) -> some View {
        WordRow(elements: c.els(ids), size: size, spacing: spacing,
                mad: true, activeId: activeId, onTap: onTap)
    }
}
