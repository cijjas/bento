import SwiftUI
import simd

struct FitPreviewView: UIViewControllerRepresentable {
    var boxSize: simd_float3
    @Binding var status: String

    func makeUIViewController(context: Context) -> FitPreviewViewController {
        let vc = FitPreviewViewController()
        vc.boxSize = boxSize
        vc.onStatus = { text in DispatchQueue.main.async { status = text } }
        return vc
    }

    func updateUIViewController(_ vc: FitPreviewViewController, context: Context) {
        vc.updateBoxSize(boxSize)
    }
}
