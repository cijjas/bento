import SwiftUI
import RealityKit

/// Full "point → walk around → reconstruct" experience. On success it saves a
/// BentoCard whose `modelFilename` points at the real-scale USDZ and whose
/// boundingBox is read from that model.
struct ObjectCaptureFlowView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    /// Pre-filled from the capture flow so the saved card keeps its context.
    let name: String
    let category: ItemCategory
    let capturedBy: String
    let notes: String
    /// Called after the card is saved, so the presenting form can also close.
    var onFinish: () -> Void = {}

    @StateObject private var model = GuidedCaptureModel()

    var body: some View {
        ZStack {
            content
        }
        .onAppear { model.start() }
        .onDisappear { model.cancel() }
        .interactiveDismissDisabled(isBusy)
    }

    private var isBusy: Bool {
        switch model.phase {
        case .reconstructing, .finishing: return true
        default: return false
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .failed(let message):
            failure(message)

        case .reconstructing(let progress):
            reconstructing(progress)

        case .done(let filename, let box):
            // Auto-save once and leave.
            Color.clear.onAppear { saveAndFinish(filename: filename, box: box) }

        default:
            captureUI
        }
    }

    // MARK: - Live capture

    @ViewBuilder
    private var captureUI: some View {
        if let session = model.session {
            ZStack(alignment: .bottom) {
                ObjectCaptureView(session: session)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    StatusBanner(text: coachingText)
                    primaryControls(session: session)
                }
                .padding(.bottom, 28)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    model.cancel(); dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white, .black.opacity(0.4))
                }
                .padding()
            }
        } else {
            ProgressView("Starting camera…")
        }
    }

    @ViewBuilder
    private func primaryControls(session: ObjectCaptureSession) -> some View {
        switch model.phase {
        case .ready:
            Button("Place box on object") { model.detectObject() }
                .buttonStyle(.borderedProminent).controlSize(.large)

        case .detecting:
            Button("Start capture") { model.beginCapture() }
                .buttonStyle(.borderedProminent).controlSize(.large)

        case .capturing:
            HStack(spacing: 12) {
                Text("\(model.shotsTaken) shots")
                    .font(.subheadline).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.black.opacity(0.4), in: Capsule())
                if model.passComplete {
                    Button("Another pass") { model.startAnotherPass() }
                        .buttonStyle(.bordered).tint(.white)
                }
                Button("Finish") { model.finishCapture() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.passComplete)
            }

        default:
            EmptyView()
        }
    }

    private var coachingText: String {
        switch model.phase {
        case .preparing: return "Move the phone slowly to map the area."
        case .ready: return "Frame the object, then place the box around it."
        case .detecting: return "Adjust the box so it wraps the whole object."
        case .capturing:
            return model.passComplete
                ? "Pass complete. Add another pass from a new height, or finish."
                : "Walk slowly all the way around the object."
        case .finishing: return "Finishing capture…"
        default: return ""
        }
    }

    // MARK: - Reconstruction / result

    private func reconstructing(_ progress: Double) -> some View {
        VStack(spacing: 20) {
            ProgressView(value: progress) {
                Text("Building 3D model")
            } currentValueLabel: {
                Text("\(Int(progress * 100))%")
            }
            .progressViewStyle(.linear)
            .padding(.horizontal, 40)
            Text("This runs on-device and can take a few minutes.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func failure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Capture failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
        }
    }

    private func saveAndFinish(filename: String, box: BoxDimensions?) {
        let dims: [Dimension]
        if let box {
            dims = [
                Dimension(label: "Width", meters: box.width),
                Dimension(label: "Height", meters: box.height),
                Dimension(label: "Depth", meters: box.depth),
            ]
        } else {
            dims = []
        }
        let card = BentoCard(name: name.isEmpty ? "Captured object" : name,
                           category: category,
                           dimensions: dims,
                           notes: notes,
                           boundingBox: box,
                           capturedBy: capturedBy,
                           modelFilename: filename)
        store.add(card)
        onFinish()
        dismiss()
    }
}
