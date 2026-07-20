import SwiftUI

/// Bespoke 1:1 renderer for book page 21 — the tail of the mad words (3 rows)
/// followed by the start of the tashdid topic: the tap-to-listen rule banner
/// (with the static `ـَّ ـِّ ـُّ` demo), three "رَبَّ - (رَبْبَ)" examples, and six
/// 7-word practice rows. Ports the web `Page21`; no row uses the mad face (the
/// web passes `mad` nowhere here — the plain body font renders the mad marks).
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page21`.
struct Page21View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-1` → 4 pt.
        VStack(spacing: 4) {
            madTail(c)                       // mad davomi (15 so'z)
            SectionDivider()
            TashdidRuleCard(rule: c.el("t_intro"), activeId: activeId, onTap: onTap)
            RabbExamples(rabb: c.els(["t_rab1", "t_rab2", "t_rab3"]),
                         activeId: activeId, onTap: onTap)
            SectionDivider()
            practiceRows(c)                  // 6 × 7 mashq
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Blocks

    /// Mad continuation words (15) — plain face, matching the web.
    @ViewBuilder private func madTail(_ c: PageContent) -> some View {
        plainRow(c, ["m01", "m02", "m03", "m04"], .lg, .gap3)
        plainRow(c, ["m05", "m06", "m07", "m08", "m09", "m10"], .sm, .gap1_5)
        plainRow(c, ["m11", "m12", "m13", "m14", "m15"], .sm, .gap1_5)
    }

    /// Six tashdid practice rows of 7 words each (`t{row}{word}`).
    @ViewBuilder private func practiceRows(_ c: PageContent) -> some View {
        ForEach(1...6, id: \.self) { row in
            plainRow(c, (1...7).map { "t\(row)\($0)" }, .sm, .gap1_5)
        }
    }

    private func plainRow(_ c: PageContent, _ ids: [String],
                          _ size: ArabicSize, _ spacing: RowSpacing) -> some View {
        WordRow(elements: c.els(ids), size: size, spacing: spacing,
                activeId: activeId, onTap: onTap)
    }
}

// MARK: - Tashdid rule banner (page-21-local)

/// The tap-to-listen tashdid rule card, with the static `ـَّ ـِّ ـُّ` demo. Port of
/// the web `TashdidRule`. When `rule` is nil it renders as a plain, non-tappable
/// card. Used once (page 21), so it lives beside its page.
private struct TashdidRuleCard: View {
    let rule: Element?
    let activeId: String?
    let onTap: (Element) -> Void

    private var isActive: Bool { rule.map { activeId == $0.id } ?? false }

    var body: some View {
        Group {
            if let rule {
                Button { onTap(rule) } label: { card }
                    .buttonStyle(.plain)
            } else {
                card
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            demo
            narration
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)   // px-3
        .padding(.vertical, 8)      // py-2
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColor.primary.opacity(isActive ? 0.12 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isActive ? AppColor.primary : AppColor.primary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 12, x: 0, y: 8)
        .environment(\.layoutDirection, .rightToLeft)   // dir="rtl"
    }

    /// Title ("تشدید قائده‌سی (کتابدن)") on the right, listen pill on the left.
    private var header: some View {
        HStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("تشدید قائده‌سی")
                    .font(arabicFont(11, weight: .semibold))
                    .foregroundStyle(AppColor.textMain)
                Text("(کتابدن)")
                    .font(arabicFont(11, weight: .regular))
                    .foregroundStyle(AppColor.textMuted)
            }
            Spacer(minLength: 8)
            if rule != nil { MadListenPill() }
        }
    }

    /// Static visual: line = letter; the three marks (fatha / kasra / damma)
    /// sit above/below it. Web `flex-row-reverse` inside the rtl card renders
    /// them left→right in DOM order, so this row is forced LTR.
    private var demo: some View {
        HStack(spacing: 32) {           // gap-8
            demoMark("ـَّ")
            demoMark("ـِّ")
            demoMark("ـُّ")
        }
        .frame(maxWidth: .infinity)     // justify-center
        .padding(.vertical, 12)         // my-3
        .environment(\.layoutDirection, .leftToRight)
    }

    private func demoMark(_ text: String) -> some View {
        Text(text)
            .font(arabicFont(40))       // text-[2.5rem]
            .foregroundStyle(AppColor.textMain)
    }

    /// Audio narration verbatim (0–9.9 s).
    private var narration: some View {
        Text("تشدیدلی حرفلر اوستیگه اوشبو تشدید علامتلری قوییلگان حرفلر ایککیلنتیریب اوقیلادی.")
            .font(arabicFont(11, weight: .regular))
            .foregroundStyle(AppColor.textMain)
            .lineSpacing(3)             // leading-relaxed
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ربب examples

/// The three "رَبَّ - (رَبْبَ)" tashdid examples. The contracted / expanded glyphs
/// are fixed (as in the web); the element only drives id + tap + highlight.
private struct RabbExamples: View {
    /// Ordered `[t_rab1, t_rab2, t_rab3]` (any missing ones dropped).
    let rabb: [Element]
    let activeId: String?
    let onTap: (Element) -> Void

    /// Fixed contracted / expanded glyph pairs, keyed by id suffix.
    private static let forms: [(suffix: String, tash: String, expand: String)] = [
        ("t_rab1", "رَبَّ", "رَبْبَ"),
        ("t_rab2", "رَبِّ", "رَبْبِ"),
        ("t_rab3", "رَبُّ", "رَبْبُ")
    ]

    var body: some View {
        HStack(spacing: 12) {                          // gap-3
            ForEach(rabb) { element in
                if let form = Self.forms.first(where: { element.id.hasSuffix($0.suffix) }) {
                    RabbButton(tash: form.tash, expand: form.expand,
                               isActive: activeId == element.id,
                               onTap: { onTap(element) })
                }
            }
        }
        .frame(maxWidth: .infinity)                    // justify-center
        .padding(.vertical, 8)                         // my-2
        // Web `flex-row-reverse` (ltr page) → first (رَبَّ) sits on the right.
        .environment(\.layoutDirection, .rightToLeft)
    }
}

/// One "رَبَّ - (رَبْبَ)" pill: contracted (bold) glyph on the right, an expanded
/// dimmed form on the left. Active fill mirrors `ArabicElementView`.
private struct RabbButton: View {
    let tash: String
    let expand: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {   // items-baseline gap-1.5
                Text(tash).font(arabicFont(24))                   // font-bold text-2xl
                Text("-").font(.system(size: 16)).opacity(0.7)    // text-base
                Text("(\(expand))")
                    .font(arabicFont(18, weight: .regular))       // text-lg (non-bold)
                    .opacity(0.7)
            }
            .foregroundStyle(isActive ? Color.white : AppColor.textMain)
            .padding(.horizontal, 8)     // px-2
            .padding(.vertical, 4)       // py-1
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)   // rounded-lg
                    .fill(isActive ? AppColor.primary : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isActive ? AppColor.primary : Color.clear, lineWidth: 2)
            )
            .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 10, x: 0, y: 6)
            .scaleEffect(isActive ? 1.1 : 1)
            .environment(\.layoutDirection, .rightToLeft)   // dir="rtl": tash right, expand left
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }
}
