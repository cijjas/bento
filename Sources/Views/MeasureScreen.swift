import SwiftUI

/// Full-screen AR ruler for capturing one labelled measurement.
/// Shows a live distance, lets the user confirm or re-measure, and supports
/// manual override (typed value) for cases where AR is awkward.
struct MeasureScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let label: String
    let current: Double
    let onConfirm: (Double) -> Void

    @State private var lastMeasurement: Double?
    @State private var livePreview: Double?
    @State private var status = "Initializing AR…"
    @State private var resetToken = 0
    @State private var showingManual = false
    @State private var manualText = ""

    var body: some View {
        ZStack(alignment: .top) {
            ARMeasureView(lastMeasurement: $lastMeasurement,
                          livePreview: $livePreview,
                          status: $status,
                          resetToken: resetToken)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                StatusBanner(text: status)
                if let hint = MeasurementGuide.hint(for: label) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: hint.icon)
                            .font(.title3)
                            .foregroundStyle(.yellow)
                        Text(hint.text)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.95))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }

            VStack {
                Spacer()
                readout
                controls
            }
            .padding()
        }
        .navigationTitle("Measure \(label)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Type") {
                    manualText = current > 0 ? String(format: "%.1f", current * 100) : ""
                    showingManual = true
                }
            }
        }
        .alert("Enter value in cm", isPresented: $showingManual) {
            TextField("cm", text: $manualText)
                .keyboardType(.decimalPad)
            Button("Use") {
                if let cm = Double(manualText.replacingOccurrences(of: ",", with: ".")), cm > 0 {
                    onConfirm(cm / 100)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var readout: some View {
        let display = lastMeasurement ?? livePreview
        return VStack(spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.8))
            Text(display.map { store.displayUnit == .centimeters
                    ? String(format: "%.1f cm", $0 * 100)
                    : String(format: "%.1f in", $0 * 39.3700787) } ?? "—")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            if lastMeasurement == nil && livePreview != nil {
                Text("live").font(.caption2).foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 24)
        .background(.black.opacity(0.45), in: Capsule())
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                resetToken += 1
                lastMeasurement = nil
                livePreview = nil
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Button {
                if let value = lastMeasurement {
                    onConfirm(value)
                    dismiss()
                }
            } label: {
                Label("Use this", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(lastMeasurement == nil)
        }
        .padding(.top, 8)
    }
}

/// Small translucent banner used by all AR screens for coaching text.
struct StatusBanner: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.black.opacity(0.5), in: Capsule())
            .padding(.top, 12)
            .multilineTextAlignment(.center)
    }
}
