import SwiftUI

/// SwiftUI bridge around `ARMeasureViewController`.
/// Reports the last completed measurement (metres) via the binding, and exposes
/// a live preview + status string for an overlay.
struct ARMeasureView: UIViewControllerRepresentable {
    @Binding var lastMeasurement: Double?
    @Binding var livePreview: Double?
    @Binding var status: String
    /// Bump this value to ask the controller to reset.
    var resetToken: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> ARMeasureViewController {
        let vc = ARMeasureViewController()
        vc.onMeasurement = { value in
            DispatchQueue.main.async { lastMeasurement = value }
        }
        vc.onLivePreview = { value in
            DispatchQueue.main.async { livePreview = value }
        }
        vc.onStatus = { text in
            DispatchQueue.main.async { status = text }
        }
        context.coordinator.controller = vc
        return vc
    }

    func updateUIViewController(_ vc: ARMeasureViewController, context: Context) {
        if context.coordinator.lastResetToken != resetToken {
            context.coordinator.lastResetToken = resetToken
            vc.reset()
        }
    }

    final class Coordinator {
        weak var controller: ARMeasureViewController?
        var lastResetToken = 0
    }
}
