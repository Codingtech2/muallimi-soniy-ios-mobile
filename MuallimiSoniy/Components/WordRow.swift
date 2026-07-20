import SwiftUI

/// A horizontally-wrapping, right-to-left row of `ArabicElementView`s — the
/// SwiftUI port of the web `Row` (`flex w-full flex-row-reverse flex-wrap
/// justify-center gap-*`).
///
/// Reading order is RTL: the first element sits at the right of the first line,
/// subsequent elements flow leftward and wrap onto centred new lines. The active
/// element's scale-up is a render transform only, so highlighting a token never
/// reflows the row.
struct WordRow: View {
    let elements: [Element]
    var size: ArabicSize = .xl
    var spacing: RowSpacing = .gap3
    /// Mad pages: forward the mad face to every token.
    var mad: Bool = false
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        FlowLayout(spacing: spacing.value, lineSpacing: spacing.value) {
            ForEach(elements) { element in
                ArabicElementView(
                    element: element,
                    size: size,
                    mad: mad,
                    isActive: activeId == element.id,
                    onTap: { onTap(element) }
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// A greedy line-breaking layout that centres each line and lays items out
/// right-to-left (first subview rightmost), reproducing CSS `flex-row-reverse
/// flex-wrap justify-center`. Line breaks are decided by accumulated width, the
/// same way flexbox wraps regardless of main-axis direction.
struct FlowLayout: Layout {
    var spacing: CGFloat = 12
    var lineSpacing: CGFloat = 12
    /// `true` → first subview is placed at the right edge of its line (RTL).
    var isRTL: Bool = true

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = finiteWidth(proposal.width)
        let rows = rows(maxWidth: maxWidth, subviews: subviews)
        var height: CGFloat = 0
        for (index, row) in rows.enumerated() {
            height += rowHeight(row, subviews)
            if index < rows.count - 1 { height += lineSpacing }
        }
        // Fill the offered width when finite; otherwise hug the widest line.
        let width = proposal.width ?? rows.map { lineWidth($0, subviews) }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = rows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let height = rowHeight(row, subviews)
            let total = lineWidth(row, subviews)
            let startX = bounds.minX + (bounds.width - total) / 2  // justify-center

            if isRTL {
                var x = startX + total
                for index in row {
                    let itemSize = subviews[index].sizeThatFits(.unspecified)
                    x -= itemSize.width
                    subviews[index].place(
                        at: CGPoint(x: x, y: y + (height - itemSize.height) / 2),
                        proposal: ProposedViewSize(itemSize)
                    )
                    x -= spacing
                }
            } else {
                var x = startX
                for index in row {
                    let itemSize = subviews[index].sizeThatFits(.unspecified)
                    subviews[index].place(
                        at: CGPoint(x: x, y: y + (height - itemSize.height) / 2),
                        proposal: ProposedViewSize(itemSize)
                    )
                    x += itemSize.width + spacing
                }
            }
            y += height + lineSpacing
        }
    }

    // MARK: - Line breaking

    /// Groups subview indices into lines that each fit within `maxWidth`.
    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [[Int]] {
        var rows: [[Int]] = []
        var current: [Int] = []
        var x: CGFloat = 0
        for index in subviews.indices {
            let width = subviews[index].sizeThatFits(.unspecified).width
            let advance = current.isEmpty ? width : width + spacing
            if !current.isEmpty, x + advance > maxWidth {
                rows.append(current)
                current = [index]
                x = width
            } else {
                current.append(index)
                x += advance
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    private func lineWidth(_ row: [Int], _ subviews: Subviews) -> CGFloat {
        guard !row.isEmpty else { return 0 }
        let widths = row.reduce(0) { $0 + subviews[$1].sizeThatFits(.unspecified).width }
        return widths + spacing * CGFloat(row.count - 1)
    }

    private func rowHeight(_ row: [Int], _ subviews: Subviews) -> CGFloat {
        row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
    }

    private func finiteWidth(_ width: CGFloat?) -> CGFloat {
        guard let width, width.isFinite else { return .greatestFiniteMagnitude }
        return width
    }
}

#if DEBUG
#Preview("WordRow") {
    let row = (0..<6).map { index in
        Element(
            id: "w\(index)", type: .soz, arabic: ["بَا", "تَا", "ثَا", "جَا", "حَا", "خَا"][index],
            uzbek: "", audioUrl: nil, start: 0, end: 0, x: 0, y: 0, width: 0, height: 0
        )
    }
    return WordRow(elements: row, size: .xl, spacing: .gap3, activeId: "w2", onTap: { _ in })
        .padding(24)
        .frame(width: 340)
        .background(AppColor.background)
}
#endif
