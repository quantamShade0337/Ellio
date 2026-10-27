import AVFoundation
import Combine
import SwiftUI
import UIKit
import Vision

enum BodyJoint: String, CaseIterable, Codable, Hashable {
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
}

enum RepFlashState {
    case none
    case good
    case bad

    var color: Color {
        switch self {
        case .none:
            .clear
        case .good:
            Color.green.opacity(0.28)
        case .bad:
            Color.red.opacity(0.28)
        }
    }
}

final class PushUpDetector: NSObject, ObservableObject {
    enum AuthorizationState {
        case unknown
        case authorized
        case denied
    }

    enum SessionState: String {
        case waiting = "Align yourself in frame"
        case tracking = "Tracking your push-ups"
        case finished = "Target reached"
        case unavailable = "Camera unavailable"
    }

    @Published private(set) var authorizationState: AuthorizationState = .unknown
    @Published private(set) var sessionState: SessionState = .waiting
    @Published private(set) var repCount = 0
    @Published private(set) var formFeedback = "Keep your full body in frame"
    @Published private(set) var bodyVisible = false
    @Published private(set) var isReady = false
    @Published private(set) var currentBodyLineScore: Double = 0
    @Published private(set) var leftElbowAngle: Double = 0
    @Published private(set) var rightElbowAngle: Double = 0
    @Published private(set) var shoulderDrop: Double = 0
    @Published private(set) var flashState: RepFlashState = .none
    @Published private(set) var overlayPoints: [BodyJoint: CGPoint] = [:]

