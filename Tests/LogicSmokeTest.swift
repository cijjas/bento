import Foundation

// Standalone smoke test for Bento's pure logic (no iOS SDK required).
// Compile with the three model files; see scripts/test-logic.sh.

@main
enum LogicSmokeTest {
static func main() {

var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if cond { print("  ✅ \(msg)") }
    else { print("  ❌ \(msg)"); failures += 1 }
}
func cm(_ v: Double) -> Double { v / 100 }

print("Bento logic smoke test\n")

// 1. Clothing fit ----------------------------------------------------------
print("Clothing vs body:")
let jacket = BentoCard(name: "Jacket", category: .clothingTop, dimensions: [
    Dimension(label: "Chest (flat)", meters: cm(55)),   // -> 110 circumference
    Dimension(label: "Shoulder", meters: cm(46)),
    Dimension(label: "Sleeve", meters: cm(64)),
])
let body = BodyProfile(chest: cm(104), shoulderWidth: cm(45), armLength: cm(63))
let cr = FitEvaluator.evaluateClothing(card: jacket, body: body)
check(cr.lines.contains { $0.label == "Chest" && $0.verdict == .fits }, "chest fits (110 vs 104)")
check(cr.overall == .tight, "overall is Tight (shoulder/sleeve only +1cm)")

// 2. Furniture fits in a doorway ------------------------------------------
print("Furniture vs space:")
let sofa = BentoCard(name: "Sofa", category: .furniture, dimensions: [],
                   boundingBox: BoxDimensions(width: cm(200), height: cm(90), depth: cm(95)))
let door = SpaceProfile(name: "Door", width: cm(210), height: cm(205), depth: cm(100))
check(FitEvaluator.evaluateSpace(card: sofa, space: door).overall == .fits, "sofa fits the doorway")

// 3. Furniture too deep ----------------------------------------------------
let narrow = SpaceProfile(name: "Narrow", width: cm(210), height: cm(205), depth: cm(80))
check(FitEvaluator.evaluateSpace(card: sofa, space: narrow).overall == .wontFit, "sofa won't fit a too-shallow space")

// 4. JSON round-trip (what travels between phones) -------------------------
print("Sharing round-trip:")
do {
    let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
    let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
    let data = try enc.encode(sofa)
    let back = try dec.decode(BentoCard.self, from: data)
    check(back.name == sofa.name && back.boundingBox == sofa.boundingBox, "card survives encode→decode")
} catch {
    check(false, "round-trip threw: \(error)")
}

print("")
if failures == 0 { print("ALL PASSED ✅") }
else { print("\(failures) FAILED ❌"); exit(1) }

}
}
