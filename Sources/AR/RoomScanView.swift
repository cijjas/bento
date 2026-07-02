import SwiftUI
import RoomPlan
import ARKit
import UIKit
import simd

/// RoomPlan-based furniture capture. RoomPlan detects objects (sofa, table,
/// bed, storage, etc.) and walls, and gives each detected object an oriented
/// bounding box with real dimensions. We surface the largest detected object's
/// box as the candidate measurement.
struct RoomScanView: UIViewControllerRepresentable {
    /// Reports the chosen object's bounding box (metres) when the scan finishes.
    var onFinish: (BoxDimensions?) -> Void
    var onStatus: (String) -> Void

    static var isSupported: Bool { RoomCaptureSession.isSupported }

    func makeUIViewController(context: Context) -> RoomCaptureViewController {
        let vc = RoomCaptureViewController()
        vc.onFinish = onFinish
        vc.onStatus = onStatus
        return vc
    }

    func updateUIViewController(_ vc: RoomCaptureViewController, context: Context) {}
}

/// Hosts a `RoomCaptureView` with a Done button.
/// The view controller itself is the RoomCaptureViewDelegate: that protocol
/// requires NSCoding, which UIViewController already conforms to (a plain
/// coordinator class would not compile).
final class RoomCaptureViewController: UIViewController, RoomCaptureViewDelegate {
    var onFinish: ((BoxDimensions?) -> Void)?
    var onStatus: ((String) -> Void)?

    private var captureView: RoomCaptureView!
    private var isScanning = false

    override func viewDidLoad() {
        super.viewDidLoad()
        captureView = RoomCaptureView(frame: view.bounds)
        captureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        captureView.delegate = self
        view.addSubview(captureView)

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .boldSystemFont(ofSize: 18)
        done.backgroundColor = .systemBlue
        done.setTitleColor(.white, for: .normal)
        done.layer.cornerRadius = 12
        done.translatesAutoresizingMaskIntoConstraints = false
        done.addTarget(self, action: #selector(finishScan), for: .touchUpInside)
        view.addSubview(done)
        NSLayoutConstraint.activate([
            done.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            done.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            done.widthAnchor.constraint(equalToConstant: 160),
            done.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
        isScanning = true
        onStatus?("Slowly move around the object to scan it.")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isScanning {
            isScanning = false
            captureView.captureSession.stop()
        }
    }

    @objc private func finishScan() {
        guard isScanning else { return }
        isScanning = false
        captureView.captureSession.stop()   // triggers post-processing -> didPresent
        onStatus?("Processing scan…")
    }

    // MARK: - RoomCaptureViewDelegate

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData,
                     error: (any Error)?) -> Bool {
        true   // run Apple's post-processing
    }

    // Called after post-processing produces the final room model.
    func captureView(didPresent processedResult: CapturedRoom, error: (any Error)?) {
        if let error {
            onStatus?("Scan failed: \(error.localizedDescription)")
            onFinish?(nil)
            return
        }
        // Pick the object with the largest volume as the thing being measured.
        let best = processedResult.objects.max { lhs, rhs in
            volume(lhs.dimensions) < volume(rhs.dimensions)
        }
        guard let obj = best else {
            onStatus?("No object detected. Try scanning closer.")
            onFinish?(nil)
            return
        }
        // RoomPlan dimensions are (x, y, z) in metres: width, height, depth.
        let d = obj.dimensions
        onFinish?(BoxDimensions(width: Double(d.x),
                                height: Double(d.y),
                                depth: Double(d.z)))
    }

    private func volume(_ v: simd_float3) -> Float { v.x * v.y * v.z }
}
