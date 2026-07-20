import SwiftUI

/// Table-of-contents outline: each chapter is a `Section`, each lesson a row
/// showing its title and 1-based global page span. Proves the flatten/outline
/// pipeline works end to end.
struct ContentsView: View {
    @Environment(ContentStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.outline) { chapter in
                    Section(chapter.chapter.title.text(.uzLatn)) {
                        ForEach(chapter.lessons) { item in
                            LessonRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle("Darslar")
        }
    }
}

/// A single lesson row: title above, page span below.
private struct LessonRow: View {
    let item: OutlineLesson

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.lesson.title.text(.uzLatn))
                .font(.body)
            Text(pageLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// Collapses a single-page lesson to "sahifa N" instead of "sahifa N–N".
    private var pageLabel: String {
        item.globalStart == item.globalEnd
            ? "sahifa \(item.globalStart)"
            : "sahifa \(item.globalStart)–\(item.globalEnd)"
    }
}
