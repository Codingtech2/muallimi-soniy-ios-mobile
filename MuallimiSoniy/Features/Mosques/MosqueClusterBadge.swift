import SwiftUI

/// The round badge standing for several mosques on the map: their count in
/// white on the app's deep green (5:1 under white in both themes), a white
/// ring, a little larger for bigger counts. Fixed sizes on purpose — like the
/// map's own pins it does not grow with Dynamic Type; VoiceOver reads the
/// count instead. Taps go through the map's selection (the badge is tagged
/// there), so a badge tap never also counts as a tap on empty map.
struct MosqueClusterBadge: View {
    let count: Int
    /// "12 ta masjid" — what VoiceOver reads.
    let label: String
    let hint: String

    private static let ringWidth: CGFloat = 2
    /// The smallest badge still gets a 44 pt target.
    private static let minimumTarget: CGFloat = 44

    /// 34 pt for a handful, about 44 pt at 100, 54 pt at a few thousand —
    /// the same size the clustering keeps apart, so badges never overlap.
    private var diameter: CGFloat { CGFloat(MosqueClustering.badgeDiameter(for: count)) }

    /// "8", "120", "2k+".
    private var countText: String {
        count >= 1000 ? "\(count / 1000)k+" : "\(count)"
    }

    var body: some View {
        Text(verbatim: countText)
            .font(.system(size: diameter * 0.38, weight: .bold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(Color.white)
            .padding(4)
            .frame(width: diameter, height: diameter)
            .background(AppColor.primaryButton, in: Circle())
            .overlay(Circle().strokeBorder(Color.white, lineWidth: Self.ringWidth))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .frame(minWidth: Self.minimumTarget, minHeight: Self.minimumTarget)
            .contentShape(Circle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
    }
}
