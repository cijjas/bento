import Foundation
import RealityKit
import simd

/// Manages captured USDZ model files on disk and derives real-world dimensions
/// from them. Models live in Documents/Models/<uuid>.usdz so they survive app
/// launches and can be referenced by a BentoCard's `modelFilename`.
enum ModelLibrary {
    static var directory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Models", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    /// Move a freshly reconstructed model into the library, returning its stored
    /// filename. Uses a UUID name so two captures never collide.
    @discardableResult
    static func adopt(from tempURL: URL) throws -> String {
        let filename = UUID().uuidString + ".usdz"
        let dest = url(for: filename)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return filename
    }

    static func delete(filename: String?) {
        guard let filename else { return }
        try? FileManager.default.removeItem(at: url(for: filename))
    }

    /// Load a USDZ and read its real-world bounding box (metres).
    /// Object Capture exports models at real-world scale, so the visual bounds
    /// directly give width (x), height (y) and depth (z).
    @MainActor
    static func boundingBox(of filename: String) async -> BoxDimensions? {
        let fileURL = url(for: filename)
        // The async Entity(contentsOf:) initializer is iOS 18+; fall back to the
        // synchronous loader on iOS 17.
        let loaded: Entity?
        if #available(iOS 18.0, *) {
            loaded = try? await Entity(contentsOf: fileURL)
        } else {
            loaded = try? Entity.load(contentsOf: fileURL)
        }
        guard let entity = loaded else { return nil }
        let bounds = entity.visualBounds(relativeTo: nil)
        let e = bounds.extents               // simd_float3 of full sizes
        guard e.x > 0, e.y > 0, e.z > 0 else { return nil }
        return BoxDimensions(width: Double(e.x), height: Double(e.y), depth: Double(e.z))
    }
}
