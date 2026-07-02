import Foundation

enum FitVerdict: String {
    case fits = "Fits"
    case tight = "Tight"
    case wontFit = "Won't fit"
    case unknown = "Not enough data"

    var systemImage: String {
        switch self {
        case .fits: return "checkmark.circle.fill"
        case .tight: return "exclamationmark.triangle.fill"
        case .wontFit: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// One line in a fit report comparing a target value to a constraint.
struct FitLine: Identifiable {
    let id = UUID()
    let label: String
    /// Metres. The item's measurement.
    let itemMeters: Double
    /// Metres. Your body/space measurement it is compared against.
    let constraintMeters: Double
    let verdict: FitVerdict
    /// Signed slack in metres: positive = room to spare, negative = over.
    let slackMeters: Double
}

struct FitReport {
    let overall: FitVerdict
    let lines: [FitLine]
}

/// Pure logic. Tolerance is the fraction of "tight" allowance (e.g. 0.03 = 3%).
enum FitEvaluator {

    /// Clothing: compare the card to a body profile.
    /// Flat garment widths are doubled to approximate circumference.
    static func evaluateClothing(card: BentoCard,
                                 body: BodyProfile,
                                 tolerance: Double = 0.04) -> FitReport {
        var lines: [FitLine] = []

        func add(_ label: String, item: Double?, constraint: Double, doubled: Bool = false) {
            guard let raw = item, raw > 0, constraint > 0 else { return }
            let item = doubled ? raw * 2 : raw
            lines.append(makeLine(label: label,
                                  item: item,
                                  constraint: constraint,
                                  tolerance: tolerance,
                                  biggerIsLooser: true))
        }

        // Flat chest/waist/hip are half-circumference; double them.
        add("Chest", item: card.dimension(labeled: "Chest (flat)")?.meters, constraint: body.chest, doubled: true)
        add("Waist", item: card.dimension(labeled: "Waist (flat)")?.meters, constraint: body.waist, doubled: true)
        add("Hip", item: card.dimension(labeled: "Hip (flat)")?.meters, constraint: body.hip, doubled: true)
        add("Shoulder", item: card.dimension(labeled: "Shoulder")?.meters, constraint: body.shoulderWidth)
        add("Sleeve", item: card.dimension(labeled: "Sleeve")?.meters, constraint: body.armLength)
        add("Inseam", item: card.dimension(labeled: "Inseam")?.meters, constraint: body.inseam)

        return FitReport(overall: combine(lines.map(\.verdict)), lines: lines)
    }

    /// Furniture/object: every box axis must be <= the space (in any orientation).
    /// We do a simple axis-sorted comparison (largest-to-largest).
    static func evaluateSpace(card: BentoCard,
                              space: SpaceProfile,
                              tolerance: Double = 0.02) -> FitReport {
        let itemAxes: [Double]
        if let box = card.boundingBox {
            itemAxes = [box.width, box.height, box.depth]
        } else {
            itemAxes = card.dimensions.map(\.meters)
        }
        let spaceAxes = [space.width, space.height, space.depth]

        // Sort both descending and compare like-for-like: this checks whether
        // the object can be slotted in some orientation.
        let item = itemAxes.sorted(by: >)
        let slot = spaceAxes.sorted(by: >)
        let labels = ["Largest side", "Middle side", "Smallest side"]

        var lines: [FitLine] = []
        for i in 0..<min(item.count, slot.count) {
            guard item[i] > 0, slot[i] > 0 else { continue }
            lines.append(makeLine(label: labels[i],
                                  item: item[i],
                                  constraint: slot[i],
                                  tolerance: tolerance,
                                  biggerIsLooser: false))
        }
        return FitReport(overall: combine(lines.map(\.verdict)), lines: lines)
    }

    // MARK: - Helpers

    /// `biggerIsLooser`: for clothing a bigger body needs a bigger garment, so the
    /// constraint is the body and the item must be >= body. For space the item
    /// must be <= space. We normalize both into "slack = headroom".
    private static func makeLine(label: String,
                                 item: Double,
                                 constraint: Double,
                                 tolerance: Double,
                                 biggerIsLooser: Bool) -> FitLine {
        // slack > 0 means comfortable.
        let slack = biggerIsLooser ? (item - constraint) : (constraint - item)
        let tol = constraint * tolerance
        let verdict: FitVerdict
        if slack >= tol {
            verdict = .fits
        } else if slack >= -tol {
            verdict = .tight
        } else {
            verdict = .wontFit
        }
        return FitLine(label: label,
                       itemMeters: item,
                       constraintMeters: constraint,
                       verdict: verdict,
                       slackMeters: slack)
    }

    private static func combine(_ verdicts: [FitVerdict]) -> FitVerdict {
        guard !verdicts.isEmpty else { return .unknown }
        if verdicts.contains(.wontFit) { return .wontFit }
        if verdicts.contains(.tight) { return .tight }
        return .fits
    }
}
