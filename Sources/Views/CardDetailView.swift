import SwiftUI
import simd

struct CardDetailView: View {
    @EnvironmentObject var store: Store
    let card: BentoCard

    @State private var showingShare = false
    @State private var shareURL: URL?
    @State private var shareModel = false
    @State private var showingFitCheck = false
    @State private var showingPreview = false
    @State private var showingModel = false
    @State private var showingOverlay = false

    var body: some View {
        List {
            header

            Section("Dimensions") {
                ForEach(card.dimensions) { dim in
                    LabeledContent(dim.label) {
                        VStack(alignment: .trailing) {
                            Text(store.format(dim.meters))
                            if let note = dim.note {
                                Text(note).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let box = card.boundingBox {
                    LabeledContent("Width", value: store.format(box.width))
                    LabeledContent("Height", value: store.format(box.height))
                    LabeledContent("Depth", value: store.format(box.depth))
                }
            }

            if !card.notes.isEmpty {
                Section("Notes") { Text(card.notes) }
            }

            Section("Check fit") {
                Button {
                    showingFitCheck = true
                } label: {
                    Label(card.category.usesBoundingBox ? "Compare to a space" : "Compare to my body",
                          systemImage: "checklist")
                }
                if !card.category.usesBoundingBox {
                    Button {
                        showingOverlay = true
                    } label: {
                        Label("Overlay on my clothes (AR)", systemImage: "camera.viewfinder")
                    }
                }
                if card.hasModel {
                    Button {
                        showingModel = true
                    } label: {
                        Label("Project the real object (AR)", systemImage: "arkit")
                    }
                }
                if card.category.usesBoundingBox, card.boundingBox != nil {
                    Button {
                        showingPreview = true
                    } label: {
                        Label(card.hasModel ? "See its box in my room (AR)"
                                            : "See it in my room (AR)",
                              systemImage: "cube.transparent")
                    }
                }
            }

            Section {
                Button {
                    shareModel = false
                    prepareShare()
                } label: {
                    Label("Share card (dimensions)", systemImage: "square.and.arrow.up")
                }
                if card.hasModel {
                    Button {
                        shareModel = true
                        showingShare = true
                    } label: {
                        Label("Send 3D model (USDZ)", systemImage: "cube.box")
                    }
                }
            } footer: {
                Text(card.hasModel
                     ? "The card holds the measurements. Send the USDZ separately to share the full 3D object for AR projection."
                     : "Sends a .bento file. The other person opens it to import the exact measurements.")
            }
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShare) {
            if shareModel, let filename = card.modelFilename {
                ShareSheet(items: [ModelLibrary.url(for: filename)])
            } else if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .sheet(isPresented: $showingFitCheck) {
            FitCheckView(card: card).environmentObject(store)
        }
        .fullScreenCover(isPresented: $showingPreview) {
            FitPreviewScreen(card: card)
        }
        .fullScreenCover(isPresented: $showingOverlay) {
            GarmentOverlayScreen(card: card).environmentObject(store)
        }
        .fullScreenCover(isPresented: $showingModel) {
            if let filename = card.modelFilename {
                ModelProjectionScreen(modelURL: ModelLibrary.url(for: filename))
            }
        }
    }

    private var header: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: card.category.systemImage)
                    .font(.system(size: 34))
                    .foregroundStyle(.tint)
                    .frame(width: 52, height: 52)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.category.title)
                        .font(.subheadline.weight(.medium))
                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var headerSubtitle: String {
        var parts: [String] = []
        if !card.capturedBy.isEmpty { parts.append("Measured by \(card.capturedBy)") }
        parts.append(card.createdAt.formatted(date: .abbreviated, time: .omitted))
        return parts.joined(separator: " · ")
    }

    private func prepareShare() {
        if let url = try? BentoCardCodec.tempFileURL(for: card) {
            shareURL = url
            showingShare = true
        }
    }
}

/// AR ghost-box preview wrapped with a status banner + close button.
private struct FitPreviewScreen: View {
    @Environment(\.dismiss) private var dismiss
    let card: BentoCard
    @State private var status = "Initializing AR…"
    @State private var rotateToken = 0

    private var boxSize: simd_float3 {
        if let b = card.boundingBox {
            return simd_float3(Float(b.width), Float(b.height), Float(b.depth))
        }
        // Fall back to first three dimensions if no explicit box.
        let dims = card.dimensions.map { Float($0.meters) }
        return simd_float3(dims.count > 0 ? dims[0] : 0.3,
                           dims.count > 1 ? dims[1] : 0.3,
                           dims.count > 2 ? dims[2] : 0.3)
    }

    var body: some View {
        ZStack(alignment: .top) {
            FitPreviewView(boxSize: boxSize, status: $status, rotateToken: rotateToken)
                .ignoresSafeArea()
            StatusBanner(text: status)
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button {
                        rotateToken += 1
                    } label: {
                        Label("Rotate", systemImage: "rotate.right")
                    }
                    .buttonStyle(.bordered).tint(.white)

                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 30)
            }
        }
    }
}

/// Projects the captured real-scale USDZ into the user's room.
private struct ModelProjectionScreen: View {
    @Environment(\.dismiss) private var dismiss
    let modelURL: URL
    @State private var status = "Loading model…"

    var body: some View {
        ZStack(alignment: .top) {
            ModelPlacementView(modelURL: modelURL, status: $status)
                .ignoresSafeArea()
            StatusBanner(text: status)
            VStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 30)
            }
        }
    }
}
