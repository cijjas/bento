import SwiftUI
import RealityKit
import ARKit
import UIKit

/// Projects a captured USDZ model into the user's real space at true 1:1 scale.
/// Tap a detected surface to place (or move) the object; because Object Capture
/// exports real-world scale, no scaling is applied — what you see is its size.
struct ModelPlacementView: UIViewRepresentable {
    let modelURL: URL
    @Binding var status: String

    func makeCoordinator() -> Coordinator { Coordinator(modelURL: modelURL, status: $status) }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        arView.session.run(config)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)
        context.coordinator.arView = arView
        context.coordinator.preload()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    final class Coordinator: NSObject {
        weak var arView: ARView?
        let modelURL: URL
        @Binding var status: String
        // Entity, not ModelEntity: the async throwing init(contentsOf:) is
        // defined on Entity. Bounds and cloning work the same.
        private var template: Entity?
        private var placedAnchor: AnchorEntity?

        init(modelURL: URL, status: Binding<String>) {
            self.modelURL = modelURL
            self._status = status
        }

        /// Load the model once up front so taps place instantly.
        func preload() {
            Task { @MainActor in
                do {
                    // The async Entity(contentsOf:) initializer is iOS 18+;
                    // fall back to the synchronous loader on iOS 17.
                    let entity: Entity
                    if #available(iOS 18.0, *) {
                        entity = try await Entity(contentsOf: modelURL)
                    } else {
                        entity = try Entity.load(contentsOf: modelURL)
                    }
                    self.template = entity
                    self.status = "Tap a surface to place the object at real size."
                } catch {
                    self.status = "Couldn't load the 3D model."
                }
            }
        }

        @MainActor @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView, let template else { return }
            let point = gesture.location(in: arView)

            guard let result = arView.raycast(from: point,
                                              allowing: .estimatedPlane,
                                              alignment: .any).first else {
                status = "Aim at a flat surface and tap."
                return
            }

            // Remove any previous placement so "move" works by tapping elsewhere.
            placedAnchor.map { arView.scene.removeAnchor($0) }

            let anchor = AnchorEntity(world: result.worldTransform)
            let model = template.clone(recursive: true)
            // Object Capture models are real-scale; rest the model on the surface.
            let bounds = model.visualBounds(relativeTo: nil)
            model.position.y += bounds.extents.y / 2 - bounds.center.y
            anchor.addChild(model)
            arView.scene.addAnchor(anchor)
            placedAnchor = anchor

            let e = bounds.extents
            status = String(format: "Placed at %.0f × %.0f × %.0f cm. Walk around it.",
                            e.x * 100, e.y * 100, e.z * 100)
        }
    }
}
