import SwiftUI

/// The children's way in: one big, calm card into the hifz (memorization)
/// surah list, with a live "X/26 yodlandi" count. The caller hides it when
/// the catalog failed to build (`HifzCatalog.empty`).
///
/// A row on iPhone; a tall tile beside the Continue card on iPad and at
/// accessibility text sizes, where the title needs the card's full width.
struct HomeHifzCard: View {
    let store: ContentStore
    let progress: ProgressStore
    let locale: AppLocale

    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var title: String { store.t("hifz_list_title", locale) }
    private var subtitle: String {
        String(
            format: store.t("hifz_memorized_count", locale),
            "\(progress.memorizedCount)",
            "\(store.hifzCatalog.surahs.count)"
        )
    }
    private var isTile: Bool { layoutMetrics.isRegular || dynamicTypeSize.isAccessibilitySize }
    private var badgeSide: CGFloat { layoutMetrics.isRegular ? 76 : 56 }
    private var chevronSide: CGFloat { layoutMetrics.isRegular ? 40 : 32 }
    private var cornerRadius: CGFloat { layoutMetrics.isRegular ? 30 : 24 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        NavigationLink(value: HifzListRoute()) {
            Group {
                if isTile { tile } else { row }
            }
            .padding(layoutMetrics.isRegular ? 24 : 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassCard(cornerRadius: cornerRadius)
            .contentShape(shape)
        }
        .buttonStyle(HomeCardButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
    }

    private var row: some View {
        HStack(spacing: 14 * layoutMetrics.uiScale) {
            badge
            labels
            Spacer(minLength: 0)
            chevron
        }
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 16 * layoutMetrics.uiScale) {
            HStack(alignment: .top) {
                badge
                Spacer(minLength: 8)
                chevron
            }
            Spacer(minLength: 0)
            labels
        }
    }

    /// Gilt "repeat" mark — the one warm accent on Home.
    private var badge: some View {
        Image(systemName: "repeat")
            .font(.system(size: badgeSide * 0.4, weight: .semibold))
            .foregroundStyle(AppColor.gold)
            .frame(width: badgeSide, height: badgeSide)
            .background(AppColor.gold.opacity(0.16), in: Circle())
            .accessibilityHidden(true)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 3 * layoutMetrics.uiScale) {
            Text(title)
                .font(layoutMetrics.font(.title3.weight(.semibold), .title2.weight(.semibold)))
                .fontDesign(.rounded)
                .foregroundStyle(AppColor.textMain)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(layoutMetrics.font(.subheadline, .title3))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(AppColor.textMuted)
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: chevronSide * 0.42, weight: .semibold))
            .foregroundStyle(AppColor.textMuted)
            .frame(width: chevronSide, height: chevronSide)
            .background(AppColor.surface, in: Circle())
            .accessibilityHidden(true)
    }
}
