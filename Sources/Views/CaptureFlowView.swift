import SwiftUI
import simd

struct CaptureFlowView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var category: ItemCategory?
    @State private var name = ""
    @State private var capturedBy = ""
    @State private var notes = ""
    @State private var dimensions: [Dimension] = []
    @State private var boundingBox: BoxDimensions?
    @State private var showing3DCapture = false

    var body: some View {
        NavigationStack {
            if let category {
                detailsForm(category: category)
            } else {
                categoryPicker
            }
        }
    }

    // MARK: Step 1 — category

    private var categoryPicker: some View {
        List {
            Section("What are you measuring?") {
                ForEach(ItemCategory.allCases) { cat in
                    Button {
                        category = cat
                        prefill(for: cat)
                    } label: {
                        Label(cat.title, systemImage: cat.systemImage)
                    }
                }
            }
        }
        .navigationTitle("New card")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func prefill(for cat: ItemCategory) {
        dimensions = cat.suggestedLabels.map { Dimension(label: $0, meters: 0) }
        boundingBox = cat.usesBoundingBox ? BoxDimensions(width: 0, height: 0, depth: 0) : nil
    }

    // MARK: Step 2 — capture + edit

    @ViewBuilder
    private func detailsForm(category: ItemCategory) -> some View {
        Form {
            Section("Details") {
                TextField("Name (e.g. Vintage denim jacket)", text: $name)
                TextField("Measured by (your name)", text: $capturedBy)
            }

            if category.usesBoundingBox {
                furnitureSection(category: category)
            } else {
                clothingSection
            }

            Section("Notes") {
                TextField("Material, condition, country…", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .navigationTitle(category.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save(category: category) }
                    .disabled(!canSave)
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (boundingBox.map { $0.width > 0 || $0.height > 0 || $0.depth > 0 } ??
         dimensions.contains { $0.meters > 0 })
    }

    // MARK: Furniture (RoomPlan + manual box)

    @ViewBuilder
    private func furnitureSection(category: ItemCategory) -> some View {
        // Primary path — works on EVERY iPhone, camera only.
        Section {
            NavigationLink {
                BoxMeasureScreen { box in boundingBox = box }
                    .environmentObject(store)
            } label: {
                Label("Measure object box (camera)", systemImage: "cube")
            }
        } header: {
            Text("Measure (any iPhone)")
        } footer: {
            Text("Tap the object’s corners on the floor, then drag the height slider until the box matches. Uses only the camera — no LiDAR needed.")
        }

        // Optional Pro extras — only shown when the device has LiDAR.
        if GuidedCaptureModel.isDeviceSupported || RoomScanView.isSupported {
            Section {
                if GuidedCaptureModel.isDeviceSupported {
                    Button {
                        showing3DCapture = true
                    } label: {
                        Label("Capture full 3D model (walk around)", systemImage: "rotate.3d")
                    }
                    .fullScreenCover(isPresented: $showing3DCapture) {
                        ObjectCaptureFlowView(name: name,
                                              category: category,
                                              capturedBy: capturedBy,
                                              notes: notes,
                                              onFinish: { dismiss() })
                            .environmentObject(store)
                    }
                }
                if RoomScanView.isSupported {
                    NavigationLink {
                        RoomScanCaptureScreen { box in
                            if let box { boundingBox = box }
                        }
                    } label: {
                        Label("Auto-scan with RoomPlan", systemImage: "viewfinder")
                    }
                }
            } header: {
                Text("Automatic (Pro / LiDAR)")
            } footer: {
                Text("This iPhone has LiDAR, so it can capture the object automatically — and the full 3D model lets the receiver project the actual object into their space.")
            }
        }

        // Manual fine-tuning / fallback.
        Section("Adjust sides") {
            boxRow("Width",  keyPath: \.width)
            boxRow("Height", keyPath: \.height)
            boxRow("Depth",  keyPath: \.depth)
        }
    }

    @ViewBuilder
    private func boxRow(_ label: String, keyPath: WritableKeyPath<BoxDimensions, Double>) -> some View {
        let value = boundingBox?[keyPath: keyPath] ?? 0
        NavigationLink {
            MeasureScreen(label: label, current: value) { meters in
                if boundingBox == nil { boundingBox = BoxDimensions(width: 0, height: 0, depth: 0) }
                boundingBox?[keyPath: keyPath] = meters
            }
        } label: {
            HStack {
                Text(label)
                Spacer()
                Text(value > 0 ? store.format(value) : "Measure")
                    .foregroundStyle(value > 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
            }
        }
    }

    // MARK: Clothing (per-label AR ruler)

    private var clothingSection: some View {
        Section {
            if let category {
                GarmentDiagram(category: category)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .listRowBackground(Color(.systemBackground))
            }

            NavigationLink {
                PhotoMeasureScreen(category: category ?? .clothingTop) { measured in
                    for (label, meters) in measured {
                        if let i = dimensions.firstIndex(where: {
                            $0.label.caseInsensitiveCompare(label) == .orderedSame
                        }) {
                            dimensions[i].meters = meters
                        } else {
                            dimensions.append(Dimension(label: label, meters: meters))
                        }
                    }
                }
                .environmentObject(store)
            } label: {
                Label("Measure from a photo (all at once)", systemImage: "camera.viewfinder")
                    .foregroundStyle(.tint)
            }

            ForEach($dimensions) { $dim in
                NavigationLink {
                    MeasureScreen(label: dim.label, current: dim.meters) { meters in
                        dim.meters = meters
                    }
                } label: {
                    HStack(spacing: 10) {
                        if let category,
                           let letter = GarmentDiagram.letter(for: dim.label, in: category) {
                            MeasureLetterBadge(letter: letter)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dim.label)
                            if let hint = MeasurementGuide.hint(for: dim.label) {
                                Text(hint.text)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(dim.meters > 0 ? store.format(dim.meters) : "Measure")
                            .foregroundStyle(dim.meters > 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
                    }
                }
            }
        } header: {
            Text("Measurements")
        } footer: {
            Text("Lay the garment flat and smooth. Measure edge-to-edge; the fit check doubles flat chest/waist/hip automatically.")
        }
    }

    // MARK: Save

    private func save(category: ItemCategory) {
        let cleanDims = dimensions.filter { $0.meters > 0 }
        let card = BentoCard(name: name.trimmingCharacters(in: .whitespaces),
                           category: category,
                           dimensions: cleanDims,
                           notes: notes,
                           boundingBox: boundingBox.flatMap { $0.width > 0 || $0.height > 0 || $0.depth > 0 ? $0 : nil },
                           capturedBy: capturedBy)
        store.add(card)
        dismiss()
    }
}

/// Wraps RoomScanView with status + auto-dismiss when a box is captured.
private struct RoomScanCaptureScreen: View {
    @Environment(\.dismiss) private var dismiss
    var onResult: (BoxDimensions?) -> Void
    @State private var status = "Initializing…"

    var body: some View {
        ZStack(alignment: .top) {
            RoomScanView(onFinish: { box in
                onResult(box)
                dismiss()
            }, onStatus: { status = $0 })
            .ignoresSafeArea()

            StatusBanner(text: status)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
