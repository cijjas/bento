import Foundation

/// A single labelled measurement, always stored in metres internally.
struct Dimension: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// Human label, e.g. "Chest (flat)", "Length", "Width", "Height", "Depth".
    var label: String
    /// Value in METRES. All math is metric; display converts as needed.
    var meters: Double
    /// Optional note, e.g. "pit-to-pit, doubled".
    var note: String?

    var centimeters: Double { meters * 100 }
    var inches: Double { meters * 39.3700787 }
}

/// What kind of thing we measured. Drives capture method and fit logic.
enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case clothingTop      // shirt, jacket
    case clothingBottom   // trousers, skirt
    case furniture        // anything with a bounding box
    case generic          // any object, measured freehand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clothingTop: return "Top / Jacket"
        case .clothingBottom: return "Trousers / Skirt"
        case .furniture: return "Furniture"
        case .generic: return "Other object"
        }
    }

    var systemImage: String {
        switch self {
        case .clothingTop: return "tshirt"
        case .clothingBottom: return "figure.walk"
        case .furniture: return "sofa"
        case .generic: return "cube"
        }
    }

    /// Suggested labels the sender should capture for this category.
    var suggestedLabels: [String] {
        switch self {
        case .clothingTop:
            return ["Chest (flat)", "Length", "Shoulder", "Sleeve"]
        case .clothingBottom:
            return ["Waist (flat)", "Hip (flat)", "Inseam", "Length"]
        case .furniture, .generic:
            return ["Width", "Height", "Depth"]
        }
    }

    var usesBoundingBox: Bool { self == .furniture || self == .generic }
}

/// The shareable record. This is exactly what gets serialized to a `.bento`.
struct BentoCard: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var schemaVersion: Int = 1
    var name: String
    var category: ItemCategory
    var dimensions: [Dimension]
    var createdAt: Date = Date()
    /// Free text the sender adds (material, condition, country, etc.).
    var notes: String = ""
    /// Optional captured bounding box (furniture): width/height/depth in metres.
    var boundingBox: BoxDimensions?
    /// Who measured it, for context across countries.
    var capturedBy: String = ""
    /// Filename (within the app's Models directory) of a captured USDZ model,
    /// produced by Object Capture. nil if this card is measurements-only.
    /// Note: the model file itself is large and is NOT embedded in the shared
    /// `.bento`; sharing sends dimensions + box. Use "Send model" to share
    /// the USDZ separately when you want the full 3D object.
    var modelFilename: String?

    var hasModel: Bool { modelFilename != nil }

    func dimension(labeled label: String) -> Dimension? {
        dimensions.first { $0.label.caseInsensitiveCompare(label) == .orderedSame }
    }
}

/// Oriented bounding box dimensions in metres (object-local axes).
/// Named `BoxDimensions` (not `BoundingBox`) to avoid clashing with
/// RealityKit's own `BoundingBox` type in files that import RealityKit.
struct BoxDimensions: Codable, Hashable {
    var width: Double
    var height: Double
    var depth: Double
}
