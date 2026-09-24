import SwiftUI

/// The reader's navigation title. iOS 26 gained a real two-part inline title,
/// so the page counter goes into `navigationSubtitle` there; below that it is
/// one `Text` run appended to the lesson name, which keeps the bar at its
/// system 44pt height. The chapter name is deliberately gone — it grew the bar
/// to 54pt and rendered a literal duplicate on the surah pages, where the
/// lesson title and the chapter title are the same string.
struct ReaderNavigationTitle: ViewModifier {
    let title: String
    let counter: String
    let titleColor: Color
    let counterColor: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .navigationTitle(title)
                .navigationSubtitle(counter)
        } else {
            content.toolbar {
                ToolbarItem(placement: .principal) {
                    (
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(titleColor)
                        + Text(" · \(counter)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(counterColor)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
            }
        }
    }
}
