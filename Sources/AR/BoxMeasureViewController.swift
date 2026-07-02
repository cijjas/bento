import UIKit
import ARKit
import SceneKit
import simd

/// Camera-only bounding-box measurement. Works on ANY ARKit iPhone — no LiDAR.
///
/// Flow:
///   1. Tap two adjacent corners of the object's footprint on the floor → width
///      (and the object's facing direction).
///   2. Tap a third corner → depth (perpendicular distance to the first edge).
///   3. Adjust a height slider (from SwiftUI) → a live AR box grows so you can
///      match it to the real object's top.
///
/// Scale comes from ARKit's visual-inertial tracking (camera + motion), so the
/// metres are real even without a depth sensor. Accuracy is a few percent;
/// measuring twice is wise.
final class BoxMeasureViewController: UIViewController, ARSessionDelegate {

    enum Step { case cornerA, cornerB, cornerC, adjustHeight, done }

    /// Reports the current box (metres) whenever it changes.
    var onBoxChanged: ((BoxDimensions) -> Void)?
    var onStep: ((Step) -> Void)?
    var onStatus: ((String) -> Void)?

    private let sceneView = ARSCNView(frame: .zero)
    private(set) var step: Step = .cornerA

    private var a: simd_float3?
    private var b: simd_float3?
    private var c: simd_float3?
    private var width: Float = 0
    private var depth: Float = 0
    private var height: Float = 0.5      // default 50 cm, driven by slider

    private var footprintNodes: [SCNNode] = []
    private var boxNode: SCNNode?

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
        sceneView.session.delegate = self

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tap)
        addCrosshair()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        // Use LiDAR mesh if present (better raycasts) but never require it.
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        onStatus?("Aim at the floor by one corner of the object and tap.")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Public control (from SwiftUI)

    func setHeight(_ meters: Float) {
        height = max(0.01, meters)
        if step == .adjustHeight || step == .done { rebuildBox() }
        emit()
    }

    func reset() {
        a = nil; b = nil; c = nil; width = 0; depth = 0
        footprintNodes.forEach { $0.removeFromParentNode() }
        footprintNodes.removeAll()
        boxNode?.removeFromParentNode(); boxNode = nil
        step = .cornerA
        onStep?(step)
        onStatus?("Aim at the floor by one corner of the object and tap.")
    }

    // MARK: - Tapping

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let pos = floorRaycast() else {
            onStatus?("Couldn't find the floor there — aim lower and tap.")
            return
        }
        switch step {
        case .cornerA:
            a = pos; dropMarker(pos)
            step = .cornerB; onStep?(step)
            onStatus?("Now tap the next corner along one side.")
        case .cornerB:
            b = pos; dropMarker(pos)
            width = simd_distance(horizontal(a!), horizontal(b!))
            step = .cornerC; onStep?(step)
            onStatus?("Tap a corner on the perpendicular side.")
        case .cornerC:
            c = pos; dropMarker(pos)
            depth = perpendicularDistance(of: c!, toLineFrom: a!, to: b!)
            step = .adjustHeight; onStep?(step)
            rebuildBox()
            emit()
            onStatus?("Drag the height slider until the box matches the top.")
        case .adjustHeight, .done:
            break
        }
    }

    /// Raycast to a horizontal surface (estimated plane works without LiDAR).
    private func floorRaycast() -> simd_float3? {
        let center = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        guard let query = sceneView.raycastQuery(from: center,
                                                 allowing: .estimatedPlane,
                                                 alignment: .horizontal),
              let hit = sceneView.session.raycast(query).first else { return nil }
        return Geometry.position(of: hit)
    }

    // MARK: - Geometry

    private func horizontal(_ v: simd_float3) -> simd_float3 { simd_float3(v.x, 0, v.z) }

    private func perpendicularDistance(of p: simd_float3,
                                       toLineFrom a: simd_float3,
                                       to b: simd_float3) -> Float {
        let ab = horizontal(b) - horizontal(a)
        let ap = horizontal(p) - horizontal(a)
        let len = simd_length(ab)
        guard len > 0 else { return 0 }
        let dir = ab / len
        let along = simd_dot(ap, dir) * dir
        return simd_length(ap - along)
    }

    private func emit() {
        onBoxChanged?(BoxDimensions(width: Double(width),
                                    height: Double(height),
                                    depth: Double(depth)))
    }

    // MARK: - Visuals

    private func dropMarker(_ pos: simd_float3) {
        let s = SCNSphere(radius: 0.008)
        s.firstMaterial?.diffuse.contents = UIColor.systemYellow
        let n = SCNNode(geometry: s)
        n.simdPosition = pos
        sceneView.scene.rootNode.addChildNode(n)
        footprintNodes.append(n)
    }

    private func rebuildBox() {
        guard let a, let b else { return }
        boxNode?.removeFromParentNode()

        let box = SCNBox(width: CGFloat(max(width, 0.001)),
                         height: CGFloat(max(height, 0.001)),
                         length: CGFloat(max(depth, 0.001)),
                         chamferRadius: 0.004)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.25)
        mat.isDoubleSided = true
        box.firstMaterial = mat

        let node = SCNNode(geometry: box)

        // Centre of the footprint, lifted by half the height.
        let edgeDir = simd_normalize(horizontal(b) - horizontal(a))
        let perpDir = simd_float3(-edgeDir.z, 0, edgeDir.x)
        let footCenter = (horizontal(a) + horizontal(b)) / 2 + perpDir * (depth / 2)
        node.simdPosition = simd_float3(footCenter.x, a.y + height / 2, footCenter.z)

        // Rotate so the box's local X axis lines up with edge AB.
        let yaw = atan2(edgeDir.x, edgeDir.z)
        node.simdOrientation = simd_quatf(angle: yaw, axis: simd_float3(0, 1, 0))

        sceneView.scene.rootNode.addChildNode(node)
        boxNode = node
    }

    private func addCrosshair() {
        let label = UILabel()
        label.text = "＋"
        label.textColor = .white
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        if case .limited(.insufficientFeatures) = camera.trackingState {
            onStatus?("Point at a more textured area and move a little.")
        }
    }
}
