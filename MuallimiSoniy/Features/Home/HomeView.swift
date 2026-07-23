import SwiftUI

/// Dashboard landing screen: time-based greeting, a continue-reading hero card
/// (logo + progress), a stats row, and a horizontal chapter quick-jump.
/// Complements the Darslar tab (full contents) rather than duplicating it.
struct HomeView: View {
    @Environment(ContentStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings
    @Environment(AudioDownloadManager.self) private var audio
    @Environment(\.layoutMetrics) private var layoutMetrics

    private var locale: AppLocale { settings.settings.locale }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22 * layoutMetrics.uiScale) {
                    GreetingHeader(locale: locale)
                    ContinueHeroCard(store: store, progress: progress, locale: locale)
                    StatsRow(store: store, progress: progress, audio: audio, locale: locale)
                    ChaptersSection(store: store, progress: progress, locale: locale)
                }
                .padding(.horizontal, 20 * layoutMetrics.uiScale)
                .padding(.top, 8 * layoutMetrics.uiScale)
                .padding(.bottom, 24 * layoutMetrics.uiScale)
                .frame(maxWidth: layoutMetrics.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ReaderEntry.self) { ReaderView(entry: $0) }
        }
    }
}

// MARK: - Greeting

private struct GreetingHeader: View {
    let locale: AppLocale

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * layoutMetrics.uiScale) {
            Text(greeting)
                .font(layoutMetrics.font(.largeTitle.bold(), .system(size: 46, weight: .bold)))
                .foregroundStyle(AppColor.textMain)
            Text(subtitle)
                .font(layoutMetrics.font(.subheadline, .title2))
                .foregroundStyle(AppColor.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Time-of-day greeting, localised for the four supported locales.
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let slot = hour < 12 ? 0 : (hour < 18 ? 1 : 2)
        switch locale {
        case .uzLatn: return ["Xayrli tong!", "Xayrli kun!", "Xayrli kech!"][slot]
        case .uzCyrl: return ["Хайрли тонг!", "Хайрли кун!", "Хайрли кеч!"][slot]
        case .ru:     return ["Доброе утро!", "Добрый день!", "Добрый вечер!"][slot]
        case .en:     return ["Good morning!", "Good afternoon!", "Good evening!"][slot]
        }
    }

    private var subtitle: String {
        switch locale {
        case .uzLatn: return "Arab tili oʻrganish platformasi"
        case .uzCyrl: return "Араб тили ўрганиш платформаси"
        case .ru:     return "Платформа изучения арабского языка"
        case .en:     return "Arabic learning platform"
        }
    }
}

// MARK: - Continue hero card

private struct ContinueHeroCard: View {
    let store: ContentStore
    let progress: ProgressStore
    let locale: AppLocale

    @Environment(\.layoutMetrics) private var layoutMetrics

    private var resume: Int { progress.resumeGlobalIndex }
    private var total: Int { max(store.totalPages, 1) }
    private var fraction: Double { total > 1 ? Double(resume) / Double(total - 1) : 0 }
    private var logoHeight: CGFloat { layoutMetrics.isRegular ? 96 : 60 }

    var body: some View {
        VStack(spacing: 14 * layoutMetrics.uiScale) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(height: logoHeight)
                .accessibilityHidden(true)

            VStack(spacing: 2 * layoutMetrics.uiScale) {
                Text(store.t("app_name", locale))
                    .font(layoutMetrics.font(.title2.bold(), .largeTitle.bold()))
                    .foregroundStyle(AppColor.textMain)
                Text(store.t("book_author", locale))
                    .font(layoutMetrics.font(.subheadline, .title3))
                    .foregroundStyle(AppColor.textMuted)
            }

            VStack(spacing: 6 * layoutMetrics.uiScale) {
                ProgressView(value: fraction)
                    .tint(AppColor.primary)
                Text("\(store.t("page", locale)) \(resume + 1) / \(total)")
                    .font(layoutMetrics.font(.caption, .subheadline))
                    .foregroundStyle(AppColor.textMuted)
                    .monospacedDigit()
            }
            .padding(.top, 2 * layoutMetrics.uiScale)

            NavigationLink(value: ReaderEntry.global(index: resume)) {
                HStack(spacing: 10 * layoutMetrics.uiScale) {
                    Image(systemName: "play.fill")
                    Text(resume > 0 ? store.t("continue", locale) : store.t("start", locale))
                }
                .font(layoutMetrics.font(.headline, .title3.weight(.semibold)))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: layoutMetrics.isRegular ? 64 : 52)
                .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(layoutMetrics.isRegular ? 28 : 20)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 26)
    }
}

// MARK: - Stats row

private struct StatsRow: View {
    let store: ContentStore
    let progress: ProgressStore
    let audio: AudioDownloadManager
    let locale: AppLocale

