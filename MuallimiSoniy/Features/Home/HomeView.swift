import SwiftUI

/// Dashboard landing screen, in reading order: a quiet greeting, the
/// Continue card (the one primary action), the hifz entry for children, the
/// stats, and a chapter quick-jump. Complements the Darslar tab (full
/// contents) rather than duplicating it.
///
/// iPhone stacks everything in one column. On the widened iPad path the top
/// cards sit on the same three columns as the chapter grid: Continue spans
/// two, the hifz tile takes the third, the stats fill the row below.
struct HomeView: View {
    @Environment(ContentStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings
    @Environment(AudioDownloadManager.self) private var audio
    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var locale: AppLocale { settings.settings.locale }
    private var gap: CGFloat { HomeStyle.cardGap * layoutMetrics.uiScale }
    private var showsHifz: Bool { !store.hifzCatalog.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28 * layoutMetrics.uiScale) {
                    GreetingHeader(store: store, locale: locale)
                    primaryCards
                    HomeChaptersSection(store: store, progress: progress, locale: locale)
                }
                .padding(.horizontal, HomeStyle.pagePadding * layoutMetrics.uiScale)
                .padding(.top, 8 * layoutMetrics.uiScale)
                .padding(.bottom, 28 * layoutMetrics.uiScale)
                .frame(maxWidth: layoutMetrics.contentMaxWidth)
                .frame(maxWidth: .infinity)
                // Same ceiling as the reader chrome: past AX3 the cards would
                // only grow into clipping.
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ReaderEntry.self) { ReaderView(entry: $0) }
            .navigationDestination(for: HifzListRoute.self) { _ in HifzSurahListView() }
        }
    }

    // MARK: - Continue, hifz and stats

    private var primaryCards: some View {
        HomeGlassGroup {
            if layoutMetrics.isRegular {
                Grid(horizontalSpacing: gap, verticalSpacing: gap) {
                    GridRow {
                        continueCard.gridCellColumns(showsHifz ? 2 : 3)
                        if showsHifz { hifzCard }
                    }
                    GridRow { statTiles(axis: .vertical) }
                }
                // Each row as tall as its tallest card, every card filling it.
                .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: gap) {
                    continueCard
                    if showsHifz { hifzCard }
                    statsRow
                }
            }
        }
    }

    private var continueCard: some View {
        HomeContinueCard(store: store, progress: progress, locale: locale)
    }

    private var hifzCard: some View {
        HomeHifzCard(store: store, progress: progress, locale: locale)
    }

    /// Three tiles in a row; a column of full-width rows at accessibility
    /// text sizes, where a third of an iPhone is too narrow for them.
    @ViewBuilder
    private var statsRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: gap) { statTiles(axis: .horizontal) }
        } else {
            HStack(spacing: gap) { statTiles(axis: .vertical) }
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statTiles(axis: Axis) -> some View {
        HomeStatTiles(store: store, progress: progress, audio: audio, locale: locale, axis: axis)
    }
}

// MARK: - Greeting

/// Quiet opener: a time-of-day greeting, the app's one-line subtitle and the
/// publisher seal on the trailing edge.
private struct GreetingHeader: View {
    let store: ContentStore
    let locale: AppLocale

    @Environment(\.layoutMetrics) private var layoutMetrics

    private var sealSide: CGFloat { layoutMetrics.isRegular ? 72 : 48 }

    var body: some View {
        HStack(spacing: 16 * layoutMetrics.uiScale) {
            VStack(alignment: .leading, spacing: 4 * layoutMetrics.uiScale) {
                Text(store.t(greetingKey, locale))
                    .font(layoutMetrics.font(.title2.weight(.bold), .largeTitle.weight(.bold)))
                    .fontDesign(.rounded)
                    .tracking(HomeStyle.titleTracking)
                    .foregroundStyle(AppColor.textMain)
                    // Same cap as the Continue title, so the greeting never
                    // outgrows it at accessibility sizes.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .accessibilityAddTraits(.isHeader)
                Text(store.t("app_subtitle", locale))
                    .font(layoutMetrics.font(.subheadline, .title3))
                    .foregroundStyle(AppColor.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: sealSide, height: sealSide)
                .accessibilityHidden(true)
        }
    }

    /// Morning before noon, day until 18:00, evening after.
    private var greetingKey: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<12: return "greeting_morning"
        case ..<18: return "greeting_day"
        default: return "greeting_evening"
        }
    }
}
