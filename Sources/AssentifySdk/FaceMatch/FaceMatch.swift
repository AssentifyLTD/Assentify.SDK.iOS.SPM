import Foundation
import UIKit
import AVFoundation
import Accelerate
import CoreImage

public class FaceMatch: UIViewController, CameraSetupDelegate, RemoteProcessingDelegate {

    // MARK: - UI / camera

    var guide: Guide = Guide()
    var countdownLabel: UIView?
    var countdownTimer: Timer?
    var previewView: PreviewView!
    var cameraFeedManager: CameraFeedManager!
    private let overlayView = OverlayView()
    private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    private var modelDataHandler: ModelDataHandler? =
        ModelDataHandler(modelFileInfo: Yolov5.modelInfo, labelsFileInfo: Yolov5.labelsInfo, isFront: true)
    private var result: Result?

    var motionRectF: [CGRect] = []
    var sendingFlags: [MotionType] = []
    var sendingFlagsZoom: [ZoomType] = []

    // MARK: - Config

    private var faceMatchDelegate: FaceMatchDelegate?
    private var configModel: ConfigModel?
    private var environmentalConditions: EnvironmentalConditions?
    private var apiKey: String
    private var performLivenessFace: Bool?
    private var performPassiveLivenessFace: Bool?
    private var performPassiveLivenessFaceChanged: Bool? = false
    private var saveCapturedVideoFace: Bool?
    private var storeImageStream: Bool?
    private var secondImage: String?
    private var stepId: Int?

    // MARK: - State

    private var remoteProcessing: RemoteProcessing?
    private var motion: MotionType = MotionType.NO_DETECT
    private var zoom: ZoomType = ZoomType.NO_DETECT

    private var detectIfRectFInsideTheScreen = DetectIfRectInsideTheScreen()
    private var isRectFInsideTheScreen: Bool = false
    private var showCountDown: Bool = true
    private var isCountDownStarted: Bool = true
    private var start = true
    private var canCheckLive = true
    private var isManual = false
    private var startCollectingClips = false

    private var faceQualityCheck = FaceQualityCheck()
    private var frontalFaceChecker = FrontalFaceChecker()

    private var faceEvent = FaceEvents.NO_DETECT
    private var eventCompletionList: [FaceEventStatus] = []
    private var audioPlayer = AssetsAudioPlayer()

    private var errorLiveView: UIView?
    private var successLiveView: UIView?
    private var activeLiveMove: UIView?
    private var frameCounter = 0
    private var frameCounterLivness = 0
    private var processEveryNFrames = 2
    private var currentImage: CVPixelBuffer?
    private var livnessRetryCount = 0

    var livenessCheckArray: [CVPixelBuffer] = []
    private var localLivenessLimit = 0

    // MARK: - Active liveness image capture

    /// Frontal frame (deep copy) captured during the active liveness session.
    /// Only read/written on the main thread.
    private var imageDuringActiveLiveness: CVPixelBuffer?

    /// Incremented each time a new active liveness session starts.
    /// Delayed callbacks from an older session compare against it and bail out.
    private var liveSessionId = 0

    // MARK: - Init

