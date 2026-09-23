import AVFoundation
import Vision
import SwiftUI

// MARK: - Camera Scanner Service (AVFoundation + Vision OCR + Barcode Engine)

@MainActor
@Observable
public final class CameraScannerService: NSObject {
    public private(set) var isCameraAvailable: Bool = false
    public private(set) var isSessionRunning: Bool = false
    public private(set) var recognizedBarcode: String?
    public private(set) var recognizedText: String?
    public var isTorchOn: Bool = false

    @ObservationIgnored nonisolated(unsafe) public let captureSession = AVCaptureSession()
    @ObservationIgnored nonisolated(unsafe) private var videoDevice: AVCaptureDevice?
    @ObservationIgnored nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    @ObservationIgnored nonisolated(unsafe) private let metadataOutput = AVCaptureMetadataOutput()

    @ObservationIgnored private let sessionQueue = DispatchQueue(label: "com.typesafe.camera.sessionQueue")
    @ObservationIgnored private let visionQueue = DispatchQueue(label: "com.typesafe.camera.visionQueue", qos: .userInitiated)

    @ObservationIgnored nonisolated(unsafe) private var lastOCRTimestamp = Date()
    @ObservationIgnored nonisolated private let ocrIntervalSeconds: TimeInterval = 0.8

    @ObservationIgnored private var lastRecognizedLabelHash: Int = 0

    @ObservationIgnored public var onBarcodeDetected: ((String) -> Void)?
    @ObservationIgnored public var onLabelTextDetected: ((String) -> Void)?

    public override init() {
        super.init()
        checkPermissionsAndConfigure()
    }

    public func checkPermissionsAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    Task { @MainActor in
                        self?.setupCaptureSession()
                    }
                }
            }
        default:
            isCameraAvailable = false
        }
    }

    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high

            // Setup Video Input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                DispatchQueue.main.async {
                    self.isCameraAvailable = false
                }
                self.captureSession.commitConfiguration()
                return
            }

            self.videoDevice = device

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }

                // Setup Barcode Metadata Output
                if self.captureSession.canAddOutput(self.metadataOutput) {
                    self.captureSession.addOutput(self.metadataOutput)
                    self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                    self.metadataOutput.metadataObjectTypes = [
                        .ean13, .ean8, .upce, .qr, .code128, .code39
                    ]
                }

                // Setup Video Data Output for Vision OCR
                if self.captureSession.canAddOutput(self.videoOutput) {
                    self.captureSession.addOutput(self.videoOutput)
                    self.videoOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoOutput.setSampleBufferDelegate(self, queue: self.visionQueue)
                }

                self.captureSession.commitConfiguration()
                self.captureSession.startRunning()

                DispatchQueue.main.async {
                    self.isCameraAvailable = true
                    self.isSessionRunning = self.captureSession.isRunning
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCameraAvailable = false
                }
                self.captureSession.commitConfiguration()
            }
        }
    }

    public func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.captureSession.isRunning
            }
        }
    }

    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    public func toggleTorch() {
        guard let device = videoDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            isTorchOn.toggle()
            device.torchMode = isTorchOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Failed to toggle torch: \(error)")
        }
    }

    /// Processes imported photos with rotation tolerance and multilingual OCR.
    public func processStillImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        visionQueue.async { [weak self] in
            guard let self = self else { return }

            let primaryOrientation = CGImagePropertyOrientation(image.imageOrientation)
            let orientations: [CGImagePropertyOrientation] = [
                primaryOrientation,
                .right,
                .left,
                .down,
                .up
            ]

            for orientation in orientations {
                var foundText: String?

                let request = VNRecognizeTextRequest { request, error in
                    guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else { return }
                    let spatialLines = NutritionLabelParser.reconstructSpatialLines(from: observations)
                    let joined = spatialLines.isEmpty
                        ? observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                        : spatialLines.joined(separator: "\n")

                    if NutritionLabelParser.isNutritionLabelOrIngredients(joined) {
                        foundText = joined
                    }
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["de-DE", "en-US", "fr-FR", "es-ES", "it-IT"]
                request.automaticallyDetectsLanguage = true

                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                try? handler.perform([request])

                if let text = foundText {
                    DispatchQueue.main.async {
                        AudioFeedback.playNutritionLabelSound()
                        self.recognizedText = text
                        self.onLabelTextDetected?(text)
                    }
                    return
                }
            }
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate (Barcode Detection + Sound 1)

extension CameraScannerService: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated public func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        for object in metadataObjects {
            guard let readable = object as? AVMetadataMachineReadableCodeObject,
                  let code = readable.stringValue else { continue }

            Task { @MainActor in
                if self.recognizedBarcode != code {
                    self.recognizedBarcode = code
                    AudioFeedback.playBarcodeSound()
                    self.onBarcodeDetected?(code)
                }
            }
            break
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (Live Multilingual Vision OCR + Sound 2)

extension CameraScannerService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastOCRTimestamp) >= ocrIntervalSeconds else { return }
        lastOCRTimestamp = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else { return }
            let spatialLines = NutritionLabelParser.reconstructSpatialLines(from: observations)
            let fullText = spatialLines.isEmpty
                ? observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                : spatialLines.joined(separator: "\n")

            // Multilingual detection for EU / German / French / English nutrition labels
            if NutritionLabelParser.isNutritionLabelOrIngredients(fullText) {
                let textHash = fullText.hashValue
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.lastRecognizedLabelHash != textHash {
                        self.lastRecognizedLabelHash = textHash
                        AudioFeedback.playNutritionLabelSound()
                        self.recognizedText = fullText
                        self.onLabelTextDetected?(fullText)
                    }
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["de-DE", "en-US", "fr-FR", "es-ES", "it-IT"]
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        try? handler.perform([request])
    }
}

// MARK: - Orientation Helper

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
