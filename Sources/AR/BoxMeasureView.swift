import SwiftUI

/// SwiftUI bridge for the camera-only box tool.
struct BoxMeasureView: UIViewControllerRepresentable {
    @Binding var box: BoxDimensions?
    @Binding var step: BoxMeasureViewController.Step
    @Binding var status: String
    /// Height in metres, driven by the slider.
    var height: Double
    var resetToken: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> BoxMeasureViewController {
        let vc = BoxMeasureViewController()
        vc.onBoxChanged = { b in DispatchQueue.main.async { box = b } }
        vc.onStep = { s in DispatchQueue.main.async { step = s } }
        vc.onStatus = { t in DispatchQueue.main.async { status = t } }
        context.coordinator.controller = vc
        return vc
    }

    func updateUIViewController(_ vc: BoxMeasureViewController, context: Context) {
        vc.setHeight(Float(height))
        if context.coordinator.lastReset != resetToken {
            context.coordinator.lastReset = resetToken
            vc.reset()
        }
    }

    final class Coordinator {
        weak var controller: BoxMeasureViewController?
        var lastReset = 0
    }
}

/// Full-screen camera-only object measurement: tap 3 footprint corners, then
/// drag the height slider until the live AR box matches the object.
struct BoxMeasureScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (BoxDimensions) -> Void

    @State private var box: BoxDimensions?
    @State private var step: BoxMeasureViewController.Step = .cornerA
    @State private var status = "Initializing AR…"
    @State private var heightCM: Double = 50
    @State private var resetToken = 0

    private var footprintDone: Bool {
        step == .adjustHeight || step == .done
    }

    var body: some View {
        ZStack(alignment: .top) {
            BoxMeasureView(box: $box,
                           step: $step,
                           status: $status,
                           height: heightCM / 100,
                           resetToken: resetToken)
                .ignoresSafeArea()

            StatusBanner(text: status)

            VStack {
                Spacer()
                if footprintDone { heightControl }
                readout
                controls
            }
            .padding()
        }
        .navigationTitle("Measure object")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heightControl: some View {
        VStack(spacing: 4) {
            Text("Height: \(store.format(heightCM / 100))")
                .font(.subheadline).foregroundStyle(.white)
            Slider(value: $heightCM, in: 1...300, step: 0.5)
                .tint(.yellow)
        }
        .padding(12)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var readout: some View {
        Group {
            if let box {
                Text("\(store.format(box.width)) W · \(store.format(box.depth)) D · \(store.format(box.height)) H")
            } else {
                Text("Tap the corners on the floor")
            }
        }
        .font(.headline.monospacedDigit())
        .foregroundStyle(.white)
        .padding(.vertical, 8).padding(.horizontal, 18)
        .background(.black.opacity(0.45), in: Capsule())
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                resetToken += 1
                box = nil
            } label: {
                Label("Restart", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).tint(.white)

            Button {
                if let box { onConfirm(box); dismiss() }
            } label: {
                Label("Use this size", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!footprintDone)
        }
        .padding(.top, 8)
    }
}
