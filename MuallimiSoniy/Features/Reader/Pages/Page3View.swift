import SwiftUI

/// Bespoke 1:1 SwiftUI port of the web `Page3` (Alifbo + harakat + Ra sections).
///
/// Mirrors `RenderedPage.tsx` `Page3` top-to-bottom: five intro sentences —
/// a'uzu billah + bismillah as `Verse`s, then two rules + one example as
/// old-Uzbek (chig'atoy) `RuleBlock`s — the 28-letter alphabet in four RTL
/// rows of seven (`2xl`, `gap-1`), a `حَرَكَاتْ` title, the three vowel marks
/// (`3xl`, `gap-6`), a divider, then Ra's three harakat forms (`3xl`) and its
/// three syllables (`2xl`), all `gap-6`.
///
/// The active token's highlight comes entirely from the primitives; other
/// elements are never dimmed (project UI rule).
struct Page3View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 4) {  // web outer `flex flex-col items-center gap-1`
            // Intro sentences — hierarchy: bismillah largest, a'uzu billah
            // medium, then the two rules + the example as muted rule blocks
            // (the web wraps the first in `mt-1` and the last in `mb-1`).
            intro(c.el("auzubillah"), size: .md)
            intro(c.el("bismillah"), size: .lg)
            rule(c.el("rule1"))
                .padding(.top, 4)
            rule(c.el("misol"))
            rule(c.el("rule2"))
                .padding(.bottom, 4)

            // Alphabet — 28 letters, four RTL rows of seven.
            WordRow(elements: c.els(["01", "02", "03", "04", "05", "06", "07"]),
                    size: .xxl, spacing: .gap1, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["08", "09", "10", "11", "12", "13", "14"]),
                    size: .xxl, spacing: .gap1, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["15", "16", "17", "18", "19", "20", "21"]),
                    size: .xxl, spacing: .gap1, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["22", "23", "24", "25", "26", "27", "28"]),
                    size: .xxl, spacing: .gap1, activeId: activeId, onTap: onTap)

            SectionDivider()
            SectionTitle("حَرَكَاتْ", subtitle: "حرکتلر")

            // The three vowel marks (fatha / kasra / damma on alif).
            WordRow(elements: c.els(["29", "30", "31"]),
                    size: .xxxl, spacing: .gap6, activeId: activeId, onTap: onTap)

            SectionDivider()

            // Ra's three harakat forms, then its three closed syllables.
            WordRow(elements: c.els(["32", "33", "34"]),
                    size: .xxxl, spacing: .gap6, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["35", "36", "37"]),
                    size: .xxl, spacing: .gap6, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }

    /// Renders one optional intro sentence (`jumla`) as a full-width tappable
    /// `Verse`; no-ops when the page lacks that element.
    @ViewBuilder
    private func intro(_ element: Element?, size: VerseSize) -> some View {
        if let element {
            Verse(
                element: element,
                size: size,
                isActive: activeId == element.id,
                onTap: onTap
            )
        }
    }

    /// Renders one optional rule sentence as a `RuleBlock`; no-ops when the
    /// page lacks that element.
    @ViewBuilder
    private func rule(_ element: Element?) -> some View {
        if let element {
            RuleBlock(element: element, isActive: activeId == element.id, onTap: onTap)
        }
    }
}

// MARK: - Rule block

/// One chig'atoy rule sentence under the bismillah — the port of the web
/// `RuleBlock`: a full-width, centred, muted paragraph capped at 560 pt
/// (`rounded-xl px-4 py-1 max-w-[560px]`) whose `arabic-text` span is set at
/// 1.1rem with line-height 2; active → primary fill, white glyphs, green glow.
/// The old-Uzbek text is the element's `arabic` field, exactly as in the web
/// `elements.ts` (`i03_rule1` / `i04_misol` / `i05_rule2`).
private struct RuleBlock: View {
    let element: Element
    let isActive: Bool
    let onTap: (Element) -> Void

    @Environment(\.arabicFontScale) private var arabicFontScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Web `1.1rem`, scaled like every other Arabic glyph on the page.
    private var pointSize: CGFloat { 18 * arabicFontScale }

    var body: some View {
        Button { onTap(element) } label: {
            Text(element.arabic)
                .font(arabicFont(pointSize, weight: .regular))
                .foregroundStyle(isActive ? Color.white : AppColor.textMuted)
                .lineSpacing(pointSize * 0.45)   // web `lineHeight: 2`
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)            // web `max-w-[560px]`
                .padding(.horizontal, 16)        // px-4
                .padding(.vertical, 4)           // py-1
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)   // rounded-xl
                        .fill(isActive ? AppColor.primary : Color.clear)
                )
                .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 10, x: 0, y: 6)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(element.accessibilityLabelText)
        .accessibilityAddTraits(isActive ? [.startsMediaSession, .isSelected] : .startsMediaSession)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.62), value: isActive)
        .id(element.id)
    }
}

#if DEBUG
private struct Page3Preview: View {
    @Environment(ContentStore.self) private var store

    var body: some View {
        ScrollView {
            if let page = store.allBookPages.first(where: { $0.pageNumber == 3 }) {
                Page3View(page: page, activeId: nil, onTap: { _ in })
                    .padding(16)
            } else {
                Text("3-sahifa topilmadi").foregroundStyle(.secondary)
            }
        }
        .background(AppColor.background)
    }
}

#Preview("Page3View — p3") {
    Page3Preview().environment(ContentStore())
}
#endif
