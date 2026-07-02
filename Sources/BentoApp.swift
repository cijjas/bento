import SwiftUI

@main
struct BentoApp: App {
    @StateObject private var store = Store()
    /// A card that arrived via an opened `.bento` file, awaiting import review.
    @State private var incomingCard: BentoCard?

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                // Handle opening a shared .bento from Files / Messages / AirDrop.
                .onOpenURL { url in
                    handleIncoming(url)
                }
                .sheet(item: $incomingCard) { card in
                    ImportReviewView(card: card) { decision in
                        if decision { store.importCard(card) }
                        incomingCard = nil
                    }
                    .environmentObject(store)
                }
        }
    }

    private func handleIncoming(_ url: URL) {
        let needsRelease = url.startAccessingSecurityScopedResource()
        defer { if needsRelease { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let card = try? BentoCardCodec.decode(data) else { return }
        incomingCard = card
    }
}

/// Confirmation shown when a card is received from someone else.
struct ImportReviewView: View {
    let card: BentoCard
    let onDecision: (Bool) -> Void
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationStack {
            List {
                Section("Received card") {
                    LabeledContent("Name", value: card.name)
                    LabeledContent("Type", value: card.category.title)
                    if !card.capturedBy.isEmpty {
                        LabeledContent("From", value: card.capturedBy)
                    }
                }
                Section("Dimensions") {
                    ForEach(card.dimensions) { dim in
                        LabeledContent(dim.label, value: store.format(dim.meters))
                    }
                    if let box = card.boundingBox {
                        LabeledContent("Bounding box",
                                       value: "\(store.format(box.width)) × \(store.format(box.height)) × \(store.format(box.depth))")
                    }
                }
                if !card.notes.isEmpty {
                    Section("Notes") { Text(card.notes) }
                }
            }
            .navigationTitle("Import card?")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) { onDecision(false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to library") { onDecision(true) }
                }
            }
        }
    }
}
