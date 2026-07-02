import UIKit
import ARKit
import SceneKit

/// Drops a translucent box of the received dimensions into the user's real
/// space so they can walk around it and see whether it physically fits.
/// Tap a detected surface to place/move the box; it sits on that surface.
final class FitPreviewViewController: UIViewController, ARSCNViewDelegate {

    /// Box size in metres (width=x, height=y, depth=z).
    var boxSize: simd_float3 = .init(0.5, 0.5, 0.5)
    var onStatus: ((String) -> Void)?

    private let sceneView = ARSCNView(frame: .zero)
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
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        sceneView.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        onStatus?("Tap a floor or surface to place the item.")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    func updateBoxSize(_ size: simd_float3) {
        boxSize = size
        if boxNode != nil { rebuildBox() }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let pt = gesture.location(in: sceneView)
        guard let query = sceneView.raycastQuery(from: pt, allowing: .estimatedPlane, alignment: .any),
              let hit = sceneView.session.raycast(query).first else {
            onStatus?("Couldn't find a surface there — aim at the floor.")
            return
        }
        let pos = Geometry.position(of: hit)
        placeBox(at: pos)
        onStatus?(String(format: "%.0f × %.0f × %.0f cm placed. Walk around it.",
                         boxSize.x * 100, boxSize.y * 100, boxSize.z * 100))
    }

    private func placeBox(at floorPos: simd_float3) {
        if boxNode == nil { rebuildBox() }
        // Sit the box on the surface: lift it by half its height.
        boxNode?.simdPosition = simd_float3(floorPos.x,
                                            floorPos.y + boxSize.y / 2,
                                            floorPos.z)
    }

    private func rebuildBox() {
        boxNode?.removeFromParentNode()
        let box = SCNBox(width: CGFloat(boxSize.x),
                         height: CGFloat(boxSize.y),
                         length: CGFloat(boxSize.z),
                         chamferRadius: 0.01)

        let fill = SCNMaterial()
        fill.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.28)
        fill.isDoubleSided = true
        box.firstMaterial = fill

        let node = SCNNode(geometry: box)
        node.addChildNode(makeWireframe(for: boxSize))
        sceneView.scene.rootNode.addChildNode(node)
        boxNode = node
    }

    /// Bright edges so the footprint reads clearly against the room.
    private func makeWireframe(for size: simd_float3) -> SCNNode {
        let edge = SCNNode()
        let hx = size.x / 2, hy = size.y / 2, hz = size.z / 2
        let corners: [simd_float3] = [
            [-hx, -hy, -hz], [hx, -hy, -hz], [hx, -hy, hz], [-hx, -hy, hz],
            [-hx,  hy, -hz], [hx,  hy, -hz], [hx,  hy, hz], [-hx,  hy, hz],
        ]
        let pairs = [(0,1),(1,2),(2,3),(3,0),
                     (4,5),(5,6),(6,7),(7,4),
                     (0,4),(1,5),(2,6),(3,7)]
        for (a, b) in pairs {
            edge.addChildNode(lineNode(from: corners[a], to: corners[b]))
        }
        return edge
    }

    private func lineNode(from a: simd_float3, to b: simd_float3) -> SCNNode {
        let v = b - a
        let length = simd_length(v)
        let cyl = SCNCylinder(radius: 0.004, height: CGFloat(length))
        cyl.firstMaterial?.diffuse.contents = UIColor.systemBlue
        let node = SCNNode(geometry: cyl)
        node.simdPosition = (a + b) / 2
        node.look(at: SCNVector3(b), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        return node
    }
}
