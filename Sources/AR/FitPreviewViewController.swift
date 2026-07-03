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

    /// Rotate the placed box by 45° around the vertical axis so the user can
    /// try different orientations against their space.
    func rotate() {
        guard let boxNode else { return }
        let turn = SCNAction.rotateBy(x: 0, y: .pi / 4, z: 0, duration: 0.2)
        boxNode.runAction(turn)
    }

    private func rebuildBox() {
        boxNode?.removeFromParentNode()
        let node = GhostBox.node(size: boxSize)
        node.addChildNode(sizeLabel())
        sceneView.scene.rootNode.addChildNode(node)
        boxNode = node
    }

    /// Floating "W × H × D" label hovering above the box, always facing the user.
    private func sizeLabel() -> SCNNode {
        let string = String(format: "%.0f × %.0f × %.0f cm",
                            boxSize.x * 100, boxSize.y * 100, boxSize.z * 100)
        let text = SCNText(string: string, extrusionDepth: 0.2)
        text.font = .systemFont(ofSize: 10, weight: .bold)
        text.flatness = 0.3
        text.firstMaterial?.diffuse.contents = UIColor.white
        text.firstMaterial?.emission.contents = UIColor.white
        text.firstMaterial?.lightingModel = .constant

        let node = SCNNode(geometry: text)
        node.scale = SCNVector3(0.004, 0.004, 0.004)
        let (minB, maxB) = text.boundingBox
        node.position = SCNVector3(-Double(maxB.x - minB.x) * 0.004 / 2,
                                   Double(boxSize.y) / 2 + 0.06, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .Y
        node.constraints = [billboard]
        return node
    }
}
