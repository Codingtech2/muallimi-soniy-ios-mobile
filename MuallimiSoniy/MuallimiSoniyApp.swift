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

    init() {
        // Register the bundled Arabic fonts with CoreText before any view
        // renders, so `arabicFont(_:)` / `madArabicFont(_:)` resolve.
        FontRegistrar.register()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
                .tint(.green)
        }
    }
}