    private var percent: Int {
        let total = max(store.totalPages - 1, 1)
        return Int((Double(progress.resumeGlobalIndex) / Double(total) * 100).rounded())
    }
    private var totalLessons: Int { store.outline.reduce(0) { $0 + $1.lessons.count } }

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        HStack(spacing: 10 * layoutMetrics.uiScale) {
            StatTile(value: "\(percent)%", label: store.t("stat_done", locale), symbol: "chart.bar.fill")
            StatTile(value: "\(progress.completedLessons.count)/\(totalLessons)", label: store.t("lessons", locale), symbol: "checkmark.seal.fill")
            StatTile(
                value: audio.isReady ? "✓" : "⬇",
                label: audio.isReady ? store.t("stat_audio_ready", locale) : store.t("stat_audio_get", locale),
                symbol: audio.isReady ? "checkmark.icloud.fill" : "icloud.and.arrow.down.fill"
            )
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let symbol: String

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        VStack(spacing: layoutMetrics.isRegular ? 8 : 4) {
            Image(systemName: symbol)
                .font(layoutMetrics.isRegular ? .title3 : .caption)
                .foregroundStyle(AppColor.primary)
            Text(value)
                .font(layoutMetrics.isRegular ? .system(size: 34, weight: .bold) : .title3.bold())
                .foregroundStyle(AppColor.textMain)
                .monospacedDigit()
            Text(label)
                .font(layoutMetrics.isRegular ? .subheadline : .caption2)
                .foregroundStyle(AppColor.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, layoutMetrics.isRegular ? 26 : 14)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Chapters quick-jump

private struct ChaptersSection: View {
    let store: ContentStore
    let progress: ProgressStore
    let locale: AppLocale

    @Environment(\.layoutMetrics) private var layoutMetrics

    private var chaptersLabel: String {
        switch locale {
        case .uzLatn: return "Boblar"
        case .uzCyrl: return "Боблар"
        case .ru:     return "Разделы"
        case .en:     return "Chapters"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * layoutMetrics.uiScale) {
            Text(chaptersLabel)
                .font(layoutMetrics.font(.headline, .title3.weight(.semibold)))
                .foregroundStyle(AppColor.textMain)

            if layoutMetrics.isRegular {
                // iPad: the quick-jump becomes a grid so the row uses the
                // wider column instead of a horizontal scroller with dead
                // space to its right.
                LazyVGrid(columns: gridColumns, spacing: 12 * layoutMetrics.uiScale) {
                    ForEach(store.outline) { chapter in chapterLink(chapter) }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.outline) { chapter in chapterLink(chapter) }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: layoutMetrics.chapterGridColumns)
    }

    private func chapterLink(_ chapter: OutlineChapter) -> some View {
        NavigationLink(value: ReaderEntry.global(index: chapter.globalStart - 1)) {
            ChapterCard(
                outline: chapter,
                locale: locale,
                done: chapter.lessons.allSatisfy { progress.isLessonComplete($0.lesson.id) }
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ChapterCard: View {
    let outline: OutlineChapter
    let locale: AppLocale
    let done: Bool

    @Environment(\.layoutMetrics) private var layoutMetrics

    /// SF Symbol per chapter order (1–10), mirroring the web lucide mapping.
    private var symbol: String {
        let symbols = [
            "book.closed.fill", "textformat", "waveform", "pencil.tip",
            "character", "a.circle.fill", "link", "text.quote",
            "book.pages.fill", "hands.and.sparkles.fill"
        ]
        let idx = outline.chapter.order - 1
        return symbols.indices.contains(idx) ? symbols[idx] : "book.closed.fill"
    }

    var body: some View {
        Group {
            if layoutMetrics.isRegular {
                // Fills its grid cell instead of the iPhone's fixed card width.
                cardContent.frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            } else {
                cardContent.frame(width: 148, height: 132, alignment: .topLeading)
            }
        }
        .glassCard(cornerRadius: 18)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.isRegular ? 10 : 8) {
            HStack {
                Image(systemName: symbol)
                    .font(layoutMetrics.isRegular ? .title2 : .title3)
                    .foregroundStyle(AppColor.primary)
                Spacer()
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(layoutMetrics.isRegular ? .title3 : .subheadline)
                        .foregroundStyle(AppColor.primary)
                }
            }
            Spacer(minLength: 4)
            Text(outline.chapter.title.text(locale))
                .font(layoutMetrics.isRegular ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textMain)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text("\(outline.globalStart)–\(outline.globalEnd)")
                .font(layoutMetrics.isRegular ? .subheadline : .caption2)
                .foregroundStyle(AppColor.textMuted)
                .monospacedDigit()
        }
        .padding(layoutMetrics.isRegular ? 20 : 14)
    }
}
