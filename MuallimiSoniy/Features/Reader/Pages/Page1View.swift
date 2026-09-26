import SwiftUI

/// Bespoke renderer for the MUQADDIMA read-along (book page 1) — a tappable
/// Bismillah at the top, a "MUQADDIMA" heading, then the nine intro prose
/// paragraphs. Ports the web `Page1`, plus one iOS addition: the narration.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page1`.
/// The prose lives outside the element structure, so it is read from the shared
/// `ContentStore.muqaddimaParagraphs` (same environment access as Page3/Page4).
/// The Bismillah uses the amber `jumla` accent when active (its element type),
/// so it carries its own button look rather than the green `ArabicElementView`.
///
/// Audio ships in the app (`Resources/Audio`, cut from the pack's
/// `02. Muqaddima.mp3`): the Bismillah element (`p1_000`) is the bismillah
/// alone; the reading element (`p1_001`) starts with the spoken "Muqaddima" and
/// goes on through all nine paragraphs, so a tap on the heading or anywhere on
/// the text plays the whole reading.
struct Page1View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    @Environment(ContentStore.self) private var store

    var body: some View {
        let c = PageContent(elements: page.elements)
        let bismillah = c.el("000")
        let reading = c.el("001")
        VStack(alignment: .leading, spacing: 16) {  // gap-4
            if let bismillah {
                BismillahButton(element: bismillah, isActive: activeId == bismillah.id) {
                    onTap(bismillah)
                }
                .frame(maxWidth: .infinity)  // mx-auto
            }
            Text("MUQADDIMA")
                .font(.system(size: 18, weight: .bold))  // text-lg
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity)  // text-center
                .padding(.bottom, 8)         // mb-2
                .contentShape(Rectangle())
                .onTapGesture { if let reading { onTap(reading) } }
            ParagraphList(paragraphs: store.muqaddimaParagraphs)
                .modifier(ReadingTapTarget(element: reading, isActive: activeId == reading?.id, onTap: onTap))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Narrated prose

/// Makes the prose one big tap target for its narration, with the Bismillah's
/// amber wash while it plays. The wash is drawn outside the text's frame, so the
/// paragraphs never move when it appears. For VoiceOver the prose is one element:
/// it reads the text, and a double-tap plays the narration like any other
/// element. Without the element (an older content package) the text stays plain.
private struct ReadingTapTarget: ViewModifier {
    let element: Element?
    let isActive: Bool
    let onTap: (Element) -> Void

    @Environment(\.readingAdjustments) private var adjustments
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var amber: Color { AppColor.elJumla }
    /// How far the wash reaches past the text on each side.
    private static let washOutset: CGFloat = 8

    @ViewBuilder
    func body(content: Content) -> some View {
        if let element {
            content
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isActive ? amber.opacity(0.094) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(isActive ? amber.opacity(0.6) : Color.clear, lineWidth: 1.5)
                        )
                        .padding(-Self.washOutset)
                )
                .contentShape(Rectangle())
                .onTapGesture { onTap(element) }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(isActive ? [.startsMediaSession, .isSelected] : .startsMediaSession)
                .accessibilityHint(adjustments.playHint)
                .accessibilityAction { onTap(element) }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isActive)
        } else {
            content
        }
    }
}

// MARK: - Bismillah

/// The tappable Bismillah. Active: amber glyph on a faint amber wash with a 2 pt
/// amber border and a soft amber glow; inactive: neutral reading text with a
/// clear border (kept at 2 pt so highlighting never shifts layout).
private struct BismillahButton: View {
    let element: Element
    let isActive: Bool
    let onTap: () -> Void

    private var amber: Color { AppColor.elJumla }

    var body: some View {
        Button(action: onTap) {
            Text(element.arabic)
                .font(arabicFont(24))  // text-2xl
                .foregroundStyle(isActive ? amber : AppColor.textMain)
                .multilineTextAlignment(.center)
                .lineSpacing(6)  // leading-relaxed
                .padding(.horizontal, 16)  // px-4
                .padding(.vertical, 8)     // py-2
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)  // rounded-lg
                        .fill(isActive ? amber.opacity(0.094) : Color.clear)  // jumla @ 0x18
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isActive ? amber : Color.clear, lineWidth: 2)
                )
                .shadow(color: isActive ? amber.opacity(0.25) : .clear,  // 0 4px 20px @ 0x40
                        radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .rightToLeft)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }
}

// MARK: - Prose

/// The stacked intro paragraphs — plain, non-tappable reading text. Extracted so
/// `Page1View.body` stays small and the paragraph list re-renders on its own.
private struct ParagraphList: View {
    let paragraphs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {  // gap-4
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, text in
                Text(text)
                    .font(.system(size: 14))  // text-sm
                    .foregroundStyle(AppColor.textMain)
                    .lineSpacing(6)           // leading-relaxed
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