    let captureSession = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "ellio.pushup.session")
    private let analysisQueue = DispatchQueue(label: "ellio.pushup.analysis")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sequenceHandler = VNSequenceRequestHandler()

    private var configured = false
    private var isProcessingFrame = false
    private var targetReps = 12
    private var phase: PushUpPhase = .waitingForTop
    private var topShoulderHeight: CGFloat?
    private var flashResetWorkItem: DispatchWorkItem?

    func setTargetReps(_ target: Int) {
        targetReps = target
        if repCount >= targetReps {
            publish { $0.sessionState = .finished }
        }
    }

    func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            publish { $0.authorizationState = .authorized }
            configureSessionIfNeeded()
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                self.publish {
                    $0.authorizationState = granted ? .authorized : .denied
                    if !granted {
                        $0.sessionState = .unavailable
                        $0.formFeedback = "Camera access is required to verify your push-ups."
                    }
                }

                if granted {
                    self.configureSessionIfNeeded()
                    self.startSession()
                }
            }
        default:
            publish {
                $0.authorizationState = .denied
                $0.sessionState = .unavailable
                $0.formFeedback = "Enable camera access in Settings to use the push-up challenge."
            }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.configured, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    private func configureSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, !self.configured else { return }

            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high

            defer {
                self.captureSession.commitConfiguration()
            }

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                self.captureSession.canAddInput(input)
            else {
                self.publish {
                    $0.sessionState = .unavailable
                    $0.formFeedback = "We couldn't access the back camera."
                }
                return
            }

            self.captureSession.addInput(input)

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            guard self.captureSession.canAddOutput(self.videoOutput) else {
                self.publish {
                    $0.sessionState = .unavailable
                    $0.formFeedback = "We couldn't stream camera frames."
                }
                return
            }

            self.videoOutput.setSampleBufferDelegate(self, queue: self.analysisQueue)
            self.captureSession.addOutput(self.videoOutput)
            self.videoOutput.connection(with: .video)?.videoRotationAngle = 90
            self.configured = true
        }
    }

    private func processPose(_ observation: VNHumanBodyPoseObservation) {
        guard
            let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
            let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
            let leftElbow = try? observation.recognizedPoint(.leftElbow),
            let rightElbow = try? observation.recognizedPoint(.rightElbow),
            let leftWrist = try? observation.recognizedPoint(.leftWrist),
            let rightWrist = try? observation.recognizedPoint(.rightWrist),
            let leftHip = try? observation.recognizedPoint(.leftHip),
            let rightHip = try? observation.recognizedPoint(.rightHip),
            let leftAnkle = try? observation.recognizedPoint(.leftAnkle),
            let rightAnkle = try? observation.recognizedPoint(.rightAnkle)
        else {
            updatePoseMissing()
            return
        }

        let requiredPoints = [
            leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist,
            leftHip, rightHip, leftAnkle, rightAnkle
        ]

        guard requiredPoints.allSatisfy({ $0.confidence > 0.20 }) else {
            updatePoseMissing()
            return
        }

        let shoulderMid = CGPoint.midpoint(leftShoulder.location, rightShoulder.location)
        let hipMid = CGPoint.midpoint(leftHip.location, rightHip.location)
        let ankleMid = CGPoint.midpoint(leftAnkle.location, rightAnkle.location)

        let leftAngle = angle(a: leftShoulder.location, b: leftElbow.location, c: leftWrist.location)
        let rightAngle = angle(a: rightShoulder.location, b: rightElbow.location, c: rightWrist.location)
        let averageShoulderY = (leftShoulder.location.y + rightShoulder.location.y) / 2
        let averageElbowY = (leftElbow.location.y + rightElbow.location.y) / 2
        let averageWristY = (leftWrist.location.y + rightWrist.location.y) / 2
        let bodyAlignment = angle(a: shoulderMid, b: hipMid, c: ankleMid)
        let bodyLineScore = max(0, min(1, (bodyAlignment - 148) / 28))
        let elbowNearShoulders = abs(averageElbowY - averageShoulderY) < 0.14
        let wristsBelowShoulders = averageWristY < averageShoulderY

        publish {
            $0.bodyVisible = true
            $0.leftElbowAngle = leftAngle
            $0.rightElbowAngle = rightAngle
            $0.currentBodyLineScore = bodyLineScore
            $0.overlayPoints = [
                .leftShoulder: leftShoulder.location.previewPoint,
                .rightShoulder: rightShoulder.location.previewPoint,
                .leftElbow: leftElbow.location.previewPoint,
                .rightElbow: rightElbow.location.previewPoint,
                .leftWrist: leftWrist.location.previewPoint,
                .rightWrist: rightWrist.location.previewPoint
            ]
        }

        guard bodyLineScore > 0.6 else {
            publish {
                $0.isReady = false
                $0.sessionState = .waiting
                $0.formFeedback = "Keep your shoulders, hips, and ankles aligned."
                $0.shoulderDrop = 0
            }
            return
        }

        guard wristsBelowShoulders else {
            publish {
                $0.isReady = false
                $0.sessionState = .waiting
                $0.formFeedback = "Move back until wrists and shoulders stay visible."
                $0.shoulderDrop = 0
            }
            return
        }

        let upPosition = (160...180).contains(Int(leftAngle)) && (160...180).contains(Int(rightAngle))
        let downPosition = (70...100).contains(Int(leftAngle)) && (70...100).contains(Int(rightAngle))

        publish {
            $0.isReady = true
            $0.sessionState = $0.repCount >= self.targetReps ? .finished : .tracking
        }

        switch phase {
        case .waitingForTop:
            if upPosition {
                topShoulderHeight = averageShoulderY
                publish {
                    $0.formFeedback = "Top position locked. Lower with control."
                    $0.shoulderDrop = 0
                }
                phase = .waitingForBottom
            } else {
                publish {
                    $0.formFeedback = "Straighten your arms to the top position first."
                }
            }

        case .waitingForBottom:
            let baseline = topShoulderHeight ?? averageShoulderY
            let drop = max(0, baseline - averageShoulderY)
            publish { $0.shoulderDrop = drop }

            if downPosition {
                let goodDepth = drop > 0.035
                let goodElbowTrack = elbowNearShoulders

                if goodDepth && goodElbowTrack {
                    phase = .waitingForTopToCount
                    publish {
                        $0.formFeedback = "Great depth. Press back up to finish the rep."
                    }
                } else {
                    phase = .waitingForTop
                    topShoulderHeight = nil
                    triggerFlash(.bad)
                    publish {
                        $0.formFeedback = goodDepth
                            ? "Keep your elbows closer to shoulder level."
                            : "Lower your shoulders more at the bottom."
                        $0.shoulderDrop = drop
                    }
                }
            } else {
                publish {
                    $0.formFeedback = "Lower until elbows are between 70 and 100 degrees."
                }
            }

        case .waitingForTopToCount:
            let baseline = topShoulderHeight ?? averageShoulderY
            let drop = max(0, baseline - averageShoulderY)
            publish { $0.shoulderDrop = drop }

            if upPosition {
                phase = .waitingForBottom
                topShoulderHeight = averageShoulderY
                triggerFlash(.good)
                publish {
                    $0.repCount += 1
                    $0.formFeedback = $0.repCount >= self.targetReps
                        ? "Push-up target reached."
                        : "Rep counted. Go again."
                    if $0.repCount >= self.targetReps {
                        $0.sessionState = .finished
                    }
                }
            } else {
                publish {
                    $0.formFeedback = "Press back to the top with straight elbows."
                }
            }
        }
    }

    private func updatePoseMissing() {
        topShoulderHeight = nil
        phase = .waitingForTop
        publish {
            $0.bodyVisible = false
            $0.isReady = false
            $0.currentBodyLineScore = 0
            $0.leftElbowAngle = 0
            $0.rightElbowAngle = 0
            $0.shoulderDrop = 0
            $0.overlayPoints = [:]
            $0.sessionState = .waiting
            $0.formFeedback = "Place the phone sideways and keep shoulders, elbows, and wrists visible."
        }
    }

    private func angle(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let ab = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let cb = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let dot = ab.dx * cb.dx + ab.dy * cb.dy
        let magnitude = sqrt(ab.dx * ab.dx + ab.dy * ab.dy) * sqrt(cb.dx * cb.dx + cb.dy * cb.dy)
        guard magnitude > 0 else { return 0 }
        let cosine = min(max(dot / magnitude, -1), 1)
        return acos(cosine) * 180 / .pi
    }

    private func triggerFlash(_ state: RepFlashState) {
        publish { $0.flashState = state }
        flashResetWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.publish { $0.flashState = .none }
        }

        flashResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    private func publish(_ updates: @escaping (PushUpDetector) -> Void) {
        DispatchQueue.main.async {
            updates(self)
        }
    }

    private enum PushUpPhase {
        case waitingForTop
        case waitingForBottom
        case waitingForTopToCount
    }
}

