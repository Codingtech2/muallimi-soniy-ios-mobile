import SwiftUI
import UIKit

/// Device-adaptive layout tokens for iPad vs iPhone — the one mechanism every
/// screen reads instead of each re-deriving "am I on iPad" with its own
/// per-view magic numbers.
///
/// `.compact` covers every iPhone (any orientation, including the `.regular`
/// horizontal class some Max-size models report in landscape) **and** an iPad
/// in a narrow Split View / Slide Over — i.e. today's exact shipped numbers.
/// `.regular` is an iPad at full width or in a wide-enough Split View. Only
/// `.regular` differs from what ships today; nothing here changes the phone
/// path.
struct LayoutMetrics: Equatable, Sendable {
    /// `true` only on the widened iPad path.
    let isRegular: Bool

    /// Cap for the scrolling list screens (Home / Contents / Settings).
    /// `.infinity` on the compact path — matches today's uncapped,
    /// padding-only width exactly (no visual change on iPhone).
    let contentMaxWidth: CGFloat

    /// Cap for the reader's outer chrome column — the pager, page indicator
    /// and audio bar all sit inside this (`ReaderView.readingColumnWidth`).
    let readingColumnWidth: CGFloat

    /// Cap for the reader header's inner title block
    /// (`ReaderHeader.innerMaxWidth`) — kept a bit wider than
    /// `readingColumnWidth`, mirroring today's relationship (768 vs 640).
    let readerHeaderMaxWidth: CGFloat

    /// Cap for the actual page card inside the pager
    /// (`HorizontalBookPager.readingColumnWidth`) — the binding constraint on
    /// the visible reading card, since it nests inside `readingColumnWidth`.
    let pagerCardMaxWidth: CGFloat

    /// Multiplies the user's Arabic-scale setting (`SettingsStore.arabicScale`)
    /// so tappable letters / words / verses read comfortably on a 13" screen.
    let arabicScaleMultiplier: CGFloat

    /// Columns for the Home chapter quick-jump grid. `1` keeps today's
    /// horizontal scroller unchanged.
    let chapterGridColumns: Int

    /// Cap for a centred one-off dialog-style card (the welcome/adab gate) —
    /// deliberately modest even on iPad, since it holds a short message + one
    /// button, not scrolling list content (`WelcomeGateView`).
    let welcomeCardMaxWidth: CGFloat

    static let compact = LayoutMetrics(
        isRegular: false,
        contentMaxWidth: .infinity,
        readingColumnWidth: 640,
        readerHeaderMaxWidth: 768,
        pagerCardMaxWidth: 560,
        arabicScaleMultiplier: 1.0,
        chapterGridColumns: 1,
        welcomeCardMaxWidth: 460
    )

    static let regular = LayoutMetrics(
        isRegular: true,
        contentMaxWidth: 960,
        readingColumnWidth: 980,
        readerHeaderMaxWidth: 1000,
        pagerCardMaxWidth: 900,
        arabicScaleMultiplier: 1.45,
        chapterGridColumns: 3,
        welcomeCardMaxWidth: 680
    )
}

private struct LayoutMetricsKey: EnvironmentKey {
    static let defaultValue: LayoutMetrics = .compact
}

extension EnvironmentValues {
    /// Adaptive layout tokens for the current window. Defaults to `.compact`
    /// (today's iPhone numbers) until `.adaptiveLayout(baseArabicScale:)`
    /// computes the live value high in the tree.
    var layoutMetrics: LayoutMetrics {
        get { self[LayoutMetricsKey.self] }
        set { self[LayoutMetricsKey.self] = newValue }
    }
}

/// Computes `LayoutMetrics` from the ambient horizontal size class + device
/// idiom, then injects it — together with the size-adjusted Arabic scale —
/// once for the whole subtree below. Apply ONCE, as high in the tree as
/// possible: the app root wraps onboarding and the tab bar, so every tab and
/// anything pushed (`NavigationStack`) or presented (`.sheet`) from them
/// inherits the same metrics without re-deriving them.
private struct AdaptiveLayoutModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The plain (pre-multiplier) Arabic scale from `SettingsStore.arabicScale`,
    /// passed by value rather than re-read through `\.arabicFontScale` — a
    /// modifier chained onto a view never sees another modifier's own
    /// environment writes on that same view; only genuine descendants do.
    let baseArabicScale: Double

    func body(content: Content) -> some View {
        let metrics = resolvedMetrics
        content
            .environment(\.layoutMetrics, metrics)
            .environment(\.arabicFontScale, baseArabicScale * metrics.arabicScaleMultiplier)
    }

    /// iPad in a regular-width context only. iPhone (any orientation) and an
    /// iPad in narrow Split View / Slide Over both resolve to `.compact`, so
    /// the phone path never sees a different number, and a narrowed iPad
    /// multitasking window gracefully falls back to the phone layout.
    private var resolvedMetrics: LayoutMetrics {
        let isPadIdiom = UIDevice.current.userInterfaceIdiom == .pad
        let isRegular = isPadIdiom && horizontalSizeClass == .regular
        return isRegular ? .regular : .compact
    }
}

extension View {
    /// See `AdaptiveLayoutModifier`. `baseArabicScale` is the user's plain
    /// font-size-derived multiplier (`SettingsStore.arabicScale`); this call
    /// combines it with the device-derived iPad multiplier and injects both
    /// `\.layoutMetrics` and the final `\.arabicFontScale` in one shot.
    func adaptiveLayout(baseArabicScale: Double) -> some View {
        modifier(AdaptiveLayoutModifier(baseArabicScale: baseArabicScale))
    }
}
