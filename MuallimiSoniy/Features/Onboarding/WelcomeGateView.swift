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

    // MARK: - iPad-adaptive tokens (B2)
    //
    // Every value here is `today's literal * layoutMetrics.uiScale`, so
    // `.compact` (uiScale 1.0) renders pixel-identical to before this pass.
    // The logo is the one exception: it's the brand mark the user sees on
    // every cold launch, so it gets a bigger boost than generic chrome
    // (~1.44x) rather than the ~1.3x `uiScale` — matching the same
    // hero-logo treatment `HomeView.ContinueHeroCard` already uses.
    private var logoHeight: CGFloat { layoutMetrics.isRegular ? 150 : 104 }
    private var outerPadding: CGFloat { 24 * layoutMetrics.uiScale }
    private var cardSpacing: CGFloat { 20 * layoutMetrics.uiScale }
    private var cardPadding: CGFloat { 28 * layoutMetrics.uiScale }
    private var buttonMinHeight: CGFloat { 54 * layoutMetrics.uiScale }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                card
                    .frame(maxWidth: layoutMetrics.welcomeCardMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(outerPadding)
                    // Center the card vertically (a full-height min frame), while
                    // still scrolling if Dynamic Type makes it taller than the screen.
                    .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(AppColor.background.ignoresSafeArea())
    }

    private var card: some View {
        VStack(spacing: cardSpacing) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(height: logoHeight)
                .accessibilityHidden(true)

            Text(tr("welcome_title"))
                .font(layoutMetrics.font(.largeTitle.bold(), .system(size: 46, weight: .bold)))
                .foregroundStyle(AppColor.textMain)
                .multilineTextAlignment(.center)

            Text(tr("welcome_desc"))
                .font(layoutMetrics.font(.subheadline, .title3))
                .foregroundStyle(AppColor.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            adabCallout

            Text(tr("welcome_offline"))
                .font(layoutMetrics.font(.caption, .subheadline))
                .foregroundStyle(AppColor.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            continueButton
                .padding(.top, 4)
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity)
        .background(AppColor.glass, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(AppColor.divider.opacity(0.6), lineWidth: 0.5)
        )
    }

    /// The green adab reminder — open hands emoji + the tahorat request.
    private var adabCallout: some View {
        HStack(alignment: .top, spacing: 10 * layoutMetrics.uiScale) {
            Text(verbatim: "🤲")
                .font(layoutMetrics.font(.title3, .title2))
                .accessibilityHidden(true)
            Text(tr("welcome_adab"))
                .font(layoutMetrics.font(.subheadline.weight(.medium), .title3.weight(.medium)))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14 * layoutMetrics.uiScale)
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
                .font(layoutMetrics.font(.headline, .title3.weight(.semibold)))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: buttonMinHeight)
                .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
