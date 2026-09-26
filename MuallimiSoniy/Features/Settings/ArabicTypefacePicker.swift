import SwiftUI

/// Picks the book's Arabic typeface from two sample cards, each drawing the
/// same short line in its own font. The line holds harakat, a shadda with
/// kasra and a tanwin — the marks that differ most between the two. Used by
/// the reader's "Aa" sheet and by Settings.
struct ArabicTypefacePicker: View {
    let selection: ArabicTypeface
    let onSelect: (ArabicTypeface) -> Void

    @Environment(\.layoutMetrics) private var layoutMetrics

    private static let sample = "بَ بِ بُ رَبِّ كِتَابٌ"

    var body: some View {
        HStack(spacing: 10 * layoutMetrics.uiScale) {
            ForEach(ArabicTypeface.allCases, id: \.self) { typeface in
                card(for: typeface)
            }
        }
    }

    private func card(for typeface: ArabicTypeface) -> some View {
        let selected = selection == typeface
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            onSelect(typeface)
        } label: {
            VStack(spacing: 6 * layoutMetrics.uiScale) {
                Text(Self.sample)
                    .font(arabicFont(22 * layoutMetrics.uiScale, typeface: typeface))
                    .foregroundStyle(AppColor.textMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .environment(\.layoutDirection, .rightToLeft)
                    .accessibilityHidden(true)
                Text(typeface.displayName)
                    .font(layoutMetrics.font(.caption.weight(.medium), .subheadline.weight(.medium)))
                    .foregroundStyle(selected ? AppColor.primary : AppColor.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12 * layoutMetrics.uiScale)
            .padding(.horizontal, 8 * layoutMetrics.uiScale)
            .background(selected ? AppColor.primary.opacity(0.18) : AppColor.surface.opacity(0.6), in: shape)
            .overlay(
                shape.strokeBorder(
                    selected ? AppColor.primary.opacity(0.4) : AppColor.divider.opacity(0.4),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(typeface.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
