import SwiftUI

/// Bespoke 1:1 renderer for book page 34 — Iymon kalimalari (the five kalimas of
/// faith). A centred title, then five kalima blocks: each is a small green
/// heading (`Heading`) above one or more RTL body rows (`KalimaBody`) whose
/// clause parts stack centred and are separated by a decorative `❀` flower
/// (web `Gul`). Every clause is a tappable jumla rendered via the shared `Verse`
/// primitive, so the active highlight matches the rest of the reader and no
/// other element is ever dimmed.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page34`
/// (page-local `Gul` / `KalimaHead` / `KalimaBody`).
struct Page34View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0`.
        VStack(spacing: 0) {
            if let title = c.el("title") {
                Heading(element: title, size: 19, corner: 8, hPad: 12, vPad: 4,
                        activeId: activeId, onTap: onTap)
                    .padding(.bottom, 4)   // mb-1
            }
            kalima(c, head: "k1_head", bodies: [["k1_body"]])
            kalima(c, head: "k2_head", bodies: [["k2_body"]])
            kalima(c, head: "k3_head", bodies: [["k3_p1", "k3_p2", "k3_p3", "k3_p4"]])
            kalima(c, head: "k4_head", bodies: [["k4_p1", "k4_p2", "k4_p3"]])
            kalima(c, head: "k5_head", bodies: [
                ["k5_ast1", "k5_ast2"],
                ["k5_ast3_ext"],
                ["k5_p2_alaniya"],
                ["k5_p3_tawba"],
                ["k5_p4_ghuyub"]
            ])
        }
        .frame(maxWidth: .infinity)
    }

    /// One kalima block — a small green heading (`mt-0.5`) then its body rows.
    @ViewBuilder
    private func kalima(_ c: PageContent, head: String, bodies: [[String]]) -> some View {
        if let h = c.el(head) {
            Heading(element: h, size: 15, corner: 6, hPad: 10, vPad: 2,
                    activeId: activeId, onTap: onTap)
                .padding(.top, 2)   // mt-0.5
        }
        ForEach(Array(bodies.enumerated()), id: \.offset) { _, ids in
            KalimaBody(parts: c.els(ids), activeId: activeId, onTap: onTap)
        }
    }
}

// MARK: - Page-local sub-views

/// A centred, tappable green heading (kalima title / head). Bold Arabic in
/// `textSecondary`; the active state uses the primitive green-pill highlight
/// (fill + glow), never a dim of siblings.
private struct Heading: View {
    let element: Element
    let size: CGFloat
    let corner: CGFloat
    let hPad: CGFloat
    let vPad: CGFloat
    let activeId: String?
    let onTap: (Element) -> Void

    private var isActive: Bool { activeId == element.id }

    var body: some View {
        Button { onTap(element) } label: {
            Text(element.arabic)
                .font(arabicFont(size))
                .foregroundStyle(isActive ? Color.white : AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(isActive ? AppColor.primary : Color.clear)
                )
                .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .rightToLeft)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }
}

/// One kalima body — its clause parts stack centred (each wraps full-width via
/// `Verse`), with a `❀` flower between consecutive parts (web `Gul`). A single
/// clause renders as one centred verse with no flower.
private struct KalimaBody: View {
    let parts: [Element]
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        VStack(spacing: 2) {   // gap-y-0.5 between wrapped clause rows
            ForEach(Array(parts.enumerated()), id: \.element.id) { idx, part in
                Verse(element: part, size: .sm,
                      isActive: activeId == part.id, onTap: onTap)
                if idx < parts.count - 1 { Gul() }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The small green flower (web `Gul`) separating kalima clause parts.
private struct Gul: View {
    var body: some View {
        Text("❀")
            .font(.system(size: 10))       // text-[0.625rem]
            .foregroundStyle(AppColor.primary)
            .opacity(0.55)
    }
}
