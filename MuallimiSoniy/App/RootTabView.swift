import SwiftUI

/// Root shell of the app: three primary tabs.
///
/// Reads the shared `ContentStore` from the environment to confirm content
/// is injected before the child screens consume it.
struct RootTabView: View {
    @Environment(ContentStore.self) private var store

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Asosiy", systemImage: "house.fill")
                }

            ContentsView()
                .tabItem {
                    Label("Darslar", systemImage: "book.fill")
                }

            SettingsPlaceholderView()
                .tabItem {
                    Label("Sozlamalar", systemImage: "gearshape.fill")
                }
        }
        .tint(.green)
    }
}
