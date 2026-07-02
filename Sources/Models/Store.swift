import Foundation
import Combine

/// Single source of truth. Persists cards + profiles as JSON in the app's
/// Documents directory. No backend, no account — everything is local and the
/// only thing that travels is a `.bento` you explicitly share.
@MainActor
final class Store: ObservableObject {
    @Published var cards: [BentoCard] = []
    @Published var body: BodyProfile = .empty
    @Published var spaces: [SpaceProfile] = []
    @Published var displayUnit: DisplayUnit = .centimeters

    enum DisplayUnit: String, Codable, CaseIterable, Identifiable {
        case centimeters, inches
        var id: String { rawValue }
        var label: String { self == .centimeters ? "cm" : "in" }
    }

    private let cardsURL: URL
    private let profileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cardsURL = dir.appendingPathComponent("cards.json")
        profileURL = dir.appendingPathComponent("profile.json")

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    // MARK: Cards

    func add(_ card: BentoCard) {
        cards.insert(card, at: 0)
        saveCards()
    }

    func update(_ card: BentoCard) {
        if let i = cards.firstIndex(where: { $0.id == card.id }) {
            cards[i] = card
            saveCards()
        }
    }

    func delete(_ card: BentoCard) {
        ModelLibrary.delete(filename: card.modelFilename)
        cards.removeAll { $0.id == card.id }
        saveCards()
    }

    /// Import a received card; if id already exists, give it a fresh id so both
    /// the original and the received copy can coexist.
    @discardableResult
    func importCard(_ incoming: BentoCard) -> BentoCard {
        var card = incoming
        if cards.contains(where: { $0.id == card.id }) {
            card.id = UUID()
        }
        add(card)
        return card
    }

    // MARK: Profiles

    func saveProfile() { saveProfileFile() }

    func addSpace(_ space: SpaceProfile) {
        spaces.append(space)
        saveProfileFile()
    }

    func deleteSpace(_ space: SpaceProfile) {
        spaces.removeAll { $0.id == space.id }
        saveProfileFile()
    }

    // MARK: Persistence

    private struct ProfileFile: Codable {
        var body: BodyProfile
        var spaces: [SpaceProfile]
        var displayUnit: DisplayUnit
    }

    private func load() {
        if let data = try? Data(contentsOf: cardsURL),
           let decoded = try? decoder.decode([BentoCard].self, from: data) {
            cards = decoded
        }
        if let data = try? Data(contentsOf: profileURL),
           let decoded = try? decoder.decode(ProfileFile.self, from: data) {
            body = decoded.body
            spaces = decoded.spaces
            displayUnit = decoded.displayUnit
        }
    }

    private func saveCards() {
        if let data = try? encoder.encode(cards) {
            try? data.write(to: cardsURL, options: .atomic)
        }
    }

    private func saveProfileFile() {
        let file = ProfileFile(body: body, spaces: spaces, displayUnit: displayUnit)
        if let data = try? encoder.encode(file) {
            try? data.write(to: profileURL, options: .atomic)
        }
    }

    // MARK: Display formatting

    func format(_ meters: Double) -> String {
        switch displayUnit {
        case .centimeters:
            return String(format: "%.1f cm", meters * 100)
        case .inches:
            return String(format: "%.1f in", meters * 39.3700787)
        }
    }
}
