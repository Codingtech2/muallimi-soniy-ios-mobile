import SwiftUI

/// The table-of-contents sheet — the SwiftUI port of the web `TocSheet` +
/// `BookToc`.
///
/// Shows the whole-book outline: single-lesson chapters collapse to one combined
/// row (chapter icon + title + global page span "X–Y"); multi-lesson chapters
/// render an uppercase section header plus lesson rows. The current lesson is
/// highlighted, and its individual global page numbers appear as tappable chips.
/// Every page number is the 1-based **global** page (matches the reader's
/// "X / 52"). Selecting a lesson or a chip jumps the reader and dismisses.
struct TocSheet: View {
    let outline: [OutlineChapter]
    /// The reader's current lesson id (live), highlighted in the list.
    let currentLessonId: String
    /// The reader's current 1-based global page.
    let currentGlobalPage: Int
    let totalPages: Int
    /// Localised header title ("Mundarija").
    let contentsLabel: String
    /// Localised "page" word ("Sahifa").
    let pageLabel: String
    /// Localised `page_of` format (two placeholders: current, total) —
    /// "Page 4 of 52".
    let pageOfFormat: String
    /// Localised label for the direct page-jump strip.
    let jumpToPageLabel: String
    /// Localised "close" accessibility label.
    let closeLabel: String
    let locale: AppLocale
    /// Reports a 1-based global page to jump to.
    let onSelectGlobalPage: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    /// Inherited from the presenting `ReaderView` — `.sheet` content inherits
    /// the presenter's environment, so this reads the same live iPad/iPhone
    /// metrics with no extra plumbing.
    @Environment(\.layoutMetrics) private var layoutMetrics

