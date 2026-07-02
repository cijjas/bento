import SwiftUI

struct FitCheckView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let card: BentoCard

    @State private var selectedSpaceID: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if card.category.usesBoundingBox {
                    spaceCheck
                } else {
                    bodyCheck
                }
            }
            .navigationTitle("Does it fit?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Clothing vs body

    private var bodyCheck: some View {
        let report = FitEvaluator.evaluateClothing(card: card, body: store.body)
        return List {
            verdictHeader(report.overall)
            if report.lines.isEmpty {
                emptyAdvice("Add your body measurements in Profiles, and make sure the card has matching dimensions.")
            } else {
                Section("Comparison (vs your body)") {
                    ForEach(report.lines) { line in fitRow(line) }
                }
            }
        }
    }

    // MARK: Furniture vs space

    private var spaceCheck: some View {
        List {
            if store.spaces.isEmpty {
                emptyAdvice("Add a space (doorway, nook, shelf) in Profiles to compare against.")
            } else {
                Section("Choose a space") {
                    Picker("Space", selection: $selectedSpaceID) {
                        ForEach(store.spaces) { space in
                            Text(space.name).tag(Optional(space.id))
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if let space = store.spaces.first(where: { $0.id == selectedSpaceID }) {
                    let report = FitEvaluator.evaluateSpace(card: card, space: space)
                    verdictHeader(report.overall)
                    Section("Comparison (item vs space)") {
                        ForEach(report.lines) { line in fitRow(line) }
                    }
                }
            }
        }
        .onAppear {
            if selectedSpaceID == nil { selectedSpaceID = store.spaces.first?.id }
        }
    }

    // MARK: Pieces

    private func verdictHeader(_ verdict: FitVerdict) -> some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: verdict.systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(color(for: verdict))
                VStack(alignment: .leading) {
                    Text(verdict.rawValue).font(.title2.bold())
                    Text(advice(for: verdict)).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func fitRow(_ line: FitLine) -> some View {
        HStack {
            Image(systemName: line.verdict.systemImage)
                .foregroundStyle(color(for: line.verdict))
            VStack(alignment: .leading) {
                Text(line.label)
                Text("\(store.format(line.itemMeters)) vs \(store.format(line.constraintMeters))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(slackText(line.slackMeters))
                .font(.caption.monospacedDigit())
                .foregroundStyle(color(for: line.verdict))
        }
    }

    private func slackText(_ meters: Double) -> String {
        let cm = meters * 100
        let sign = cm >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", cm)) cm"
    }

    private func emptyAdvice(_ text: String) -> some View {
        Section {
            Label(text, systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func color(for verdict: FitVerdict) -> Color {
        switch verdict {
        case .fits: return .green
        case .tight: return .orange
        case .wontFit: return .red
        case .unknown: return .secondary
        }
    }

    private func advice(for verdict: FitVerdict) -> String {
        switch verdict {
        case .fits: return "Comfortable margin on every dimension."
        case .tight: return "It’ll go in, but with little room to spare."
        case .wontFit: return "At least one dimension is over the limit."
        case .unknown: return "Not enough overlapping measurements to decide."
        }
    }
}
