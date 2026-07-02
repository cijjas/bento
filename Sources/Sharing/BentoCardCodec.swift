import Foundation

/// Centralized JSON coding for `.bento` files so the share and import paths
/// always agree. (Import happens via onOpenURL in BentoApp; the .bento
/// extension/type is registered in Info.plist.)
enum BentoCardCodec {
    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func encode(_ card: BentoCard) throws -> Data { try encoder().encode(card) }
    static func decode(_ data: Data) throws -> BentoCard { try decoder().decode(BentoCard.self, from: data) }

    /// Write a card to a temp `.bento` file and return its URL (for sharing).
    static func tempFileURL(for card: BentoCard) throws -> URL {
        let safeName = card.name.isEmpty ? "BentoCard" :
            card.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeName)
            .appendingPathExtension("bento")
        try encode(card).write(to: url, options: .atomic)
        return url
    }
}
