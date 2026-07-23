import SwiftUI

/// First-run screen. Lets the user pick interface language + light/dark up front
/// (everything starts here), explains the app, then offers a ONE-tap audio
/// download (~127 MB) with real-time progress so playback later is fully offline
/// with no per-tap network stalls. The download runs on the shared
/// `AudioDownloadManager`, so "Boshlash" can dismiss onboarding while it keeps
/// downloading in the background (progress stays visible in Sozlamalar → Offline).
struct OnboardingView: View {
    @Environment(AudioDownloadManager.self) private var manager
    @Environment(ContentStore.self) private var content
    @Environment(SettingsStore.self) private var settings
    @Environment(\.layoutMetrics) private var layoutMetrics
    /// Called when the user is ready to enter the app (downloaded, skipped, or
    /// chose to continue in the background).
    let onDone: () -> Void

    private var locale: AppLocale { settings.settings.locale }
    private func tr(_ key: String) -> String { content.t(key, locale) }

    /// The identity logo is the same brand mark as `WelcomeGateView`'s, so it
    /// gets the same bigger-than-`uiScale` hero boost (compact stays 168).
    private var logoHeight: CGFloat { layoutMetrics.isRegular ? 244 : 168 }

    var body: some View {
        VStack(spacing: 0) {
            settingsBar
            Spacer(minLength: 20 * layoutMetrics.uiScale)
            identity
            Spacer().frame(height: 32 * layoutMetrics.uiScale)
            features
            Spacer(minLength: 24 * layoutMetrics.uiScale)
            downloadSection
        }
        .padding(24 * layoutMetrics.uiScale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background.ignoresSafeArea())
    }

    // MARK: - Language + theme selector

