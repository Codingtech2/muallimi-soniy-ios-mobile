import SwiftUI

/// Bespoke 1:1 renderer for book page 18 — the mad **practice** grid: page 17's
/// syllables shuffled into a 3-column × 9-row layout (3 mad syllables per cell).
/// NO `MadRule` and no header row here — the preamble banner and `ا ي و` header
/// are shown only on page 17. A tappable chig'atoy-Turkic footnote (the "master
/// every letter's mad flawlessly before moving on" advice) sits below the grid.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page18`.
struct Page18View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-1` → 4 pt.
        VStack(spacing: 4) {
            MadColumnGrid(
                right: col(c, Self.rightRows),
                middle: col(c, Self.middleRows),
                left: col(c, Self.leftRows),
                size: .sm,
                activeId: activeId,
                onTap: onTap
            )
            madOutro(c.el("outro"))
                .padding(.top, 8)   // web `mt-2` on the footnote
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footnote

    @ViewBuilder
    private func madOutro(_ element: Element?) -> some View {
        if let element {
            MadOutroButton(
                element: element,
                isActive: activeId == element.id,
                onTap: { onTap(element) }
            )
        } else {
            Text(Self.outroFallback)
                .font(arabicFont(11, weight: .regular))
                .foregroundStyle(AppColor.textMuted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
                .padding(.horizontal, 12)   // web `mx-3`
        }
    }

    /// Maps each column's rows of id-suffixes to their `Element`s (one inner
    /// `[Element]` per visual cell of 3 mad syllables).
    private func col(_ c: PageContent, _ rows: [[String]]) -> [[Element]] {
        rows.map { c.els($0) }
    }

    // MARK: - Grid ids (RTL outer order: right, middle, left) — 9 rows × 3

    private static let rightRows: [[String]] = [
        ["01", "02", "03"], ["10", "11", "12"], ["19", "20", "21"],
        ["28", "29", "30"], ["37", "38", "39"], ["46", "47", "48"],
        ["55", "56", "57"], ["64", "65", "66"], ["73", "74", "75"]
    ]
    private static let middleRows: [[String]] = [
        ["04", "05", "06"], ["13", "14", "15"], ["22", "23", "24"],
        ["31", "32", "33"], ["40", "41", "42"], ["49", "50", "51"],
        ["58", "59", "60"], ["67", "68", "69"], ["76", "77", "78"]
    ]
    private static let leftRows: [[String]] = [
        ["07", "08", "09"], ["16", "17", "18"], ["25", "26", "27"],
        ["34", "35", "36"], ["43", "44", "45"], ["52", "53", "54"],
        ["61", "62", "63"], ["70", "71", "72"], ["79", "80", "81"]
    ]

    /// Static fallback shown when the tappable `outro` element is absent
    /// (mirrors the web `<p>` fallback branch, verbatim).
    private static let outroFallback =
        "اوشبو درسده يازيلگان حرفلرنينگ هر قايسيسي خطاسيز مد قيلينماگونچه كيينگي درسلر كورسه تلميذي"
}

/// The tappable footnote button under page 18's grid — the advice text plus a
/// "listen" pill, playing its own audio chunk. Extracted so it re-renders only
/// on its own active-state change, keeping `Page18View.body` small.
private struct MadOutroButton: View {
    let element: Element
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(element.arabic)   // same advice text, baked into book.json
                    .font(arabicFont(11, weight: .regular))
                    .foregroundStyle(AppColor.textMuted)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .rightToLeft)
                MadListenPill()
            }
            .padding(.horizontal, 12)   // px-3
            .padding(.vertical, 8)      // py-2
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? AppColor.primary.opacity(0.12) : .clear)
            )
            .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)   // web `mx-3`
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }
}
