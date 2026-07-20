import SwiftUI

/// Bespoke 1:1 renderer for book page 24 — the tanvin alphabet drill (28 letters
/// × 3 forms = 84 syllables) followed by 30 example words. Three blocks of three
/// wrapping rows each (fatha `-an` / kasra `-in` / damma `-un`), separated by
/// tight dotted rules, then a five-row word grid.
///
/// Every token is `size="sm"`; the alphabet rows use `gap-1`, the word rows
/// `gap-1.5`. The tanvin Unicode is already baked into `element.arabic`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page24`.
struct Page24View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            block(c, base: 1)        // fatha tanvin (-an): r1–r3
            DottedSep()
            block(c, base: 4)        // kasra tanvin (-in): r4–r6
            DottedSep()
            block(c, base: 7)        // damma tanvin (-un): r7–r9
            DottedSep()
            wordSection(c)           // 30 words → 5 rows of 6
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Blocks

    /// One tanvin block = three alphabet rows (9 / 10 / 9 syllables). The letter
    /// index continues across the block (01–09, 10–19, 20–28), matching the web
    /// id suffixes `r{row}_{NN}`.
    @ViewBuilder
    private func block(_ c: PageContent, base row: Int) -> some View {
        alphaRow(c, row, 1...9)
        alphaRow(c, row + 1, 10...19)
        alphaRow(c, row + 2, 20...28)
    }

    private func alphaRow(_ c: PageContent, _ row: Int, _ nums: ClosedRange<Int>) -> some View {
        WordRow(
            elements: c.els(nums.map { "r\(row)_\(Self.pad2($0))" }),
            size: .sm, spacing: .gap1,
            activeId: activeId, onTap: onTap
        )
    }

    /// The 30 example words (`w01`…`w30`) in five rows of six.
    @ViewBuilder
    private func wordSection(_ c: PageContent) -> some View {
        ForEach(0..<5, id: \.self) { line in
            WordRow(
                elements: c.els((1...6).map { "w\(Self.pad2(line * 6 + $0))" }),
                size: .sm, spacing: .gap1_5,
                activeId: activeId, onTap: onTap
            )
        }
    }

    /// Zero-pads to two digits (`3` → `"03"`) — element ids use `NN` suffixes.
    private static func pad2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
}

// MARK: - Page-local tight dotted rule

/// Port of the web page-24 `Sep` (`border-b-2 border-dotted border-white/10
/// my-1`) — a hairline dotted divider with a tight 4 pt gutter, denser than the
/// shared `SectionDivider` (my-2) so the 114 elements fit one viewport.
private struct DottedSep: View {
    var verticalPadding: CGFloat = 4   // my-1

    var body: some View {
        DottedRule()
            .stroke(
                AppColor.divider,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 4])
            )
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
    }
}

private struct DottedRule: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
