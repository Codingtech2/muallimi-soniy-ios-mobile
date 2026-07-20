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

                // TEMP (M2 verification) — pushes the primitives/font sample
                // screen. Remove once the real reader lands in M4.
                NavigationLink {
                    PrimitivesPreviewView()
                } label: {
                    Label("Namuna (primitivlar)", systemImage: "eye.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle("Asosiy")
        }
    }
}
