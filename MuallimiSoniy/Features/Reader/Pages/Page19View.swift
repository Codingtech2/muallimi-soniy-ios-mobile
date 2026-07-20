import SwiftUI

/// Bespoke 1:1 renderer for book page 19 — mad **words** (71 elements in 12
/// wrapping rows). A top section of 9 rows, a dotted divider, then a bottom
/// section of 3 verb-form rows. NO `MadRule` (shown only on page 17). Every
/// token renders with the mad face via `WordRow(mad:)`; the mad Unicode is
/// already baked into `element.arabic`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page19`.
struct Page19View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            SectionTitle("مدّی سوزلر", subtitle: "مدلی سوزلر")
            topSection(c)
            SectionDivider()
            bottomSection(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    /// R1–R9 (word counts 6-6-7-7-6-6-6-6-6; sizes md/md/sm×5/md/md).
    @ViewBuilder
    private func topSection(_ c: PageContent) -> some View {
        madRow(c, ["01", "02", "03", "04", "05", "06"], .md)
        madRow(c, ["07", "08", "09", "10", "11", "12"], .md)
        madRow(c, ["13", "14", "15", "16", "17", "18", "19"], .sm)
        madRow(c, ["20", "21", "22", "23", "24", "25", "26"], .sm)
        madRow(c, ["27", "28", "29", "30", "31", "32"], .sm)
        madRow(c, ["33", "34", "35", "36", "37", "38"], .sm)
        madRow(c, ["39", "40", "41", "42", "43", "44"], .sm)
        madRow(c, ["45", "46", "47", "48", "49", "50"], .md)
        madRow(c, ["51", "52", "53", "54", "55", "56"], .md)
    }

    /// R10–R12 — verb forms (word counts 6-5-4; sizes md/sm/sm).
    @ViewBuilder
    private func bottomSection(_ c: PageContent) -> some View {
        madRow(c, ["57", "58", "59", "60", "61", "62"], .md)
        madRow(c, ["63", "64", "65", "66", "67"], .sm)
        madRow(c, ["68", "69", "70", "71"], .sm)
    }

    /// One wrapping RTL mad-word row (web `MadWordRow`: `WordRow` + `mad`, gap
    /// `clamp(…,0.375rem)` → `.gap1_5`).
    private func madRow(_ c: PageContent, _ ids: [String], _ size: ArabicSize) -> some View {
        WordRow(
            elements: c.els(ids),
            size: size,
            spacing: .gap1_5,
            mad: true,
            activeId: activeId,
            onTap: onTap
        )
    }
}
