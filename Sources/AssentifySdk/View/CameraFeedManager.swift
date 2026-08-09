import UIKit
import AVFoundation


public enum CameraConfiguration {
    case success
    case failed
    case permissionDenied
}

public final class CameraFeedManager: NSObject {

    // MARK: - Camera
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    private let previewView: PreviewView
    private let useFrontCamera: Bool

    private var cameraConfiguration: CameraConfiguration = .failed
    private var isSessionRunning = false

    private let videoDataOutput = AVCaptureVideoDataOutput()

     weak var delegate: CameraSetupDelegate?

   
     init(previewView: PreviewView, isFront: Bool) {
        self.previewView = previewView
        self.useFrontCamera = isFront
        super.init()

        // Attach session to preview
        previewView.session = session
        previewView.previewLayer.videoGravity = .resizeAspectFill

        attemptToConfigureSession()
    }

    deinit {
        removeObservers()
    }

    // MARK: - Public control
    public func checkCameraConfigurationAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            switch self.cameraConfiguration {
            case .success:
                self.addObservers()
                self.startSession()
            case .failed, .permissionDenied:
                break
            }
        }
    }

    public func stopSession() {
        removeObservers()
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            self.isSessionRunning = self.session.isRunning
        }
    }

    public func resumeInterruptedSession(withCompletion completion: @escaping (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.startSession()
            DispatchQueue.main.async { completion(self.isSessionRunning) }
        }
    }

    // MARK: - Private: session lifecycle
    private func startSession() {
        guard !session.isRunning else { return }
        session.startRunning()
        isSessionRunning = session.isRunning
    }

    private func attemptToConfigureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraConfiguration = .success
        case .notDetermined:
            sessionQueue.suspend()
            requestCameraAccess { [weak self] _ in
                self?.sessionQueue.resume()
            }
        case .denied:
            cameraConfiguration = .permissionDenied
        default: break
        }

        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    private func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            self?.cameraConfiguration = granted ? .success : .permissionDenied
            completion(granted)
        }
    }

    private func configureSession() {
        guard cameraConfiguration == .success else { return }

        session.beginConfiguration()
        setBestPreset(for: session)

        guard addVideoDeviceInput() else {
            session.commitConfiguration()
            cameraConfiguration = .failed
            return
        }

        guard addVideoDataOutput() else {
            session.commitConfiguration()
            cameraConfiguration = .failed
            return
        }

        session.commitConfiguration()
        cameraConfiguration = .success
    }

    private func setBestPreset(for session: AVCaptureSession) {
//        if session.canSetSessionPreset(.vga640x480) {
//               // ✅ This is 4:3
//               session.sessionPreset = .vga640x480
//        } else
        if session.canSetSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        } else if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
    }

    private func makeDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInDualCamera,
            .builtInDualWideCamera,
            .builtInTripleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: position
        )
        return discovery.devices.first
    }

    private func addVideoDeviceInput() -> Bool {
        let position: AVCaptureDevice.Position = useFrontCamera ? .front : .back
        guard let device = makeDevice(position: position) else {
            print("❌ Cannot find \(position == .front ? "front" : "back") camera")
            return false
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else { return false }
            session.addInput(input)
            return true
        } catch {
            print("❌ Error creating device input: \(error)")
            return false
        }
    }

    private func addVideoDataOutput() -> Bool {
        let queue = DispatchQueue(label: "camera.samplebuffer.queue")

        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCMPixelFormat_32BGRA
        ]

        guard session.canAddOutput(videoDataOutput) else { return false }
        session.addOutput(videoDataOutput)
        videoDataOutput.setSampleBufferDelegate(self, queue: queue)

        // Orientation & mirroring AFTER adding output
        if let conn = videoDataOutput.connection(with: .video) {
            if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
            if useFrontCamera, conn.isVideoMirroringSupported { conn.isVideoMirrored = true }
        }

        return true
    }

    // MARK: - Observers
    private func addObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeErrorOccurred(notification:)),
            name: .AVCaptureSessionRuntimeError,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted(notification:)),
            name: .AVCaptureSessionWasInterrupted,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionInterruptionEnded),
            name: .AVCaptureSessionInterruptionEnded,
            object: session
        )
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionInterruptionEnded, object: session)
    }

    // MARK: - Notifications
    @objc private func sessionWasInterrupted(notification: Notification) {
        if let value = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
           let raw = value.integerValue,
           let reason = AVCaptureSession.InterruptionReason(rawValue: raw) {
            print("⚠️ Session interrupted: \(reason)")
        }
    }

    @objc private func sessionInterruptionEnded(notification: Notification) {
        print("ℹ️ Session interruption ended")
    }

    @objc private func sessionRuntimeErrorOccurred(notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        print("❌ Session runtime error: \(error)")

        if error.code == .mediaServicesWereReset {
            sessionQueue.async { [weak self] in
                guard let self else { return }
                if self.isSessionRunning { self.startSession() }
            }
        }
    }
}

// MARK: - Output delegate
extension CameraFeedManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput,
                              didOutput sampleBuffer: CMSampleBuffer,
                              from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        delegate?.didCaptureCVPixelBuffer(pixelBuffer)
    }
}
