import SceneKit
import simd
import UIKit

/// Builds the translucent "ghost" boxes used by the measuring and preview AR
/// screens. One shared look: a clearly visible tinted fill plus bright
/// emissive edges so the box reads against any room, bright or dark.
enum GhostBox {

    static let fillColor = UIColor.systemCyan
    static let edgeColor = UIColor.systemYellow

    /// A box of `size` metres centred on its own origin: visible fill + edges.
    static func node(size: simd_float3) -> SCNNode {
        let box = SCNBox(width: CGFloat(max(size.x, 0.001)),
                         height: CGFloat(max(size.y, 0.001)),
                         length: CGFloat(max(size.z, 0.001)),
                         chamferRadius: 0)

        let fill = SCNMaterial()
        fill.diffuse.contents = fillColor.withAlphaComponent(0.35)
        // Emission keeps the fill visible in dim rooms where diffuse goes muddy.
        fill.emission.contents = fillColor.withAlphaComponent(0.25)
        fill.isDoubleSided = true
        box.firstMaterial = fill

        let node = SCNNode(geometry: box)
        node.addChildNode(edges(for: size))
        return node
    }

    /// Bright glowing wireframe for a box of `size` centred on the origin.
    static func edges(for size: simd_float3) -> SCNNode {
        let parent = SCNNode()
        let hx = size.x / 2, hy = size.y / 2, hz = size.z / 2
        let corners: [simd_float3] = [
            [-hx, -hy, -hz], [hx, -hy, -hz], [hx, -hy, hz], [-hx, -hy, hz],
            [-hx,  hy, -hz], [hx,  hy, -hz], [hx,  hy, hz], [-hx,  hy, hz],
        ]
        let pairs = [(0,1),(1,2),(2,3),(3,0),
                     (4,5),(5,6),(6,7),(7,4),
                     (0,4),(1,5),(2,6),(3,7)]
        for (a, b) in pairs {
            parent.addChildNode(line(from: corners[a], to: corners[b]))
        }
        return parent
    }

    /// A single glowing edge segment.
    static func line(from a: simd_float3, to b: simd_float3,
                     radius: CGFloat = 0.006,
                     color: UIColor = edgeColor) -> SCNNode {
        let v = b - a
        let length = simd_length(v)
        guard length > 0 else { return SCNNode() }
        let cyl = SCNCylinder(radius: radius, height: CGFloat(length))
        cyl.firstMaterial?.diffuse.contents = color
        cyl.firstMaterial?.emission.contents = color
        cyl.firstMaterial?.lightingModel = .constant
        let node = SCNNode(geometry: cyl)
        node.simdPosition = (a + b) / 2
        node.look(at: SCNVector3(b), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        return node
    }

    /// A numbered corner marker: bright sphere + floating digit that always
    /// faces the camera. Far easier to follow than identical dots.
    static func cornerMarker(at pos: simd_float3, number: Int) -> SCNNode {
        let parent = SCNNode()
        parent.simdPosition = pos

        let sphere = SCNSphere(radius: 0.012)
        sphere.firstMaterial?.diffuse.contents = edgeColor
        sphere.firstMaterial?.emission.contents = edgeColor
        sphere.firstMaterial?.lightingModel = .constant
        parent.addChildNode(SCNNode(geometry: sphere))

        let text = SCNText(string: "\(number)", extrusionDepth: 0.2)
        text.font = .systemFont(ofSize: 10, weight: .heavy)
        text.flatness = 0.3
        text.firstMaterial?.diffuse.contents = UIColor.white
        text.firstMaterial?.emission.contents = UIColor.white
        text.firstMaterial?.lightingModel = .constant
        let textNode = SCNNode(geometry: text)
        // SCNText is huge in scene units; shrink to ~2.5 cm tall.
        textNode.scale = SCNVector3(0.0025, 0.0025, 0.0025)
        let (minB, maxB) = text.boundingBox
        textNode.position = SCNVector3(-Double(maxB.x - minB.x) * 0.0025 / 2, 0.02, 0)
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = .all
        textNode.constraints = [billboard]
        parent.addChildNode(textNode)
        return parent
    }
}
