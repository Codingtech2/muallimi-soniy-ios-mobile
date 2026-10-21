import SwiftUI
import OSLog

/// The glass search field floating over the top of the map. It only looks
/// like a field: tapping it opens the search sheet, which owns the typing.
struct MosqueSearchBar: View {
    let locale: AppLocale
    let onTap: () -> Void

    @Environment(ContentStore.self) private var content
    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        let scale = layoutMetrics.uiScale
        let margin = layoutMetrics.isRegular ? MosqueLayout.regularMargin : MosqueLayout.compactMargin
        Button(action: onTap) {
            HStack(spacing: 10 * scale) {
                Image(systemName: "magnifyingglass")
                    .font(layoutMetrics.font(.body.weight(.semibold), .title3.weight(.semibold)))
                    .foregroundStyle(AppColor.primary)
                    .accessibilityHidden(true)
                Text(content.t("mosques_search", locale))
                    .font(layoutMetrics.font(.body, .title3))
                    .foregroundStyle(AppColor.textMuted)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16 * scale)
            .frame(minHeight: 50 * scale)
            .glassCard(cornerRadius: 25 * scale)
            .contentShape(Capsule())
        }
        .buttonStyle(MosqueRowButtonStyle())
        .accessibilityLabel(content.t("mosques_search", locale))
        .frame(maxWidth: layoutMetrics.isRegular ? MosqueLayout.regularPanelWidth : .infinity, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, margin)
        .padding(.top, 4 * scale)
        .padding(.bottom, 6 * scale)
    }
}

/// "© OpenStreetMap" on the map, linking to the copyright page — the
/// attribution the ODbL asks for wherever the data is shown. The page opens
/// inside the app, so a mis-tap on the small chip never leaves it.
struct MosqueAttributionChip: View {
    let locale: AppLocale

    @Environment(ContentStore.self) private var content

    var body: some View {
        if let url = MosqueAttribution.copyrightURL {
            Link(destination: url) {
                Text(content.t("mosques_attribution", locale))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColor.textMain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.regularMaterial, in: Capsule())
                    // An invisible 44 pt band keeps the small chip easy to hit.
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .opensWebLinksInApp()
        }
    }
}

/// Where the OpenStreetMap licence and copyright page live, and when the
/// bundled snapshot was taken.
nonisolated enum MosqueAttribution {
    static let copyrightURL = URL(string: "https://www.openstreetmap.org/copyright")

    /// Just the top-level `generatedAt` of `mosques-uz.json`.
    private struct SnapshotHeader: Decodable {
        let generatedAt: String?
    }

    /// The snapshot date ("2026-10-21T09:10:18Z") read straight from the
    /// bundled dataset — for the credits page, which must not start the
    /// store: loading it also starts the location flow. nil on any problem.
    static func bundledSnapshotDate() -> String? {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy", category: "Mosques")
        guard let url = Bundle.main.url(forResource: "mosques-uz", withExtension: "json") else {
            logger.error("credits: mosques-uz.json is missing")
            return nil
        }
        do {
            return try JSONDecoder().decode(SnapshotHeader.self, from: Data(contentsOf: url)).generatedAt
        } catch {
            logger.error("credits: could not read the snapshot date: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

/// "≈ 2,5 km · toʻgʻri chiziq" on the middle of a straight-line route.
/// VoiceOver hears "taxminan 2,5 km, toʻgʻri chiziq" — a map annotation stays
/// reachable whatever the view asks, so it gets words, not symbols.
struct MosqueRouteChip: View {
    let text: String
    let spokenText: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppColor.textMain)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(AppColor.divider, lineWidth: 0.5))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenText)
    }
}

/// Where a route starts: a small blue dot in a white ring, like the user's
/// own location dot but smaller.
struct MosqueRouteStart: View {
    private static let diameter: CGFloat = 12
    private static let ring: CGFloat = 2

    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: Self.diameter, height: Self.diameter)
            .overlay(Circle().strokeBorder(Color.white, lineWidth: Self.ring))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .accessibilityHidden(true)
    }
}

/// A soft frosted band behind the status bar, so the clock and battery stay
/// readable over busy map pins. Lets every touch through.
struct MosqueStatusBarFade: View {
    /// How far the band reaches below the status bar, in points.
    private static let overhang: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.55),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(height: proxy.safeAreaInsets.top + Self.overhang)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
