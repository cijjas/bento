import SwiftUI
import UIKit
import ARKit
import SceneKit
import Vision
import simd

/// Photo-based garment measuring.
///
/// A plain photo has no absolute scale, so "fully automatic from a picture"
/// isn't physically possible — but ARKit knows the real-world position of the
/// surface the garment lies on. So: freeze a photo of the garment laid flat,
/// then tap guided point-pairs on the still image. Every tap is unprojected
/// onto the AR-detected surface, giving true metre distances. Vision draws the
/// detected garment outline as a visual sanity check.
final class PhotoMeasureViewController: UIViewController {

    var onStatus: ((String) -> Void)?
    /// Fired when the frame freezes successfully.
    var onFrozen: (() -> Void)?

    private let sceneView = ARSCNView(frame: .zero)
    private let frozenImageView = UIImageView(frame: .zero)
    private let contourLayer = CAShapeLayer()

    /// Camera + surface plane at the moment of capture; both are needed to
    /// turn a 2D tap on the still photo back into a 3D point on the surface.
    private var frozenCamera: ARCamera?
    private var surfaceTransform: simd_float4x4?

    var isFrozen: Bool { frozenCamera != nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(sceneView)
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        frozenImageView.translatesAutoresizingMaskIntoConstraints = false
        frozenImageView.contentMode = .scaleAspectFill
        frozenImageView.isHidden = true
        view.addSubview(frozenImageView)
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            frozenImageView.topAnchor.constraint(equalTo: view.topAnchor),
            frozenImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            frozenImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            frozenImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        sceneView.automaticallyUpdatesLighting = true

        contourLayer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8).cgColor
        contourLayer.fillColor = nil
        contourLayer.lineWidth = 2
        frozenImageView.layer.addSublayer(contourLayer)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Freeze / unfreeze

    /// Freeze the current camera frame. Requires the garment's surface to be
    /// detected under the screen centre.
    func freeze() {
        guard let frame = sceneView.session.currentFrame else { return }
        let center = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        guard let query = sceneView.raycastQuery(from: center,
                                                 allowing: .estimatedPlane,
                                                 alignment: .horizontal),
              let hit = sceneView.session.raycast(query).first else {
            onStatus?("Can't see the surface yet — aim the centre of the screen at the garment and move a little.")
            return
        }
        frozenCamera = frame.camera
        surfaceTransform = hit.worldTransform

        let snapshot = sceneView.snapshot()
        frozenImageView.image = snapshot
        frozenImageView.isHidden = false
        detectContour(in: snapshot)
        onFrozen?()
    }

    func unfreeze() {
        frozenCamera = nil
        surfaceTransform = nil
        frozenImageView.isHidden = true
        frozenImageView.image = nil
        contourLayer.path = nil
    }

    /// Convert a tap on the frozen photo (view coordinates) into a real-world
    /// point on the garment's surface. Metres.
    func worldPoint(at viewPoint: CGPoint) -> simd_float3? {
        guard let camera = frozenCamera, let plane = surfaceTransform else { return nil }
        return camera.unprojectPoint(viewPoint,
                                     ontoPlane: plane,
                                     orientation: .portrait,
                                     viewportSize: sceneView.bounds.size)
    }

    // MARK: - Vision contour (visual aid only)

    /// Outline the garment on the frozen photo so the user can see that the
    /// edges were picked up. Best-effort: silently does nothing on failure.
    private func detectContour(in image: UIImage) {
        guard let cg = image.cgImage else { return }
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.5
        request.detectsDarkOnLight = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
            guard (try? handler.perform([request])) != nil,
                  let observation = request.results?.first else { return }

            // Largest top-level contour ≈ the garment.
            let biggest = observation.topLevelContours.max { a, b in
                a.normalizedPath.boundingBox.width * a.normalizedPath.boundingBox.height <
                b.normalizedPath.boundingBox.width * b.normalizedPath.boundingBox.height
            }
            guard let path = biggest?.normalizedPath else { return }

            DispatchQueue.main.async {
                guard let self, self.isFrozen else { return }
                // Normalized Vision coords (origin bottom-left) → view coords.
                let size = self.frozenImageView.bounds.size
                var transform = CGAffineTransform(scaleX: size.width, y: -size.height)
                    .translatedBy(x: 0, y: -1)
                if let scaled = path.copy(using: &transform) {
                    self.contourLayer.path = scaled
                }
            }
        }
    }
}

/// Owner-accessible handle so the SwiftUI screen can call into the controller.
final class PhotoMeasureController: ObservableObject {
    weak var vc: PhotoMeasureViewController?
}

struct PhotoMeasureView: UIViewControllerRepresentable {
    let controller: PhotoMeasureController
    @Binding var status: String
    @Binding var frozen: Bool

    func makeUIViewController(context: Context) -> PhotoMeasureViewController {
        let vc = PhotoMeasureViewController()
        vc.onStatus = { t in DispatchQueue.main.async { status = t } }
        vc.onFrozen = { DispatchQueue.main.async { frozen = true } }
        controller.vc = vc
        return vc
    }

    func updateUIViewController(_ vc: PhotoMeasureViewController, context: Context) {}
}

/// One guided tap-pair: e.g. "left armpit" → "right armpit" = Chest (flat).
struct MeasurePair {
    let label: String          // dimension label to fill
    let firstPrompt: String
    let secondPrompt: String
    let optional: Bool

