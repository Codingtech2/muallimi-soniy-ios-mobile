import SwiftUI

/// What the reader's download UI shows, collapsed from the shared
/// `AudioDownloadManager` — its live `phase` plus the cross-launch `isReady`
/// flag. `fraction` is the overall 0…1 progress across download, extract and
/// verify, so the bar only ever moves forward.
enum AudioDownloadStatus {
    case notDownloaded
    /// `stageKey` is the localization key of the running stage.
    case working(stageKey: String, fraction: Double)
    case ready
    case failed(String)

    init(_ manager: AudioDownloadManager) {
        switch manager.phase {
        case .idle:
            // A pack installed on a previous launch is ready even though the
            // pipeline hasn't run this session.
            self = manager.isReady ? .ready : .notDownloaded
        case .checking:
            self = .working(stageKey: "offline_idle", fraction: manager.progressFraction)
        case .downloading:
            self = .working(stageKey: "downloading", fraction: manager.progressFraction)
        case .extracting:
            self = .working(stageKey: "extracting", fraction: manager.progressFraction)
        case .verifying:
            self = .working(stageKey: "offline_scanning", fraction: manager.progressFraction)
        case .ready:
            self = .ready
        case .failed(let message):
            self = .failed(message)
        }
    }

    /// Whole-number percent for a 0…1 fraction.
    static func percent(_ fraction: Double) -> Int {
        Int((fraction * 100).rounded())
    }
}

/// The reader's audio download prompt. It replaced a system alert that closed
/// on "Download now" and left no sign the 127 MB pack was on its way (tapping
/// again just offered the download again). This sheet stays open and follows
/// the download through every stage — offer, live progress, ready, failed.
/// Closing it never stops the download; the reader's `AudioDownloadStrip`
/// keeps showing it until the pack is ready.
struct AudioDownloadSheet: View {
    /// Runs right after the ready state's play button closes the sheet.
    let onPlay: () -> Void

    @Environment(AudioDownloadManager.self) private var manager
    @Environment(ContentStore.self) private var content
    @Environment(SettingsStore.self) private var settings
    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.dismiss) private var dismiss

    /// Measured height of the content, so the sheet hugs it instead of
    /// covering half the screen.
    @State private var contentHeight: CGFloat = 320

    private var locale: AppLocale { settings.settings.locale }
    private var status: AudioDownloadStatus { AudioDownloadStatus(manager) }
    private func tr(_ key: String) -> String { content.t(key, locale) }

    var body: some View {
        VStack(spacing: 16 * layoutMetrics.uiScale) {
            switch status {
            case .notDownloaded:
                offerContent
            case .working(let stageKey, let fraction):
                workingContent(stageKey: stageKey, fraction: fraction)
            case .ready:
                readyContent
            case .failed(let message):
                failedContent(message)
            }
        }
        .padding(.horizontal, 24 * layoutMetrics.uiScale)
        .padding(.top, 28 * layoutMetrics.uiScale)
        .padding(.bottom, 12 * layoutMetrics.uiScale)
        .frame(maxWidth: layoutMetrics.isRegular ? 520 : .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .animation(.easeInOut(duration: 0.25), value: stateKey)
    }

    /// Coarse key so only real state changes animate, not every progress tick.
    private var stateKey: Int {
        switch status {
        case .notDownloaded: return 0
        case .working: return 1
        case .ready: return 2
        case .failed: return 3
        }
    }

    // MARK: - States

    private var offerContent: some View {
        Group {
            header(
                icon: "icloud.and.arrow.down",
                tint: AppColor.primary,
                title: tr("audio_not_downloaded"),
                message: tr("audio_not_downloaded_desc")
            )
            primaryButton(tr("download_now"), systemImage: "arrow.down.circle.fill") {
                Task { await manager.ensureReady() }
            }
            secondaryButton(tr("cancel"))
        }
    }

    private func workingContent(stageKey: String, fraction: Double) -> some View {
        let percent = "\(AudioDownloadStatus.percent(fraction))%"
        return Group {
            header(icon: "icloud.and.arrow.down", tint: AppColor.primary, title: tr(stageKey), message: nil)
            VStack(spacing: 8 * layoutMetrics.uiScale) {
                ProgressView(value: fraction)
                    .tint(AppColor.primary)
                Text(percent)
                    .font(layoutMetrics.font(.title3.weight(.semibold), .title2.weight(.semibold)))
                    .monospacedDigit()
                    .foregroundStyle(AppColor.textMain)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tr(stageKey))
            .accessibilityValue(percent)
            .accessibilityAddTraits(.updatesFrequently)
            Text(tr("download_continues_hint"))
                .font(layoutMetrics.font(.footnote, .body))
                .foregroundStyle(AppColor.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            secondaryButton(tr("close"))
        }
    }

    private var readyContent: some View {
        Group {
            header(icon: "checkmark.circle.fill", tint: AppColor.primary, title: tr("offline_ready"), message: nil)
            primaryButton(tr("play"), systemImage: "play.fill") {
                dismiss()
                onPlay()
            }
            secondaryButton(tr("close"))
        }
    }

    private func failedContent(_ message: String) -> some View {
        Group {
            header(icon: "exclamationmark.triangle.fill", tint: .red, title: tr("download_error"), message: message)
            primaryButton(tr("retry"), systemImage: "arrow.clockwise") {
                Task { await manager.ensureReady() }
            }
            secondaryButton(tr("close"))
        }
    }

    // MARK: - Building blocks

    private func header(icon: String, tint: Color, title: String, message: String?) -> some View {
        VStack(spacing: 10 * layoutMetrics.uiScale) {
            Image(systemName: icon)
                .font(.system(size: 24 * layoutMetrics.uiScale, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 56 * layoutMetrics.uiScale, height: 56 * layoutMetrics.uiScale)
                .background(tint.opacity(0.15), in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(layoutMetrics.font(.title3.weight(.semibold), .title2.weight(.semibold)))
                .foregroundStyle(AppColor.textMain)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let message {
                Text(message)
                    .font(layoutMetrics.font(.subheadline, .body))
                    .foregroundStyle(AppColor.textMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(layoutMetrics.font(.headline, .title3.weight(.semibold)))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50 * layoutMetrics.uiScale)
                .background(AppColor.primaryButton, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4 * layoutMetrics.uiScale)
    }

    /// Closes the sheet. The download, if one is running, keeps going.
    private func secondaryButton(_ title: String) -> some View {
        Button(title) { dismiss() }
            .font(layoutMetrics.font(.body.weight(.medium), .title3.weight(.medium)))
            .foregroundStyle(AppColor.controlTint)
            .frame(maxWidth: .infinity, minHeight: 44 * layoutMetrics.uiScale)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }
}
