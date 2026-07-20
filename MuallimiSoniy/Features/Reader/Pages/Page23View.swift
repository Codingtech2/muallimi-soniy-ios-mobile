import SwiftUI

/// Bespoke 1:1 renderer for book page 23 — tashdid continued (t01–t40, 40 words
/// across 8 rows split by a tight divider) followed by the Tanvin intro banner.
/// Tight `gap-0.5` spacing + `my-1` dividers keep all 47 elements on one screen.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page23`
/// (+ its `TanvinRule`, ported below as private views).
struct Page23View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            tashdidTop(c)
            TightDivider()
            tashdidBottom(c)
            TightDivider()
            TanvinRule(
                rule: c.el("tn_intro"),
                signs: c.els(["tn_fath", "tn_kasr", "tn_damm"]),
                examples: c.els(["tn_an", "tn_in", "tn_un"]),
                activeId: activeId,
                onTap: onTap
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tashdid rows (all size=sm, gap-1.5)

    /// R1–R3: V-bob masdar (6-5-5 words).
    @ViewBuilder
    private func tashdidTop(_ c: PageContent) -> some View {
        tRow(c, 1, 6)
        tRow(c, 7, 11)
        tRow(c, 12, 16)
    }

    /// R4–R8: V-bob ism-fail → IX bob → X bob (5-5-5-5-4 words).
    @ViewBuilder
    private func tashdidBottom(_ c: PageContent) -> some View {
        tRow(c, 17, 21)
        tRow(c, 22, 26)
        tRow(c, 27, 31)
        tRow(c, 32, 36)
        tRow(c, 37, 40)
    }

    /// A word row over the padded `t{NN}` id range (inclusive).
    private func tRow(_ c: PageContent, _ first: Int, _ last: Int) -> some View {
        WordRow(
            elements: c.els((first...last).map { String(format: "t%02d", $0) }),
            size: .sm,
            spacing: .gap1_5,
            activeId: activeId,
            onTap: onTap
        )
    }
}

// MARK: - TanvinRule (page 23 intro banner)

/// The tanvin intro card: a tappable title (full narration), a static Chigʻatoy
/// explanation, and three columns (fatha / kasra / damma) each pairing a big
/// tanvin sign with its `A = AN` example. Port of the web `TanvinRule`.
private struct TanvinRule: View {
    let rule: Element?
    let signs: [Element]
    let examples: [Element]
    let activeId: String?
    let onTap: (Element) -> Void

    private var ruleActive: Bool { rule.map { activeId == $0.id } ?? false }

