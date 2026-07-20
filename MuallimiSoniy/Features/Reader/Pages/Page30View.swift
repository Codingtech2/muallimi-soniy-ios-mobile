import SwiftUI

/// Bespoke 1:1 renderer for book page 30 — the tail of the alif-lom vasl
/// examples plus the start of the Vasl (وصل) topic. A tappable chig'atoy
/// narration banner, six RTL example rows (word counts 4-3-3-4-4-3), a dotted
/// divider, the tappable "وصل" title, a second narration banner, four two-word
/// vasl rows, and a static reading-note footnote.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page30`.
struct Page30View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-1.5 w-full` → 6 pt.
        VStack(spacing: 6) {
            NarrationBanner(rule: c.el("top_header"), fontSize: 10.5,
                            activeId: activeId, onTap: onTap)
            topRows(c)
            SectionDivider()
            VaslTitleButton(title: c.el("vasl_title"), activeId: activeId, onTap: onTap)
            NarrationBanner(rule: c.el("vasl_rule"), fontSize: 10,
                            activeId: activeId, onTap: onTap)
            bottomRows(c)
            footnote
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rows

    /// TOP: 6 alif-lom vasl example rows (`size="sm"`, `gap-1.5`).
    @ViewBuilder private func topRows(_ c: PageContent) -> some View {
        vaslRow(c, ["r1_w1", "r1_w2", "r1_w3", "r1_w4"])
        vaslRow(c, ["r2_w1", "r2_w2", "r2_w3"])
        vaslRow(c, ["r3_w1", "r3_w2", "r3_w3"])
        vaslRow(c, ["r4_w1", "r4_w2", "r4_w3", "r4_w4"])
        vaslRow(c, ["r5_w1", "r5_w2", "r5_w3", "r5_w4"])
        vaslRow(c, ["r6_w1", "r6_w2", "r6_w3"])
    }

    /// BOTTOM: 4 two-word vasl rows (`size="sm"`, `gap-2`).
    @ViewBuilder private func bottomRows(_ c: PageContent) -> some View {
        ForEach(1...4, id: \.self) { i in
            WordRow(elements: c.els(["b\(i)_w1", "b\(i)_w2"]),
                    size: .sm, spacing: .gap2, activeId: activeId, onTap: onTap)
        }
    }

    private func vaslRow(_ c: PageContent, _ ids: [String]) -> some View {
        WordRow(elements: c.els(ids), size: .sm, spacing: .gap1_5,
                activeId: activeId, onTap: onTap)
    }

    /// Static footnote: بِئْسَ لِسْمُ reading note (`text-text-muted`, mt-1).
    private var footnote: some View {
        Text("(٭) بُو سُوزْ بِئْسَ لِسْمُ دیب اوقیلادی")
            .font(arabicFont(10, weight: .regular))
            .foregroundStyle(AppColor.textMuted)
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)                       // mt-1
            .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Vasl title (page-30-local)

/// The tappable "وصل" section title with its static "وصل — قوشیش" subtitle.
/// Port of the page-30 `vasl_title` button (`rounded-md px-3 py-0.5`, green
/// `text-secondary` inactive). Renders nothing when the element is absent.
private struct VaslTitleButton: View {
    let title: Element?
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        if let title {
            let isActive = activeId == title.id
            Button { onTap(title) } label: { label(title.arabic, isActive) }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
        }
    }

    private func label(_ arabic: String, _ isActive: Bool) -> some View {
        VStack(spacing: 2) {                        // mt-0.5 between title/sub
            Text(arabic)
                .font(arabicFont(16, weight: .bold))    // text-base font-bold
            Text("وصل — قوشیش")
                .font(arabicFont(9, weight: .regular))  // text-[0.5625rem]
                .opacity(0.7)
        }
        .foregroundStyle(isActive ? Color.white : AppColor.textSecondary)
        .padding(.horizontal, 12)                   // px-3
        .padding(.vertical, 2)                      // py-0.5
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)   // rounded-md
                .fill(isActive ? AppColor.primary : Color.clear)
        )
        .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 10, x: 0, y: 6)
        .environment(\.layoutDirection, .rightToLeft)
    }
}
