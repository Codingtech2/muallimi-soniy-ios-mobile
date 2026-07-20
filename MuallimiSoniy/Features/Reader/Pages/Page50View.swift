import SwiftUI

/// Bespoke 1:1 renderer for book page 50 — Du'a al-Qunut (the book's last page,
/// user-facing "52 / 52"). An ornamented, tappable title (دُعَاءُ الْقُنُوتِ)
/// over a flowing right-to-left paragraph: the seven semantic clauses (`02`–`08`)
/// read as one continuous dua, each an inline tappable pill separated by a muted
/// `·`. No audio: tapping a clause only shows the shared green highlight.
///
/// The paragraph flows via the page-local `QunutFlow` layout, which measures each
/// pill against the full column width so a long clause wraps *inside* its own
/// pill instead of overflowing — reproducing the web `<p dir="rtl">` inline flow.
/// Per the project rule, an inactive clause is never dimmed.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page50`.
struct Page50View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    private static let phraseIds = ["02", "03", "04", "05", "06", "07", "08"]

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-3` → 12 pt.
        VStack(spacing: 12) {
            QunutTitle(title: c.el("01"), activeId: activeId, onTap: onTap)
            QunutParagraph(phrases: c.els(Self.phraseIds), activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Page-local sub-views

/// The ornamented, tappable title: `❀  دُعَاءُ الْقُنُوتِ  ❀` — the green title
/// pill (web `text-secondary`, active → primary fill) flanked by muted flowers.
private struct QunutTitle: View {
    let title: Element?
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        if let title {
            HStack(spacing: 12) {   // gap-3
                Ornament()
                TappableTextLabel(
                    element: title, font: arabicFont(22),
                    inactiveColor: AppColor.textSecondary, horizontalPadding: 12,
                    activeId: activeId, onTap: onTap
                )
                Ornament()
            }
            .padding(.top, 4)   // mt-1
        }
    }
}

/// The flowing dua paragraph: clause pills interleaved with `·` separators, laid
/// out RTL by `QunutFlow` (right-aligned, wrap-aware).
private struct QunutParagraph: View {
    let phrases: [Element]
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        QunutFlow(hSpacing: 2, lineSpacing: 10) {
            ForEach(Array(phrases.enumerated()), id: \.element.id) { index, phrase in
                TappableTextLabel(
                    element: phrase, font: arabicFont(17),
                    inactiveColor: AppColor.textMain, horizontalPadding: 6,
                    activeId: activeId, onTap: onTap
                )
                if index < phrases.count - 1 { Separator() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)   // px-1
    }
}

/// A small muted `❀` title ornament (web `text-xs opacity-60`).
private struct Ornament: View {
    var body: some View {
        Text("❀")
            .font(.system(size: 12))
            .foregroundStyle(AppColor.textMuted)
            .opacity(0.6)
    }
}

/// The `·` between two clauses (web muted dot, `opacity-50`).
private struct Separator: View {
    var body: some View {
        Text("·")
            .font(arabicFont(17, weight: .regular))
            .foregroundStyle(AppColor.textMuted)
            .opacity(0.5)
    }
}

// MARK: - Wrap-aware RTL flow

/// A right-to-left, right-aligned wrapping flow — the SwiftUI port of the web
/// flowing `<p>`. Unlike the shared `FlowLayout` (which measures items at their
/// intrinsic single-line width and so can't wrap an over-wide item), `QunutFlow`
/// measures every subview against the available column width. A short clause
/// reports a narrow single-line size and flows inline with the `·` separators; a
/// long clause reports a near-full width with a multi-line height and wraps
/// *inside* its own pill, taking its own line. Reading order is RTL: the first
/// subview sits at the right edge.
private struct QunutFlow: Layout {
    var hSpacing: CGFloat = 2
    var lineSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? 10_000
        let sizes = measure(subviews, maxWidth: maxWidth)
        let rows = pack(sizes, maxWidth: maxWidth)
        var height: CGFloat = 0
        for (index, row) in rows.enumerated() {
            height += row.map { sizes[$0].height }.max() ?? 0
            if index < rows.count - 1 { height += lineSpacing }
        }
        return CGSize(width: proposal.width ?? rowsWidth(rows, sizes), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let sizes = measure(subviews, maxWidth: bounds.width)
        let rows = pack(sizes, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { sizes[$0].height }.max() ?? 0
            var x = bounds.maxX   // RTL: start at the right edge, flow left
            for index in row {
                let size = sizes[index]
                x -= size.width
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x -= hSpacing
            }
            y += rowHeight + lineSpacing
        }
    }

    // MARK: Helpers

    /// Measures each subview against the column width, so over-wide pills report
    /// their wrapped (multi-line, ≤ `maxWidth`) size.
    private func measure(_ subviews: Subviews, maxWidth: CGFloat) -> [CGSize] {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil)) }
    }

    /// Greedy line-breaking on the measured widths; a pill measured near the full
    /// width naturally lands on its own line.
    private func pack(_ sizes: [CGSize], maxWidth: CGFloat) -> [[Int]] {
        var rows: [[Int]] = []
        var current: [Int] = []
        var x: CGFloat = 0
        for index in sizes.indices {
            let width = sizes[index].width
            let advance = current.isEmpty ? width : width + hSpacing
            if !current.isEmpty, x + advance > maxWidth + 0.5 {
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

    private func rowsWidth(_ rows: [[Int]], _ sizes: [CGSize]) -> CGFloat {
        rows.map { row in
            row.reduce(0) { $0 + sizes[$1].width } + hSpacing * CGFloat(max(0, row.count - 1))
        }.max() ?? 0
    }
}
