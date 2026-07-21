//
//  MuallimiSoniyApp.swift
//  MuallimiSoniy
//
//  Created by Coding Tech on 20/07/26.
//

import SwiftUI

@main
struct MuallimiSoniyApp: App {
    /// Single source of truth for bundled content, created once and shared
    /// down the view tree via the Observation environment.
    @State private var store = ContentStore()
    /// Shared playback controller — one player for the whole app, injected so the
    /// reader (and later chrome) read it from the environment.
    @State private var audio = AudioController()
    /// Owns the audio-pack download / install / verify pipeline. Onboarding
    /// triggers it later; injected so any screen can observe `phase`.
    @State private var downloadManager = AudioDownloadManager()
    /// Persisted reading progress (resume page + completed lessons), mirroring
    /// the web `ProgressProvider`. Injected so home / reader / contents share it.
    @State private var progress = ProgressStore()
    /// User preferences (theme / locale / font size / repeat count), mirroring
    /// the web `SettingsProvider`. Drives app-wide appearance + Arabic scale.
    @State private var settings = SettingsStore()

    /// One-shot first-run flag. While false, onboarding is shown; its download /
    /// skip / start actions flip it true (persisted), so later launches skip it.
    @AppStorage("ms.hasOnboarded") private var hasOnboarded = false

    init() {
        // Register the bundled Arabic fonts with CoreText before any view
        // renders, so `arabicFont(_:)` / `madArabicFont(_:)` resolve.
        FontRegistrar.register()
    }

    var body: some Scene {
        WindowGroup {
            root
                .environment(store)
                .environment(audio)
                .environment(downloadManager)
                .environment(progress)
                .environment(settings)
                .environment(\.arabicFontScale, settings.arabicScale)
                .tint(.green)
                .preferredColorScheme(settings.preferredColorScheme)
                .task {
                    // Release builds trigger the download from onboarding, not here.
                    #if DEBUG
                    if ProcessInfo.processInfo.wantsAudioDownload {
                        await downloadManager.ensureReady()
                    }
                    #endif
                }
        }
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
        // Screenshot/QA shortcuts (off by default → normal app on launch):
        //  • -MSScreen <home|contents|settings> renders one tab screen directly,
        //    so auth-free QA can reach Contents / Settings without a tap tool.
        //  • -MSPageOnly <bookPageNumber> renders exactly one page through the real
        //    dispatcher, bypassing the pager (reliable for any page).
        //  • -MSReaderPage <globalIndex> opens the full reader at a global page.
        if let screen = ProcessInfo.processInfo.environmentScreen {
            DebugScreenHost(screen: screen)
        } else if let bookPageNumber = ProcessInfo.processInfo.environmentSinglePage {
            DebugSinglePageView(bookPageNumber: bookPageNumber)
        } else if let index = ProcessInfo.processInfo.environmentGlobalReaderPage {
            NavigationStack { ReaderView(entry: .global(index: index)) }
        } else {
            gatedRoot
        }
        #else
        gatedRoot
        #endif
    }

    /// First launch shows onboarding (one-tap audio download with live progress);
    /// afterwards it goes straight to the tabs.
    @ViewBuilder
    private var gatedRoot: some View {
        if hasOnboarded {
            RootTabView()
        } else {
            OnboardingView { hasOnboarded = true }
        }
    }
}

#if DEBUG
/// QA-only: renders one primary tab screen directly (no tab bar, no taps) so
/// screenshot tooling can reach Contents / Settings. Reads the shared stores
/// from the environment exactly as the real tabs do.
private struct DebugScreenHost: View {
    @Environment(ContentStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    let screen: String

    var body: some View {
        Group {
            switch screen {
            case "home": HomeView()
            case "contents": ContentsView()
            case "settings": SettingsV2View()
            default:
                ContentUnavailableView("Unknown screen: \(screen)", systemImage: "questionmark.circle")
            }
        }
        .onAppear { seedDemoProgressIfNeeded() }
    }

    /// Seeds a mid-book demo state (resume at page 41; every lesson finished
    /// before it marked complete) for the home / contents screenshot hosts.
    private func seedDemoProgressIfNeeded() {
        guard screen == "home" || screen == "contents" else { return }
        let completed = store.outline
            .flatMap(\.lessons)
            .filter { $0.globalEnd <= 40 }   // fully before the 41st global page
            .map(\.id)
        progress.debugSeed(resumeGlobalIndex: 40, completedLessons: completed)
    }
}
#endif

#if DEBUG
/// QA-only: renders one book page through the real `PageDispatcher` (in the same
/// card chrome the reader uses), with no pager and no taps — so screenshot tooling
/// can reach any page reliably. Picks the first occurrence of a book page number.
private struct DebugSinglePageView: View {
    @Environment(ContentStore.self) private var store
    let bookPageNumber: Int

    var body: some View {
        Group {
            if let page = store.allBookPages.first(where: { $0.pageNumber == bookPageNumber }) {
                ScrollView(.vertical) {
                    PageHostView(page: page, activeId: nil, onTap: { _ in })
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                }
                .scrollIndicators(.hidden)
            } else {
                ContentUnavailableView(
                    "No book page \(bookPageNumber)",
                    systemImage: "questionmark.circle"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background.ignoresSafeArea())
    }
}
#endif

#if DEBUG
private extension ProcessInfo {
    /// Reads the `-MSReaderPage <int>` launch argument (a 0-based global page).
    var environmentGlobalReaderPage: Int? {
        guard let value = environment["MSReaderPage"] ?? argumentValue(for: "-MSReaderPage") else { return nil }
        return Int(value)
    }

    /// Reads the `-MSPageOnly <int>` launch argument (a book page number).
    var environmentSinglePage: Int? {
        guard let value = environment["MSPageOnly"] ?? argumentValue(for: "-MSPageOnly") else { return nil }
        return Int(value)
    }

    /// Reads the `-MSScreen <name>` launch argument (home / contents / settings).
    var environmentScreen: String? {
        environment["MSScreen"] ?? argumentValue(for: "-MSScreen")
    }

    /// Whether `-MSDownloadAudio` was passed, so headless QA can install the
    /// audio pack on launch without going through onboarding.
    var wantsAudioDownload: Bool {
        arguments.contains("-MSDownloadAudio") || environment["MSDownloadAudio"] != nil
    }

    private func argumentValue(for flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
#endif
