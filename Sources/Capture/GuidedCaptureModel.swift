import Foundation
import RealityKit
import Combine
import os

/// Drives Apple's Object Capture pipeline:
///   guided capture (ObjectCaptureSession) -> reconstruction (PhotogrammetrySession)
///   -> a real-scale USDZ stored in ModelLibrary.
///
/// Modeled on Apple's "Guided Capture" sample. Object Capture requires a device
/// with LiDAR and a recent chip; `isDeviceSupported` gates the whole feature.
///
/// NOTE: API names here track the iOS 17 RealityKit Object Capture surface.
/// If Apple adjusts a label in your installed SDK, the fixes are mechanical
/// (state-case / method renames) — the state machine below is the real logic.
@MainActor
final class GuidedCaptureModel: ObservableObject {

    /// High-level phase the UI renders against.
    enum Phase: Equatable {
        case preparing
        case ready          // point at object
        case detecting      // box reticle placed, confirm to start
        case capturing      // walking around
        case finishing
        case reconstructing(Double)   // progress 0...1
        case done(modelFilename: String, box: BoxDimensions?)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .preparing
    @Published private(set) var shotsTaken: Int = 0
    @Published private(set) var passComplete: Bool = false
    @Published private(set) var feedback: String = ""

    /// The live session the SwiftUI `ObjectCaptureView` renders.
    @Published private(set) var session: ObjectCaptureSession?

    private let imagesDir: URL
    private let checkpointDir: URL
    private var stateTask: Task<Void, Never>?
    private let log = Logger(subsystem: "com.bento.app", category: "capture")

    static var isDeviceSupported: Bool {
        ObjectCaptureSession.isSupported && PhotogrammetrySession.isSupported
    }

    init() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("Capture-\(UUID().uuidString)", isDirectory: true)
        imagesDir = root.appendingPathComponent("Images", isDirectory: true)
        checkpointDir = root.appendingPathComponent("Checkpoint", isDirectory: true)
        for dir in [imagesDir, checkpointDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard Self.isDeviceSupported else {
            phase = .failed("This device doesn't support 3D Object Capture (needs LiDAR).")
            return
        }
        let session = ObjectCaptureSession()
        self.session = session

        var config = ObjectCaptureSession.Configuration()
        config.checkpointDirectory = checkpointDir
        session.start(imagesDirectory: imagesDir, configuration: config)

        observe(session)
    }

    private func observe(_ session: ObjectCaptureSession) {
        stateTask?.cancel()
        stateTask = Task { [weak self] in
            // React to the session's state stream.
            for await state in session.stateUpdates {
                guard let self else { return }
                await self.handle(state: state, session: session)
            }
        }
    }

    private func handle(state: ObjectCaptureSession.CaptureState,
                        session: ObjectCaptureSession) async {
        shotsTaken = session.numberOfShotsTaken
        passComplete = session.userCompletedScanPass

        switch state {
        case .initializing:
            phase = .preparing
        case .ready:
            phase = .ready
        case .detecting:
            phase = .detecting
        case .capturing:
            phase = .capturing
        case .finishing:
            phase = .finishing
        case .completed:
            // Images captured; kick off reconstruction.
            await reconstruct()
        case .failed(let error):
            phase = .failed(error.localizedDescription)
        @unknown default:
            break
        }
    }

    // MARK: - User-driven transitions

    /// Object detected & box placed -> begin the photo pass.
    /// (CaptureState has a .failed(Error) case so it is not Equatable —
    /// pattern-match instead of ==.)
    func beginCapture() {
        guard let session else { return }
        if case .detecting = session.state {
            session.startCapturing()
        } else {
            // From .ready we must first detect the object.
            _ = session.startDetecting()
        }
    }

    /// Whether the session is currently in the .detecting state.
    var isDetecting: Bool {
        guard let session else { return false }
        if case .detecting = session.state { return true }
        return false
    }

    /// Call from .ready to place the detection bounding box.
    func detectObject() {
        _ = session?.startDetecting()
    }

    /// User finished a loop around the object. Encourage a second pass from a
    /// different height for better coverage, or finish.
    func startAnotherPass() {
        session?.beginNewScanPassAfterFlip()
    }

    func finishCapture() {
        session?.finish()   // -> .finishing -> .completed -> reconstruct()
    }

    func cancel() {
        stateTask?.cancel()
        session?.cancel()
    }

    // MARK: - Reconstruction

    private func reconstruct() async {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-\(UUID().uuidString).usdz")
        phase = .reconstructing(0)

        do {
            let photogrammetry = try PhotogrammetrySession(input: imagesDir)
            // `.reduced` keeps the mesh light enough to place in AR on-device.
            try photogrammetry.process(requests: [.modelFile(url: outputURL, detail: .reduced)])

            for try await output in photogrammetry.outputs {
                switch output {
                case .requestProgress(_, let fraction):
                    phase = .reconstructing(fraction)
                case .requestComplete(_, let result):
                    if case .modelFile = result {
                        log.info("Model file written.")
                    }
                case .processingComplete:
                    await finalize(outputURL: outputURL)
                    return
                case .requestError(_, let error):
                    phase = .failed("Reconstruction failed: \(error.localizedDescription)")
                    return
                case .processingCancelled:
                    phase = .failed("Reconstruction cancelled.")
                    return
                default:
                    break
                }
            }
        } catch {
            phase = .failed("Couldn't reconstruct: \(error.localizedDescription)")
        }
    }

    private func finalize(outputURL: URL) async {
        do {
            let filename = try ModelLibrary.adopt(from: outputURL)
            let box = await ModelLibrary.boundingBox(of: filename)
            phase = .done(modelFilename: filename, box: box)
        } catch {
            phase = .failed("Couldn't save model: \(error.localizedDescription)")
        }
    }
}
