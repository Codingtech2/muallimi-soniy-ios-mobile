import SwiftUI

/// The one primary action on Home: where the reader left off (page counter,
/// lesson title, the book), a progress bar that fills on first appear, and
/// the big Continue / Start button into the reader at the resume page.
struct HomeContinueCard: View {
    let store: ContentStore
    let progress: ProgressStore
    let locale: AppLocale

    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// What the bar currently shows. Starts empty so it fills once on first
    /// appear; later appears only animate the difference.
    @State private var drawnFraction: Double = 0

    private var resume: Int { progress.resumeGlobalIndex }
    private var total: Int { max(store.totalPages, 1) }
    private var fraction: Double { total > 1 ? Double(resume) / Double(total - 1) : 0 }
    private var hasStarted: Bool { resume > 0 }

    /// The lesson at the resume page; before the first page turn it invites
    /// the reader to begin instead.
    private var title: String {
        guard hasStarted, store.allBookPages.indices.contains(resume) else {
            return store.t("start_subtitle", locale)
        }
        return store.allBookPages[resume].lesson.title.text(locale)
    }

    private var pageCounter: String { "\(store.t("page", locale)) \(resume + 1) / \(total)" }
    private var bookLine: String { "\(store.t("app_name", locale)) · \(store.t("book_author", locale))" }
    private var cornerRadius: CGFloat { layoutMetrics.isRegular ? 30 : 26 }

    var body: some View {
        VStack(alignment: .leading, spacing: 16 * layoutMetrics.uiScale) {
            summary
            // Pins the bar + button to the bottom when the iPad grid row is
            // taller than this card; collapses on iPhone.
            Spacer(minLength: 0)
            HomeProgressBar(fraction: drawnFraction)
            continueButton
        }
        .padding(layoutMetrics.isRegular ? 28 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(cornerRadius: cornerRadius)
        .onAppear { showProgress() }
        .onChange(of: fraction) { showProgress() }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6 * layoutMetrics.uiScale) {
            Text(pageCounter)
                .font(layoutMetrics.font(.caption.weight(.semibold), .subheadline.weight(.semibold)))
                .fontDesign(.rounded)
                .monospacedDigit()
                .homeCapsLabel()
                .foregroundStyle(AppColor.textSecondary)
            Text(title)
                .font(layoutMetrics.font(.title.weight(.bold), .largeTitle.weight(.bold)))
                .fontDesign(.rounded)
                .tracking(HomeStyle.titleTracking)
                .foregroundStyle(AppColor.textMain)
                .fixedSize(horizontal: false, vertical: true)
                // A long single word ("Kalimalarning") must still fit an
                // SE-width card without breaking mid-word.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            Text(bookLine)
                .font(layoutMetrics.font(.subheadline, .title3))
                .foregroundStyle(AppColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(bookLine)")
        .accessibilityValue(String(format: store.t("page_of", locale), "\(resume + 1)", "\(total)"))
    }

    private var continueButton: some View {
        let shape = RoundedRectangle(cornerRadius: 16 * layoutMetrics.uiScale, style: .continuous)
        return NavigationLink(value: ReaderEntry.global(index: resume)) {
            HStack(spacing: 10 * layoutMetrics.uiScale) {
                Image(systemName: "play.fill")
                    .accessibilityHidden(true)
                Text(store.t(hasStarted ? "continue" : "start", locale))
                    .multilineTextAlignment(.center)
            }
            .font(layoutMetrics.font(.headline, .title3.weight(.semibold)))
            .foregroundStyle(.white)
            .padding(.vertical, 12 * layoutMetrics.uiScale)
            .frame(maxWidth: .infinity, minHeight: layoutMetrics.isRegular ? 64 : 54)
            // The deeper green keeps white text readable in both themes.
            .background(AppColor.primaryButton, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(HomeCardButtonStyle())
    }

    /// Moves the bar to the real value: animated (from empty on the first
    /// appear), or instantly under Reduce Motion.
    private func showProgress() {
        guard drawnFraction != fraction else { return }
        if reduceMotion {
            drawnFraction = fraction
        } else {
            withAnimation(HomeStyle.fillAnimation) { drawnFraction = fraction }
        }
    }
}

/// Slim capsule bar, hero green by default (gold on the hifz tile). Display
/// only — VoiceOver hears the count from the card's summary instead.
struct HomeProgressBar: View {
    let fraction: Double
    var tint: Color = AppColor.primary
    /// The empty track; the gold hifz bar raises it so an all-zero bar still
    /// reads as a runway rather than a stray line.
    var trackOpacity: Double = 0.16

    @Environment(\.layoutMetrics) private var layoutMetrics

    private var height: CGFloat { 8 * layoutMetrics.uiScale }

    var body: some View {
        Capsule()
            .fill(tint.opacity(trackOpacity))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint)
                        .frame(width: fillWidth(in: proxy.size.width))
                }
            }
            .frame(height: height)
            .accessibilityHidden(true)
    }

    /// At least as wide as the bar is tall once there is any progress, so a
    /// small value still reads as a rounded pill.
    private func fillWidth(in width: CGFloat) -> CGFloat {
        let clamped = min(max(fraction, 0), 1)
        guard clamped > 0 else { return 0 }
        return max(width * clamped, height)
    }
}