extension PushUpDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessingFrame else { return }
        isProcessingFrame = true
        defer { isProcessingFrame = false }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest()
        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .right)
            guard let observation = request.results?.first else {
                updatePoseMissing()
                return
            }
            processPose(observation)
        } catch {
            publish {
                $0.sessionState = .unavailable
                $0.formFeedback = "Vision pose tracking failed. Try again."
            }
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
    }
}

struct SkeletonOverlayView: View {
    let points: [BodyJoint: CGPoint]

    private let limbs: [(BodyJoint, BodyJoint)] = [
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.leftShoulder, .rightShoulder)
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<limbs.count, id: \.self) { index in
                    let limb = limbs[index]
                    if let start = points[limb.0], let end = points[limb.1] {
                        Path { path in
                            path.move(to: start.scaled(to: geometry.size))
                            path.addLine(to: end.scaled(to: geometry.size))
                        }
                        .stroke(Color.green.opacity(0.95), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    }
                }

                ForEach(Array(points.keys), id: \.self) { joint in
                    if let point = points[joint] {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .position(point.scaled(to: geometry.size))
                    }
                }
            }
        }
    }
}

final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

private extension CGPoint {
    static func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }

    var previewPoint: CGPoint {
        CGPoint(x: x, y: 1 - y)
    }

    func scaled(to size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}
