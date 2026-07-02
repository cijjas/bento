import SwiftUI
import UIKit

/// Thin wrapper over UIActivityViewController so we can present the system
/// share sheet (Messages, Mail, AirDrop, …) from SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
