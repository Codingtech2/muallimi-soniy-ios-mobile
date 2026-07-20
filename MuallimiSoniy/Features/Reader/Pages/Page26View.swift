import SwiftUI

/// Bespoke 1:1 renderer for book page 26 — hamza examples (56 elements). A top
/// section of 7 numbered rows (٣–٩) plus 3 unnumbered continuation rows, a
/// dotted divider, then a bottom section of 2 rows (al-mar' / al-juz'
/// declension). Every row is a `P26NumberedRow`: a small Arabic-Indic number
/// marker pinned to the RTL-right, then the tokens spread `justify-around`
/// across the remaining width (single line, never wrapping).
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page26`
/// (+ its page-local `P26NumberedRow`).
struct Page26View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            topSection(c)
            SectionDivider()
            bottomSection(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    /// R3–R9 (numbered ٣–٩) + 3 unnumbered continuation rows (c1/c2/c3). All
    /// `sm`; every row gap-1.5 except c2 which is gap-1 (6 tokens).
    @ViewBuilder
    private func topSection(_ c: PageContent) -> some View {
        numbered(c, "٣", ["r3_w1", "r3_w2", "r3_w3", "r3_w4"], .gap1_5)
        numbered(c, "٤", ["r4_w1", "r4_w2", "r4_w3", "r4_w4"], .gap1_5)
        numbered(c, "٥", ["r5_w1", "r5_w2", "r5_w3", "r5_w4"], .gap1_5)
        numbered(c, "٦", ["r6_w1", "r6_w2", "r6_w3", "r6_w4", "r6_w5"], .gap1_5)
        numbered(c, "٧", ["r7_w1", "r7_w2", "r7_w3", "r7_w4", "r7_w5"], .gap1_5)
        numbered(c, "٨", ["r8_w1", "r8_w2", "r8_w3", "r8_w4", "r8_w5"], .gap1_5)
        numbered(c, "٩", ["r9_w1", "r9_w2", "r9_w3", "r9_w4", "r9_w5"], .gap1_5)
        numbered(c, nil, ["c1_w1", "c1_w2", "c1_w3", "c1_w4", "c1_w5"], .gap1_5)
        numbered(c, nil, ["c2_w1", "c2_w2", "c2_w3", "c2_w4", "c2_w5", "c2_w6"], .gap1)
        numbered(c, nil, ["c3_w1", "c3_w2", "c3_w3", "c3_w4", "c3_w5"], .gap1_5)
    }

    /// Bottom: al-mar' / al-juz' declension (2 rows, `md`).
    @ViewBuilder
    private func bottomSection(_ c: PageContent) -> some View {
        numbered(c, nil, ["b1_w1", "b1_w2", "b1_w3", "b1_w4"], .gap1_5, size: .md)
        numbered(c, nil, ["b2_w1", "b2_w2", "b2_w3", "b2_w4"], .gap1_5, size: .md)
    }

    private func numbered(_ c: PageContent, _ num: String?, _ ids: [String],
                          _ gap: RowSpacing, size: ArabicSize = .sm) -> some View {
        P26NumberedRow(num: num, elements: c.els(ids), size: size, gap: gap,
                       activeId: activeId, onTap: onTap)
    }
}

/// One numbered example row — a fixed 14 pt Arabic-Indic marker (`٣)`) pinned to
/// the RTL-right, then the tokens distributed evenly (`justify-around`) across
/// the rest of the width on a single, non-wrapping line. Port of the web
/// `P26NumberedRow` (`dir=rtl flex w-full items-center gap-1`).
private struct P26NumberedRow: View {
    var num: String?
    let elements: [Element]
    var size: ArabicSize = .sm
    var gap: RowSpacing = .gap1_5
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        HStack(spacing: 4) {                       // gap-1 between marker and row
            Text(num.map { "\($0))" } ?? "")
                .font(arabicFont(10, weight: .regular))  // text-[0.625rem]
                .foregroundStyle(AppColor.textMuted)
                .frame(width: 14)
                .multilineTextAlignment(.center)
            spread                                 // flex-1 justify-around
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .rightToLeft)   // marker at the right edge
    }

    /// Tokens flanked by equal spacers → evenly spread, single line, RTL.
    private var spread: some View {
        HStack(spacing: 0) {
            ForEach(elements) { e in
                Spacer(minLength: gap.value)
                ArabicElementView(element: e, size: size,
                                  isActive: activeId == e.id,
                                  onTap: { onTap(e) })
            }
            Spacer(minLength: gap.value)
        }
        .frame(maxWidth: .infinity)
    }
}
