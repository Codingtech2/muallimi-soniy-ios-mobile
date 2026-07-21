import SwiftUI

/// Table-of-contents outline: each chapter is a `Section`, each lesson a row
/// showing its title and 1-based global page span. Proves the flatten/outline
/// pipeline works end to end.
struct ContentsView: View {
    @Environment(ContentStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings

    private var locale: AppLocale { settings.settings.locale }

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.outline) { chapter in
                    Section(chapter.chapter.title.text(locale)) {
                        ForEach(chapter.lessons) { item in
                            // Opens the reader at this lesson's first page.
                            // `globalStart` is 1-based; the reader takes a
                            // 0-based global index.
                            NavigationLink(value: ReaderEntry.global(index: item.globalStart - 1)) {
                                LessonRow(
                                    item: item,
                                    isComplete: progress.isLessonComplete(item.id),
                                    locale: locale,
                                    pageWord: store.t("pages", locale)
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle(store.t("contents", locale))
            .navigationDestination(for: ReaderEntry.self) { entry in
                ReaderView(entry: entry)
            }
        }
    }
}

/// A single lesson row: title above, page span below, with a trailing green
/// checkmark once the lesson has been completed.
private struct LessonRow: View {
    let item: OutlineLesson
    let isComplete: Bool
    let locale: AppLocale
    /// Localised word for "page(s)" ("sahifa" / "стр." / "pages").
    let pageWord: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.lesson.title.text(locale))
                    .font(.body)
                Text(pageLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if isComplete {
                Spacer(minLength: 8)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Tugallangan")
            }
        }
        .padding(.vertical, 2)
    }

    /// Collapses a single-page lesson to "sahifa N" instead of "sahifa N–N".
    private var pageLabel: String {
        item.globalStart == item.globalEnd
            ? "\(pageWord) \(item.globalStart)"
            : "\(pageWord) \(item.globalStart)–\(item.globalEnd)"
    }
}
