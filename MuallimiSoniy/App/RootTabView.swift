import SwiftUI

/// Root shell of the app: three primary tabs.
///
/// Reads the shared `ContentStore` from the environment to confirm content
/// is injected before the child screens consume it.
struct RootTabView: View {
    @Environment(ContentStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    /// Chrome locale — tab labels re-localise live when the user switches language.
    private var locale: AppLocale { settings.settings.locale }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label(store.t("home", locale), systemImage: "house.fill")
                }

            ContentsView()
                .tabItem {
                    Label(store.t("lessons", locale), systemImage: "book.fill")
                }

            SettingsView()
                .tabItem {
                    Label(store.t("settings", locale), systemImage: "gearshape.fill")
                }
        }
        .tint(.green)
    }
}
