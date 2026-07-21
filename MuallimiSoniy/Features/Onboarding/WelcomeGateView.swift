import SwiftUI

/// Shown on **every** app launch, before any content — a welcome + adab
/// (etiquette) reminder. Because the book teaches Qurʼanic letters, the user is
/// asked to use the app in a state of ritual purity (tahorat / wudu). Mirrors the
/// web welcome gate.
///
/// Deliberately **not** persisted: the app holds a fresh `@State` gate that is
/// `false` on each cold launch, so this appears every time (unlike one-time
/// onboarding, which is guarded by `@AppStorage`). Fully localized via
/// `ContentStore.t(_:_:)`.
struct WelcomeGateView: View {
    @Environment(ContentStore.self) private var content
    @Environment(SettingsStore.self) private var settings
    @Environment(\.layoutMetrics) private var layoutMetrics
    /// Called when the user taps "Continue" — the app then shows onboarding
    /// (first run) or the tabs.
    let onContinue: () -> Void

    private var locale: AppLocale { settings.settings.locale }
    private func tr(_ key: String) -> String { content.t(key, locale) }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                card
                    .frame(maxWidth: layoutMetrics.welcomeCardMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    // Center the card vertically (a full-height min frame), while
                    // still scrolling if Dynamic Type makes it taller than the screen.
                    .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(AppColor.background.ignoresSafeArea())
    }

    private var card: some View {
        VStack(spacing: 20) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 104)
                .accessibilityHidden(true)

            Text(tr("welcome_title"))
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textMain)
                .multilineTextAlignment(.center)

            Text(tr("welcome_desc"))
                .font(.subheadline)
                .foregroundStyle(AppColor.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            adabCallout

            Text(tr("welcome_offline"))
                .font(.caption)
                .foregroundStyle(AppColor.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            continueButton
                .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(AppColor.glass, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(AppColor.divider.opacity(0.6), lineWidth: 0.5)
        )
    }

    /// The green adab reminder — open hands emoji + the tahorat request.
    private var adabCallout: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(verbatim: "🤲")
                .font(.title3)
                .accessibilityHidden(true)
            Text(tr("welcome_adab"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppColor.primary.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var continueButton: some View {
        Button(action: onContinue) {
            Text(tr("continue"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
