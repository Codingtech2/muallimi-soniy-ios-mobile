import SwiftUI

/// One Home stat: decorative icon, big rounded value, small caps label, and
/// what VoiceOver reads after the label (`nil` when the label says it all).
struct HomeStat: Identifiable {
    enum Value {
        case text(String)
        case symbol(String)
    }

    let id: String
    let symbol: String
    let value: Value
    let label: String
    let spokenValue: String?
    /// Set on the audio cell while the pack is missing: tapping starts the
    /// download, so a label that says "download" is not a dead end.
    var action: (() -> Void)? = nil

    /// The three stats (progress %, lessons done, audio state), computed in
    /// one place so the iPhone tiles and the iPad strip always agree.
    static func all(
        store: ContentStore,
        progress: ProgressStore,
        audio: AudioDownloadManager,
        locale: AppLocale
    ) -> [HomeStat] {
        let lastPage = max(store.totalPages - 1, 1)
        let percent = Int((Double(progress.resumeGlobalIndex) / Double(lastPage) * 100).rounded())
        let completedLessons = progress.completedLessons.count
        let totalLessons = store.outline.reduce(0) { $0 + $1.lessons.count }
        return [
            HomeStat(
                id: "progress",
                symbol: "chart.bar.fill",
                value: .text("\(percent)%"),
                label: store.t("stat_done", locale),
                spokenValue: "\(percent)%"
            ),
            HomeStat(
                id: "lessons",
                symbol: "checkmark.seal.fill",
                value: .text("\(completedLessons)/\(totalLessons)"),
                label: store.t("lessons", locale),
                spokenValue: String(format: store.t("a11y_page_value", locale), "\(completedLessons)", "\(totalLessons)")
            ),
            audioStat(store: store, audio: audio, locale: locale)
        ]
    }

    /// The audio-pack cell: a tappable download while the pack is missing, a
    /// live percentage while it installs, a checkmark once it is verified.
    private static func audioStat(
        store: ContentStore,
        audio: AudioDownloadManager,
        locale: AppLocale
    ) -> HomeStat {
        if audio.isReady {
            return HomeStat(
                id: "audio",
                symbol: "checkmark.icloud.fill",
                value: .symbol("checkmark"),
                label: store.t("stat_audio_ready", locale),
                spokenValue: nil
            )
        }
        switch audio.phase {
        case .checking, .downloading, .extracting, .verifying:
            let percent = "\(Int((audio.progressFraction * 100).rounded()))%"
            return HomeStat(
                id: "audio",
                symbol: "icloud.and.arrow.down.fill",
                value: .text(percent),
                label: store.t("downloading", locale),
                spokenValue: percent
            )
        case .idle, .ready, .failed:
            return HomeStat(
                id: "audio",
                symbol: "icloud.and.arrow.down.fill",
                value: .text(store.t("download", locale)),
                label: store.t("stat_audio_get", locale),
                spokenValue: nil,
                action: { Task { await audio.ensureReady() } }
            )
        }
    }
}

/// Home's three stat tiles as plain siblings with no container of their own,
/// so the caller lays them out: a row of tiles on iPhone, a column of rows at
/// accessibility text sizes.
struct HomeStatTiles: View {
    let store: ContentStore
    let progress: ProgressStore
    let audio: AudioDownloadManager
    let locale: AppLocale
    /// `.vertical` stacks icon / value / label in a tile; `.horizontal` puts
    /// them in one row for accessibility text sizes.
    let axis: Axis

    var body: some View {
        ForEach(HomeStat.all(store: store, progress: progress, audio: audio, locale: locale)) { stat in
            HomeStatTile(stat: stat, axis: axis)
        }
    }
}

/// iPad: the three stats in one glass strip — an icon chip with the value and
/// label beside it per segment, hairlines between — one calm row instead of
/// three small cards competing with the chapter grid below.
struct HomeStatsStrip: View {
    let store: ContentStore
    let progress: ProgressStore
    let audio: AudioDownloadManager
    let locale: AppLocale

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        let stats = HomeStat.all(store: store, progress: progress, audio: audio, locale: locale)
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                if index > 0 {
                    Rectangle()
                        .fill(AppColor.divider)
                        .frame(width: 1)
                        .padding(.vertical, 6)
                }
                HomeStatSegment(stat: stat)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 24)
    }
}

/// One strip segment. VoiceOver gets a single stop — the label plus its
/// value — never the SF Symbol names.
private struct HomeStatSegment: View {
    let stat: HomeStat

    var body: some View {
        if let action = stat.action {
            Button(action: action) { content }
                .buttonStyle(HomeCardButtonStyle())
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 14) {
            Image(systemName: stat.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColor.primary)
                .frame(width: 48, height: 48)
                .background(AppColor.primary.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HomeStatValue(value: stat.value)
                    .font(.title.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(stat.action == nil ? AppColor.textMain : AppColor.primary)
                    // Numbers stay on one line; the "download" word may wrap
                    // in a narrow Split View pane instead of truncating.
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(stat.label)
                    .font(.subheadline.weight(.semibold))
                    .homeCapsLabel()
                    .foregroundStyle(AppColor.textMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stat.label)
        .accessibilityValue(stat.spokenValue ?? "")
    }
}

/// One stat tile (iPhone): decorative icon, big rounded value, small caps
/// label. VoiceOver gets a single stop per tile — the label plus its value —
/// never the SF Symbol names.
private struct HomeStatTile: View {
    let stat: HomeStat
    let axis: Axis

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        if let action = stat.action {
            Button(action: action) { tile }
                .buttonStyle(HomeCardButtonStyle())
        } else {
            tile
        }
    }

    private var tile: some View {
        content
            .padding(.vertical, layoutMetrics.isRegular ? 22 : 14)
            .padding(.horizontal, layoutMetrics.isRegular ? 16 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: axis == .vertical ? .center : .leading)
            .glassCard(cornerRadius: layoutMetrics.isRegular ? 22 : 18)
            .contentShape(RoundedRectangle(cornerRadius: layoutMetrics.isRegular ? 22 : 18, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(stat.label)
            .accessibilityValue(stat.spokenValue ?? "")
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
        Image(systemName: stat.symbol)
            .font(layoutMetrics.font(.footnote, .title3))
            .foregroundStyle(AppColor.primary)
    }

    private var valueView: some View {
        HomeStatValue(value: stat.value)
            .font(layoutMetrics.font(.title2.weight(.bold), .largeTitle.weight(.bold)))
            .fontDesign(.rounded)
            .foregroundStyle(stat.action == nil ? AppColor.textMain : AppColor.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var labelView: some View {
        Text(stat.label)
            .font(layoutMetrics.font(.caption2.weight(.semibold), .subheadline.weight(.semibold)))
            .homeCapsLabel()
            .foregroundStyle(AppColor.textMuted)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }
}

/// The value glyphs: text with tabular digits, or an SF Symbol.
private struct HomeStatValue: View {
    let value: HomeStat.Value

    var body: some View {
        switch value {
        case .text(let text): Text(text).monospacedDigit()
        case .symbol(let name): Image(systemName: name)
        }
    }
}
