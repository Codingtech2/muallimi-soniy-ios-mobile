import SwiftUI

/// "Eng yaqin masjidlar": the closest mosques (five, three on short
/// screens) with distance and an estimated walk. Tapping a row chooses that
/// mosque (the map follows).
struct MosqueNearbyList: View {
    let locale: AppLocale
    var limit = MosqueLayout.nearbyCount

    @Environment(MosqueStore.self) private var mosques
    @Environment(ContentStore.self) private var content
    @Environment(\.layoutMetrics) private var layoutMetrics

    private var scale: CGFloat { layoutMetrics.uiScale }
    private var formatter: MosqueFormatter { MosqueFormatter(content: content, mosques: mosques, locale: locale) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            header
            if mosques.nearby.isEmpty {
                Text(content.t("mosques_none_nearby", locale))
                    .font(layoutMetrics.font(.subheadline, .body))
                    .foregroundStyle(AppColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                ForEach(Array(mosques.nearby.prefix(limit).enumerated()), id: \.element.id) { index, item in
                    if index > 0 { divider }
                    MosqueRow(
                        title: formatter.name(of: item.mosque),
                        detail: formatter.summary(meters: item.meters),
                        spokenDetail: formatter.spokenSummary(meters: item.meters)
                    ) {
                        mosques.select(item.mosque)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8 * scale) {
            HomeSectionLabel(text: content.t("mosques_nearest", locale))
            Spacer(minLength: 8)
            Button {
                Task { await mosques.locateUser() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14 * scale, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 32 * scale, height: 32 * scale)
                    .background(AppColor.surface, in: Circle())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MosqueRowButtonStyle())
            .accessibilityLabel(content.t("mosques_refresh_location", locale))
        }
    }

    /// Hairline between rows, starting under the text (not the icon).
    private var divider: some View {
        Rectangle()
            .fill(AppColor.divider.opacity(0.6))
            .frame(height: 0.5)
            .padding(.leading, (MosqueRow.iconSide + 12) * scale)
    }
}

/// One tappable mosque line: crescent chip, name, a muted detail line and a
/// chevron. VoiceOver hears it as one button — "<name>, 350 m, taxminan
/// 5 daqiqa piyoda".
struct MosqueRow: View {
    let title: String
    let detail: String?
    var spokenDetail: String?
    var trailing: String?
    let action: () -> Void

    static let iconSide: CGFloat = 36

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        let scale = layoutMetrics.uiScale
        Button(action: action) {
            HStack(spacing: 12 * scale) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
                    .frame(width: Self.iconSide * scale, height: Self.iconSide * scale)
                    .background(AppColor.primary.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2 * scale) {
                    Text(title)
                        .font(layoutMetrics.font(.subheadline.weight(.semibold), .body.weight(.semibold)))
                        .foregroundStyle(AppColor.textMain)
                        .lineLimit(3)
                    if let detail {
                        Text(detail)
                            .font(layoutMetrics.font(.caption, .subheadline))
                            .foregroundStyle(AppColor.textMuted)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if let trailing {
                    Text(trailing)
                        .font(layoutMetrics.font(.subheadline.weight(.medium), .body.weight(.medium)))
                        .monospacedDigit()
                        .foregroundStyle(AppColor.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12 * scale, weight: .semibold))
                    .foregroundStyle(AppColor.textMuted)
            }
            .padding(.vertical, 6 * scale)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(MosqueRowButtonStyle())
        .accessibilityLabel(spokenLabel)
    }

    private var spokenLabel: String {
        [title, spokenDetail ?? detail, trailing].compactMap { $0 }.joined(separator: ", ")
    }
}
