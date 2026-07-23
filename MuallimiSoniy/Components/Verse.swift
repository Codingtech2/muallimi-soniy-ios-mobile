import SwiftUI

/// Font-size buckets for `Verse`, mirroring the web Verse `size` clamp maxima
/// (`sm`/`md`/`lg`). Distinct from `ArabicSize`: surah verse text runs smaller
/// and flows as multi-word lines.
nonisolated enum VerseSize: Sendable {
    case sm, md, lg

    var pointSize: CGFloat {
        switch self {
        case .sm: return 15   // …,0.92rem
        case .md: return 17   // …,1.05rem
        case .lg: return 19   // …,1.2rem
        }
    }
}

/// A tappable Qur'anic verse (or bismillah) — the SwiftUI port of the surah-page
/// `Verse`. The verse words render right-to-left with an optional ayah number
/// appended as `﴿N﴾` in Arabic-Indic digits, followed by a decorative `❀`
/// separator.
///
/// Group-active support: pass `linkedIds` (via the group initialiser) so a verse
/// highlights whenever any element of its shared-audio group is active — the
/// green highlight then covers the whole group, showing the audio spans it.
struct Verse: View {
    let element: Element
    var ayah: Int?
    var size: VerseSize = .sm
    /// When `true`, render inline (no full-width centring wrapper) so several
    /// verses can sit side-by-side inside another row.
    var inRow: Bool = false
    let isActive: Bool
    let onTap: (Element) -> Void

    /// Global Arabic scale from the user's font-size preference (injected at root).
    @Environment(\.arabicFontScale) private var arabicFontScale
    /// Reader page/text palette — defaults to `.paper` (today's exact look)
    /// outside the reader; `ReaderView` injects the live value.
    @Environment(\.readingTheme) private var readingTheme
    /// Line spacing / bold / highlight / VoiceOver strings from the "Aa" sheet.
    @Environment(\.readingAdjustments) private var adjustments
    /// System-wide Settings → Accessibility → Bold Text — treated the same as
    /// the app's own `boldText` reading option.
    @Environment(\.legibilityWeight) private var legibilityWeight
    /// Settings → Accessibility → Reduce Motion — skips the highlight spring.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var effectiveBold: Bool { adjustments.boldText || legibilityWeight == .bold }

    /// Canonical initialiser — the caller supplies `isActive`.
    init(
        element: Element,
        ayah: Int? = nil,
        size: VerseSize = .sm,
        inRow: Bool = false,
        isActive: Bool,
        onTap: @escaping (Element) -> Void
    ) {
        self.element = element
        self.ayah = ayah
        self.size = size
        self.inRow = inRow
        self.isActive = isActive
        self.onTap = onTap
    }

    /// Group initialiser — derives `isActive` from the active id and this verse's
    /// linked (shared-audio) element ids.
    init(
        element: Element,
        ayah: Int? = nil,
        size: VerseSize = .sm,
        inRow: Bool = false,
        activeId: String?,
        linkedIds: [String] = [],
        onTap: @escaping (Element) -> Void
    ) {
        let group = [element.id] + linkedIds
        let active = activeId.map(group.contains) ?? false
        self.init(element: element, ayah: ayah, size: size, inRow: inRow, isActive: active, onTap: onTap)
    }

    var body: some View {
        core
            .modifier(CenterIf(active: !inRow))
    }

    private var core: some View {
        HStack(spacing: 3) {  // gap-[clamp(0.125rem,…,0.25rem)]
            Button {
                onTap(element)
            } label: {
                verseText
                    .multilineTextAlignment(.center)
                    .lineSpacing(1 * adjustments.lineSpacingScale)
                    .padding(.horizontal, 8)  // px-2
                    .padding(.vertical, 2)    // py-0.5
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)  // rounded-md
                            .fill(isActive ? AppColor.primary : Color.clear)
                    )
                    .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(element.accessibilityLabelText)
            .accessibilityHint(adjustments.playHint)
            .accessibilityAddTraits(isActive ? [.startsMediaSession, .isSelected] : .startsMediaSession)
            .accessibilityValue(isActive ? adjustments.activeValueLabel : "")

            if ayah != nil {
                AyahSeparator(pointSize: size.pointSize * arabicFontScale)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }

    /// The verse glyphs plus, when present, a smaller dimmed ayah marker.
    private var verseText: Text {
        let base = isActive ? Color.white : readingTheme.textMain
        var text = Text(element.arabic)
            .font(arabicFont(size.pointSize * arabicFontScale, weight: arabicWeight(bold: effectiveBold)))
            .foregroundStyle(base)
        if let ayah {
            text = text + Text("  ﴿\(arabicIndicDigits(ayah))﴾")
                .font(arabicFont(size.pointSize * 0.78 * arabicFontScale, weight: .regular))
                .foregroundStyle(base.opacity(0.7))
        }
        return text
    }
}

/// The decorative `❀` that trails a verse (web `AyahSeparator`): green
/// `textSecondary`, lightly transparent, scaled to the verse text. Purely
/// decorative — hidden from VoiceOver so it never becomes a confusing extra
/// stop between two meaningful, tappable verses.
struct AyahSeparator: View {
    var pointSize: CGFloat = 15

    @Environment(\.readingTheme) private var readingTheme

    var body: some View {
        Text("❀")
            .font(arabicFont(pointSize, weight: .regular))
            .foregroundStyle(readingTheme.textSecondary)
            .opacity(0.75)
            .accessibilityHidden(true)
    }
}

/// Centres content in a full-width row when `active`; otherwise leaves it inline.
private struct CenterIf: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active {
            content.frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

/// Converts a non-negative integer to Arabic-Indic digits (U+0660…U+0669).
nonisolated func arabicIndicDigits(_ value: Int) -> String {
    let arabic: [Character] = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
    return String(String(value).map { character in
        character.wholeNumberValue.map { arabic[$0] } ?? character
    })
}

#if DEBUG
#Preview("Verse") {
    let verse = Element(
        id: "v1", type: .jumla,
        arabic: "اِيَّاكَ نَعْبُدُ وَاِيَّاكَ نَسْتَعِينُ",
        uzbek: "", audioUrl: nil, start: 0, end: 0, x: 0, y: 0, width: 0, height: 0
    )
    return VStack(spacing: 12) {
        Verse(element: verse, ayah: 5, size: .sm, isActive: false, onTap: { _ in })
        Verse(element: verse, ayah: 5, size: .sm, isActive: true, onTap: { _ in })
    }
    .padding(24)
    .frame(width: 340)
    .background(AppColor.background)
}
#endif
