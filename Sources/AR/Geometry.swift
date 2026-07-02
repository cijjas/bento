import simd
import ARKit

enum Geometry {
    /// Distance in metres between two world points.
    static func distance(_ a: simd_float3, _ b: simd_float3) -> Double {
        Double(simd_distance(a, b))
    }

    /// World position from a raycast result's transform.
    static func position(of result: ARRaycastResult) -> simd_float3 {
        let t = result.worldTransform
        return simd_float3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
    }
}
