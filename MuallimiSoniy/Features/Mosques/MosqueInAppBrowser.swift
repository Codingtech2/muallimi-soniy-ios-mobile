import SwiftUI
import SafariServices

extension View {
    /// Web links inside this view open in an in-app browser sheet
    /// (`SFSafariViewController`) instead of leaving for Safari — so a
    /// mis-tap on a small link (the map's "© OpenStreetMap") never throws
    /// the user out of the app. Other schemes (tel:, mailto:) go to the system.
    func opensWebLinksInApp() -> some View {
        modifier(InAppBrowserModifier())
    }
}

/// Catches `openURL` for http(s) links and shows them in a sheet.
private struct InAppBrowserModifier: ViewModifier {
    @State private var page: BrowserPage?

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
                    return .systemAction
                }
                page = BrowserPage(url: url)
                return .handled
            })
            .sheet(item: $page) { page in
                InAppBrowser(url: page.url) { self.page = nil }
                    .ignoresSafeArea()
            }
    }
}

/// The page shown in the sheet.
private struct BrowserPage: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// `SFSafariViewController` for SwiftUI. Its "Done" button closes the sheet.
private struct InAppBrowser: UIViewControllerRepresentable {
    let url: URL
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDone: onDone)
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(AppColor.controlTint)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDone: () -> Void

        init(onDone: @escaping () -> Void) {
            self.onDone = onDone
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDone()
        }
    }
}
