import SwiftUI

/// Landing screen: book identity plus the total page count derived from the
/// flattened content store.
struct HomeView: View {
    @Environment(ContentStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings

    private var locale: AppLocale { settings.settings.locale }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.t("app_name", locale))
                        .font(.largeTitle.bold())
                    Text(store.t("book_author", locale))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Label("\(store.totalPages) \(store.t("pages", locale))", systemImage: "book.closed.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                // Primary CTA — opens the reader at the saved page. Reads the
                // persisted resume index; 0 → "Boshlash", otherwise "Davom eting".
                NavigationLink(value: ReaderEntry.global(index: resumeIndex)) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text(resumeIndex > 0 ? store.t("continue", locale) : store.t("start", locale))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle(store.t("home", locale))
            .navigationDestination(for: ReaderEntry.self) { entry in
                ReaderView(entry: entry)
            }
        }
    }

    /// Saved 0-based global page to resume from (`0` when there is no progress).
    private var resumeIndex: Int { progress.resumeGlobalIndex }
}
