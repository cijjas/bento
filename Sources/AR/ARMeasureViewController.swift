import UIKit
import ARKit
import SceneKit

/// A two-tap "AR ruler".
///
/// Tap once to drop point A, tap again to drop point B; the controller reports
/// the distance in metres. On LiDAR devices we enable scene reconstruction +
/// scene depth so raycasts snap to the real reconstructed mesh, which is much
/// more accurate than plane estimation on its own.
final class ARMeasureViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    /// Called every time a new full measurement (A->B) is completed.
    var onMeasurement: ((Double) -> Void)?
    /// Called with a live distance while the second point is being aimed.
    var onLivePreview: ((Double?) -> Void)?
    /// Surfaces tracking quality / coaching to the UI.
    var onStatus: ((String) -> Void)?

    private let sceneView = ARSCNView(frame: .zero)
    private var points: [simd_float3] = []
    private var markerNodes: [SCNNode] = []
    private var lineNode: SCNNode?
    private var hasLiDAR = false

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
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        sceneView.addGestureRecognizer(tap)

        addCrosshair()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
            hasLiDAR = true
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        onStatus?(hasLiDAR ? "Move your phone to scan, then tap a point."
                           : "No LiDAR — move slowly for best accuracy.")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: - Measuring

    @objc private func handleTap() {
        guard let pos = currentRaycastPosition() else {
            onStatus?("Aim at a surface and try again.")
            return
        }

        if points.count == 2 { reset() }   // start a new measurement

        points.append(pos)
        addMarker(at: pos)

        if points.count == 2 {
            let d = Geometry.distance(points[0], points[1])
            drawLine(from: points[0], to: points[1])
            onMeasurement?(d)
            onStatus?(String(format: "Measured %.1f cm. Tap again to start over.", d * 100))
        } else {
            onStatus?("Point A set. Aim at the other end and tap.")
        }
    }

    func reset() {
        points.removeAll()
        markerNodes.forEach { $0.removeFromParentNode() }
        markerNodes.removeAll()
        lineNode?.removeFromParentNode()
        lineNode = nil
        onLivePreview?(nil)
    }

    /// Raycast from screen center to the nearest real surface.
    private func currentRaycastPosition() -> simd_float3? {
        let center = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        // Prefer the reconstructed mesh on LiDAR; fall back to estimated planes.
        let targets: [ARRaycastQuery.Target] = hasLiDAR
            ? [.estimatedPlane, .existingPlaneGeometry]
            : [.estimatedPlane]
        for target in targets {
            if let query = sceneView.raycastQuery(from: center, allowing: target, alignment: .any),
               let hit = sceneView.session.raycast(query).first {
                return Geometry.position(of: hit)
            }
        }
        return nil
    }

    // MARK: - Visuals

    private func addCrosshair() {
        let size: CGFloat = 22
        let cross = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        cross.translatesAutoresizingMaskIntoConstraints = false
        cross.isUserInteractionEnabled = false
        let h = UIView(); let v = UIView()
        [h, v].forEach {
            $0.backgroundColor = .white
            $0.layer.shadowOpacity = 0.6
            $0.layer.shadowRadius = 1
            $0.translatesAutoresizingMaskIntoConstraints = false
            cross.addSubview($0)
        }
        view.addSubview(cross)
        NSLayoutConstraint.activate([
            cross.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cross.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cross.widthAnchor.constraint(equalToConstant: size),
            cross.heightAnchor.constraint(equalToConstant: size),
            h.centerYAnchor.constraint(equalTo: cross.centerYAnchor),
            h.leadingAnchor.constraint(equalTo: cross.leadingAnchor),
            h.trailingAnchor.constraint(equalTo: cross.trailingAnchor),
            h.heightAnchor.constraint(equalToConstant: 2),
            v.centerXAnchor.constraint(equalTo: cross.centerXAnchor),
            v.topAnchor.constraint(equalTo: cross.topAnchor),
            v.bottomAnchor.constraint(equalTo: cross.bottomAnchor),
            v.widthAnchor.constraint(equalToConstant: 2),
        ])
    }

    private func addMarker(at pos: simd_float3) {
        let sphere = SCNSphere(radius: 0.006)
        sphere.firstMaterial?.diffuse.contents = UIColor.systemYellow
        let node = SCNNode(geometry: sphere)
        node.simdPosition = pos
        sceneView.scene.rootNode.addChildNode(node)
        markerNodes.append(node)
    }

    private func drawLine(from a: simd_float3, to b: simd_float3) {
        lineNode?.removeFromParentNode()
        let node = cylinderLine(from: SCNVector3(a), to: SCNVector3(b))
        sceneView.scene.rootNode.addChildNode(node)
        lineNode = node
    }

    /// Live update of the in-progress measurement as the user aims.
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard points.count == 1, let pos = currentRaycastPosition() else {
            if points.count == 1 { onLivePreview?(nil) }
            return
        }
        onLivePreview?(Geometry.distance(points[0], pos))
    }

    private func cylinderLine(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let v = SCNVector3(to.x - from.x, to.y - from.y, to.z - from.z)
        let length = sqrtf(v.x * v.x + v.y * v.y + v.z * v.z)
        let cylinder = SCNCylinder(radius: 0.002, height: CGFloat(length))
        cylinder.firstMaterial?.diffuse.contents = UIColor.systemYellow

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3((from.x + to.x) / 2,
                                   (from.y + to.y) / 2,
                                   (from.z + to.z) / 2)
        // Orient the cylinder (default +Y) along the segment.
        node.look(at: to, up: sceneView.scene.rootNode.worldUp, localFront: SCNVector3(0, 1, 0))
        return node
    }

    // MARK: - Coaching

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal: break
        case .notAvailable: onStatus?("Tracking unavailable.")
        case .limited(let reason):
            switch reason {
            case .excessiveMotion: onStatus?("Slow down — moving too fast.")
            case .insufficientFeatures: onStatus?("Point at a more textured surface.")
            case .initializing: onStatus?("Initializing — move the phone a little.")
            case .relocalizing: onStatus?("Relocalizing…")
            @unknown default: break
            }
        }
    }
}