    init(configModel: ConfigModel!,
         environmentalConditions: EnvironmentalConditions,
         apiKey: String,
         performLivenessFace: Bool,
         faceMatchDelegate: FaceMatchDelegate,
         secondImage: String,
         showCountDown: Bool,
         isManual: Bool
    ) {
        self.configModel = configModel
        self.environmentalConditions = environmentalConditions
        self.apiKey = apiKey
        self.performLivenessFace = performLivenessFace
        self.faceMatchDelegate = faceMatchDelegate
        self.secondImage = secondImage
        self.showCountDown = showCountDown
        self.isManual = isManual

        modelDataHandler?.customColor = ConstantsValues.DetectColor

        BugsnagObject.initialize(configModel: configModel)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setStepId(_ stepId: Int?) {
        self.stepId = stepId
        if self.stepId == nil {
            let steps = self.configModel?.stepDefinitions.filter { $0.stepDefinition == "FaceImageAcquisition" }
            if steps?.count == 1, let step = steps?.first {
                self.stepId = step.stepId
            } else {
                fatalError("Step ID is required because multiple 'FaceImage Acquisition' steps are present.")
            }
        }
        for item in self.configModel!.stepDefinitions {
            if let stepIdInt = self.stepId, stepIdInt == item.stepId {
                if performPassiveLivenessFace == nil {
                    performPassiveLivenessFace = item.customization.performLivenessDetection
                }
                if saveCapturedVideoFace == nil {
                    saveCapturedVideoFace = item.customization.saveCapturedVideo
                }
                if storeImageStream == nil {
                    storeImageStream = item.customization.storeImageStream
                }
            }
        }

        localLivenessLimit = (self.performPassiveLivenessFace ?? false) ? 12 : 0
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        guard modelDataHandler != nil else {
            fatalError("Failed to load model")
        }
        overlayView.clearsContextBeforeDrawing = true
        self.previewView = PreviewView()
        self.previewView.translatesAutoresizingMaskIntoConstraints = false
        self.previewView.contentMode = .scaleToFill
        view.addSubview(self.previewView)
        NSLayoutConstraint.activate([
            self.previewView.topAnchor.constraint(equalTo: view.topAnchor),
            self.previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            self.previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            self.previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        self.cameraFeedManager = CameraFeedManager(previewView: self.previewView, isFront: true)
        self.cameraFeedManager.checkCameraConfigurationAndStartSession()
        self.cameraFeedManager.delegate = self

        self.remoteProcessing = RemoteProcessing()

        if self.isManual {
            if environmentalConditions!.enableGuide {
                showGuide(color: self.environmentalConditions!.HoldHandColor)
            }
        } else {
            if isActiveLivenessConfigured() {
                self.fillCompletionMap()
            } else {
                eventCompletionList = []
            }

            if environmentalConditions!.enableGuide && !self.performLivenessFace! {
                showGuide(color: self.environmentalConditions!.HoldHandColor)
            }
        }

        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }
    public override var shouldAutorotate: Bool { false }

    // MARK: - Helpers

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }

    private func isActiveLivenessConfigured() -> Bool {
        return (self.performLivenessFace ?? false)
            && self.environmentalConditions?.activeLiveType != ActiveLiveType.NONE
            && self.environmentalConditions?.activeLivenessCheckCount != 0
    }

    /// Must be called on main thread.
    private func showGuide(color: String) {
        if self.guide.faceSvgImageView == nil {
            self.guide.showFaceGuide(view: self.view)
        }
        self.guide.changeFaceColor(view: self.view, to: color, notTransmitting: self.start)
    }

    // MARK: - Camera frames

    func didCaptureCVPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        if self.isManual {
            handleManualFrame(pixelBuffer)
            return
        }

        if self.areAllEventsDone() {
            self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: ActiveLiveEvents.GOOD)
            DispatchQueue.main.async {
                self.clearLiveUi()
                self.errorLiveView?.removeFromSuperview()
                self.successLiveView?.removeFromSuperview()
            }
        }

        runModel(onPixelBuffer: pixelBuffer)
        openCvCheck(pixelBuffer: pixelBuffer)

        let cropRect = CGRect(x: 0, y: 0, width: 256, height: 256)
        let imageBrightnessChecker = cropPixelBuffer(pixelBuffer, toRect: cropRect)!.brightness

        DispatchQueue.main.async {
            self.faceMatchDelegate?.onEnvironmentalConditionsChange?(
                brightnessEvents: self.environmentalConditions!.checkConditions(brightness: imageBrightnessChecker),
                motion: self.motion,
                faceEvents: !self.start && self.areAllEventsDone() ? FaceEvents.GOOD : self.faceEvent,
                zoom: self.zoom,
                detectedFaces: self.faces(),
                isCentered: self.isRectFInsideTheScreen)
        }
    }

