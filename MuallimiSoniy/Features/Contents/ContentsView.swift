import SwiftUI

/// Table-of-contents ("Mundarija") rebuilt on the Liquid-Glass system.
///
/// Each chapter reads as a glass card (real Liquid Glass on iOS 26,
/// `.ultraThinMaterial` + hairline on iOS 17–25), mirroring `SettingsView`.
/// Single-lesson chapters collapse to one tappable combined row; multi-lesson
/// chapters show an icon-chip header plus a lesson row per lesson. Completed
/// lessons keep their green ✓, page spans stay, and every row is still a
/// `NavigationLink` into the reader at the lesson's first global page.
struct ContentsView: View {
    @Environment(ContentStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings
    @Environment(\.layoutMetrics) private var layoutMetrics

    private var locale: AppLocale { settings.settings.locale }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20 * layoutMetrics.uiScale) {
                    header

                    VStack(spacing: 16 * layoutMetrics.uiScale) {
                        ForEach(store.outline) { chapter in
                            ChapterCard(
                                chapter: chapter,
                                progress: progress,
                                locale: locale,
                                pageWord: store.t("pages", locale),
                                completedLabel: store.t("completed", locale)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20 * layoutMetrics.uiScale)
                .padding(.top, 8 * layoutMetrics.uiScale)
                .padding(.bottom, 24 * layoutMetrics.uiScale)
                .frame(maxWidth: layoutMetrics.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(AppColor.background.ignoresSafeArea())
            // The screen owns its large title, so hide the nav bar here — matching
            // the sibling glass screens (Home / Settings).
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ReaderEntry.self) { entry in
                ReaderView(entry: entry)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4 * layoutMetrics.uiScale) {
            Text(store.t("contents", locale))
                .font(layoutMetrics.font(.largeTitle.bold(), .system(size: 46, weight: .bold)))
                .foregroundStyle(AppColor.textMain)
            Text(subtitle)
                .font(layoutMetrics.font(.subheadline, .title2))
                .foregroundStyle(AppColor.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "52 sahifa · 10 bob", localised (the page word is shared with the rows).
    private var subtitle: String {
        "\(store.totalPages) \(store.t("pages", locale)) · \(store.outline.count) \(chapterWord)"
    }

    private var chapterWord: String {
        switch locale {
        case .uzLatn: return "bob"
        case .uzCyrl: return "боб"
        case .ru:     return "разд."
        case .en:     return "chapters"
        }
    }
}

// MARK: - Chapter card

/// One chapter rendered as a glass card. A single-lesson chapter collapses to a
/// combined tappable card (icon + chapter title + span); a multi-lesson chapter
/// shows an icon-chip header plus one lesson row per lesson.
private struct ChapterCard: View {
    let chapter: OutlineChapter
    let progress: ProgressStore
    let locale: AppLocale
    /// Localised word for "page(s)" ("sahifa" / "стр." / "pages").
    let pageWord: String
    /// Localised "completed" accessibility label.
    let completedLabel: String

    @Environment(\.layoutMetrics) private var layoutMetrics

    private var allComplete: Bool {
        chapter.lessons.allSatisfy { progress.isLessonComplete($0.lesson.id) }
    }

    var body: some View {
        if chapter.lessons.count == 1, let only = chapter.lessons.first {
            combinedRow(only)
        } else {
            multiLessonCard
        }
    }

    // MARK: Single-lesson chapter (whole card is one link)

    private func combinedRow(_ lesson: OutlineLesson) -> some View {
        NavigationLink(value: ReaderEntry.global(index: lesson.globalStart - 1)) {
            HStack(spacing: 14 * layoutMetrics.uiScale) {
                iconChip
                titleBlock(
                    title: chapter.chapter.title.text(locale),
                    start: lesson.globalStart,
                    end: lesson.globalEnd,
                    weight: .semibold
                )
                Spacer(minLength: 8)
                trailing(isComplete: progress.isLessonComplete(lesson.lesson.id))
            }
            .padding(layoutMetrics.isRegular ? 24 : 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassCard(cornerRadius: 28)
    }

    // MARK: Multi-lesson chapter (header + rows)

    private var multiLessonCard: some View {
        VStack(alignment: .leading, spacing: layoutMetrics.isRegular ? 18 : 14) {
            chapterHeader
            VStack(spacing: 8 * layoutMetrics.uiScale) {
                ForEach(chapter.lessons) { lesson in
                    lessonRow(lesson)
                }
            }
        }
        .padding(layoutMetrics.isRegular ? 24 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 28)
    }

    private var chapterHeader: some View {
        HStack(spacing: 12 * layoutMetrics.uiScale) {
            iconChip
            titleBlock(
                title: chapter.chapter.title.text(locale),
                start: chapter.globalStart,
                end: chapter.globalEnd,
                weight: .semibold
            )
            Spacer(minLength: 8)
            if allComplete { completeMark }
        }
    }

    /// A lesson inside a multi-lesson card: a subtle surface row that stays a
    /// `NavigationLink` into the reader at the lesson's first page.
    private func lessonRow(_ lesson: OutlineLesson) -> some View {
        NavigationLink(value: ReaderEntry.global(index: lesson.globalStart - 1)) {
            HStack(spacing: 12 * layoutMetrics.uiScale) {
                titleBlock(
                    title: lesson.lesson.title.text(locale),
                    start: lesson.globalStart,
                    end: lesson.globalEnd,
                    weight: .medium
                )
                Spacer(minLength: 8)
                trailing(isComplete: progress.isLessonComplete(lesson.lesson.id))
            }
            .padding(.horizontal, layoutMetrics.isRegular ? 18 : 14)
            .padding(.vertical, layoutMetrics.isRegular ? 15 : 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColor.surface.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Shared pieces

    private var iconChip: some View {
        let side: CGFloat = layoutMetrics.isRegular ? 52 : 36
        return Image(systemName: chapterSymbol(chapter.chapter.id))
            .font(.system(size: layoutMetrics.isRegular ? 26 : 18))
            .foregroundStyle(AppColor.primary)
            .frame(width: side, height: side)
            .background(
                AppColor.primary.opacity(0.2),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }

    private func titleBlock(
        title: String,
        start: Int,
        end: Int,
        weight: Font.Weight
    ) -> some View {
        VStack(alignment: .leading, spacing: layoutMetrics.isRegular ? 5 : 3) {
            Text(title)
                .font(layoutMetrics.isRegular ? .title3.weight(weight) : .subheadline.weight(weight))
                .foregroundStyle(AppColor.textMain)
                .multilineTextAlignment(.leading)
            Text(spanLabel(start, end))
                .font(layoutMetrics.isRegular ? .subheadline : .caption)
                .foregroundStyle(AppColor.textMuted)
                .monospacedDigit()
        }
    }

    /// Trailing cluster: the green completed ✓ (when done) plus a chevron.
    private func trailing(isComplete: Bool) -> some View {
        HStack(spacing: 10 * layoutMetrics.uiScale) {
            if isComplete { completeMark }
            Image(systemName: "chevron.right")
                .font(.system(size: layoutMetrics.isRegular ? 16 : 13, weight: .semibold))
                .foregroundStyle(AppColor.textMuted)
        }
    }

    private var completeMark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(layoutMetrics.isRegular ? .title3 : .subheadline)
            .foregroundStyle(AppColor.primary)
            .accessibilityLabel(completedLabel)
    }

    /// Collapses a single-page span to "sahifa N" instead of "sahifa N–N".
    private func spanLabel(_ start: Int, _ end: Int) -> String {
        start == end ? "\(pageWord) \(start)" : "\(pageWord) \(start)–\(end)"
    }

    /// SF Symbol per chapter id (mirrors the reader TOC + web lucide mapping).
    private func chapterSymbol(_ id: String) -> String {
        switch id {
        case "ch_muqaddima": return "book"
        case "ch_harflar":   return "textformat"
        case "ch_madlar":    return "waveform"
        case "ch_tashdid":   return "repeat"
        case "ch_tanvin":    return "text.quote"
        case "ch_alif":      return "pencil"
        case "ch_vasl":      return "link"
        case "ch_kalimalar": return "character.textbox"
        case "ch_suralar":   return "scroll"
        case "ch_duolar":    return "hands.and.sparkles"
        default:             return "bookmark"
        }
    }
}
