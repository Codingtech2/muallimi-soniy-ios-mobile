import SwiftUI

/// "Boblar" quick-jump into the reader at each chapter's first page.
///
/// iPhone: a horizontal shelf that runs to the screen edges (a plain column
/// at accessibility text sizes, where shelf cards would be too narrow).
/// iPad: a grid of five columns when five `HomeStyle.chapterCardMinWidth`
/// cards fit (a 13" iPad, either orientation), otherwise two — both divide
/// the ten chapters evenly, so no row ever ends in an orphaned card.
struct HomeChaptersSection: View {
    let store: ContentStore
    let progress: ProgressStore
    let locale: AppLocale

    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Wide enough for every chapter title in all four languages to fit two
    /// lines, and it widens with Dynamic Type so a long word never breaks.
    @ScaledMetric(relativeTo: .subheadline) private var shelfCardWidth: CGFloat = 156
    /// Measured content width for the iPad column rule. Starts at "wide" so
    /// the common full-width launch never flashes from two columns to five.
    @State private var gridWidth: CGFloat = .infinity

    private var gap: CGFloat { HomeStyle.cardGap * layoutMetrics.uiScale }
    private var pagePadding: CGFloat { HomeStyle.pagePadding * layoutMetrics.uiScale }

    private var chaptersLabel: String {
        switch locale {
        case .uzLatn: return "Boblar"
        case .uzCyrl: return "Боблар"
        case .ru:     return "Разделы"
        case .en:     return "Chapters"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * layoutMetrics.uiScale) {
            HomeSectionLabel(text: chaptersLabel)
            chapters
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }
    }

    @ViewBuilder
    private var chapters: some View {
        if layoutMetrics.isRegular {
            HomeGlassGroup {
                LazyVGrid(columns: gridColumns, spacing: gap) {
                    ForEach(store.outline) { chapterLink($0) }
                }
            }
        } else if dynamicTypeSize.isAccessibilitySize {
            HomeGlassGroup {
                VStack(spacing: gap) {
                    ForEach(store.outline) { chapterLink($0) }
                }
            }
        } else {
            shelf
        }
    }

    /// Bleeds to the screen edges while the first card still lines up with
    /// the page margin. Not clipped, so the glass edges stay soft instead of
    /// being cut into a visible band.
    private var shelf: some View {
        ScrollView(.horizontal) {
            HomeGlassGroup {
                HStack(alignment: .top, spacing: gap) {
                    ForEach(store.outline) { chapter in
                        chapterLink(chapter).frame(width: shelfCardWidth)
                    }
                }
                // Every card takes the tallest card's height.
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, pagePadding, for: .scrollContent)
        .scrollClipDisabled()
        .padding(.horizontal, -pagePadding)
    }

    /// Five columns need room for five minimum-width cards at the default
    /// text size; every narrower pane or larger text size takes two.
    private var gridColumns: [GridItem] {
        let fiveAcross = 5 * HomeStyle.chapterCardMinWidth + 4 * gap
        let count = gridWidth >= fiveAcross && dynamicTypeSize <= .large ? 5 : 2
        return Array(repeating: GridItem(.flexible(), spacing: gap), count: count)
    }

    private func chapterLink(_ chapter: OutlineChapter) -> some View {
        HomeChapterLink(
            outline: chapter,
            locale: locale,
            isDone: chapter.lessons.allSatisfy { progress.isLessonComplete($0.lesson.id) },
            pageWord: store.t("pages", locale),
            completedLabel: store.t("completed", locale)
        )
    }
}

/// One chapter card (icon chip, done ✓, title, page span) linking into the
/// reader. VoiceOver reads one stop — title, span and completion — never
/// the symbol names.
private struct HomeChapterLink: View {
    let outline: OutlineChapter
    let locale: AppLocale
    let isDone: Bool
    /// Localized "page(s)" word ("sahifa" / "стр." / "pages").
    let pageWord: String
    /// Localized "completed", spoken after the span when the chapter is done.
    let completedLabel: String

    @Environment(\.layoutMetrics) private var layoutMetrics

    private var title: String { outline.chapter.title.text(locale) }
    /// "sahifa 3–16", worded like the Darslar tab; one page collapses to "sahifa N".
    private var span: String {
        outline.globalStart == outline.globalEnd
            ? "\(pageWord) \(outline.globalStart)"
            : "\(pageWord) \(outline.globalStart)–\(outline.globalEnd)"
    }
    private var cornerRadius: CGFloat { 20 }
    private var chipSide: CGFloat { layoutMetrics.isRegular ? 48 : 36 }

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
        NavigationLink(value: ReaderEntry.global(index: outline.globalStart - 1)) {
            card
        }
        .buttonStyle(HomeCardButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isDone ? "\(span), \(completedLabel)" : span)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 6 * layoutMetrics.uiScale) {
            HStack(alignment: .top) {
                chip
                Spacer(minLength: 8)
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(layoutMetrics.font(.subheadline, .title3))
                        .foregroundStyle(AppColor.primary)
                        .accessibilityHidden(true)
                }
            }
            Spacer(minLength: 12)
            Text(title)
                .font(layoutMetrics.font(.subheadline.weight(.semibold), .title3.weight(.semibold)))
                .foregroundStyle(AppColor.textMain)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                // A long single word ("Kalimalarning") shrinks a little in a
                // narrow iPad column rather than breaking mid-word.
                .minimumScaleFactor(0.9)
            Text(span)
                .font(layoutMetrics.font(.caption, .subheadline))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(AppColor.textMuted)
        }
        .padding(layoutMetrics.isRegular ? 16 : 14)
        // Every iPad card as tall as a two-line title needs, so the rows stay
        // even whether a title wraps or not.
        .frame(maxWidth: .infinity, minHeight: layoutMetrics.isRegular ? 176 : nil, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(cornerRadius: cornerRadius)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var chip: some View {
        Image(systemName: symbol)
            .font(.system(size: chipSide * 0.46))
            .foregroundStyle(AppColor.primary)
            .frame(width: chipSide, height: chipSide)
            .background(AppColor.primary.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityHidden(true)
    }
}
