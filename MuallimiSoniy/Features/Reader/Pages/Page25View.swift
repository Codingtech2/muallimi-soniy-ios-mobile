import SwiftUI

/// Bespoke 1:1 renderer for book page 25 — tanvinli tashdid (top) and the Alif
/// va Hamza chapter intro (bottom). The top half: a tappable title, a static
/// `ـًّ ـٍّ ـٌّ` signs header, three "رَبٌّ − (رَبُّنْ)" example cells, then six tanvin
/// practice rows. A tight dotted rule separates the `AlifHamzaIntro` banner.
///
/// Ports the web `Page25` plus its page-local `RabbCell`, `SignsHeader` and the
/// `AlifHamzaIntro` component. Element text (`element.arabic`) already carries
/// the correct tanvin/hamza Unicode — only the expanded `(رَبُّنْ)` glosses are
/// literals, exactly as in the web JSX.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page25`
/// and `function AlifHamzaIntro`.
struct Page25View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0`.
        VStack(spacing: 0) {
            title(c)
            SignsHeader()
                .padding(.bottom, -4)   // web `-mb-1` pulls R1 up
            rabbRow(c)
            tanvinRows(c)
            DottedSep()                 // web `Sep` (my-0.5)
            alifHamza(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top: tanvinli tashdid

    /// Tappable "تنوينلي تشديد" heading. `el("title")` resolves to `p25_title`
    /// (the page's first element) — it precedes `p25_ah_title` in JSON order, so
    /// the first `_title` suffix match is the intended one.
    @ViewBuilder
    private func title(_ c: PageContent) -> some View {
        if let t = c.el("title") {
            ClickableTitle(element: t, isActive: activeId == t.id) { onTap(t) }
        }
    }

    /// R1 — the three "رَبٌّ − (…)" example cells, distributed RTL (rabban →
    /// rabbin → rabbun, right to left). Web `justify-around`, `mt-0.5`.
    private func rabbRow(_ c: PageContent) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 4)
            rabbCell(c, "r1_w3_an", "رَبَّنْ")
            Spacer(minLength: 4)
            rabbCell(c, "r1_w2_in", "رَبِّنْ")
            Spacer(minLength: 4)
            rabbCell(c, "r1_w1_un", "رَبُّنْ")
            Spacer(minLength: 4)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .frame(maxWidth: .infinity)
        .padding(.top, 2)   // mt-0.5
    }

    @ViewBuilder
    private func rabbCell(_ c: PageContent, _ suffix: String, _ expand: String) -> some View {
        if let e = c.el(suffix) {
            RabbCell(element: e, expand: expand, isActive: activeId == e.id) { onTap(e) }
        }
    }

    /// R2–R4 (6 words, gap-1.5) then R5–R7 (5 mu-prefixed words, gap-1).
    @ViewBuilder
    private func tanvinRows(_ c: PageContent) -> some View {
        wordRow(c, row: 2, count: 6, spacing: .gap1_5)
        wordRow(c, row: 3, count: 6, spacing: .gap1_5)
        wordRow(c, row: 4, count: 6, spacing: .gap1_5)
        wordRow(c, row: 5, count: 5, spacing: .gap1)
        wordRow(c, row: 6, count: 5, spacing: .gap1)
        wordRow(c, row: 7, count: 5, spacing: .gap1)
    }

    private func wordRow(_ c: PageContent, row: Int, count: Int, spacing: RowSpacing) -> some View {
        WordRow(
            elements: c.els((1...count).map { "r\(row)_w\($0)" }),
            size: .sm, spacing: spacing,
            activeId: activeId, onTap: onTap
        )
    }

    // MARK: - Bottom: Alif va Hamza

    private func alifHamza(_ c: PageContent) -> some View {
        AlifHamzaIntro(
            title: c.el("ah_title"),
            subtitle: c.el("ah_subtitle"),
            forms: c.els((1...9).map { "ah_f\($0)" }),
            row1: c.els((1...4).map { "ah_p1_w\($0)" }),
            row2: c.els((1...4).map { "ah_p2_w\($0)" }),
            activeId: activeId,
            onTap: onTap
        )
    }
}

// MARK: - Clickable Arabic heading (shared by the two titles on this page)

/// A small tappable Arabic heading (`text-sm` bold, green `textSecondary`) that
/// fills with the primary colour + glow when active. Used for both the
/// "تنوينلي تشديد" title and the "الف و همزة" title.
private struct ClickableTitle: View {
    let element: Element
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(element.arabic)
                .font(arabicFont(14))   // text-sm, font-bold
                .foregroundStyle(isActive ? Color.white : AppColor.textSecondary)
                .padding(.horizontal, 8)   // px-2
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? AppColor.primary : .clear)
                )
                .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 10, x: 0, y: 6)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }
}

// MARK: - Signs header (static)

/// The visual-only `ـًّ ـٍّ ـٌّ` header sitting on a 55%-wide muted underline. Port
/// of the web page-25 `SignsHeader`. Non-tappable; RTL (fatha → kasra → damma).
private struct SignsHeader: View {
    private let signPoint: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            marks
                .frame(width: geo.size.width * 0.55)   // w-[55%]
                .frame(maxWidth: .infinity)            // centre the box
        }
        .frame(height: signPoint + 8)                  // bound the reader's height
    }

    private var marks: some View {
        HStack(spacing: 25) {   // gap clamp max ~1.6rem
            ForEach(["ـًّ", "ـٍّ", "ـٌّ"], id: \.self) { sign in
                Text(sign)
                    .font(arabicFont(signPoint, weight: .regular))
                    .foregroundStyle(AppColor.textMuted)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .frame(maxWidth: .infinity)   // justify-center within the box
        .padding(.bottom, 2)          // pb-0.5
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColor.textMuted.opacity(0.2))   // border-b border-text-muted/20
                .frame(height: 1)
        }
    }
}

// MARK: - رَبٌّ example cell

/// One "رَبٌّ − (رَبُّنْ)" cell: the tanvin+tashdid glyph (from `element.arabic`)
/// on the right, a dash, then the dimmed expanded reading. Active fill mirrors
/// `ArabicElementView`. Port of the web page-25 `RabbCell`.
private struct RabbCell: View {
    let element: Element
    let expand: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {   // items-baseline gap-0.5
                Text(element.arabic).font(arabicFont(18))         // clamp max 1.1rem, bold
                Text("−").font(.system(size: 10)).opacity(0.6)    // text-[0.625rem] opacity-60
                Text("(\(expand))")
                    .font(arabicFont(13, weight: .regular))       // clamp max 0.85rem
                    .opacity(0.6)
            }
            .foregroundStyle(isActive ? Color.white : AppColor.textMain)
            .padding(.horizontal, 6)   // px-1.5
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? AppColor.primary : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isActive ? AppColor.primary : .clear, lineWidth: 2)
            )
            .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 7, x: 0, y: 4)
            .scaleEffect(isActive ? 1.06 : 1)
            .environment(\.layoutDirection, .rightToLeft)   // dir="rtl"
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }
}

// MARK: - Alif va Hamza intro banner

/// The "الف و همزة" chapter intro on page 25's lower half: a tappable title +
/// chig'atoy subtitle, a numbered row of the 9 hamza forms, and two numbered
/// practice rows (old / new orthography). Port of the web `AlifHamzaIntro`.
private struct AlifHamzaIntro: View {
    let title: Element?
    let subtitle: Element?
    let forms: [Element]
    let row1: [Element]
    let row2: [Element]
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        VStack(spacing: 0) {   // gap-0
            if let title {
                ClickableTitle(element: title, isActive: activeId == title.id) { onTap(title) }
            }
            if let subtitle {
                subtitleButton(subtitle)
            }
            formsRow
            numberedRow("١)", row1)
            numberedRow("٢)", row2)
        }
        .frame(maxWidth: .infinity)
    }

    /// Chig'atoy narration line — smaller, muted, tappable.
    private func subtitleButton(_ element: Element) -> some View {
        let isActive = activeId == element.id
        return Button { onTap(element) } label: {
            Text(element.arabic)
                .font(arabicFont(10, weight: .regular))   // text-[0.625rem]
                .foregroundStyle(isActive ? Color.white : AppColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)   // px-2
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? AppColor.primary : .clear)
                )
                .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 7, x: 0, y: 4)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }

    /// Leading `١` marker then the 9 hamza forms, distributed RTL (justify-around).
    private var formsRow: some View {
        HStack(spacing: 0) {
            numberLabel("١")
            ForEach(forms) { form in
                Spacer(minLength: 4)
                FormCell(element: form, isActive: activeId == form.id) { onTap(form) }
            }
            Spacer(minLength: 4)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .frame(maxWidth: .infinity)
        .padding(.top, 2)   // mt-0.5
    }

    /// A numbered practice row: `NN)` marker (right) + words distributed RTL.
    private func numberedRow(_ marker: String, _ elements: [Element]) -> some View {
        HStack(spacing: 4) {   // gap-1
            numberLabel(marker)
            HStack(spacing: 0) {   // flex-1 justify-around
                ForEach(elements) { e in
                    Spacer(minLength: 2)
                    ArabicElementView(element: e, size: .sm, isActive: activeId == e.id) { onTap(e) }
                }
                Spacer(minLength: 2)
            }
            .frame(maxWidth: .infinity)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .frame(maxWidth: .infinity)
    }

    private func numberLabel(_ text: String) -> some View {
        Text(text)
            .font(arabicFont(10, weight: .regular))   // text-[0.625rem]
            .foregroundStyle(AppColor.textMuted)
            .frame(width: 16)   // w-[16px] shrink-0
            .multilineTextAlignment(.center)
    }
}

/// One tappable hamza form glyph (no border, unlike `ArabicElementView`). Port
/// of the web `AlifHamzaIntro` inner `FormCell`.
private struct FormCell: View {
    let element: Element
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(element.arabic)
                .font(arabicFont(18))   // clamp max 1.15rem, bold
                .foregroundStyle(isActive ? Color.white : AppColor.textMain)
                .padding(.horizontal, 4)   // px-1
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? AppColor.primary : .clear)
                )
                .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 7, x: 0, y: 4)
                .scaleEffect(isActive ? 1.12 : 1)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }
}

// MARK: - Page-local tight dotted rule (web `Sep`, my-0.5)

private struct DottedSep: View {
    var verticalPadding: CGFloat = 2   // my-0.5

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
