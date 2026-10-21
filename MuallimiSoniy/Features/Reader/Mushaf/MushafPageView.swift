import SwiftUI
import OSLog

/// Book pages 36–47 with translations off — the surahs set like a printed
/// mushaf, the native port of the web `MushafPage` (`MushafPage.tsx`, user
/// request 2026-10-20). The page is grouped automatically (`MushafBlocks`):
/// a surah banner where a surah starts, the isti'adha and each bismillah
/// centred on a line of their own, and every surah's ayat as ONE flowing
/// right-to-left paragraph, each ayah ending in its number medallion. A surah
/// carried over from the previous page continues without a banner.
///
/// Tapping an ayah plays only that ayah, as before; ayat recorded as one audio
/// take (Ikhlas 3+4) light up together. With translations on, `PageDispatcher`
/// shows the ayah-by-ayah `PageNView` instead.
struct MushafPageView: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    @Environment(ContentStore.self) private var store

    /// Web `flex flex-col gap-1` between blocks.
    private static let blockSpacing: CGFloat = 4

    var body: some View {
        let blocks = MushafBlocks.build(elements: page.elements, verses: store.mushafVerses)
        let highlighted = MushafBlocks.highlightedIds(activeId: currentActiveId, elements: page.elements)
        // The one-time "tap the surah name" hint goes under the page's first banner.
        let hintIndex = blocks.firstIndex(where: \.isBanner)
        VStack(spacing: Self.blockSpacing) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                blockView(block, carriesHint: index == hintIndex, highlighted: highlighted)
            }
        }
        .frame(maxWidth: .infinity)
        #if DEBUG
        .onAppear { MushafPageDebug.runSelfCheckOnce() }
        #endif
    }

    @ViewBuilder
    private func blockView(_ block: MushafBlock, carriesHint: Bool, highlighted: Set<String>) -> some View {
        switch block {
        case .banner(let surah, let lead):
            let banner = MushafBlocks.bannerText(surah: surah, lead: lead)
            SurahBanner(surah: surah, text: banner.text, sub: banner.sub, carriesHint: carriesHint)
        case .line(let item):
            MushafFlowText(items: [item], alignment: .centered, highlightedIds: highlighted, onTap: onTap)
        case .flow(_, let items):
            MushafFlowText(items: items, alignment: .justified, highlightedIds: highlighted, onTap: onTap)
        }
    }

    /// The highlighted element. DEBUG builds also take `-MSMushafActive <id>`,
    /// so a screenshot can show the highlight without a tap.
    private var currentActiveId: String? {
        #if DEBUG
        return activeId ?? MushafPageDebug.activeIdOverride
        #else
        return activeId
        #endif
    }
}

#if DEBUG
/// QA hooks for the Mushaf view, compiled out of release builds.
private enum MushafPageDebug {
    /// `-MSMushafActive <elementId>` — draws that element (and its audio
    /// partner) highlighted, as if it were playing.
    static let activeIdOverride: String? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-MSMushafActive"), arguments.indices.contains(flag + 1) else {
            return nil
        }
        return arguments[flag + 1]
    }()

    private static var didRunSelfCheck = false

    /// Runs `MushafBlocks.selfCheckFailures()` once per launch and logs any
    /// failure loudly — the stand-in for a unit test.
    static func runSelfCheckOnce() {
        guard !didRunSelfCheck else { return }
        didRunSelfCheck = true
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy", category: "Mushaf")
        let failures = MushafBlocks.selfCheckFailures()
        for failure in failures {
            logger.fault("Mushaf self-check failed: \(failure, privacy: .public)")
        }
        if failures.isEmpty {
            logger.debug("Mushaf self-check passed")
        }
    }
}
#endif
