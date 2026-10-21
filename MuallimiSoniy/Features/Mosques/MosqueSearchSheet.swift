import SwiftUI

/// Find a mosque by name. Latin and Cyrillic both work (the store folds
/// them); results come closest first once the user is located. Picking one
/// closes the sheet; the caller then chooses it and the map flies there.
/// With nothing typed yet the nearest mosques are offered instead.
struct MosqueSearchSheet: View {
    let locale: AppLocale
    /// Called with the picked mosque right before the sheet closes.
    let onPick: (Mosque) -> Void

    @Environment(MosqueStore.self) private var mosques
    @Environment(ContentStore.self) private var content
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [Mosque] = []
    /// The text `results` belong to, so "nothing found" never flashes while
    /// a search is still waiting for typing to pause.
    @State private var searchedQuery = ""
    @State private var isFieldActive = false

    private static let resultLimit = 40
    /// Wait this long after the last keystroke before searching.
    private static let typingPause: Duration = .milliseconds(150)

    private var formatter: MosqueFormatter { MosqueFormatter(content: content, mosques: mosques, locale: locale) }
    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func tr(_ key: String) -> String { content.t(key, locale) }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    nearbySection
                } else {
                    ForEach(results) { mosque in
                        resultRow(mosque)
                    }
                    .listSectionSeparator(.hidden, edges: .top)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColor.background.ignoresSafeArea())
            .overlay { emptyState }
            .navigationTitle(tr("mosques_search"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("close")) { dismiss() }
                }
            }
            .searchable(
                text: $query,
                isPresented: $isFieldActive,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(tr("mosques_search_prompt"))
            )
            .task(id: "\(query)|\(mosques.isLoaded)") { await runSearch() }
            .task { isFieldActive = true }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    // MARK: - Rows

    @ViewBuilder
    private var nearbySection: some View {
        if !mosques.nearby.isEmpty {
            Section {
                ForEach(mosques.nearby) { item in
                    row(
                        for: item.mosque,
                        detail: formatter.summary(meters: item.meters),
                        spokenDetail: formatter.spokenSummary(meters: item.meters),
                        trailing: nil
                    )
                }
            } header: {
                HomeSectionLabel(text: tr("mosques_nearest"))
            }
        }
    }

    private func resultRow(_ mosque: Mosque) -> some View {
        let trailing = mosques.distance(to: mosque).map(formatter.distance)
        return row(for: mosque, detail: formatter.otherNames(of: mosque), spokenDetail: nil, trailing: trailing)
    }

    private func row(for mosque: Mosque, detail: String?, spokenDetail: String?, trailing: String?) -> some View {
        MosqueRow(title: formatter.name(of: mosque), detail: detail, spokenDetail: spokenDetail, trailing: trailing) {
            choose(mosque)
        }
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(AppColor.divider)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !mosques.isLoaded {
            ProgressView()
                .tint(AppColor.primary)
        } else if trimmedQuery.isEmpty, mosques.nearby.isEmpty {
            // Nothing typed and no nearest list to offer: say what to type.
            ContentUnavailableView {
                Label(tr("mosques_search"), systemImage: "magnifyingglass")
            } description: {
                Text(tr("mosques_search_hint"))
            }
        } else if !trimmedQuery.isEmpty, searchedQuery == trimmedQuery, results.isEmpty {
            ContentUnavailableView {
                Label(tr("mosques_search_empty"), systemImage: "magnifyingglass")
            }
        }
    }

    // MARK: - Actions

    private func choose(_ mosque: Mosque) {
        onPick(mosque)
        dismiss()
    }

    /// Searches once typing pauses; a newer keystroke cancels the wait.
    private func runSearch() async {
        let text = trimmedQuery
        guard !text.isEmpty else {
            results = []
            searchedQuery = ""
            return
        }
        try? await Task.sleep(for: Self.typingPause)
        guard !Task.isCancelled else { return }
        results = mosques.search(text, limit: Self.resultLimit)
        searchedQuery = text
    }
}
