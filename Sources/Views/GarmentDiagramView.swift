import SwiftUI
import UIKit

/// Size-chart style garment diagram: the silhouette with lettered measurement
/// lines (A, B, C…) that match the rows listed under it — the layout everyone
/// knows from online-shop size guides.
struct GarmentDiagram: View {
    let category: ItemCategory

    /// Letter assigned to a measurement label (A, B, C… in the category's
    /// suggested order). Shared with the rows so they always agree.
    static func letter(for label: String, in category: ItemCategory) -> String? {
        guard let i = category.suggestedLabels.firstIndex(where: {
            $0.caseInsensitiveCompare(label) == .orderedSame
        }) else { return nil }
        return String(UnicodeScalar(UInt8(65 + i)))   // 65 = "A"
    }

    var body: some View {
        if let blueprint = GarmentSilhouette.nominalBlueprint(for: category) {
            Canvas { context, size in
                draw(blueprint, in: context, size: size)
            }
            .frame(height: 230)
            .accessibilityLabel("Diagram showing where each measurement runs on the garment")
        }
    }

    private func draw(_ blueprint: GarmentSilhouette.Blueprint,
                      in context: GraphicsContext, size: CGSize) {
        // Combined bounds of the garment and its measurement lines (metres).
        var bounds = blueprint.path.bounds
        for line in blueprint.lines {
            bounds = bounds.union(CGRect(origin: line.from, size: .zero))
            bounds = bounds.union(CGRect(origin: line.to, size: .zero))
        }
        bounds = bounds.insetBy(dx: -0.06, dy: -0.06)   // margin for letters

        let scale = min(size.width / bounds.width, size.height / bounds.height)
        // Metres → view points, flipping y (path grows up, screen grows down).
        func pt(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (p.x - bounds.minX) * scale + (size.width - bounds.width * scale) / 2,
                    y: size.height - ((p.y - bounds.minY) * scale + (size.height - bounds.height * scale) / 2))
        }

        // Garment silhouette.
        var garment = Path(blueprint.path.cgPath)
        garment = garment.applying(
            CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY)
                .concatenating(CGAffineTransform(scaleX: scale, y: -scale))
                .concatenating(CGAffineTransform(translationX: (size.width - bounds.width * scale) / 2,
                                                 y: size.height - (size.height - bounds.height * scale) / 2)))
        context.fill(garment, with: .color(Color(.systemGray5)))
        context.stroke(garment, with: .color(Color(.systemGray2)), lineWidth: 1.5)

        // Measurement lines with end ticks + letter badges.
        for (i, line) in blueprint.lines.enumerated() {
            let a = pt(line.from), b = pt(line.to)
            var path = Path()
            path.move(to: a); path.addLine(to: b)

            // Small perpendicular ticks at both ends.
            let v = CGVector(dx: b.x - a.x, dy: b.y - a.y)
            let len = max(sqrt(v.dx * v.dx + v.dy * v.dy), 0.001)
            let n = CGVector(dx: -v.dy / len * 5, dy: v.dx / len * 5)
            for end in [a, b] {
                path.move(to: CGPoint(x: end.x - n.dx, y: end.y - n.dy))
                path.addLine(to: CGPoint(x: end.x + n.dx, y: end.y + n.dy))
            }
            context.stroke(path, with: .color(.accentColor), lineWidth: 1.5)

            // Letter badge just past the line's start.
            let letter = String(UnicodeScalar(UInt8(65 + i)))
            let badgeCenter = CGPoint(x: a.x - v.dx / len * 11, y: a.y - v.dy / len * 11)
            let badgeRect = CGRect(x: badgeCenter.x - 8, y: badgeCenter.y - 8, width: 16, height: 16)
            context.fill(Path(ellipseIn: badgeRect), with: .color(.accentColor))
            context.draw(Text(letter).font(.system(size: 10, weight: .bold)).foregroundColor(.white),
                         at: badgeCenter)
        }
    }
}

/// Circular letter badge used in the measurement rows to match the diagram.
struct MeasureLetterBadge: View {
    let letter: String
    var body: some View {
        Text(letter)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(Circle().fill(.tint))
    }
}
