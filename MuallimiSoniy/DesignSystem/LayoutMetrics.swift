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

    /// Cap for the actual page card inside the pager
    /// (`HorizontalBookPager.readingColumnWidth`) — the binding constraint on
    /// the visible reading card. `.regular` is deliberately narrower than the
    /// iPad's available width: at 900 a verse line measured ~90 characters,
    /// roughly double the 45–75 comfortable reading measure. The glyph size is
    /// untouched (`arabicScaleMultiplier` stays 1.45) — only where lines wrap.
    let pagerCardMaxWidth: CGFloat

    /// Gap between the navigation bar's bottom edge and the page card's top
    /// edge. The pager's single source of vertical truth: applied as the inner
    /// scroll view's top content margin, so it resolves to the same number on
    /// every device instead of once per safe-area quirk.
    let cardTopGap: CGFloat

    /// Gap between the page card's bottom edge and the control bar.
    let cardBottomGap: CGFloat

    /// Minimum horizontal inset from the pager cell's edge to the page card.
    /// A floor only — `interPageGutter` usually wins (see below).
    let cardSideGap: CGFloat

    /// Total visible space between two adjacent page cards while a swipe is in
    /// flight. Pager cells abut (`LazyHStack(spacing: 0)`) and are exactly one
    /// viewport wide — paging snap depends on that — so the gutter can only
    /// come from the card's own inset *inside* the cell, which makes it exactly
    /// twice that inset. Declaring the gutter as the primary token keeps the
    /// number that actually matters (what the reader sees mid-turn) the one
    /// that is written down.
    let interPageGutter: CGFloat

    /// Fixed height of the one bottom control bar, **excluding** the bottom
    /// safe area (the bar's fill extends behind the home indicator; only its
    /// content is inset).
    let controlBarHeight: CGFloat

    /// Play/pause circle diameter in the control bar. The visible circle *is*
    /// the hit target — no invisible larger frame around a smaller pill.
    let controlBarPrimaryDiameter: CGFloat

    /// Secondary (page step / element skip / loop) button diameter in the
    /// control bar. Same rule: visible size equals hit target.
    let controlBarSecondaryDiameter: CGFloat

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

    /// General-purpose multiplier for hard-coded chrome numbers (icon sizes,
    /// button heights, fixed padding/spacing) that aren't already covered by
    /// one of the caps above. `.compact` is `1.0` — every existing iPhone
    /// number, multiplied by `1.0`, is itself, so the phone path renders
    /// pixel-identical to today. `.regular` is `1.3` — chosen so chrome grows
    /// visibly on a 13" screen without outgrowing the widened `arabicScaleMultiplier`
    /// (1.45) that already governs the reading content itself.
    let uiScale: CGFloat

    static let compact = LayoutMetrics(
        isRegular: false,
        contentMaxWidth: .infinity,
        pagerCardMaxWidth: 560,
        cardTopGap: 16,
        cardBottomGap: 16,
        cardSideGap: 12,
        interPageGutter: 36,
        controlBarHeight: 72,
        controlBarPrimaryDiameter: 56,
        controlBarSecondaryDiameter: 44,
        arabicScaleMultiplier: 1.0,
        chapterGridColumns: 1,
        welcomeCardMaxWidth: 460,
        uiScale: 1.0
    )

    static let regular = LayoutMetrics(
        isRegular: true,
        contentMaxWidth: 960,
        pagerCardMaxWidth: 760,
        cardTopGap: 24,
        cardBottomGap: 24,
        cardSideGap: 24,
        interPageGutter: 64,
        controlBarHeight: 92,
        controlBarPrimaryDiameter: 72,
        controlBarSecondaryDiameter: 58,
        arabicScaleMultiplier: 1.45,
        chapterGridColumns: 3,
        welcomeCardMaxWidth: 860,
        uiScale: 1.3
    )

    /// Picks `regular` on the widened iPad path, `compact` otherwise — the
    /// one-line way to route a semantic `Font` (e.g. `.subheadline`) through
    /// the same compact/regular split as every raw-number token above,
    /// instead of hand-rolling `layoutMetrics.isRegular ? a : b` at each call
    /// site.
    func font(_ compact: Font, _ regular: Font) -> Font {
        isRegular ? regular : compact
    }
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
