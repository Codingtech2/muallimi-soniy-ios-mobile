import SwiftUI

/// Bespoke 1:1 renderer for the interactive COVER (book page 0) — three tappable
/// title tokens (معلم ثانى / ياكى / الفباء عربى) stacked between diamond dividers,
/// framed by the static author and reader names. Ports the web `Page0`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page0`.
/// The cover buttons use their own look (bespoke `coverBtn` on the web too):
/// green-dark hero titles, amber diamond rules — distinct from the standard
/// `ArabicElementView`, so a small private `CoverTitle` carries that styling.
struct Page0View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 24) {  // gap-6
            author
            coverTitle(c.el("m01_title_main"), size: 60, style: .hero)   // text-6xl
            CoverDivider()
            coverTitle(c.el("m02_yoki"), size: 24, style: .linking)      // text-2xl
            CoverDivider()
            coverTitle(c.el("m03_title_sub"), size: 48, style: .hero)    // text-5xl
            reader
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)  // py-10
    }

    // MARK: - Tappable titles

    @ViewBuilder
    private func coverTitle(_ element: Element?, size: CGFloat, style: CoverTitleStyle) -> some View {
        if let element {
            CoverTitle(element: element, fontSize: size, style: style,
                       isActive: activeId == element.id) { onTap(element) }
        }
    }

    // MARK: - Static chrome

    private var author: some View {
        VStack(spacing: 8) {  // mt-2
            Text("مؤلف")
                .font(arabicFont(14, weight: .regular))  // text-sm
                .foregroundStyle(AppColor.textMuted)
                .environment(\.layoutDirection, .rightToLeft)
            Text("أحمد هادي مقصودي")
                .font(arabicFont(20, weight: .regular))  // text-xl
                .foregroundStyle(AppColor.elJumla)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var reader: some View {
        HStack(spacing: 8) {
            Text("🎧").font(.system(size: 14))
            Text("اوقیدی: جهانگیر قاری نعمتاو")
                .font(arabicFont(14, weight: .regular))
                .environment(\.layoutDirection, .rightToLeft)
        }
        .foregroundStyle(AppColor.textMuted)
        .padding(.top, 16)  // mt-6 (beyond the gap-6)
    }
}

// MARK: - Cover title button

/// Which cover-button look to apply. `hero` — the big green-dark titles;
/// `linking` — the smaller neutral "yoki" word between them.
private enum CoverTitleStyle {
    case hero, linking

    var inactiveColor: Color { self == .hero ? AppColor.primaryDark : AppColor.textMain }
    var weight: Font.Weight { self == .hero ? .bold : .regular }
    var cornerRadius: CGFloat { self == .hero ? 16 : 12 }      // rounded-2xl / rounded-xl
    var hPadding: CGFloat { self == .hero ? 20 : 16 }          // px-5 / px-4
    var vPadding: CGFloat { self == .hero ? 8 : 4 }            // py-2 / py-1
    var glowRadius: CGFloat { self == .hero ? 14 : 10 }        // 28px / 20px blur
    var glowY: CGFloat { self == .hero ? 8 : 6 }
}

/// One tappable cover title. Active: white glyph on a primary-green fill with a
/// soft green glow and a gentle scale-up; inactive: the style's flat colour with
/// no fill. Per the project rule, inactive tokens are never dimmed.
private struct CoverTitle: View {
    let element: Element
    let fontSize: CGFloat
    let style: CoverTitleStyle
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(element.arabic)
                .font(arabicFont(fontSize, weight: style.weight))
                .foregroundStyle(isActive ? Color.white : style.inactiveColor)
                .shadow(color: isActive ? Color.black.opacity(0.3) : .clear, radius: 1, x: 0, y: 1)
                .padding(.horizontal, style.hPadding)
                .padding(.vertical, style.vPadding)
                .background(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .fill(isActive ? AppColor.primary : Color.clear)
                )
                .shadow(color: isActive ? AppColor.primaryGlow : .clear,
                        radius: style.glowRadius, x: 0, y: style.glowY)
                .scaleEffect(isActive ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .rightToLeft)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }
}

// MARK: - Diamond divider

/// The amber `◇ ◇ ◇` rule flanked by two hairlines — the web `CoverDivider`.
private struct CoverDivider: View {
    var body: some View {
        HStack(spacing: 8) {
            hairline
            Text("◇ ◇ ◇")
                .font(.system(size: 12))
                .foregroundStyle(AppColor.elJumla.opacity(0.7))
            hairline
        }
        .frame(maxWidth: 200)
    }

    private var hairline: some View {
        Rectangle()
            .fill(AppColor.elJumla.opacity(0.5))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}
