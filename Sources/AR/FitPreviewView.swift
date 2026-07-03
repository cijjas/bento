import SwiftUI
import simd

struct FitPreviewView: UIViewControllerRepresentable {
    var boxSize: simd_float3
    @Binding var status: String
    var rotateToken: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> FitPreviewViewController {
        let vc = FitPreviewViewController()
        vc.boxSize = boxSize
        vc.onStatus = { text in DispatchQueue.main.async { status = text } }
        return vc
    }

    func updateUIViewController(_ vc: FitPreviewViewController, context: Context) {
        vc.updateBoxSize(boxSize)
        if context.coordinator.lastRotate != rotateToken {
            context.coordinator.lastRotate = rotateToken
            vc.rotate()
        }
    }

    final class Coordinator { var lastRotate = 0 }
}
