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
                .tint(.green)
        }
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
        // Screenshot/QA shortcut: launch with -MSReaderPage <globalIndex> to open
        // the reader directly (no taps). Off by default → normal app on launch.
        if let index = ProcessInfo.processInfo.environmentGlobalReaderPage {
            NavigationStack { ReaderView(entry: .global(index: index)) }
        } else {
            RootTabView()
        }
        #else
        RootTabView()
        #endif
    }
}

#if DEBUG
private extension ProcessInfo {
    /// Reads the `-MSReaderPage <int>` launch argument (a 0-based global page).
    var environmentGlobalReaderPage: Int? {
        guard let value = environment["MSReaderPage"] ?? argumentValue(for: "-MSReaderPage") else { return nil }
        return Int(value)
    }

    private func argumentValue(for flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
#endif
