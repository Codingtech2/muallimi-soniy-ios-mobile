import SwiftUI

/// Landing screen: book identity plus the total page count derived from the
/// flattened content store.
struct HomeView: View {
    @Environment(ContentStore.self) private var store

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Muallimi Soniy")
                        .font(.largeTitle.bold())
                    Text("Ahmad Hodiy Maqsudiy")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Label("Jami: \(store.totalPages) sahifa", systemImage: "book.closed.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                // Primary CTA — opens the reader at the saved page. No progress
                // persistence yet, so it starts at global page 0 → "Boshlash".
                NavigationLink(value: ReaderEntry.global(index: resumeIndex)) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text(resumeIndex > 0 ? "Davom eting" : "Boshlash")
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
            .navigationTitle("Asosiy")
            .navigationDestination(for: ReaderEntry.self) { entry in
                ReaderView(entry: entry)
            }
        }
    }

    /// Saved 0-based global page to resume from. Persistence lands in a later
    /// milestone; for now the book always opens at the first page.
    private var resumeIndex: Int { 0 }
}
