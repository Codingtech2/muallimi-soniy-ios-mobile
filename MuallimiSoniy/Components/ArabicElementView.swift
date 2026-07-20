import SwiftUI

/// Discrete font-size buckets for tappable Arabic elements, mirroring the web
/// `ArabicEl` `size` prop. The web uses `clamp()` keyed on the card container
/// width (`cqi`); on a phone-width card the rendered size sits near the clamp
/// **max**, so each bucket maps to that max (in points ≈ CSS px).
///
/// Names avoid a leading digit: `xxl` == web `2xl`, `xxxl` == `3xl`,
/// `xxxxl` == `4xl`.
nonisolated enum ArabicSize: CaseIterable, Sendable {
    case sm, md, lg, xl, xxl, xxxl, xxxxl

    /// Point size ≈ the web `clamp()` maximum for this bucket.
    var pointSize: CGFloat {
        switch self {
        case .sm: return 18      // text-[…,1.125rem]
        case .md: return 20      // text-[…,1.25rem]
        case .lg: return 24      // text-[…,1.5rem]
        case .xl: return 30      // text-[…,1.875rem]
        case .xxl: return 36     // text-[…,2.25rem]
        case .xxxl: return 48    // text-[…,3rem]
        case .xxxxl: return 60   // text-[…,3.75rem]
        }
    }

    /// Horizontal padding ≈ the web `px-[…]` clamp max for this bucket.
    var horizontalPadding: CGFloat {
        switch self {
        case .sm: return 6
        case .md: return 8
        case .lg: return 10
        case .xl: return 12
        case .xxl: return 12
        case .xxxl: return 16
        case .xxxxl: return 20
        }
    }

    /// Vertical padding ≈ the web `py-[…]` clamp max for this bucket.
    var verticalPadding: CGFloat {
        switch self {
        case .sm, .md: return 2
        case .lg, .xl: return 4
        case .xxl: return 6
        case .xxxl, .xxxxl: return 8
        }
    }
}

/// Gap buckets for `WordRow`, mirroring the web `FLUID_GAP` maxima (Tailwind
/// `gap-*` → rem). Applied to both the inter-item and inter-line spacing, as
/// CSS `flex-wrap` `gap` does.
nonisolated enum RowSpacing: Sendable {
    case gap1, gap1_5, gap2, gap3, gap5, gap6

    var value: CGFloat {
        switch self {
        case .gap1: return 4      // 0.25rem
        case .gap1_5: return 6    // 0.375rem
        case .gap2: return 8      // 0.5rem
        case .gap3: return 12     // 0.75rem
        case .gap5: return 20     // 1.25rem
        case .gap6: return 24     // 1.5rem
        }
    }
}

/// A single tappable Arabic token (letter / syllable / word) — the SwiftUI port
/// of the web `ArabicEl`.
///
/// Active state: primary-green fill, white glyph, a 2 pt green border, a soft
/// green glow and a gentle scale-up. Inactive state: clear fill, `textMain`
/// glyph. Per the project UI rule, an inactive element is **never dimmed** — its
/// opacity is untouched regardless of whether some other element is active, so
/// the whole page stays fully legible while one token is highlighted.
struct ArabicElementView: View {
    let element: Element
    var size: ArabicSize = .lg
    /// Mad pages (17–21): render with the Amiri-Quran-based mad face (large,
    /// prominent U+064F damma; vertical mad marks) instead of the bold body font.
    var mad: Bool = false
    let isActive: Bool
    let onTap: () -> Void

    /// `rounded-lg` corner radius.
    private let cornerRadius: CGFloat = 8
    /// Web `transform: scale(1.18)`; the task calls for ~1.15.
    private let activeScale: CGFloat = 1.15

    var body: some View {
        Button(action: onTap) {
            Text(element.arabic)
                .font(mad ? madArabicFont(size.pointSize) : arabicFont(size.pointSize))
                .foregroundStyle(isActive ? Color.white : AppColor.textMain)
                // Web `textShadow: 0 1px 2px rgba(0,0,0,0.3)` on the active glyph.
                .shadow(color: isActive ? Color.black.opacity(0.3) : .clear, radius: 1, x: 0, y: 1)
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, size.verticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isActive ? AppColor.primary : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(isActive ? AppColor.primary : Color.clear, lineWidth: 2)
                )
                // Web `boxShadow: 0 8px 28px var(--color-primary-glow)`.
                .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 13, x: 0, y: 8)
                .scaleEffect(isActive ? activeScale : 1)
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .rightToLeft)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }
}

#if DEBUG
private nonisolated let previewElement = Element(
    id: "preview", type: .harf, arabic: "بَ", uzbek: "Ba",
    audioUrl: nil, start: 0, end: 0, x: 0, y: 0, width: 0, height: 0
)

#Preview("ArabicElementView") {
    HStack(spacing: 16) {
        ArabicElementView(element: previewElement, size: .xl, isActive: false) {}
        ArabicElementView(element: previewElement, size: .xl, isActive: true) {}
    }
    .padding(40)
    .background(AppColor.background)
}
#endif
