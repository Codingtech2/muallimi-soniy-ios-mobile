import SwiftUI

/// A thin, full-width dotted rule — the SwiftUI port of the web `Divider`
/// (`w-full border-b-2 border-dotted border-white/10 my-2`).
struct SectionDivider: View {
    var body: some View {
        DottedLine()
            .stroke(
                AppColor.divider,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 4])
            )
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)   // my-2
    }
}

/// A single horizontal line drawn across the middle of its rect; stroked with a
/// round-capped dash to read as dots.
private struct DottedLine: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

#if DEBUG
#Preview("SectionDivider") {
    VStack {
        Text("above")
        SectionDivider()
        Text("below")
    }
    .padding(24)
    .background(AppColor.background)
}
#endif
