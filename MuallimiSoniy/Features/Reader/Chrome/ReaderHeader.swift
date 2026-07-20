import SwiftUI

/// The reader's top bar — the SwiftUI port of the web lesson-page `<header>`.
///
/// Layout: a back button (dismisses the reader) on the left, the current
/// lesson title with its chapter title beneath it in the centre, and a
/// table-of-contents button on the right. A hairline rule seals the bottom
/// edge (web `border-b border-white/10`). Inner content is capped at the
/// web `max-w-3xl` reading width and centred on wide screens.
struct ReaderHeader: View {
    let lessonTitle: String
    let chapterTitle: String
    /// Accessibility label for the TOC button (localised "Darslar").
    let tocLabel: String
    let onBack: () -> Void
    let onOpenToc: () -> Void

    /// Web `max-w-3xl` (48rem) inner cap.
    private let innerMaxWidth: CGFloat = 768

    var body: some View {
        HStack(spacing: 12) {
            iconButton(system: "arrow.left", label: "Orqaga", action: onBack)

            VStack(alignment: .leading, spacing: 1) {
                Text(lessonTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.textMain)
                    .lineLimit(1)
                if !chapterTitle.isEmpty {
                    Text(chapterTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColor.textMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            iconButton(system: "list.bullet", label: tocLabel, action: onOpenToc)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(maxWidth: innerMaxWidth)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppColor.divider)
                .frame(height: 1)
        }
    }

    /// A 40×40 rounded icon button matching the web header buttons
    /// (`bg-white/5`, `rounded-xl`).
    private func iconButton(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppColor.textMain)
                .frame(width: 40, height: 40)
                .background(
                    AppColor.surface,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#if DEBUG
#Preview("ReaderHeader") {
    VStack {
        ReaderHeader(
            lessonTitle: "Harflar (1-qism)",
            chapterTitle: "Harflar",
            tocLabel: "Darslar",
            onBack: {},
            onOpenToc: {}
        )
        Spacer()
    }
    .background(AppColor.background)
}
#endif
