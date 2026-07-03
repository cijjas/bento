import SwiftUI
import UIKit
import ARKit
import SceneKit
import simd

/// True-scale garment silhouette projected into the camera view.
///
/// The killer flow for remote fit-checking clothes: lay YOUR OWN garment flat
/// on a bed or floor, then tap it — the received card's garment is drawn on
/// top of it as a flat, real-size outline. Where the outline sticks out, the
/// remote garment is bigger; where your garment sticks out, it's smaller.
enum GarmentSilhouette {

    /// Build a flat silhouette path (metres, XY plane, hem at y=0) for a card.
    /// Returns nil when the card has no usable width/length.
    static func path(for card: BentoCard) -> UIBezierPath? {
        switch card.category {
        case .clothingTop:
            return shirtPath(chestFlat: card.dimension(labeled: "Chest (flat)")?.meters,
                             length: card.dimension(labeled: "Length")?.meters,
                             shoulder: card.dimension(labeled: "Shoulder")?.meters,
                             sleeve: card.dimension(labeled: "Sleeve")?.meters)
        case .clothingBottom:
            return trousersPath(waistFlat: card.dimension(labeled: "Waist (flat)")?.meters,
                                hipFlat: card.dimension(labeled: "Hip (flat)")?.meters,
                                length: card.dimension(labeled: "Length")?.meters,
                                inseam: card.dimension(labeled: "Inseam")?.meters)
        case .furniture, .generic:
            return nil
        }
    }

    /// Stylized flat T-shirt/jacket outline. Chest width and length are exact;
    /// everything else is proportional so the shape reads as a garment.
    private static func shirtPath(chestFlat: Double?, length: Double?,
                                  shoulder: Double?, sleeve: Double?) -> UIBezierPath? {
        guard let cw = chestFlat, cw > 0.05 else { return nil }
        let W = CGFloat(cw)
        let L = CGFloat(length ?? cw * 1.3)
        guard L > 0.1 else { return nil }
        let SH = CGFloat(shoulder.flatMap { $0 > 0.05 ? $0 : nil } ?? cw * 0.92)
        let SL = CGFloat(sleeve.flatMap { $0 > 0.05 ? $0 : nil } ?? cw * 0.35)

        let w2 = W / 2
        let sw2 = min(SH / 2, w2 * 1.15)
        let armDepth = min(L * 0.42, max(0.14, W * 0.45))
        let yArm = L - armDepth
        // Sleeves slope ~35° below horizontal.
        let dir = CGPoint(x: cos(CGFloat.pi * 35 / 180), y: -sin(CGFloat.pi * 35 / 180))
        let cuffW = max(0.09, armDepth * 0.55)
        let perp = CGPoint(x: -dir.y, y: dir.x)

        let shoulderR = CGPoint(x: sw2, y: L - 0.01)
        let cuffOuterR = CGPoint(x: shoulderR.x + dir.x * SL, y: shoulderR.y + dir.y * SL)
        let cuffInnerR = CGPoint(x: cuffOuterR.x - perp.x * cuffW, y: cuffOuterR.y - perp.y * cuffW)
        let neckHalf = min(0.09, sw2 * 0.45)
        let neckDrop: CGFloat = 0.05

        let p = UIBezierPath()
        p.move(to: CGPoint(x: -w2, y: 0))                       // hem left
        p.addLine(to: CGPoint(x: w2, y: 0))                     // hem
        p.addLine(to: CGPoint(x: w2, y: yArm))                  // right side seam
        p.addLine(to: cuffInnerR)                               // under right sleeve
        p.addLine(to: cuffOuterR)                               // right cuff
        p.addLine(to: shoulderR)                                // top of right sleeve
        p.addLine(to: CGPoint(x: neckHalf, y: L))               // right shoulder → neck
        p.addQuadCurve(to: CGPoint(x: -neckHalf, y: L),         // neckline dip
                       controlPoint: CGPoint(x: 0, y: L - neckDrop * 2))
        p.addLine(to: CGPoint(x: -shoulderR.x, y: shoulderR.y)) // left shoulder
        p.addLine(to: CGPoint(x: -cuffOuterR.x, y: cuffOuterR.y))
        p.addLine(to: CGPoint(x: -cuffInnerR.x, y: cuffInnerR.y))
        p.addLine(to: CGPoint(x: -w2, y: yArm))                 // left side seam
        p.close()
        return p
    }