    var body: some View {
        VStack(spacing: 6) {
            titleBar
            note
            columns
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)   // px-3
        .padding(.vertical, 6)      // py-1.5
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)   // rounded-xl
                .fill(AppColor.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppColor.primary.opacity(0.2), lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: ruleActive)
    }

    // MARK: Title bar (tappable when `rule` present)

    @ViewBuilder
    private var titleBar: some View {
        if let rule {
            Button { onTap(rule) } label: {
                HStack(spacing: 8) {   // justify-between, LTR: title left, pill right
                    Text(rule.arabic)
                        .font(arabicFont(16))                 // text-base font-bold
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer(minLength: 8)
                    MadListenPill()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(ruleActive ? AppColor.primary.opacity(0.12) : .clear)
                )
                .shadow(color: ruleActive ? AppColor.primaryGlow : .clear, radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        } else {
            Text("تنوينلي حرفلر")
                .font(arabicFont(16))
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Chigʻatoy explanation (static, bold middle phrase)

    private var note: some View {
        (Text("اوشبو اوچ تنوین علامتلرینینگ بیری قوییلگان حرفلردن سونگ ")
            .font(arabicFont(10, weight: .regular))
         + Text("بیر سکونلی نون").font(arabicFont(10, weight: .semibold))
         + Text(" اورتیریب اوقیلادی.").font(arabicFont(10, weight: .regular)))
            .foregroundStyle(AppColor.textMain.opacity(0.85))
            .lineSpacing(3)                       // leading-relaxed
            .multilineTextAlignment(.center)
            .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: Three sign/example columns

    private var columns: some View {
        HStack(alignment: .top, spacing: 8) {   // justify-around gap-2
            ForEach(Array(signs.enumerated()), id: \.offset) { index, sign in
                TanvinColumn(
                    sign: sign,
                    example: index < examples.count ? examples[index] : nil,
                    activeId: activeId,
                    onTap: onTap
                )
                .frame(maxWidth: .infinity)      // flex-1
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .rightToLeft)   // flex-row-reverse (fatha rightmost)
    }
}

/// One tanvin column: big tappable sign + Uzbek label + tappable `A = AN` pair.
private struct TanvinColumn: View {
    let sign: Element
    let example: Element?
    let activeId: String?
    let onTap: (Element) -> Void

    private var signActive: Bool { activeId == sign.id }

    var body: some View {
        VStack(spacing: 2) {   // gap-0.5
            signButton
            Text(Self.stripParen(sign.uzbek))
                .font(.system(size: 9))          // text-[0.5625rem]
                .foregroundStyle(AppColor.textMuted)
                .lineLimit(1)
            if let example {
                exampleButton(example)
            }
        }
    }

    private var signButton: some View {
        Button { onTap(sign) } label: {
            Text(sign.arabic)
                .font(arabicFont(32))            // clamp(1.5rem…2rem)
                .foregroundStyle(signActive ? .white : AppColor.textMain)
                .padding(.horizontal, 8)         // px-2
                .padding(.vertical, 2)           // py-0.5
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(signActive ? AppColor.primary : .clear)
                )
                .shadow(color: signActive ? AppColor.primaryGlow : .clear, radius: 10, x: 0, y: 6)
                .scaleEffect(signActive ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: signActive)
    }

    private func exampleButton(_ ex: Element) -> some View {
        let active = activeId == ex.id
        return Button { onTap(ex) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 4) {  // items-baseline gap-1
                Text(ex.arabic).font(arabicFont(16))             // font-bold text-base
                Text("=").font(.system(size: 12)).opacity(0.7)   // text-xs
                Text(Self.expand(ex.uzbek))
                    .font(arabicFont(14, weight: .regular))      // text-sm
                    .opacity(0.7)
            }
            .foregroundStyle(active ? .white : AppColor.textMain)
            .padding(.horizontal, 6)     // px-1.5
            .padding(.vertical, 2)       // py-0.5
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? AppColor.primary : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(active ? AppColor.primary : .clear, lineWidth: 2)
            )
            .shadow(color: active ? AppColor.primaryGlow : .clear, radius: 7, x: 0, y: 4)
            .scaleEffect(active ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .rightToLeft)   // dir="rtl"
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: active)
    }

    // MARK: Uzbek text helpers (mirror the web regexes)

    /// Text after `= ` up to the closing `)` — web `uzbek.match(/=\s*(.+?)\)/)`.
    private static func expand(_ uzbek: String) -> String {
        guard let eq = uzbek.range(of: "= ") else { return "" }
        let tail = uzbek[eq.upperBound...]
        let end = tail.firstIndex(of: ")") ?? tail.endIndex
        return String(tail[..<end]).trimmingCharacters(in: .whitespaces)
    }

    /// Drops the trailing parenthetical — web `uzbek.replace(/\s*\([^)]+\)/, "")`.
    private static func stripParen(_ uzbek: String) -> String {
        guard let open = uzbek.firstIndex(of: "(") else { return uzbek }
        return String(uzbek[..<open]).trimmingCharacters(in: .whitespaces)
    }
}

/// A thin dotted rule with `my-1` margins — the web `Page23` `<Sep>`
/// (`border-b-2 border-dotted border-white/10 my-1`), tighter than
/// `SectionDivider` (`my-2`) so the whole page fits one viewport.
private struct TightDivider: View {
    var body: some View {
        HDottedLine()
            .stroke(
                AppColor.divider,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 4])
            )
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)   // my-1
    }
}

/// A single horizontal midline, stroked as dots.
private struct HDottedLine: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
