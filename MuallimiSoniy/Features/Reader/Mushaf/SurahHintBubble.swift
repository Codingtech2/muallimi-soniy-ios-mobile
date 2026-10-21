import SwiftUI

/// The one-time "tap the surah name to hear the whole surah" bubble under the
/// page's first surah banner — the port of the web `SurahHint`
/// (`SurahBanner.tsx`). A green bubble whose small arrow points up at the
/// banner, holding a headphones icon, the hint, a "Got it" button and ✕.
/// Either button closes it for good; `SurahBannerFrame` keeps it outside the
/// banner's button, so closing it never starts the surah. No timer — it stays
/// until the learner closes it or taps the banner.
struct SurahHintBubble: View {
    /// "Tap the surah name to hear the whole surah" in the reader's language.
    let text: String
    /// "Got it" — the button's title and what VoiceOver calls the ✕.
    let dismissText: String
    let onDismiss: () -> Void

    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Dynamic Type multiplier for the fixed point sizes below. Fixed sizes on
    /// purpose: a text-style font (`.footnote`) lets iOS hyphenate the hint
    /// ("бери-лади"), which the web never does.
    @ScaledMetric(relativeTo: .footnote) private var typeScale: CGFloat = 1

    /// Drives the soft fade-in (web `animate-fade-in`).
    @State private var hasAppeared = false

    private var scale: CGFloat { layoutMetrics.uiScale }
    /// Point size × Dynamic Type (capped, the bubble sits inside the page) × iPad scale.
    private func size(_ points: CGFloat) -> CGFloat {
        points * min(typeScale, Self.maxTypeScale) * scale
    }
    /// Reduce Motion: there from the first frame, no fade or rise.
    private var isVisible: Bool { hasAppeared || reduceMotion }