    /// Stylized flat trousers outline. Waist width, length and inseam are exact.
    private static func trousersPath(waistFlat: Double?, hipFlat: Double?,
                                     length: Double?, inseam: Double?) -> UIBezierPath? {
        guard let wf = waistFlat ?? hipFlat, wf > 0.05 else { return nil }
        let W = CGFloat(hipFlat.flatMap { $0 > 0.05 ? $0 : nil } ?? wf)
        let waistW = CGFloat(wf)
        let L = CGFloat(length ?? wf * 3)
        guard L > 0.2 else { return nil }
        var I = CGFloat(inseam.flatMap { $0 > 0.1 ? $0 : nil } ?? L * 0.75)
        I = min(I, L * 0.9)

        let w2 = W / 2
        let ww2 = min(waistW / 2, w2)
        let ankleOuter = w2 * 0.82
        let ankleGap = max(0.015, w2 * 0.12)   // space between the two legs

        let p = UIBezierPath()
        p.move(to: CGPoint(x: -ww2, y: L))                      // waist left
        p.addLine(to: CGPoint(x: ww2, y: L))                    // waistband
        p.addLine(to: CGPoint(x: w2, y: L - (L - I) * 0.8))     // right hip
        p.addLine(to: CGPoint(x: ankleOuter, y: 0))             // right outer seam
        p.addLine(to: CGPoint(x: ankleGap, y: 0))               // right ankle hem
        p.addLine(to: CGPoint(x: 0, y: I))                      // right inner seam → crotch
        p.addLine(to: CGPoint(x: -ankleGap, y: 0))              // left inner seam
        p.addLine(to: CGPoint(x: -ankleOuter, y: 0))            // left ankle hem
        p.addLine(to: CGPoint(x: -w2, y: L - (L - I) * 0.8))    // left outer seam → hip
        p.close()
        return p
    }
}

/// AR view controller that places the silhouette flat on a horizontal surface.
final class GarmentOverlayViewController: UIViewController {

    var card: BentoCard?
    var onStatus: ((String) -> Void)?

    private let sceneView = ARSCNView(frame: .zero)
    private var garmentNode: SCNNode?
    private var yaw: Float = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(sceneView)
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        sceneView.automaticallyUpdatesLighting = true

        sceneView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))))
        sceneView.addGestureRecognizer(
            UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        onStatus?("Lay your own garment flat, then tap it on screen.")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    /// Rotate the outline in 15° steps to line it up with the real garment.
    func rotate() {
        yaw += .pi / 12
        garmentNode?.simdOrientation = simd_quatf(angle: yaw, axis: simd_float3(0, 1, 0))
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        place(at: gesture.location(in: sceneView))
    }

    /// Drag to slide the outline around once placed.
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard garmentNode != nil else { return }
        place(at: gesture.location(in: sceneView), quiet: true)
    }

    private func place(at point: CGPoint, quiet: Bool = false) {
        guard let query = sceneView.raycastQuery(from: point,
                                                 allowing: .estimatedPlane,
                                                 alignment: .horizontal),
              let hit = sceneView.session.raycast(query).first else {
            if !quiet { onStatus?("No flat surface there — aim at the bed or floor.") }
            return
        }
        let pos = Geometry.position(of: hit)

        if garmentNode == nil {
            guard let node = buildGarment() else {
                onStatus?("This card is missing the width/length needed to draw an outline.")
                return
            }
            sceneView.scene.rootNode.addChildNode(node)
            garmentNode = node
            onStatus?("Outline is real size. Drag to move, rotate to line it up.")
        }
        // Hover 3 mm above the surface to avoid z-fighting with the real fabric.
        garmentNode?.simdPosition = pos + simd_float3(0, 0.003, 0)
    }

    private func buildGarment() -> SCNNode? {
        guard let card, let path = GarmentSilhouette.path(for: card) else { return nil }
        path.flatness = 0.001   // smooth curves at metre scale

        let shape = SCNShape(path: path, extrusionDepth: 0.002)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.5)
        mat.emission.contents = UIColor.systemGreen.withAlphaComponent(0.4)
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        shape.firstMaterial = mat

        let shapeNode = SCNNode(geometry: shape)
        // The path grows +y from the hem; tip it back to lie flat on the floor
        // (path X stays X, path Y becomes floor -Z), centred on its footprint.
        shapeNode.eulerAngles.x = -.pi / 2
        let (minB, maxB) = shapeNode.boundingBox
        shapeNode.position = SCNVector3(0, 0, Double(maxB.z - minB.z) / 2 - Double(maxB.z))

        let parent = SCNNode()
        parent.addChildNode(shapeNode)
        return parent
    }
}

struct GarmentOverlayView: UIViewControllerRepresentable {
    let card: BentoCard
    @Binding var status: String
    var rotateToken: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> GarmentOverlayViewController {
        let vc = GarmentOverlayViewController()
        vc.card = card
        vc.onStatus = { t in DispatchQueue.main.async { status = t } }
        return vc
    }

    func updateUIViewController(_ vc: GarmentOverlayViewController, context: Context) {
        if context.coordinator.lastRotate != rotateToken {
            context.coordinator.lastRotate = rotateToken
            vc.rotate()
        }
    }

    final class Coordinator { var lastRotate = 0 }
}

/// Full-screen overlay experience with coaching and controls.
struct GarmentOverlayScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let card: BentoCard

    @State private var status = "Initializing AR…"
    @State private var rotateToken = 0

    var body: some View {
        ZStack(alignment: .top) {
            GarmentOverlayView(card: card, status: $status, rotateToken: rotateToken)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                StatusBanner(text: status)
                howTo
            }

            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        rotateToken += 1
                    } label: {
                        Label("Rotate", systemImage: "rotate.right")
                    }
                    .buttonStyle(.bordered).tint(.white)

                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 30)
            }
        }
    }

    private var howTo: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: card.category.systemImage)
                .font(.title3)
                .foregroundStyle(.green)
            Text("Lay one of YOUR garments flat and tap it. “\(card.name)” is drawn on top at its real size — anywhere the green outline pokes out, it's bigger than yours.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
