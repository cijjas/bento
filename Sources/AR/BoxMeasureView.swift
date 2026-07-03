import SwiftUI

/// SwiftUI bridge for the camera-only box tool.
struct BoxMeasureView: UIViewControllerRepresentable {
    @Binding var box: BoxDimensions?
    @Binding var step: BoxMeasureViewController.Step
    @Binding var status: String
    /// Height in metres, driven by the slider.
    var height: Double
    var resetToken: Int
    var undoToken: Int

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
        if context.coordinator.lastUndo != undoToken {
            context.coordinator.lastUndo = undoToken
            vc.undo()
        }
    }

    final class Coordinator {
        weak var controller: BoxMeasureViewController?
        var lastReset = 0
        var lastUndo = 0
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
    @State private var status = ""
    @State private var heightCM: Double = 50
    @State private var resetToken = 0
    @State private var undoToken = 0

    private var footprintDone: Bool {
        step == .adjustHeight || step == .done
    }

    var body: some View {
        ZStack(alignment: .top) {
            BoxMeasureView(box: $box,
                           step: $step,
                           status: $status,
                           height: heightCM / 100,
                           resetToken: resetToken,
                           undoToken: undoToken)
                .ignoresSafeArea()

            // Transient AR warnings only (tracking quality, missed raycasts).
            if !status.isEmpty {
                StatusBanner(text: status)
            }

            VStack(spacing: 10) {
                Spacer()
                stepCard
                if footprintDone { heightControl }
                if let box, footprintDone { readout(box) }
                controls
            }
            .padding()
        }
        .navigationTitle("Measure object")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Step coaching

    private struct StepInfo {
        let number: Int
        let title: String
        let detail: String
        let icon: String
    }

    private var stepInfo: StepInfo {
        switch step {
        case .cornerA:
            return StepInfo(number: 1,
                            title: "First floor corner",
                            detail: "Stand by the object. Point the ＋ at the floor exactly where one corner of the object meets the ground, then tap the screen.",
                            icon: "1.circle.fill")
        case .cornerB:
            return StepInfo(number: 2,
                            title: "Second corner — same side",
                            detail: "Follow one edge of the object. Aim the ＋ at the floor under the corner at the other end of that side, then tap.",
                            icon: "2.circle.fill")
        case .cornerC:
            return StepInfo(number: 3,
                            title: "Third corner — other side",
                            detail: "Now aim at a floor corner on the opposite side of the object (this gives its depth), then tap.",
                            icon: "3.circle.fill")
        case .adjustHeight, .done:
            return StepInfo(number: 4,
                            title: "Match the height",
                            detail: "Drag the slider until the glowing box's top lines up with the top of the object. Then tap “Use this size”.",
                            icon: "4.circle.fill")
        }
    }

    private var stepCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: stepInfo.icon)
                .font(.title)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(stepInfo.title).font(.headline)
                    Spacer()
                    Text("Step \(stepInfo.number) of 4")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(stepInfo.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .animation(.easeInOut(duration: 0.2), value: stepInfo.number)
    }

    private var heightControl: some View {
        VStack(spacing: 4) {
            Text("Height: \(store.format(heightCM / 100))")
                .font(.subheadline).foregroundStyle(.white)
            Slider(value: $heightCM, in: 1...300, step: 0.5)
                .tint(.yellow)
        }
        .padding(12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private func readout(_ box: BoxDimensions) -> some View {
        Text("\(store.format(box.width)) W · \(store.format(box.depth)) D · \(store.format(box.height)) H")
            .font(.headline.monospacedDigit())
            .foregroundStyle(.white)
            .padding(.vertical, 8).padding(.horizontal, 18)
            .background(.black.opacity(0.55), in: Capsule())
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                resetToken += 1
                box = nil
            } label: {
                Label("Restart", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered).tint(.white)

            Button {
                undoToken += 1
                if step != .done { box = nil }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered).tint(.white)
            .disabled(step == .cornerA)

            Button {
                if let box { onConfirm(box); dismiss() }
            } label: {
                Label("Use this size", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!footprintDone)
        }
        .padding(.top, 4)
    }
}