    var body: some View {
        // The arrow overlaps the bubble by a point so no seam shows between them.
        VStack(spacing: -1) {
            HintArrow()
                .fill(Self.fill)
                .frame(width: Self.arrowWidth * scale, height: Self.arrowHeight * scale)
            content
                .background(
                    Self.fill,
                    in: RoundedRectangle(cornerRadius: Self.cornerRadius * scale, style: .continuous)
                )
        }
        // The arrow's row reaches up into the banner's tappable margin; making
        // the whole bubble rect solid to taps keeps a near-miss beside the
        // arrow from starting the surah.
        .contentShape(Rectangle())
        .compositingGroup()
        .shadow(color: .black.opacity(Self.shadowOpacity), radius: Self.shadowRadius, y: Self.shadowOffsetY)
        // Hugs its content up to the column width, centred (web `w-fit max-w-full mx-auto`).
        .frame(maxWidth: .infinity)
        // UI chrome in the reader's language, not Arabic content — keep it
        // left-to-right even where the page sets right-to-left.
        .environment(\.layoutDirection, .leftToRight)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : Self.riseDistance)
        .onAppear(perform: fadeIn)
        .accessibilityElement(children: .contain)
    }

    private var content: some View {
        // At accessibility text sizes the buttons go under the text, or the text
        // column shrinks to a word or two per line.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Self.itemSpacing * scale))
            : AnyLayout(HStackLayout(spacing: Self.itemSpacing * scale))
        return layout {
            HStack(spacing: Self.itemSpacing * scale) {
                Image(systemName: "headphones")
                    .font(.system(size: size(Self.iconSize)))
                    .accessibilityHidden(true)
                Text(text)
                    .font(.system(size: size(Self.textSize), weight: .medium))
                    .lineSpacing(size(Self.textLineSpacing))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Self.itemSpacing * scale) {
                okButton
                closeButton
            }
        }
        .foregroundStyle(.white)
        .padding(.leading, Self.leadingPadding * scale)
        .padding(.trailing, Self.trailingPadding * scale)
        .padding(.vertical, Self.verticalPadding * scale)
    }

    private var okButton: some View {
        Button(action: onDismiss) {
            Text(dismissText)
                .font(.system(size: size(Self.buttonTextSize), weight: .semibold))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, Self.buttonHorizontalPadding * scale)
                .padding(.vertical, Self.buttonVerticalPadding * scale)
                .background(Color.white.opacity(Self.buttonFillOpacity), in: Capsule())
                // Taller hit area than the small pill, without growing the bubble.
                .contentShape(Rectangle().inset(by: -Self.hitSlop))
        }
        .buttonStyle(HintButtonStyle())
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: size(Self.closeGlyphSize), weight: .bold))
                .opacity(Self.closeOpacity)
                .frame(width: size(Self.closeSide), height: size(Self.closeSide))
                .contentShape(Rectangle().inset(by: -Self.hitSlop))
        }
        .buttonStyle(HintButtonStyle())
        .accessibilityLabel(dismissText)
    }

    private func fadeIn() {
        guard !reduceMotion, !hasAppeared else { return }
        withAnimation(.easeOut(duration: Self.fadeSeconds)) { hasAppeared = true }
    }

    // MARK: - Metrics (web `SurahHint` classes, in points)

    /// A deeper green than `primary` (web `bg-primary`): white 13 pt text on
    /// `primary` is only 3.3:1 (2.3:1 in dark mode) and the "Got it" pill on it
    /// less. On this one the hint reads at 7:1 and the white/20 pill at 4.7:1.
    private static let fill = Color(hex: "166534")

    private static let textSize: CGFloat = 13           // text-[0.8125rem] font-medium
    /// Brings a 13 pt line to ~18 pt, like the web's `leading-snug`.
    private static let textLineSpacing: CGFloat = 2.5
    private static let buttonTextSize: CGFloat = 12     // text-[0.75rem] font-semibold
    private static let iconSize: CGFloat = 16           // Headphones size 16
    private static let closeGlyphSize: CGFloat = 12     // X size 14 (lucide draws it smaller)
    private static let closeSide: CGFloat = 24          // w-6 h-6
    /// Largest Dynamic Type growth, so the bubble stays inside the page column.
    private static let maxTypeScale: CGFloat = 1.6
    private static let arrowWidth: CGFloat = 14
    private static let arrowHeight: CGFloat = 7
    private static let cornerRadius: CGFloat = 12        // rounded-xl
    private static let itemSpacing: CGFloat = 8          // gap-2
    private static let leadingPadding: CGFloat = 12      // pl-3
    private static let trailingPadding: CGFloat = 6      // pr-1.5
    private static let verticalPadding: CGFloat = 6      // py-1.5
    private static let buttonHorizontalPadding: CGFloat = 8  // px-2
    private static let buttonVerticalPadding: CGFloat = 4    // py-1
    private static let buttonFillOpacity: Double = 0.2   // bg-white/20
    private static let closeOpacity: Double = 0.8        // opacity-80
    /// Grows the ~22 pt "Got it" pill's hit area to 44 pt (the ✕ to 46).
    private static let hitSlop: CGFloat = 11
    private static let shadowOpacity: Double = 0.15      // shadow-lg
    private static let shadowRadius: CGFloat = 8
    private static let shadowOffsetY: CGFloat = 4
    private static let riseDistance: CGFloat = 10        // translateY(10px)
    private static let fadeSeconds: Double = 0.5
}

/// Web `active:scale-95` — a small press-in; a dim instead under Reduce Motion.
private struct HintButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let pressedScale: CGFloat = 0.95
    private static let pressedOpacity: Double = 0.7
    private static let pressSeconds: Double = 0.12

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? Self.pressedScale : 1)
            .opacity(configuration.isPressed && reduceMotion ? Self.pressedOpacity : 1)
            .animation(.easeOut(duration: Self.pressSeconds), value: configuration.isPressed)
    }
}

/// The bubble's small triangle, pointing up at the banner.
private struct HintArrow: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("SurahHintBubble") {
    VStack(spacing: 24) {
        SurahHintBubble(text: String(localized: "surah_hint"), dismissText: String(localized: "surah_hint_ok")) {}
        SurahHintBubble(text: "Нажмите на название суры — она будет прочитана целиком", dismissText: "Понятно") {}
    }
    .padding(24)
    .frame(width: 390)
    .background(AppColor.background)
}
#endif
