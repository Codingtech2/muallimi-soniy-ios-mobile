import SwiftUI

/// Root shell of the app: Home · Darslar · [Masjidlar] · Sozlamalar.
///
/// Reads the shared `ContentStore` from the environment to confirm content
/// is injected before the child screens consume it. The Masjidlar tab is
/// optional (off by default) and switched on in Settings.
struct RootTabView: View {
    @Environment(ContentStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    /// The optional mosques map tab. iOS-only, so it lives here rather than
    /// in `AppSettings` (that model mirrors the web settings).
    @AppStorage("ms.showMosquesTab") private var showMosquesTab = false
    /// Explicit tags, so showing or hiding the Masjidlar tab never moves the
    /// user to another tab.
    @State private var selection: RootTab = .home

    /// Chrome locale — tab labels re-localise live when the user switches language.
    private var locale: AppLocale { settings.settings.locale }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Label(store.t("home", locale), systemImage: "house.fill")
                }
                .tag(RootTab.home)

            ContentsView()
                .tabItem {
                    Label(store.t("lessons", locale), systemImage: "book.fill")
                }
                .tag(RootTab.lessons)

            if FeatureFlags.mosquesMap, showMosquesTab {
                MosquesView()
                    .tabItem {
                        Label(store.t("mosques_tab", locale), systemImage: "moon.stars.fill")
                    }
                    .tag(RootTab.mosques)
            }

            SettingsView()
                .tabItem {
                    Label(store.t("settings", locale), systemImage: "gearshape.fill")
                }
                .tag(RootTab.settings)
        }
        .tint(AppColor.controlTint)
        .onChange(of: showMosquesTab) { _, isShown in
            // The tab went away while open: land on Settings, where it is switched.
            if !isShown, selection == .mosques {
                selection = .settings
            }
        }
    }
}

/// The root tabs, used as selection tags.
private enum RootTab: Hashable {
    case home
    case lessons
    case mosques
    case settings
}
