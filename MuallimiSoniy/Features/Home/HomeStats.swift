import SwiftUI

/// Home's three stat tiles (progress %, lessons done, audio state) as plain
/// siblings with no container of their own, so the caller lays them out: a
/// row of tiles on iPhone (a column of rows at accessibility text sizes),
/// three grid cells on iPad.
struct HomeStatTiles: View {
    let store: ContentStore
    let progress: ProgressStore
    let audio: AudioDownloadManager
    let locale: AppLocale
    /// `.vertical` stacks icon / value / label in a tile; `.horizontal` puts
    /// them in one row for accessibility text sizes.
    let axis: Axis

    private var percent: Int {
        let total = max(store.totalPages - 1, 1)
        return Int((Double(progress.resumeGlobalIndex) / Double(total) * 100).rounded())
    }
    private var completedLessons: Int { progress.completedLessons.count }
    private var totalLessons: Int { store.outline.reduce(0) { $0 + $1.lessons.count } }

    var body: some View {
        HomeStatTile(
            symbol: "chart.bar.fill",
            value: .text("\(percent)%"),
            label: store.t("stat_done", locale),
            spokenValue: "\(percent)%",
            axis: axis
        )
        HomeStatTile(
            symbol: "checkmark.seal.fill",
            value: .text("\(completedLessons)/\(totalLessons)"),
            label: store.t("lessons", locale),
            spokenValue: String(format: store.t("a11y_page_value", locale), "\(completedLessons)", "\(totalLessons)"),
            axis: axis
        )
        HomeStatTile(
            symbol: audio.isReady ? "checkmark.icloud.fill" : "icloud.and.arrow.down.fill",
            value: .symbol(audio.isReady ? "checkmark" : "arrow.down"),
            label: store.t(audio.isReady ? "stat_audio_ready" : "stat_audio_get", locale),
            spokenValue: nil,
            axis: axis
        )
    }
}

/// One stat: decorative icon, big rounded value, small caps label. VoiceOver
/// gets a single stop per tile — the label plus its value — never the SF
/// Symbol names.
private struct HomeStatTile: View {
    enum Value {
        case text(String)
        case symbol(String)
    }

    let symbol: String
    let value: Value
    let label: String
    /// Read after the label; `nil` when the label already says it all.
    let spokenValue: String?
    let axis: Axis

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        content
            .padding(.vertical, layoutMetrics.isRegular ? 22 : 14)
            .padding(.horizontal, layoutMetrics.isRegular ? 16 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: axis == .vertical ? .center : .leading)
            .glassCard(cornerRadius: layoutMetrics.isRegular ? 22 : 18)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(spokenValue ?? "")
    }

    @ViewBuilder
    private var content: some View {
        if axis == .vertical {
            VStack(spacing: layoutMetrics.isRegular ? 8 : 5) {
                icon
                valueView
                labelView
            }
            .multilineTextAlignment(.center)
        } else {
            HStack(spacing: 14) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    valueView
                    labelView
                }
            }
            .padding(.horizontal, 6)
        }
    }

    private var icon: some View {
        Image(systemName: symbol)
            .font(layoutMetrics.font(.footnote, .title3))
            .foregroundStyle(AppColor.primary)
    }

    private var valueView: some View {
        Group {
            switch value {
            case .text(let text):
                Text(text).monospacedDigit()
            case .symbol(let name):
                Image(systemName: name)
            }
        }
        .font(layoutMetrics.font(.title2.weight(.bold), .largeTitle.weight(.bold)))
        .fontDesign(.rounded)
        .foregroundStyle(AppColor.textMain)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private var labelView: some View {
        Text(label)
            .font(layoutMetrics.font(.caption2.weight(.semibold), .subheadline.weight(.semibold)))
            .homeCapsLabel()
            .foregroundStyle(AppColor.textMuted)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }
}
