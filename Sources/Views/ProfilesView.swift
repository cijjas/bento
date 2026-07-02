import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var addingSpace = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("These are used to answer “will it fit me / my space?”. Enter values in \(store.displayUnit.label).")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("My body") {
                    bodyRow("Chest (circumference)", \.chest)
                    bodyRow("Waist", \.waist)
                    bodyRow("Hip", \.hip)
                    bodyRow("Shoulder width", \.shoulderWidth)
                    bodyRow("Arm length", \.armLength)
                    bodyRow("Inseam", \.inseam)
                    bodyRow("Height", \.height)
                }

                Section("My spaces") {
                    ForEach(store.spaces) { space in
                        VStack(alignment: .leading) {
                            Text(space.name).font(.headline)
                            Text("\(store.format(space.width)) × \(store.format(space.height)) × \(store.format(space.depth))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { idx in
                        idx.map { store.spaces[$0] }.forEach(store.deleteSpace)
                    }
                    Button {
                        addingSpace = true
                    } label: {
                        Label("Add a space", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Profiles")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.saveProfile(); dismiss() }
                }
            }
            .sheet(isPresented: $addingSpace) {
                AddSpaceView().environmentObject(store)
            }
        }
    }

    /// A row that edits a body metric, displayed in the user's chosen unit.
    private func bodyRow(_ label: String, _ keyPath: WritableKeyPath<BodyProfile, Double>) -> some View {
        UnitField(label: label,
                  meters: Binding(
                    get: { store.body[keyPath: keyPath] },
                    set: { store.body[keyPath: keyPath] = $0 }),
                  unit: store.displayUnit)
    }
}

private struct AddSpaceView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var width: Double = 0
    @State private var height: Double = 0
    @State private var depth: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. Living room nook)", text: $name)
                UnitField(label: "Width", meters: $width, unit: store.displayUnit)
                UnitField(label: "Height", meters: $height, unit: store.displayUnit)
                UnitField(label: "Depth", meters: $depth, unit: store.displayUnit)
            }
            .navigationTitle("New space")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addSpace(SpaceProfile(name: name.isEmpty ? "Space" : name,
                                                    width: width, height: height, depth: depth))
                        dismiss()
                    }
                    .disabled(width <= 0 && height <= 0 && depth <= 0)
                }
            }
        }
    }
}

/// Numeric field that stores metres but shows/edits in cm or inches.
private struct UnitField: View {
    let label: String
    @Binding var meters: Double
    let unit: Store.DisplayUnit
    @State private var text = ""

    private var factor: Double { unit == .centimeters ? 100 : 39.3700787 }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .onAppear { text = meters > 0 ? String(format: "%.1f", meters * factor) : "" }
                .onChange(of: text) { _, new in
                    if let v = Double(new.replacingOccurrences(of: ",", with: ".")) {
                        meters = v / factor
                    } else if new.isEmpty {
                        meters = 0
                    }
                }
            Text(unit.label).foregroundStyle(.secondary)
        }
    }
}
