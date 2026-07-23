import SwiftUI

/// Shared "Aa" text-size slider: a title + live percentage readout above, a
/// small "A" / large "A" flanking the slider itself (the same shape as
/// Apple's own Dynamic Type slider). One control, two call sites — the
/// reader's `ReadingOptionsSheet` and the Settings screen's font-size
/// section — so there is exactly one text-scale slider in the app (plan A6).
///
/// Visual language matches the audio sliders in `SettingsView`
/// (`AudioSliderRow`): title left, live value right, `.tint(AppColor.primary)`.
struct TextScaleSlider: View {
    let title: String
    @Binding var value: Double

    @Environment(\.layoutMetrics) private var layoutMetrics

    /// Bounds + step mirror `SettingsStore`'s own text-scale clamp range
    /// (0.8…2.5, step 0.05) — kept here too since the store's range is a
    /// private implementation detail of its clamping, not a public API.
    private static let range: ClosedRange<Double> = 0.8...2.5
    private static let step = 0.05

    var body: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.isRegular ? 12 : 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(layoutMetrics.isRegular ? .title3.weight(.medium) : .subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textMain)
                Spacer(minLength: 8)
                Text(display)
                    .font(.system(size: layoutMetrics.isRegular ? 20 : 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColor.primary)
                    .monospacedDigit()
            }
            HStack(spacing: 12) {
                Text("A")
                    .font(.system(size: layoutMetrics.isRegular ? 15 : 12, weight: .semibold))
                    .foregroundStyle(AppColor.textMuted)
                Slider(value: $value, in: Self.range, step: Self.step)
                    .tint(AppColor.primary)
                    .accessibilityLabel(title)
                    .accessibilityValue(display)
                Text("A")
                    .font(.system(size: layoutMetrics.isRegular ? 28 : 22, weight: .semibold))
                    .foregroundStyle(AppColor.textMuted)
            }
        }
    }

    /// Percentage readout — 1.0× reads "100%", matching the 0.8…2.5 scale.
    private var display: String { "\(Int((value * 100).rounded()))%" }
}

#if DEBUG
private struct TextScaleSliderPreview: View {
    @State private var value: Double = 1.0
    var body: some View {
        TextScaleSlider(title: "Matn o'lchami", value: $value)
            .padding(24)
            .background(AppColor.background)
    }
}

#Preview("TextScaleSlider") {
    TextScaleSliderPreview()
}
#endif