    static func pairs(for category: ItemCategory) -> [MeasurePair] {
        switch category {
        case .clothingTop:
            return [
                MeasurePair(label: "Chest (flat)",
                            firstPrompt: "Tap the LEFT armpit seam",
                            secondPrompt: "Tap the RIGHT armpit seam", optional: false),
                MeasurePair(label: "Length",
                            firstPrompt: "Tap the top of the collar",
                            secondPrompt: "Tap the bottom hem, straight below", optional: false),
                MeasurePair(label: "Shoulder",
                            firstPrompt: "Tap the LEFT shoulder seam",
                            secondPrompt: "Tap the RIGHT shoulder seam", optional: true),
                MeasurePair(label: "Sleeve",
                            firstPrompt: "Tap a shoulder seam",
                            secondPrompt: "Tap the cuff of that sleeve", optional: true),
            ]
        case .clothingBottom:
            return [
                MeasurePair(label: "Waist (flat)",
                            firstPrompt: "Tap the LEFT end of the waistband",
                            secondPrompt: "Tap the RIGHT end of the waistband", optional: false),
                MeasurePair(label: "Length",
                            firstPrompt: "Tap the top of the waistband",
                            secondPrompt: "Tap the ankle hem, straight below", optional: false),
                MeasurePair(label: "Hip (flat)",
                            firstPrompt: "Tap the LEFT edge at the widest point",
                            secondPrompt: "Tap the RIGHT edge at the widest point", optional: true),
                MeasurePair(label: "Inseam",
                            firstPrompt: "Tap the crotch seam",
                            secondPrompt: "Tap the ankle hem of one leg", optional: true),
            ]
        case .furniture, .generic:
            return []
        }
    }
}

/// Full-screen photo measuring experience.
struct PhotoMeasureScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let category: ItemCategory
    /// Called with every completed measurement, label → metres.
    let onComplete: ([String: Double]) -> Void

    @StateObject private var controller = PhotoMeasureController()
    @State private var status = ""
    @State private var frozen = false

    @State private var pairIndex = 0
    @State private var firstPoint: simd_float3?
    @State private var tapMarks: [CGPoint] = []          // current pair, view coords
    @State private var doneLines: [(CGPoint, CGPoint)] = []
    @State private var results: [String: Double] = [:]

    private var pairs: [MeasurePair] { MeasurePair.pairs(for: category) }
    private var currentPair: MeasurePair? {
        pairIndex < pairs.count ? pairs[pairIndex] : nil
    }
    private var finished: Bool { pairIndex >= pairs.count }

    var body: some View {
        ZStack(alignment: .top) {
            PhotoMeasureView(controller: controller, status: $status, frozen: $frozen)
                .ignoresSafeArea()
                .onTapGesture { point in handleTap(at: point) }

            marksOverlay.ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 8) {
                if !status.isEmpty { StatusBanner(text: status) }
                instructionCard
            }

            VStack {
                Spacer()
                if !results.isEmpty { resultsBoard }
                controls
            }
            .padding()
        }
        .navigationTitle("Photo measure")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Interaction

    private func handleTap(at point: CGPoint) {
        guard frozen, let pair = currentPair else { return }
        guard let world = controller.vc?.worldPoint(at: point) else {
            status = "That tap missed the surface — try again."
            return
        }
        status = ""
        tapMarks.append(point)
        if let first = firstPoint {
            let meters = Double(simd_distance(first, world))
            results[pair.label] = meters
            doneLines.append((tapMarks[0], tapMarks[1]))
            firstPoint = nil
            tapMarks = []
            pairIndex += 1
        } else {
            firstPoint = world
        }
    }

    // MARK: Pieces

    private var instructionCard: some View {
        Group {
            if !frozen {
                coachText("Lay the garment flat on a contrasting surface. Hold the phone straight above it so the WHOLE garment is in frame, then hit Capture.",
                          icon: "camera.viewfinder")
            } else if let pair = currentPair {
                coachText("\(pair.label): \(firstPoint == nil ? pair.firstPrompt : pair.secondPrompt)",
                          icon: firstPoint == nil ? "1.circle.fill" : "2.circle.fill")
            } else {
                coachText("All done — check the numbers below, then save.",
                          icon: "checkmark.circle.fill")
            }
        }
    }

    private func coachText(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(.yellow)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var marksOverlay: some View {
        Canvas { context, _ in
            for (a, b) in doneLines {
                var line = Path()
                line.move(to: a); line.addLine(to: b)
                context.stroke(line, with: .color(.yellow), lineWidth: 2)
            }
            for p in tapMarks {
                let r: CGFloat = 7
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2*r, height: 2*r)),
                             with: .color(.yellow))
            }
        }
    }

    private var resultsBoard: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(results.sorted(by: { $0.key < $1.key }), id: \.key) { label, meters in
                HStack {
                    Text(label).font(.caption)
                    Spacer()
                    Text(store.format(meters)).font(.caption.monospacedDigit().bold())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if !frozen {
                Button {
                    controller.vc?.freeze()
                } label: {
                    Label("Capture", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    controller.vc?.unfreeze()
                    frozen = false
                    pairIndex = 0
                    firstPoint = nil
                    tapMarks = []
                    doneLines = []
                    results = [:]
                    status = ""
                } label: {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered).tint(.white)

                if let pair = currentPair, pair.optional {
                    Button("Skip") {
                        firstPoint = nil
                        tapMarks = []
                        pairIndex += 1
                    }
                    .buttonStyle(.bordered).tint(.white)
                }

                Button {
                    onComplete(results)
                    dismiss()
                } label: {
                    Label("Save all", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(results.isEmpty)
            }
        }
    }
}
