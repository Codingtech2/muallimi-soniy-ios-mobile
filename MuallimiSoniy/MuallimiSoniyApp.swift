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

    /// Per-launch adab gate — shown on every cold launch (NOT persisted, unlike
    /// `hasOnboarded`), so the Qurʼan-letters etiquette reminder (use in a state
    /// of tahorat) always appears before the app content.
    @State private var passedWelcome = false

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
                .adaptiveLayout(baseArabicScale: settings.arabicScale)
                .tint(.green)
                .preferredColorScheme(settings.preferredColorScheme)
                .task {
                    // Release builds trigger the download from onboarding, not here.
                    #if DEBUG
                    if let locale = ProcessInfo.processInfo.environmentLocale {
                        settings.setLocale(locale)
                    }
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
        //  • -MSHifz <surah:N|ayah:<id>|continuous:<id>|continuous:start> opens the
        //    reader with a hifz (memorization) session already running, tuned by
        //    -MSHifzRepeat / -MSHifzEach / -MSHifzPause / -MSHifzSleepSeconds.
        if let screen = ProcessInfo.processInfo.environmentScreen {
            DebugScreenHost(screen: screen)
        } else if let bookPageNumber = ProcessInfo.processInfo.environmentSinglePage {
            DebugSinglePageView(bookPageNumber: bookPageNumber)
        } else if let index = ProcessInfo.processInfo.environmentGlobalReaderPage {
            NavigationStack { ReaderView(entry: .global(index: index)) }
        } else if let hifzTarget = ProcessInfo.processInfo.environmentHifzTarget {
            DebugHifzHost(
                target: hifzTarget,
                repeatOverride: ProcessInfo.processInfo.environmentHifzRepeat,
                eachOverride: ProcessInfo.processInfo.environmentHifzEach,
                pauseToRepeat: ProcessInfo.processInfo.wantsHifzPause,
                sleepSeconds: ProcessInfo.processInfo.environmentHifzSleepSeconds
            )
        } else {
            gatedRoot
        }
        #else
        gatedRoot
        #endif
    }

    /// Every cold launch shows the welcome/adab gate first (tahorat reminder);
    /// once dismissed it falls through to first-run onboarding (one-tap audio
    /// download) or the tabs. `passedWelcome` is `@State`, so the gate returns on
    /// every launch while onboarding stays one-shot via `@AppStorage`.
    @ViewBuilder
    private var gatedRoot: some View {
        if !passedWelcome {
            WelcomeGateView { passedWelcome = true }
        } else if hasOnboarded {
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
            case "settings": SettingsView()
            case "hifz": NavigationStack { HifzSurahListView() }
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
/// QA-only: resolves `-MSHifz*` launch arguments into a `HifzPlan` + start
/// page, then opens the reader with the session already running — so
/// screenshot/log QA can reach any hifz scenario without a single tap.
private struct DebugHifzHost: View {
    @Environment(ContentStore.self) private var store
    let target: String
    let repeatOverride: HifzRepeat?
    let eachOverride: HifzRepeat?
    let pauseToRepeat: Bool
    let sleepSeconds: TimeInterval?

    var body: some View {
        if let resolved = resolvePlan() {
            NavigationStack {
                ReaderView(entry: .global(index: resolved.startIndex), hifzAutoStart: resolved.plan)
            }
        } else {
            ContentUnavailableView("Unknown hifz target: \(target)", systemImage: "questionmark.circle")
        }
    }

    /// Parses `target` (`surah:N`, `ayah:<id>`, `continuous:<id>`,
    /// `continuous:start`) against the catalog and applies the repeat/each/
    /// pause/sleep overrides on top of `HifzPlan.defaults(for:)`.
    private func resolvePlan() -> (plan: HifzPlan, startIndex: Int)? {
        guard let (scope, startIndex) = resolveScope() else { return nil }
        var plan = HifzPlan.defaults(for: scope)
        if let repeatOverride {
            switch scope {
            case .ayah: plan.eachAyah = repeatOverride
            case .surah, .continuous: plan.rounds = repeatOverride
            }
        }
        if let eachOverride {
            plan.eachAyah = eachOverride
        }
        plan.pauseToRepeat = pauseToRepeat
        plan.sleepAfter = sleepSeconds
        return (plan, startIndex)
    }

    /// Resolves just the `target` string into a scope + its start page,
    /// split out from `resolvePlan` to keep each function's job to one thing.
    private func resolveScope() -> (scope: HifzScope, startIndex: Int)? {
        let catalog = store.hifzCatalog
        if target.hasPrefix("surah:"), let number = Int(target.dropFirst("surah:".count)) {
            guard let start = catalog.startGlobalIndex(for: number) else { return nil }
            return (.surah(number: number), start)
        }
        if target.hasPrefix("ayah:") {
            let unitID = String(target.dropFirst("ayah:".count))
            guard let unit = catalog.unit(containing: unitID) else { return nil }
            return (.ayah(unitID: unitID), unit.globalIndex)
        }
        if target == "continuous:start" {
            guard let firstUnit = catalog.surahs.first?.units.first else { return nil }
            return (.continuous(fromUnitID: firstUnit.id), firstUnit.globalIndex)
        }
        if target.hasPrefix("continuous:") {
            let unitID = String(target.dropFirst("continuous:".count))
            guard let unit = catalog.unit(containing: unitID) else { return nil }
            return (.continuous(fromUnitID: unitID), unit.globalIndex)
        }
        return nil
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

    /// Reads the `-MSLocale <uz-latn|uz-cyrl|ru|en>` launch argument so QA /
    /// screenshot tooling can force the app's interface language.
    var environmentLocale: AppLocale? {
        guard let raw = environment["MSLocale"] ?? argumentValue(for: "-MSLocale") else { return nil }
        return AppLocale(rawValue: raw)
    }

    /// Whether `-MSDownloadAudio` was passed, so headless QA can install the
    /// audio pack on launch without going through onboarding.
    var wantsAudioDownload: Bool {
        arguments.contains("-MSDownloadAudio") || environment["MSDownloadAudio"] != nil
    }

    /// Reads the `-MSHifz <target>` launch argument: `surah:N`, `ayah:<id>`,
    /// `continuous:<id>`, or `continuous:start`.
    var environmentHifzTarget: String? {
        environment["MSHifz"] ?? argumentValue(for: "-MSHifz")
    }

    /// Reads `-MSHifzRepeat <1…10|inf>` — maps to `eachAyah` for an ayah
    /// scope, `rounds` for surah/continuous (`DebugHifzHost.resolvePlan`).
    var environmentHifzRepeat: HifzRepeat? {
        guard let raw = environment["MSHifzRepeat"] ?? argumentValue(for: "-MSHifzRepeat") else { return nil }
        return Self.parseHifzRepeat(raw)
    }

    /// Reads `-MSHifzEach <1…10>` — always overrides `eachAyah`.
    var environmentHifzEach: HifzRepeat? {
        guard let raw = environment["MSHifzEach"] ?? argumentValue(for: "-MSHifzEach") else { return nil }
        return Self.parseHifzRepeat(raw)
    }

    /// Whether `-MSHifzPause` was passed (pause-to-repeat on).
    var wantsHifzPause: Bool {
        arguments.contains("-MSHifzPause") || environment["MSHifzPause"] != nil
    }

    /// Reads `-MSHifzSleepSeconds <n>` — a sleep timer of `n` seconds, far
    /// under the sheet's 5-minute minimum, so QA can watch it end a session.
    var environmentHifzSleepSeconds: TimeInterval? {
        guard let raw = environment["MSHifzSleepSeconds"] ?? argumentValue(for: "-MSHifzSleepSeconds") else {
            return nil
        }
        return TimeInterval(raw)
    }

    private static func parseHifzRepeat(_ raw: String) -> HifzRepeat {
        raw.lowercased() == "inf" ? .forever : .count(Int(raw) ?? 1)
    }

    private func argumentValue(for flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
#endif
