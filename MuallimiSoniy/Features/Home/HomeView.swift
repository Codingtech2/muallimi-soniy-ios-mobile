import SwiftUI

/// Dashboard landing screen: time-based greeting, a continue-reading hero card
/// (logo + progress), a stats row, and a horizontal chapter quick-jump.
/// Complements the Darslar tab (full contents) rather than duplicating it.
struct HomeView: View {
    @Environment(ContentStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings
    @Environment(AudioDownloadManager.self) private var audio

    private var locale: AppLocale { settings.settings.locale }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    GreetingHeader(locale: locale)
                    ContinueHeroCard(store: store, progress: progress, locale: locale)
                    StatsRow(store: store, progress: progress, audio: audio)
                    ChaptersSection(store: store, progress: progress, locale: locale)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textMain)
            Text(subtitle)
                .font(.subheadline)
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

    private var resume: Int { progress.resumeGlobalIndex }
    private var total: Int { max(store.totalPages, 1) }
    private var fraction: Double { total > 1 ? Double(resume) / Double(total - 1) : 0 }

    var body: some View {
        VStack(spacing: 14) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
                .accessibilityHidden(true)

            VStack(spacing: 2) {
                Text(store.t("app_name", locale))
                    .font(.title2.bold())
                    .foregroundStyle(AppColor.textMain)
                Text(store.t("book_author", locale))
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textMuted)
            }

            VStack(spacing: 6) {
                ProgressView(value: fraction)
                    .tint(AppColor.primary)
                Text("\(store.t("page", locale)) \(resume + 1) / \(total)")
                    .font(.caption)
                    .foregroundStyle(AppColor.textMuted)
                    .monospacedDigit()
            }
            .padding(.top, 2)

            NavigationLink(value: ReaderEntry.global(index: resume)) {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                    Text(resume > 0 ? store.t("continue", locale) : store.t("start", locale))
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(AppColor.glassGreen, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(AppColor.divider, lineWidth: 1))
    }
}

// MARK: - Stats row

private struct StatsRow: View {
    let store: ContentStore
    let progress: ProgressStore
    let audio: AudioDownloadManager

    private var percent: Int {
        let total = max(store.totalPages - 1, 1)
        return Int((Double(progress.resumeGlobalIndex) / Double(total) * 100).rounded())
    }
    private var totalLessons: Int { store.outline.reduce(0) { $0 + $1.lessons.count } }

    var body: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(percent)%", label: "tugadi", symbol: "chart.bar.fill")
            StatTile(value: "\(progress.completedLessons.count)/\(totalLessons)", label: "darslar", symbol: "checkmark.seal.fill")
            StatTile(
                value: audio.isReady ? "✓" : "⬇",
                label: audio.isReady ? "audio oflayn" : "audio yuklang",
                symbol: audio.isReady ? "checkmark.icloud.fill" : "icloud.and.arrow.down.fill"
            )
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(AppColor.primary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppColor.textMain)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColor.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppColor.divider, lineWidth: 1))
    }
}

// MARK: - Chapters quick-jump

private struct ChaptersSection: View {
    let store: ContentStore
    let progress: ProgressStore
    let locale: AppLocale

    private var chaptersLabel: String {
        switch locale {
        case .uzLatn: return "Boblar"
        case .uzCyrl: return "Боблар"
        case .ru:     return "Разделы"
        case .en:     return "Chapters"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(chaptersLabel)
                .font(.headline)
                .foregroundStyle(AppColor.textMain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.outline) { oc in
                        NavigationLink(value: ReaderEntry.global(index: oc.globalStart - 1)) {
                            ChapterCard(
                                outline: oc,
                                locale: locale,
                                done: oc.lessons.allSatisfy { progress.isLessonComplete($0.lesson.id) }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

private struct ChapterCard: View {
    let outline: OutlineChapter
    let locale: AppLocale
    let done: Bool

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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(AppColor.primary)
                Spacer()
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.primary)
                }
            }
            Spacer(minLength: 4)
            Text(outline.chapter.title.text(locale))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textMain)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text("\(outline.globalStart)–\(outline.globalEnd)")
                .font(.caption2)
                .foregroundStyle(AppColor.textMuted)
                .monospacedDigit()
        }
        .padding(14)
        .frame(width: 148, height: 132, alignment: .topLeading)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AppColor.divider, lineWidth: 1))
    }
}
