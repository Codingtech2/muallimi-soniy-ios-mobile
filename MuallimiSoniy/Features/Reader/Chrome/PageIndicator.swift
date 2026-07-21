import SwiftUI

/// The whole-book page indicator — the SwiftUI port of the web `PageIndicator`.
///
/// A single row: a `‹` chevron, a draggable / tappable progress bar spanning the
/// whole book, the "X / total" position inline, and a `›` chevron. Tapping or
/// dragging the bar maps the touch x-position to a page index
/// (`round(ratio * (total - 1))`, exactly like the web) and reports it through
/// `onSelect`. Chevrons step one page and disable at the ends.
struct ReaderPageIndicator: View {
    let total: Int
    /// 0-based current page.
    let current: Int
    /// Localised accessibility labels for the step chevrons.
    let prevLabel: String
    let nextLabel: String
    /// Reports a 0-based target page.
    let onSelect: (Int) -> Void

    /// De-dupes drag emissions so a continuous drag fires `onSelect` once per
    /// distinct target page (mirrors the web `if (idx !== current)` guard).
    @State private var lastEmitted: Int?

    private var canPrev: Bool { current > 0 }
    private var canNext: Bool { current < total - 1 }

    var body: some View {
        HStack(spacing: 12) {
            chevron("chevron.left", enabled: canPrev, label: prevLabel) {
                if canPrev { onSelect(current - 1) }
            }

            bar

            Text("\(current + 1) / \(total)")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(AppColor.textMuted)
                .frame(minWidth: 52)
                .multilineTextAlignment(.center)

            chevron("chevron.right", enabled: canNext, label: nextLabel) {
                if canNext { onSelect(current + 1) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        // Floating Liquid-Glass pill (real glass on iOS 26, frosted material +
        // hairline below). The green progress bar keeps its accent on top.
        .glassCard(cornerRadius: 24)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Progress bar

    private var bar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pct = total > 0 ? CGFloat(current + 1) / CGFloat(total) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(AppColor.divider).frame(height: 8)
                Capsule().fill(AppColor.primary).frame(width: max(8, width * pct), height: 8)
                Circle()
                    .fill(AppColor.primary)
                    .frame(width: 16, height: 16)
                    .shadow(color: AppColor.primaryGlow, radius: 4, x: 0, y: 1)
                    .offset(x: min(max(width * pct - 8, 0), width - 16))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let index = pageIndex(atX: value.location.x, width: width)
                        guard index != lastEmitted else { return }
                        lastEmitted = index
                        if index != current { onSelect(index) }
                    }
                    .onEnded { _ in lastEmitted = nil }
            )
            .animation(.easeOut(duration: 0.25), value: current)
        }
        .frame(height: 20)
        .frame(maxWidth: .infinity)
    }

    /// Maps a touch x within `width` to a 0-based page index.
    private func pageIndex(atX x: CGFloat, width: CGFloat) -> Int {
        guard width > 0, total > 1 else { return current }
        let ratio = min(max(x / width, 0), 1)
        return Int((ratio * CGFloat(total - 1)).rounded())
    }

    // MARK: - Chevrons

    private func chevron(
        _ system: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColor.textMain)
                .frame(width: 36, height: 36)
                .background(AppColor.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}

#if DEBUG
private struct PageIndicatorPreview: View {
    @State private var current = 12
    var body: some View {
        ReaderPageIndicator(total: 52, current: current, prevLabel: "Oldingi", nextLabel: "Keyingi") { current = $0 }
            .padding(.vertical, 24)
            .background(AppColor.background)
    }
}

#Preview("ReaderPageIndicator") { PageIndicatorPreview() }
#endif
