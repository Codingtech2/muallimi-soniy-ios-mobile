import SwiftUI

/// One item inside the long-press menu attached to a hifz-playable ayah
/// element (`ArabicElementView`, `Verse`). `ReaderView` is the only place
/// that ever builds these, by looking the element up in `HifzCatalog` —
/// everywhere else the environment provider stays `nil`.
struct AyahMenuAction: Identifiable {
    let title: String
    let systemImage: String
    let action: () -> Void

    var id: String { title }
}

/// Returns the long-press actions for one element, or an empty array when it
/// carries none (not part of any hifz unit).
typealias AyahMenuProvider = (Element) -> [AyahMenuAction]

private struct AyahMenuProviderKey: EnvironmentKey {
    static let defaultValue: AyahMenuProvider? = nil
}

extension EnvironmentValues {
    /// The reader's long-press menu provider. `nil` everywhere except inside
    /// `ReaderView`, which supplies a closure built from `HifzCatalog`.
    var ayahMenuProvider: AyahMenuProvider? {
        get { self[AyahMenuProviderKey.self] }
        set { self[AyahMenuProviderKey.self] = newValue }
    }
}

/// Attaches `.contextMenu` only when the environment provider exists *and*
/// returns at least one action for `element`. With no provider (every screen
/// except the reader) or no matching unit (a reader element that isn't part
/// of a hifz unit), `content` passes through completely unmodified — so
/// nothing about today's tap/render behaviour changes anywhere this isn't
/// explicitly wired up.
private struct AyahContextMenuModifier: ViewModifier {
    let element: Element

    @Environment(\.ayahMenuProvider) private var provider

    @ViewBuilder
    func body(content: Content) -> some View {
        let actions = provider?(element) ?? []
        if actions.isEmpty {
            content
        } else {
            content.hifzPeekableContextMenu(for: element) {
                // Menu titles are localized UI chrome (Latin/Cyrillic script),
                // never the Arabic reading content — force left-to-right so
                // icon+text ordering stays normal no matter which reading
                // direction the calling element applies to itself.
                ForEach(actions) { item in
                    Button(action: item.action) {
                        Label(item.title, systemImage: item.systemImage)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
    }
}

extension View {
    /// See `AyahContextMenuModifier`. Attach once, on the element's own
    /// tappable `Button` — the modifier itself decides whether a menu ever
    /// appears.
    func ayahContextMenu(for element: Element) -> some View {
        modifier(AyahContextMenuModifier(element: element))
    }
}