    private var progress: CGFloat {
        guard totalPages > 0 else { return 0 }
        return min(1, CGFloat(currentGlobalPage) / CGFloat(totalPages))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            pageJumpRow
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(outline) { chapter in
                            chapterSection(chapter)
                        }
                    }
                    .padding(16 * layoutMetrics.uiScale)
                }
                .task {
                    // Centre the current lesson once the sheet has settled.
                    try? await Task.sleep(for: .milliseconds(150))
                    proxy.scrollTo(currentLessonId, anchor: .center)
                }
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(contentsLabel)
                    .font(.system(size: 18 * layoutMetrics.uiScale, weight: .bold))
                    .foregroundStyle(AppColor.textMain)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15 * layoutMetrics.uiScale, weight: .semibold))
                        .foregroundStyle(AppColor.textMain)
                        .frame(width: 36 * layoutMetrics.uiScale, height: 36 * layoutMetrics.uiScale)
                        .glassCard(cornerRadius: 12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(closeLabel)
            }
            .padding(.horizontal, 20 * layoutMetrics.uiScale)
            .padding(.top, 18 * layoutMetrics.uiScale)
            .padding(.bottom, 12 * layoutMetrics.uiScale)

            // Position line — the drawer's echo of the reader indicator.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(AppColor.divider)
                    Rectangle().fill(AppColor.primary).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 3)
        }
        // Frosted glass sheet header; the outline list below keeps its opaque,
        // legible background.
        .background(.ultraThinMaterial)
    }

    // MARK: - Direct page jump

    /// "Page 4 of 52" plus every global page number as a tappable chip. This
    /// is what the reader's 52-page drag scrubber becomes: the scrubber needed
    /// ±2.2pt of precision to land on one page, which is hostile for an
    /// elderly or low-vision reader; a numeric chip is a 44pt target that
    /// says exactly where it goes.
    private var pageJumpRow: some View {
        VStack(alignment: .leading, spacing: 8 * layoutMetrics.uiScale) {
            Text(String(format: pageOfFormat, "\(currentGlobalPage)", "\(totalPages)"))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(AppColor.textMuted)
                .padding(.horizontal, 20 * layoutMetrics.uiScale)

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 6 * layoutMetrics.uiScale) {
                        ForEach(1...max(totalPages, 1), id: \.self) { global in
                            jumpChip(global)
                        }
                    }
                    .padding(.horizontal, 20 * layoutMetrics.uiScale)
                }
                .scrollIndicators(.hidden)
                .task {
                    // Let the sheet settle before centring, same as the
                    // outline list below.
                    try? await Task.sleep(for: .milliseconds(150))
                    proxy.scrollTo(currentGlobalPage, anchor: .center)
                }
            }
        }
        .padding(.top, 12 * layoutMetrics.uiScale)
        .padding(.bottom, 12 * layoutMetrics.uiScale)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(jumpToPageLabel)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColor.divider)
                .frame(height: 0.5)
        }
    }

    private func jumpChip(_ global: Int) -> some View {
        let isCurrent = global == currentGlobalPage
        let side = 44 * layoutMetrics.uiScale
        return Button {
            onSelectGlobalPage(global)
            dismiss()
        } label: {
            Text("\(global)")
                .font(.system(size: 15 * layoutMetrics.uiScale, weight: isCurrent ? .semibold : .regular)
                    .monospacedDigit())
                .foregroundStyle(isCurrent ? .white : AppColor.textMain)
                .frame(width: side, height: side)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isCurrent ? AppColor.primary : AppColor.surface)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .id(global)
        .accessibilityLabel("\(pageLabel) \(global)")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    // MARK: - Chapter

    @ViewBuilder
    private func chapterSection(_ chapter: OutlineChapter) -> some View {
        if chapter.lessons.count == 1 {
            lessonRow(chapter: chapter, lesson: chapter.lessons[0], combined: true)
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 10 * layoutMetrics.uiScale) {
                    Image(systemName: chapterSymbol(chapter.chapter.id))
                        .font(.system(size: 14 * layoutMetrics.uiScale, weight: .medium))
                        .foregroundStyle(AppColor.textMuted)
                    Text(chapter.chapter.title.text(locale).uppercased())
                        .font(.system(size: 11 * layoutMetrics.uiScale, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(AppColor.textMuted)
                        .lineLimit(1)
                    Spacer()
                    Text(spanLabel(chapter.globalStart, chapter.globalEnd))
                        .font(.system(size: 11 * layoutMetrics.uiScale).monospacedDigit())
                        .foregroundStyle(AppColor.textMuted)
                }
                .padding(.horizontal, 4 * layoutMetrics.uiScale)
                .padding(.top, 14 * layoutMetrics.uiScale)
                .padding(.bottom, 6 * layoutMetrics.uiScale)

                ForEach(chapter.lessons) { lesson in
                    lessonRow(chapter: chapter, lesson: lesson, combined: false)
                }
            }
        }
    }

    // MARK: - Lesson row

    @ViewBuilder
    private func lessonRow(chapter: OutlineChapter, lesson: OutlineLesson, combined: Bool) -> some View {
        let isCurrent = lesson.lesson.id == currentLessonId
        let multiPage = lesson.globalEnd > lesson.globalStart
        let numberText = isCurrent
            ? String(currentGlobalPage)
            : (combined && multiPage ? spanLabel(lesson.globalStart, lesson.globalEnd) : String(lesson.globalStart))
        let title = combined ? chapter.chapter.title.text(locale) : lesson.lesson.title.text(locale)

        Button {
            onSelectGlobalPage(lesson.globalStart)
            dismiss()
        } label: {
            HStack(spacing: 10 * layoutMetrics.uiScale) {
                if combined {
                    Image(systemName: chapterSymbol(chapter.chapter.id))
                        .font(.system(size: 17 * layoutMetrics.uiScale))
                        .foregroundStyle(isCurrent ? AppColor.primary : AppColor.textMuted)
                        .frame(width: 22 * layoutMetrics.uiScale)
                }
                Text(title)
                    .font(.system(size: 14 * layoutMetrics.uiScale, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(AppColor.textMain)
                    .lineLimit(1)
                leaderDots
                HStack(spacing: 6 * layoutMetrics.uiScale) {
                    if lesson.lesson.audioUrl != nil {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 10 * layoutMetrics.uiScale))
                            .foregroundStyle(AppColor.primary.opacity(0.6))
                    }
                    pageNumber(numberText, isCurrent: isCurrent)
                }
            }
            .padding(.leading, (combined ? 8 : 40) * layoutMetrics.uiScale)
            .padding(.trailing, 12 * layoutMetrics.uiScale)
            .frame(minHeight: (combined ? 48 : 44) * layoutMetrics.uiScale)
            .frame(maxWidth: .infinity)
            .background(isCurrent ? AppColor.primary.opacity(0.2) : Color.clear)
            .overlay(alignment: .leading) {
                if isCurrent {
                    Capsule()
                        .fill(AppColor.primary)
                        .frame(width: 3, height: 20 * layoutMetrics.uiScale)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(lesson.lesson.id)

        if isCurrent {
            pageChips(lesson: lesson)
        }
    }

    /// The current lesson's individual global page numbers as tappable chips.
    private func pageChips(lesson: OutlineLesson) -> some View {
        let numbers = Array(lesson.globalStart...lesson.globalEnd)
        let chipSide = 36 * layoutMetrics.uiScale
        let chipSpacing = 6 * layoutMetrics.uiScale
        let chipColumn = GridItem(
            .adaptive(minimum: chipSide, maximum: chipSide),
            spacing: chipSpacing,
            alignment: .leading
        )
        return LazyVGrid(
            columns: [chipColumn],
            alignment: .leading,
            spacing: chipSpacing
        ) {
            ForEach(numbers, id: \.self) { global in
                let isCur = global == currentGlobalPage
                Button {
                    onSelectGlobalPage(global)
                    dismiss()
                } label: {
                    Text("\(global)")
                        .font(.system(size: 12 * layoutMetrics.uiScale, weight: .medium).monospacedDigit())
                        .foregroundStyle(isCur ? .white : AppColor.textMuted)
                        .frame(width: chipSide, height: chipSide)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isCur ? AppColor.primary : AppColor.surface)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(pageLabel) \(global)")
            }
        }
        .padding(.leading, 40 * layoutMetrics.uiScale)
        .padding(.trailing, 12 * layoutMetrics.uiScale)
        .padding(.top, 2 * layoutMetrics.uiScale)
        .padding(.bottom, 10 * layoutMetrics.uiScale)
    }

    // MARK: - Small pieces

    @ViewBuilder
    private func pageNumber(_ text: String, isCurrent: Bool) -> some View {
        if isCurrent {
            Text(text)
                .font(.system(size: 12 * layoutMetrics.uiScale, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8 * layoutMetrics.uiScale)
                .frame(minWidth: 28 * layoutMetrics.uiScale, minHeight: 24 * layoutMetrics.uiScale)
                .background(Capsule().fill(AppColor.primary))
        } else {
            Text(text)
                .font(.system(size: 12 * layoutMetrics.uiScale).monospacedDigit())
                .foregroundStyle(AppColor.textMuted)
        }
    }

    private var leaderDots: some View {
        LeaderLine()
            .stroke(
                AppColor.textMuted.opacity(0.3),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 4])
            )
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
    }

    private func spanLabel(_ start: Int, _ end: Int) -> String {
        start == end ? "\(start)" : "\(start)–\(end)"
    }

    /// Maps a chapter id to an SF Symbol (native analogue of the web
    /// `chapter-icons` lucide map). Falls back to a bookmark glyph.
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

/// A single horizontal line filling its rect — stroked dashed to read as the
/// leader dots between a lesson title and its page number.
private struct LeaderLine: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

#if DEBUG
private struct TocSheetPreview: View {
    @Environment(ContentStore.self) private var store
    var body: some View {
        TocSheet(
            outline: store.outline,
            currentLessonId: store.allBookPages.first?.lessonId ?? "",
            currentGlobalPage: 6,
            totalPages: store.totalPages,
            contentsLabel: store.t("contents", .uzLatn),
            pageLabel: store.t("page", .uzLatn),
            pageOfFormat: store.t("page_of", .uzLatn),
            jumpToPageLabel: store.t("jump_to_page", .uzLatn),
            closeLabel: store.t("close", .uzLatn),
            locale: .uzLatn,
            onSelectGlobalPage: { _ in }
        )
    }
}

#Preview("TocSheet") {
    TocSheetPreview().environment(ContentStore())
}
#endif