    private func handleManualFrame(_ pixelBuffer: CVPixelBuffer) {
        self.currentImage = pixelBuffer
        if environmentalConditions!.enableGuide {
            DispatchQueue.main.async {
                self.showGuide(color: self.environmentalConditions!.HoldHandColor)
            }
        }

        guard self.startCollectingClips, self.performPassiveLivenessFace == true else { return }

        if livenessCheckArray.count < self.localLivenessLimit {
            self.faceMatchDelegate?.onCollectingManualImages()
            frameCounterLivness += 1
            if frameCounterLivness % processEveryNFrames == 0 {
                appendLivenessFrame(pixelBuffer)
            }
        }

        if livenessCheckArray.count == self.localLivenessLimit {
            self.start = false
            self.startCollectingClips = false
            self.faceMatchDelegate?.onSend()
            convertClipsAndSend(fallbackBuffer: pixelBuffer, isManualCapture: false)
        }
    }

    private func appendLivenessFrame(_ pixelBuffer: CVPixelBuffer) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            if let copiedBuffer = copyPixelBuffer(pixelBuffer) {
                DispatchQueue.main.async {
                    self.livenessCheckArray.append(copiedBuffer)
                }
            }
        }
    }

    // MARK: - Model

    @objc func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {
        result = self.modelDataHandler?.runModel(onFrame: pixelBuffer)
        if result?.inferences.count == 0 {
            livenessCheckArray.removeAll()
            motionRectF.removeAll()
            sendingFlagsZoom.removeAll()
            sendingFlags.removeAll()
            motion = MotionType.NO_DETECT
            zoom = ZoomType.NO_DETECT
        }
        guard let displayResult = result else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        DispatchQueue.main.async {
            self.drawAfterPerformingCalculations(onInferences: displayResult.inferences,
                                                 withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
        }
    }

    func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize: CGSize) {
        self.overlayView.objectOverlays = []
        self.overlayView.setNeedsDisplay()
        var objectOverlays: [ObjectOverlay] = []
        for inference in inferences {
            if inference.className == "face" {
                motionRectF.append(inference.rect)
            }

            var convertedRect = inference.rect.applying(CGAffineTransform(
                scaleX: self.overlayView.bounds.size.width / imageSize.width,
                y: self.overlayView.bounds.size.height / imageSize.height))
            if convertedRect.origin.x < 0 { convertedRect.origin.x = self.edgeOffset }
            if convertedRect.origin.y < 0 { convertedRect.origin.y = self.edgeOffset }
            if convertedRect.maxY > self.overlayView.bounds.maxY {
                convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
            }
            if convertedRect.maxX > self.overlayView.bounds.maxX {
                convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
            }

            if inference.className == "face" {
                isRectFInsideTheScreen = detectIfRectFInsideTheScreen.isRectWithinMargins(rect: convertedRect)
            }

            let confidenceValue = Int(inference.confidence * 100.0)
            let string = "\(inference.className) (\(confidenceValue)%)"
            let size = string.size(usingFont: self.displayFont)
            objectOverlays.append(ObjectOverlay(name: string, borderRect: convertedRect,
                                                nameStringSize: size, color: inference.displayColor,
                                                font: self.displayFont))
        }
        self.draw(objectOverlays: objectOverlays)
    }

    func draw(objectOverlays: [ObjectOverlay]) {
        self.overlayView.objectOverlays = objectOverlays
        self.overlayView.setNeedsDisplay()
        self.overlayView.frame = self.view.bounds
        self.overlayView.backgroundColor = UIColor.clear
        if environmentalConditions!.enableDetect && start && self.areAllEventsDone() {
            self.view.addSubview(self.overlayView)
        } else {
            self.overlayView.removeFromSuperview()
        }
    }

    // MARK: - Quality / liveness checks

    func openCvCheck(pixelBuffer: CVPixelBuffer) {
        let cropRect = CGRect(x: 0, y: 0, width: 256, height: 256)
        let croppedBuffer = cropPixelBuffer(pixelBuffer, toRect: cropRect)!
        let brightnessGood = environmentalConditions!.checkConditions(brightness: croppedBuffer.brightness) == BrightnessEvents.Good

        if motionRectF.count >= 2 {
            let rect1 = motionRectF[motionRectF.count - 2]
            let rect2 = motionRectF[motionRectF.count - 1]
            motion = calculateFaceMotion(rect1: rect1, rect2: rect2)
            zoom = calculatePercentageChangeWidth(rect: rect2, pixelBuffer: pixelBuffer)
        }

        frameCounter += 1
        if frameCounter % processEveryNFrames == 0,
           let downscaledBuffer = downscalePixelBuffer(pixelBuffer, scaleFactor: 0.3) {

            // Head pose / quality (ACTIONS) + frontal frame capture
            faceQualityCheck.checkQualityAction(pixelBuffer: downscaledBuffer) { faceEvent in
                DispatchQueue.main.async {
                    self.faceEvent = faceEvent
                    guard self.isActiveLivenessConfigured() else { return }

                    // FIX: capture whenever the face is frontal (before, between and
                    // after the moves), not only inside the short canCheckLive window.
                    if self.performPassiveLivenessFaceChanged == true,
                       faceEvent == FaceEvents.GOOD,
                       self.hasFace(),
                       self.isRectFInsideTheScreen {
                        self.captureActiveLivenessFrame(pixelBuffer, downscaled: downscaledBuffer)
                    }

                    if !self.areAllEventsDone(),
                       self.canCheckLive,
                       self.environmentalConditions?.activeLiveType == ActiveLiveType.ACTIONS {
                        self.isSpecificItemFlagEqualToActions(targetEvent: faceEvent)
                    }
                }
            }

            // Wink / blink
            if self.environmentalConditions?.activeLiveType == ActiveLiveType.WINK
                || self.environmentalConditions?.activeLiveType == ActiveLiveType.BLINK {
                faceQualityCheck.checkQualityWinkAndBLINK(pixelBuffer: downscaledBuffer) { faceEvent in
                    DispatchQueue.main.async {
                        guard self.isActiveLivenessConfigured(),
                              !self.areAllEventsDone(),
                              self.canCheckLive else { return }
                        self.isSpecificItemFlagEqualToWinkAndBLINK(targetEvent: faceEvent)
                    }
                }
            }
        }

        let readyToSend = motion == MotionType.SENDING
            && zoom == ZoomType.SENDING
            && isRectFInsideTheScreen
            && brightnessGood
            && self.faceEvent == FaceEvents.GOOD

        if readyToSend {
            modelDataHandler?.customColor = ConstantsValues.DetectColor
            sendingFlags.append(MotionType.SENDING)
            sendingFlagsZoom.append(ZoomType.SENDING)
            if self.performPassiveLivenessFace == true, livenessCheckArray.count < self.localLivenessLimit {
                frameCounterLivness += 1
                if frameCounterLivness % processEveryNFrames == 0 {
                    appendLivenessFrame(pixelBuffer)
                }
            }
            if environmentalConditions!.enableGuide && self.areAllEventsDone() {
                DispatchQueue.main.async { self.showGuide(color: ConstantsValues.DetectColor) }
            }
        } else {
            modelDataHandler?.customColor = environmentalConditions!.HoldHandColor
            sendingFlags.removeAll()
            sendingFlagsZoom.removeAll()
            livenessCheckArray.removeAll()
            if environmentalConditions!.enableGuide && self.areAllEventsDone() {
                DispatchQueue.main.async { self.showGuide(color: self.environmentalConditions!.HoldHandColor) }
            }
        }

        if self.showCountDown {
            if !hasFace() || !isRectFInsideTheScreen || self.faceEvent != FaceEvents.GOOD || self.zoom != ZoomType.SENDING {
                DispatchQueue.main.async {
                    self.countdownLabel?.removeFromSuperview()
                    self.countdownTimer?.invalidate()
                    self.isCountDownStarted = true
                }
            }
        }

        guard readyToSend,
              start,
              self.areAllEventsDone(),
              sendingFlags.count > environmentalConditions!.MotionLimitFace,
              sendingFlagsZoom.count > FaceZoomLimit,
              livenessCheckArray.count == self.localLivenessLimit,
              hasFace() else { return }

        if self.showCountDown {
            guard self.isCountDownStarted else { return }
            self.isCountDownStarted = false
            DispatchQueue.main.async {
                (self.countdownLabel, self.countdownTimer) = self.guide.showFaceTimer(
                    view: self.view,
                    initialTextColorHex: self.environmentalConditions!.CountDownNumbersColor
                ) {
                    self.isCountDownStarted = true
                    self.start = false
                    self.faceMatchDelegate?.onSend()
                    self.convertClipsAndSend(fallbackBuffer: pixelBuffer, isManualCapture: false)
                }
            }
        } else {
            self.start = false
            self.faceMatchDelegate?.onSend()
            convertClipsAndSend(fallbackBuffer: pixelBuffer, isManualCapture: false)
        }
    }

    /// Stores a deep copy of a frontal frame for the active liveness selfie. Main thread only.
    private func captureActiveLivenessFrame(_ pixelBuffer: CVPixelBuffer, downscaled: CVPixelBuffer) {
        // Fallback: keep the first GOOD frame immediately so we never end up with nil.
        if imageDuringActiveLiveness == nil, let copy = copyPixelBuffer(pixelBuffer) {
            imageDuringActiveLiveness = copy
        }

        let session = liveSessionId
        frontalFaceChecker.check(downscaled, orientation: .up) { [weak self] result in
            guard let self = self else { return }
            // If your result type exposes a frontal flag (e.g. result.isFrontal),
            // check it here as well so non-frontal frames are skipped.
            guard let _ = result else { return }
            guard let copy = copyPixelBuffer(pixelBuffer) else { return }
            DispatchQueue.main.async {
                guard session == self.liveSessionId else { return } // stale session
                self.imageDuringActiveLiveness = copy
            }
        }
    }

    /// Selfie for the request: active liveness frame if available, otherwise the given frame.
    private func activeSelfieData(fallback pixelBuffer: CVPixelBuffer) -> Data? {
        if self.performPassiveLivenessFaceChanged == true,
           let img = self.imageDuringActiveLiveness,
           let data = convertPixelToDataImage(pixelBuffer: img) {
            return data
        }
        return convertPixelToDataImage(pixelBuffer: pixelBuffer)
    }

    // MARK: - Sending

    private func convertClipsAndSend(fallbackBuffer: CVPixelBuffer, isManualCapture: Bool) {
        let buffers = self.livenessCheckArray
        // Read on main because imageDuringActiveLiveness is main-thread state.
        var activeSelfie: Data?
        let readSelfie = { activeSelfie = self.activeSelfieData(fallback: fallbackBuffer) }
        if Thread.isMainThread { readSelfie() } else { DispatchQueue.main.sync(execute: readSelfie) }

        let converter = ParallelImageProcessing()
        converter.setPixelBuffers(buffers)
        converter.convertBuffers { [weak self] in
            guard let self = self else { return }
            let clips = converter.getClips()
            let selfie: Data? = clips.isEmpty ? activeSelfie : clips[clips.count / 2]
            guard let selfieImage = selfie else {
                self.reportError()
                return
            }
            self.sendFace(selfieImage: selfieImage, clips: clips, isManualCapture: isManualCapture)
        }
    }

    private func sendFace(selfieImage: Data, clips: [Data], isManualCapture: Bool) {
        guard let secondString = self.secondImage,
              let secondDataImage = base64ToData(secondString),
              let config = self.configModel,
              let stepId = self.stepId else {
            reportError()
            return
        }

        self.remoteProcessing?.starProcessingFace(
            url: BaseUrls.signalRHub + HubConnectionFunctions.etHubConnectionFunction(blockType: BlockType.FACE_MATCH),
            appConfiguration: config,
            stepIdString: String(stepId),
            selfieImage: selfieImage,
            livenessFrames: clips,
            secondImage: secondDataImage,
            isLivenessEnabled: self.performPassiveLivenessFace ?? false,
            retryCount: self.livnessRetryCount,
            isManualCapture: isManualCapture,
            isAutoCapture: !isManualCapture,
            connectionId: "ConnectionId",
            onProgress: { [weak self] progress in
                self?.faceMatchDelegate?.onUploadingProgress(progress: progress)
            }
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let model):
                let endpoint = model?.destinationEndpoint ?? ""
                if let model = model {
                    self.onMessageReceived(eventName: endpoint, remoteProcessingModel: model)
                } else {
                    self.reportError()
                }
            case .failure(_):
                self.reportError()
            }
        }
    }

    private func reportError() {
        DispatchQueue.main.async { self.start = true }
        self.onMessageReceived(
            eventName: HubConnectionTargets.ON_ERROR,
            remoteProcessingModel: RemoteProcessingModel(
                destinationEndpoint: HubConnectionTargets.ON_ERROR,
                response: "",
                error: EventsErrorMessages.OnErrorMessage,
                success: false))
    }

    // MARK: - Server messages

    func onMessageReceived(eventName: String, remoteProcessingModel: RemoteProcessingModel) {
        DispatchQueue.main.async {
            self.motionRectF.removeAll()
            self.sendingFlags.removeAll()
            self.sendingFlagsZoom.removeAll()
            self.livenessCheckArray.removeAll()

            if eventName == HubConnectionTargets.ON_COMPLETE {
                let faceExtractedModel = FaceExtractedModel.fromJsonString(responseString: remoteProcessingModel.response!)
                let faceResponseModel = FaceResponseModel(
                    destinationEndpoint: remoteProcessingModel.destinationEndpoint,
                    faceExtractedModel: faceExtractedModel,
                    error: remoteProcessingModel.error,
                    success: remoteProcessingModel.success)
                self.faceMatchDelegate?.onComplete(dataModel: faceResponseModel)
                self.start = false

            } else if eventName == HubConnectionTargets.ON_RETRY {
                self.start = true
                remoteProcessingModel.error = EventsErrorMessages.OnRetryFaceMessage
                self.faceMatchDelegate?.onRetry(dataModel: remoteProcessingModel)

            } else if eventName == HubConnectionTargets.ON_LIVENESS_UPDATE {
                self.livnessRetryCount += 1
                self.start = true
                remoteProcessingModel.error = EventsErrorMessages.OnLivenessFaceUpdateMessage
                self.faceMatchDelegate?.onLivenessUpdate?(dataModel: remoteProcessingModel)

                if !self.isManual,
                   self.livnessRetryCount == self.environmentalConditions?.faceLivenessRetryCount {
                    self.switchToActiveLiveness()
                }

            } else {
                self.start = true
                switch eventName {
                case HubConnectionTargets.ON_ERROR:
                    remoteProcessingModel.error = EventsErrorMessages.OnErrorMessage
                    self.faceMatchDelegate?.onError(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_CLIP_PREPARATION_COMPLETE:
                    self.faceMatchDelegate?.onClipPreparationComplete?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_STATUS_UPDATE:
                    self.faceMatchDelegate?.onStatusUpdated?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_UPDATE:
                    self.faceMatchDelegate?.onUpdated?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_CARD_DETECTED:
                    self.faceMatchDelegate?.onCardDetected?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_MRZ_EXTRACTED:
                    self.faceMatchDelegate?.onMrzExtracted?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_MRZ_DETECTED:
                    self.faceMatchDelegate?.onMrzDetected?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_NO_MRZ_EXTRACTED:
                    self.faceMatchDelegate?.onNoMrzDetected?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_FACE_DETECTED:
                    self.faceMatchDelegate?.onFaceDetected?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_NO_FACE_DETECTED:
                    self.faceMatchDelegate?.onNoFaceDetected?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_FACE_EXTRACTED:
                    self.faceMatchDelegate?.onFaceExtracted?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_QUALITY_CHECK_AVAILABLE:
                    self.faceMatchDelegate?.onQualityCheckAvailable?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_DOCUMENT_CAPTURED:
                    self.faceMatchDelegate?.onDocumentCaptured?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_DOCUMENT_CROPPED:
                    self.faceMatchDelegate?.onDocumentCropped?(dataModel: remoteProcessingModel)
                case HubConnectionTargets.ON_UPLOAD_FAILED:
                    self.faceMatchDelegate?.onUploadFailed?(dataModel: remoteProcessingModel)
                default:
                    break
                }
            }
        }
    }

    /// Clean switch from passive to active liveness. Main thread only.
    private func switchToActiveLiveness() {
        self.livnessRetryCount = 0
        self.environmentalConditions?.activeLivenessCheckCount = 2
        self.environmentalConditions?.activeLiveType = ActiveLiveType.ACTIONS
        self.performLivenessFace = true
        self.performPassiveLivenessFace = false
        self.performPassiveLivenessFaceChanged = true
        self.localLivenessLimit = 0

        // Close the gap where start == true and the event list is still empty.
        self.start = false

        // Remove any leftover UI. NOTE: resetActiveLive() is NOT called anymore:
        // it played the "wrong" sound and re-randomized the moves 3 s later.
        self.countdownLabel?.removeFromSuperview()
        self.countdownTimer?.invalidate()
        self.isCountDownStarted = true
        self.errorLiveView?.removeFromSuperview(); self.errorLiveView = nil
        self.successLiveView?.removeFromSuperview(); self.successLiveView = nil

        self.fillCompletionMap()
    }

    func onVideCreated(videoBase64: String) {
    }

    // MARK: - Faces

    func hasFace() -> Bool {
        return faces() == 1
    }

    func faces() -> Int {
        guard let result = self.result, let conditions = self.environmentalConditions else { return 0 }
        return result.inferences.filter { item in
            item.className == "face" && conditions.isPredictionValid(confidence: item.confidence)
        }.count
    }

    // MARK: - Active liveness flow

    func fillCompletionMap() {
        runOnMain {
            self.liveSessionId += 1                 // invalidates delayed callbacks of old sessions
            self.start = false
            self.canCheckLive = true
            self.imageDuringActiveLiveness = nil    // never reuse an image from an old attempt
            self.activeLiveMove?.removeFromSuperview()
            self.activeLiveMove = nil
            self.eventCompletionList.removeAll()

            for event in getRandomEvents(activeLiveType: self.environmentalConditions!.activeLiveType,
                                         activeLivenessCheckCount: self.environmentalConditions!.activeLivenessCheckCount) {
                switch event {
                case .PITCH_UP:   self.eventCompletionList.append(FaceEventStatus(event: .PITCH_UP, isCompleted: false))
                case .PITCH_DOWN: self.eventCompletionList.append(FaceEventStatus(event: .PITCH_DOWN, isCompleted: false))
                case .YAW_RIGHT:  self.eventCompletionList.append(FaceEventStatus(event: .YAW_RIGHT, isCompleted: false))
                case .YAW_LEFT:   self.eventCompletionList.append(FaceEventStatus(event: .YAW_LEFT, isCompleted: false))
                case .WINK_LEFT:  self.eventCompletionList.append(FaceEventStatus(event: .WINK_LEFT, isCompleted: false))
                case .WINK_RIGHT: self.eventCompletionList.append(FaceEventStatus(event: .WINK_RIGHT, isCompleted: false))
                case .BLINK:      self.eventCompletionList.append(FaceEventStatus(event: .BLINK, isCompleted: false))
                case .GOOD:       break
                }
            }
            self.nextMove()
        }
    }

    func isSpecificItemFlagEqualToActions(targetEvent: FaceEvents) {
        guard let firstUncompleted = eventCompletionList.first(where: { !$0.isCompleted }) else { return }
        if firstUncompleted.event == targetEvent {
            firstUncompleted.isCompleted = true
            self.successActiveLive()
        } else if targetEvent != .NO_DETECT &&
                    targetEvent != .GOOD &&
                    targetEvent != .BLINK &&
                    targetEvent != .ROLL_RIGHT &&
                    targetEvent != .ROLL_LEFT &&
                    targetEvent != .WINK_LEFT &&
                    targetEvent != .WINK_RIGHT {
            if self.errorLiveView == nil {
                resetActiveLive()
            }
        }
    }

    func isSpecificItemFlagEqualToWinkAndBLINK(targetEvent: FaceEvents) {
        guard let firstUncompleted = eventCompletionList.first(where: { !$0.isCompleted }) else { return }
        if firstUncompleted.event == targetEvent {
            firstUncompleted.isCompleted = true
            self.successActiveLive()
        } else if targetEvent != .NO_DETECT &&
                    targetEvent != .GOOD &&
                    targetEvent != .ROLL_RIGHT &&
                    targetEvent != .ROLL_LEFT &&
                    targetEvent != .PITCH_UP &&
                    targetEvent != .PITCH_DOWN &&
                    targetEvent != .YAW_LEFT &&
                    targetEvent != .YAW_RIGHT {
            if self.errorLiveView == nil {
                resetActiveLive()
            }
        }
    }

    /// Main thread only.
    private func successActiveLive() {
        guard self.canCheckLive else { return }
        self.canCheckLive = false
        let session = liveSessionId

        self.audioPlayer.playAudio(fileName: ConstantsValues.AudioFaceSuccess)
        self.clearLiveUi()
        self.successLiveView?.removeFromSuperview()
        self.successLiveView = nil

        if areAllEventsDone() {
            start = true
            if self.environmentalConditions!.enableGuide {
                self.showGuide(color: self.environmentalConditions!.HoldHandColor)
            }
        } else {
            self.successLiveView = self.guide.showSuccessLiveCheck(view: self.view)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self = self, session == self.liveSessionId else { return }
                self.canCheckLive = true
                self.nextMove()
            }
        }
    }

    /// Main thread only.
    func resetActiveLive() {
        guard self.canCheckLive else { return }
        self.canCheckLive = false
        let session = liveSessionId

        self.audioPlayer.playAudio(fileName: ConstantsValues.AudioWrong)
        self.clearLiveUi()
        self.successLiveView?.removeFromSuperview()
        self.successLiveView = nil
        self.errorLiveView = self.guide.showErrorLiveCheck(view: self.view)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            self.errorLiveView?.removeFromSuperview()
            self.errorLiveView = nil
            guard session == self.liveSessionId else { return } // a newer session already started
            self.fillCompletionMap()
        }
    }

    func nextMove() {
        runOnMain {
            guard self.activeLiveMove == nil else { return }
            self.errorLiveView?.removeFromSuperview()
            self.successLiveView?.removeFromSuperview()

            guard let firstUncompleted = self.eventCompletionList.first(where: { !$0.isCompleted }) else { return }
            let key = firstUncompleted.event

            switch key {
            case .PITCH_UP:   self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .PITCH_UP)
            case .PITCH_DOWN: self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .PITCH_DOWN)
            case .YAW_RIGHT:  self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .YAW_RIGHT)
            case .YAW_LEFT:   self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .YAW_LEFT)
            case .WINK_LEFT:  self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .WINK_LEFT)
            case .WINK_RIGHT: self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .WINK_RIGHT)
            case .BLINK:      self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .BLINK)
            default: break
            }

            self.activeLiveMove = self.guide.setActiveLiveMove(view: self.view, event: key)
        }
    }

    func areAllEventsDone() -> Bool {
        return !eventCompletionList.contains { !$0.isCompleted }
    }

    func clearLiveUi() {
        runOnMain {
            self.activeLiveMove?.removeFromSuperview()
            self.activeLiveMove = nil
        }
    }

    // MARK: - Public

    public func stopScanning() {
        DispatchQueue.main.async {
            self.audioPlayer.stopAudio()
        }
        self.previewView.stopSession()
        self.cameraFeedManager.stopSession()
    }

    public func takePicture() {
        guard start else { return }
        guard let image = self.currentImage else { return }

        result = self.modelDataHandler?.runModel(onFrame: image)

        guard hasFace() else {
            self.faceMatchDelegate?.onRetry(dataModel: RemoteProcessingModel(
                destinationEndpoint: HubConnectionTargets.ON_RETRY,
                response: "",
                error: EventsErrorMessages.OnRetryFaceMessage,
                success: false))
            return
        }

        if self.performPassiveLivenessFace == true {
            DispatchQueue.main.async {
                self.startCollectingClips = true
            }
        } else {
            self.start = false
            self.faceMatchDelegate?.onSend()
            guard let selfieImage = convertPixelToDataImage(pixelBuffer: image) else {
                reportError()
                return
            }
            sendFace(selfieImage: selfieImage, clips: [], isManualCapture: true)
        }
    }
}
