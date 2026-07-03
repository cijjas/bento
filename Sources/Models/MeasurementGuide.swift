import Foundation

/// Plain-language "how do I take this measurement" help, keyed by the
/// dimension labels used in `ItemCategory.suggestedLabels`. Shown in the
/// capture form and inside the AR ruler so the user always knows what the
/// number should represent.
enum MeasurementGuide {

    struct Hint {
        /// SF Symbol that illustrates the measurement.
        let icon: String
        /// One-sentence instruction.
        let text: String
    }

    static func hint(for label: String) -> Hint? {
        switch normalize(label) {
        case "chest (flat)":
            return Hint(icon: "arrow.left.and.right",
                        text: "Lay the garment flat and measure straight across, armpit to armpit. We double it for you.")
        case "waist (flat)":
            return Hint(icon: "arrow.left.and.right",
                        text: "Garment flat and buttoned: measure straight across the waistband. We double it for you.")
        case "hip (flat)":
            return Hint(icon: "arrow.left.and.right",
                        text: "Garment flat: measure across the widest point below the waistband. We double it for you.")
        case "length":
            return Hint(icon: "arrow.up.and.down",
                        text: "From the highest point (shoulder or waistband) straight down to the bottom hem.")
        case "shoulder":
            return Hint(icon: "figure.arms.open",
                        text: "Across the back, from one shoulder seam to the other.")
        case "sleeve":
            return Hint(icon: "arrow.down.right",
                        text: "From the shoulder seam along the sleeve down to the cuff.")
        case "inseam":
            return Hint(icon: "arrow.up.and.down",
                        text: "Inside of the leg: from the crotch seam straight down to the ankle hem.")
        case "width":
            return Hint(icon: "arrow.left.and.right",
                        text: "The object's widest side, left edge to right edge.")
        case "height":
            return Hint(icon: "arrow.up.and.down",
                        text: "Floor to the object's highest point.")
        case "depth":
            return Hint(icon: "arrow.forward",
                        text: "Front edge to back edge.")
        default:
            return nil
        }
    }

    private static func normalize(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
