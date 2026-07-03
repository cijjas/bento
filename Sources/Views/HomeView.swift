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
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "shippingbox")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Check fit across any distance")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 18) {
                howItWorksRow(icon: "ruler",
                              title: "Measure",
                              text: "Capture a garment or object with the camera — or type the numbers in.")
                howItWorksRow(icon: "square.and.arrow.up",
                              title: "Share",
                              text: "Send the tiny .bento card to anyone, anywhere in the world.")
                howItWorksRow(icon: "checkmark.seal",
                              title: "Compare",
                              text: "They check it against their body, clothes or space — live, in AR.")
            }
            .padding(.horizontal, 32)

            VStack(spacing: 10) {
                Button {
                    showingCapture = true
                } label: {
                    Label("Measure something", systemImage: "plus")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showingProfiles = true
                } label: {
                    Text("Set up my body & spaces")
                        .frame(maxWidth: 240)
                }
                .buttonStyle(.bordered)
            }

            Text("Received a .bento file? Just open it — it imports here.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    private func howItWorksRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
