import SwiftUI

/// Settings card that drives the one-shot audio-pack download, mirroring the web
/// `OfflineCard`. Bound to the shared `AudioDownloadManager` from the
/// environment; it reads `phase` / `isReady` and calls `ensureReady()` /
/// `reset()`. Four visual states: idle, working (checking / downloading /
/// extracting / verifying), ready, and failed.
struct OfflineCard: View {
    @Environment(AudioDownloadManager.self) private var manager
    @Environment(ContentStore.self) private var content
    @Environment(SettingsStore.self) private var settings
    @Environment(\.layoutMetrics) private var layoutMetrics

    private var locale: AppLocale { settings.settings.locale }
    private func tr(_ key: String) -> String { content.t(key, locale) }

    var body: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.isRegular ? 18 : 14) {
            switch viewState {
            case .idle:
                idleContent
            case .working(let label, let fraction):
                workingContent(label: label, fraction: fraction)
            case .ready:
                readyContent
            case .failed(let message):
                failedContent(message)
            }
        }
        .padding(layoutMetrics.isRegular ? 22 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.glass, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(AppColor.divider, lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.25), value: stateKey)
    }

    // MARK: - View state

    /// Collapses the manager's `Phase` (plus the cross-launch `isReady` flag)
    /// into exactly what the card needs to render.
    private enum ViewState {
        case idle
        case working(label: String, fraction: Double?)   // nil fraction = indeterminate
        case ready
        case failed(String)
    }

    private var viewState: ViewState {
        switch manager.phase {
        case .ready:
            return .ready
        case .failed(let message):
            return .failed(message)
        case .checking:
            return .working(label: tr("offline_idle"), fraction: nil)
        case .downloading(let fraction):
            return .working(label: "\(tr("downloading")) \(percent(fraction))%", fraction: fraction)
        case .extracting(let fraction):
            return .working(label: tr("extracting"), fraction: fraction)
        case .verifying(let fraction):
            return .working(label: tr("offline_scanning"), fraction: fraction)
        case .idle:
            // A pack installed on a previous launch reports ready even though the
            // pipeline hasn't run this session.
            return manager.isReady ? .ready : .idle
        }
    }

    /// Coarse key so only real state transitions animate — not every progress tick.
    private var stateKey: Int {
        switch viewState {
        case .idle: return 0
        case .working: return 1
        case .ready: return 2
        case .failed: return 3
        }
    }

    private func percent(_ fraction: Double) -> Int {
        Int((fraction * 100).rounded())
    }

    // MARK: - States

    private var idleContent: some View {
        Group {
            header(
                icon: "icloud.and.arrow.down",
                title: tr("offline_audio"),
                subtitle: tr("offline_card_desc")
            )
            primaryButton(tr("download"), systemImage: "arrow.down.circle.fill") {
                Task { await manager.ensureReady() }
            }
        }
    }

    @ViewBuilder
    private func workingContent(label: String, fraction: Double?) -> some View {
        header(icon: "icloud.and.arrow.down", title: tr("offline_audio"), subtitle: nil)

        if let fraction {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: fraction)
                    .tint(AppColor.primary)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppColor.textMuted)
            }
        } else {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppColor.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var readyContent: some View {
        Group {
            header(
                icon: "checkmark.circle.fill",
                title: tr("offline_ready"),
                subtitle: nil
            )
            Button {
                Task {
                    manager.reset()
                    await manager.ensureReady()
                }
            } label: {
                Label(tr("redownload"), systemImage: "arrow.clockwise")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColor.textMuted)
            }
            .buttonStyle(.plain)
        }
    }

    private func failedContent(_ message: String) -> some View {
        Group {
            HStack(alignment: .top, spacing: 12) {
                iconChip("exclamationmark.triangle.fill", tint: .red)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("download_error"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textMain)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(AppColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.20), lineWidth: 0.5)
            )

            primaryButton(tr("retry"), systemImage: "arrow.clockwise") {
                Task { await manager.ensureReady() }
            }
        }
    }

    // MARK: - Building blocks

    private func header(icon: String, title: String, subtitle: String?) -> some View {
        HStack(alignment: .top, spacing: layoutMetrics.isRegular ? 16 : 12) {
            iconChip(icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(layoutMetrics.isRegular ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textMain)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(layoutMetrics.isRegular ? .subheadline : .caption)
                        .foregroundStyle(AppColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func iconChip(_ systemName: String, tint: Color = AppColor.primary) -> some View {
        let side: CGFloat = layoutMetrics.isRegular ? 48 : 36
        return Image(systemName: systemName)
            .font(.system(size: layoutMetrics.isRegular ? 22 : 17, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: side, height: side)
            .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func primaryButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(layoutMetrics.isRegular ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: layoutMetrics.isRegular ? 58 : 46)
            .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OfflineCard()
        .environment(AudioDownloadManager())
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background)
}
