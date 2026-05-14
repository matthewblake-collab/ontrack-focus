import SwiftUI
import SafariServices

/// SFSafariViewController wrapper for opening the magic-link URL.
/// Lets the user land authenticated in the web dashboard without
/// re-entering credentials.
struct DashboardSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // no-op
    }
}
