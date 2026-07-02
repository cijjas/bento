import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var showingCapture = false
    @State private var showingProfiles = false

    var body: some View {
        NavigationStack {
            Group {
                if store.cards.isEmpty {
                    emptyState
                } else {
                    cardList
                }
            }
            .navigationTitle("Bento")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingProfiles = true
                    } label: { Image(systemName: "person.crop.square") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Units", selection: $store.displayUnit) {
                            ForEach(Store.DisplayUnit.allCases) { u in
                                Text(u.label).tag(u)
                            }
                        }
                        .onChange(of: store.displayUnit) { _, _ in store.saveProfile() }
                    } label: { Image(systemName: "ruler") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCapture = true
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingCapture) {
                CaptureFlowView().environmentObject(store)
            }
            .sheet(isPresented: $showingProfiles) {
                ProfilesView().environmentObject(store)
            }
        }
    }

    private var cardList: some View {
        List {
            ForEach(store.cards) { card in
                NavigationLink {
                    CardDetailView(card: card).environmentObject(store)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: card.category.systemImage)
                            .font(.title2)
                            .frame(width: 34)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(card.name).font(.headline)
                            Text(summary(card))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { idx in
                idx.map { store.cards[$0] }.forEach(store.delete)
            }
        }
    }

    private func summary(_ card: BentoCard) -> String {
        if let box = card.boundingBox {
            return "\(store.format(box.width)) × \(store.format(box.height)) × \(store.format(box.depth))"
        }
        return card.dimensions
            .prefix(3)
            .map { "\($0.label) \(store.format($0.meters))" }
            .joined(separator: " · ")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No cards yet", systemImage: "ruler")
        } description: {
            Text("Measure an item, or open a .bento someone sent you.")
        } actions: {
            Button("Measure something") { showingCapture = true }
                .buttonStyle(.borderedProminent)
        }
    }
}
