import Foundation

/// Your own body measurements (metres), used to answer "will it fit me?".
struct BodyProfile: Codable, Equatable {
    var chest: Double = 0       // full circumference -> compared to flat*2
    var waist: Double = 0
    var hip: Double = 0
    var height: Double = 0
    var shoulderWidth: Double = 0
    var armLength: Double = 0
    var inseam: Double = 0

    static let empty = BodyProfile()
}

/// A space you want to fit furniture into (metres). e.g. a doorway, a nook.
struct SpaceProfile: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var width: Double
    var height: Double
    var depth: Double
}
