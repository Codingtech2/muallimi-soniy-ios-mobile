import SwiftUI

/// Bespoke 1:1 renderer for book page 27 — Ta-marbuta (`ة ـة = ت`) up top, then
/// the three Muqaddara sub-blocks (Alif / Yā / Vāv — silent letters that are
/// written but not spelled). 49 elements. Section headings are the tappable
/// `BlockTitle` (they play the narration chunk); the R3 singular/plural pairs
/// use the page-local `PairRow` (word — word, comma-separated).
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page27`
/// (+ its page-local `BlockTitle` and `PairRow`).
struct Page27View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0` → 0 pt.
        VStack(spacing: 0) {
            taMarbutaSection(c)
            SectionDivider()
            muqaddaraSection(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Ta-marbuta (top)

    /// `ة ـة = ت` heading + two `-atun` rows + the singular/plural pair row.
    @ViewBuilder
    private func taMarbutaSection(_ c: PageContent) -> some View {
        blockTitle(c, "head")
        row(c, ["r1_w1", "r1_w2", "r1_w3", "r1_w4", "r1_w5"], .gap1_5)
        row(c, ["r2_w1", "r2_w2", "r2_w3", "r2_w4", "r2_w5"], .gap1_5)
        PairRow(
            pairs: [(c.el("r3_w1"), c.el("r3_w2")),
                    (c.el("r3_w3"), c.el("r3_w4")),
                    (c.el("r3_w5"), c.el("r3_w6"))],
            activeId: activeId, onTap: onTap
        )
    }

    // MARK: - Muqaddara (bottom)

    /// Subtitle heading + the Alif / Yā / Vāv Muqaddara blocks.
    @ViewBuilder
    private func muqaddaraSection(_ c: PageContent) -> some View {
        blockTitle(c, "subtitle")
        alifBlock(c)
        yaBlock(c)
        vavBlock(c)
    }

    @ViewBuilder
    private func alifBlock(_ c: PageContent) -> some View {
        blockTitle(c, "alif_intro")
        row(c, ["alif_r1_w1", "alif_r1_w2", "alif_r1_w3", "alif_r1_w4"], .gap1_5)
        row(c, ["alif_r2_w1", "alif_r2_w2", "alif_r2_w3", "alif_r2_w4", "alif_r2_w5"], .gap1_5)
        row(c, ["alif_r3_w1", "alif_r3_w2", "alif_r3_w3", "alif_r3_w4", "alif_r3_w5"], .gap1)
    }

    @ViewBuilder
    private func yaBlock(_ c: PageContent) -> some View {
        blockTitle(c, "ya_intro")
        row(c, ["ya_r1_w1", "ya_r1_w2", "ya_r1_w3", "ya_r1_w4", "ya_r1_w5"], .gap1_5)
    }

    @ViewBuilder
    private func vavBlock(_ c: PageContent) -> some View {
        blockTitle(c, "vav_intro")
        row(c, ["vav_r1_w1", "vav_r1_w2", "vav_r1_w3", "vav_r1_w4", "vav_r1_w5"], .gap1_5)
        row(c, ["vav_r2_w1", "vav_r2_w2", "vav_r2_w3", "vav_r2_w4"], .gap2)
    }

    // MARK: - Helpers

    private func blockTitle(_ c: PageContent, _ suffix: String) -> some View {
        BlockTitle(element: c.el(suffix), activeId: activeId, onTap: onTap)
    }

    private func row(_ c: PageContent, _ ids: [String], _ gap: RowSpacing) -> some View {
        WordRow(elements: c.els(ids), size: .sm, spacing: gap,
                activeId: activeId, onTap: onTap)
    }
}

// MARK: - Page-local sub-views

/// A tappable section heading that plays its narration chunk. Active → primary
/// fill + white glyph + green glow. Renders nothing when the element is absent.
/// Port of the web `BlockTitle` (`element-spring rounded-md px-3 py-0 mt-0.5`,
/// `h3 text-[0.8125rem] font-bold`).
private struct BlockTitle: View {
    let element: Element?
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        if let element {
            let isActive = activeId == element.id
            Button { onTap(element) } label: {
                Text(element.arabic)
                    .font(arabicFont(13, weight: .bold))     // text-[0.8125rem] font-bold
                    .foregroundStyle(isActive ? Color.white : AppColor.textSecondary)
                    .padding(.horizontal, 12)                // px-3 (py-0)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)  // rounded-md
                            .fill(isActive ? AppColor.primary : Color.clear)
                    )
                    .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)                                // mt-0.5
            .environment(\.layoutDirection, .rightToLeft)
            .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
        }
    }
}

/// The R3 singular/plural pair row: each pair is `word — word`, and pairs are
/// separated by a muted `،`. Wraps + centres RTL like a `WordRow`. Port of the
/// web `PairRow`.
private struct PairRow: View {
    let pairs: [(Element?, Element?)]
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {   // outer gap clamp max 0.5rem
            ForEach(Array(pairs.enumerated()), id: \.offset) { index, pair in
                if let a = pair.0, let b = pair.1 {
                    cell(a, b, showComma: index < pairs.count - 1)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// One `a — b` cell (RTL: `a` rightmost), with a trailing `،` between pairs.
    private func cell(_ a: Element, _ b: Element, showComma: Bool) -> some View {
        HStack(spacing: 4) {                       // inner gap clamp max 0.25rem
            token(a)
            Text("—")
                .font(.system(size: 12))
                .foregroundStyle(AppColor.textMuted)
                .opacity(0.7)
            token(b)
            if showComma {
                Text("،")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColor.textMuted)
                    .opacity(0.6)
                    .padding(.horizontal, 2)       // mx-0.5
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func token(_ e: Element) -> some View {
        ArabicElementView(element: e, size: .sm,
                          isActive: activeId == e.id,
                          onTap: { onTap(e) })
    }
}