    /// Up-front language pills + a light/dark toggle. Both apply live: the whole
    /// screen re-localises and re-themes instantly as the user taps.
    private var settingsBar: some View {
        HStack(spacing: 6 * layoutMetrics.uiScale) {
            ForEach(Self.languageOptions, id: \.locale) { option in
                let selected = settings.settings.locale == option.locale
                Button { settings.setLocale(option.locale) } label: {
                    Text(option.short)
                        .font(layoutMetrics.font(.caption.weight(.semibold), .subheadline.weight(.semibold)))
                        .foregroundStyle(selected ? .white : AppColor.textMuted)
                        .padding(.horizontal, 11 * layoutMetrics.uiScale)
                        .padding(.vertical, 7 * layoutMetrics.uiScale)
                        .background(selected ? AppColor.primary : AppColor.surface, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
            }
            Spacer(minLength: 8 * layoutMetrics.uiScale)
            Button { settings.setTheme(isDark ? .light : .dark) } label: {
                Image(systemName: isDark ? "moon.stars.fill" : "sun.max.fill")
                    .font(.system(size: 16 * layoutMetrics.uiScale, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
                    .frame(width: 38 * layoutMetrics.uiScale, height: 38 * layoutMetrics.uiScale)
                    .glassCard(cornerRadius: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("theme"))
        }
    }

    private var isDark: Bool { settings.settings.theme == .dark }

    // MARK: - Identity

    private var identity: some View {
        VStack(spacing: 16 * layoutMetrics.uiScale) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(height: logoHeight)
                .accessibilityHidden(true)
            Text(tr("app_name"))
                .font(layoutMetrics.font(.largeTitle.bold(), .system(size: 46, weight: .bold)))
                .foregroundStyle(AppColor.textMain)
            Text(tr("book_tagline"))
                .font(layoutMetrics.font(.subheadline, .title3))
                .foregroundStyle(AppColor.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var features: some View {
        VStack(alignment: .leading, spacing: 16 * layoutMetrics.uiScale) {
            FeatureRow(symbol: "waveform", title: tr("ob_feat1_title"), subtitle: tr("ob_feat1_desc"))
            FeatureRow(symbol: "book.pages.fill", title: tr("ob_feat2_title"), subtitle: tr("ob_feat2_desc"))
            FeatureRow(symbol: "wifi.slash", title: tr("ob_feat3_title"), subtitle: tr("ob_feat3_desc"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Download section (state machine over AudioDownloadManager.phase)

    @ViewBuilder
    private var downloadSection: some View {
        switch state {
        case .idle:
            VStack(spacing: 12 * layoutMetrics.uiScale) {
                statusPanel {
                    Text(tr("ob_prompt"))
                        .font(layoutMetrics.font(.footnote, .subheadline))
                        .foregroundStyle(AppColor.textMuted)
                        .multilineTextAlignment(.center)
                }
                primaryButton(tr("ob_download"), systemImage: "arrow.down.circle.fill") {
                    Task { await manager.ensureReady() }
                }
                skipButton(tr("ob_later"))
            }

        case .working(let label, let fraction):
            VStack(spacing: 12 * layoutMetrics.uiScale) {
                statusPanel {
                    ProgressView(value: fraction)
                        .tint(AppColor.primary)
                    Text(label)
                        .font(layoutMetrics.font(.footnote, .subheadline))
                        .foregroundStyle(AppColor.textMuted)
                        .monospacedDigit()
                    Text(tr("ob_bg"))
                        .font(layoutMetrics.font(.caption2, .subheadline))
                        .foregroundStyle(AppColor.textMuted)
                }
                // The download continues in the background if they enter now.
                primaryButton(tr("start"), systemImage: "play.fill", action: onDone)
            }

        case .ready:
            VStack(spacing: 12 * layoutMetrics.uiScale) {
                statusPanel {
                    Label(tr("ob_ready"), systemImage: "checkmark.circle.fill")
                        .font(layoutMetrics.font(.subheadline.weight(.semibold), .title3.weight(.semibold)))
                        .foregroundStyle(AppColor.primary)
                }
                primaryButton(tr("start"), systemImage: "play.fill", action: onDone)
            }

        case .failed(let message):
            VStack(spacing: 12 * layoutMetrics.uiScale) {
                statusPanel {
                    Text(message)
                        .font(layoutMetrics.font(.caption, .subheadline))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                primaryButton(tr("retry"), systemImage: "arrow.clockwise") {
                    Task { await manager.ensureReady() }
                }
                skipButton(tr("ob_skip"))
            }
        }
    }

    /// Frosted glass status panel that hosts the informational content of each
    /// download state (info text, progress, ready/failed message). Keeps the
    /// solid-green CTA and text skip button as separate, dominant elements.
    private func statusPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10 * layoutMetrics.uiScale) {
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18 * layoutMetrics.uiScale)
        .padding(.vertical, 16 * layoutMetrics.uiScale)
        .glassCard(cornerRadius: 20)
    }

    // MARK: - State mapping

    private enum State {
        case idle
        case working(label: String, fraction: Double)
        case ready
        case failed(String)
    }

    private var state: State {
        switch manager.phase {
        case .ready: return .ready
        case .failed(let m): return .failed(m)
        case .checking: return .working(label: tr("offline_idle"), fraction: 0)
        case .downloading(let f): return .working(label: "\(tr("downloading")) \(Int((f * 100).rounded()))%", fraction: f)
        case .extracting(let f): return .working(label: tr("extracting"), fraction: f)
        case .verifying(let f): return .working(label: tr("offline_scanning"), fraction: f)
        case .idle: return manager.isReady ? .ready : .idle
        }
    }

    // MARK: - Building blocks

    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8 * layoutMetrics.uiScale) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(layoutMetrics.font(.headline, .title3.weight(.semibold)))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54 * layoutMetrics.uiScale)
            .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func skipButton(_ title: String) -> some View {
        Button(title, action: onDone)
            .font(layoutMetrics.font(.subheadline.weight(.medium), .title3.weight(.medium)))
            .foregroundStyle(AppColor.textMuted)
            .padding(.top, 2 * layoutMetrics.uiScale)
    }

    // MARK: - Language options

    private struct LanguageChoice {
        let locale: AppLocale
        let short: String
        let name: String
    }

    private static let languageOptions: [LanguageChoice] = [
        LanguageChoice(locale: .uzLatn, short: "OʻZ", name: "Oʻzbekcha"),
        LanguageChoice(locale: .uzCyrl, short: "ЎЗ", name: "Ўзбекча"),
        LanguageChoice(locale: .ru, short: "RU", name: "Русский"),
        LanguageChoice(locale: .en, short: "EN", name: "English")
    ]
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        HStack(alignment: .top, spacing: 14 * layoutMetrics.uiScale) {
            Image(systemName: symbol)
                .font(.system(size: 18 * layoutMetrics.uiScale, weight: .semibold))
                .foregroundStyle(AppColor.primary)
                .frame(width: 40 * layoutMetrics.uiScale, height: 40 * layoutMetrics.uiScale)
                .glassCard(cornerRadius: 12)
            VStack(alignment: .leading, spacing: 2 * layoutMetrics.uiScale) {
                Text(title)
                    .font(layoutMetrics.font(.subheadline.weight(.semibold), .title3.weight(.semibold)))
                    .foregroundStyle(AppColor.textMain)
                Text(subtitle)
                    .font(layoutMetrics.font(.caption, .subheadline))
                    .foregroundStyle(AppColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
