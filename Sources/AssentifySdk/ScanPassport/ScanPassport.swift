import UIKit
import AVFoundation
import Accelerate
import CoreImage
import CoreMotion

public class ScanPassport :UIViewController, CameraSetupDelegate , RemoteProcessingDelegate ,LanguageTransformationDelegate {
    
    
    
    
    var guide : Guide = Guide();
    var previewView: PreviewView!
    var cameraFeedManager:CameraFeedManager!
    private let overlayView = OverlayView()
    private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    private var modelDataHandler: ModelDataHandler? =
    ModelDataHandler(modelFileInfo: Yolov5.modelInfo, labelsFileInfo: Yolov5.labelsInfo,isFront: false)
    private var result: Result?
    var motionRectF: [CGRect] = []
    var sendingFlagsMotion: [MotionType] = []
    var sendingFlagsZoom: [ZoomType] = []
    
    
    private var scanPassportDelegate: ScanPassportDelegate?
    private var configModel: ConfigModel?
    private var environmentalConditions: EnvironmentalConditions?
    private var apiKey: String
    private var processMrz: Bool?
    private var performLivenessDocument: Bool?
    private var saveCapturedVideoID: Bool?
    private var storeCapturedDocument: Bool?
    private var language: String
    private var stepId:Int?;
    
    private var remoteProcessing: RemoteProcessing?
    private var motion:MotionType = MotionType.NO_DETECT;
    private var zoom:ZoomType = ZoomType.NO_DETECT;
    
    private var passportResponseModel: PassportResponseModel?
    
    private var detectIfRectFInsideTheScreen = DetectIfRectInsideTheScreen();
    private var isRectFInsideTheScreen:Bool = false;
    
    private var  start = true;
    
    private var audioPlayer = AssetsAudioPlayer();
    private var  retryCount = 0;
    private var  isManual = false;
    private var  currentImage : CVPixelBuffer?;

    // =============================================================================================
    // Local liveness: fields (the section itself is at the bottom of the class)
    // =============================================================================================

    /// The finder model in the SDK bundle (the same file as Android's ConstantsValues.FinderFileName), without ".tflite".
    private static let FINDER_MODEL = "finder_fp32"
    private static let DEBUG_LOGS = false                            // TEMP: set false for release

    private var finder: Finder?
    private var finderFailed = false

    // ---- config (rectifier_config_file.json) ----
    private var cfg: LivenessConfig?
    private var documentKind = LivenessConfig.KIND_OTHER_PASSPORT    // lb_passport or other_passport (default)

    private var PASSPORT_ASPECT = 1.4204545454545454
    private lazy var stab = OutlineStabilizer(docAspect: PASSPORT_ASPECT)
    private var RECT_H = 338
    private var FRAME_MARGIN_PX = 4.0, MIN_QUAD_AREA_FRAC = 0.08, FRONTAL_MAX = 0.16, SHAPE_TOL = 0.1
    private var STABLE_MS = 300, ANALYSIS_LONG_EDGE = 720, LOSS_MS = 1500, PHASE_TIMEOUT_MS = 15000
    private var MAX_ATTEMPTS = 3, MAX_RESTARTS = 8, MAX_EARLY_RESTARTS = 40, BASELINE_HOLD_MS = 400
    private var SHARPNESS_MIN = 60.0, GLARE_MAX = 0.04, DRIFT_MAX = 0.03
    private var LIGHT_SETTLE_MS = 300, LIGHT_MAX_MS = 2500, LIGHT_FRAMES = 5, OFF_SETTLE_MS = 500, OFF_MAX_MS = 4000
    private var BATTERY_LOW = 0.05
    private var TILT_MIN = 0.08, SWEEP_FRAMES = 6, WRONG_WAY_FRAMES = 4, STUCK_MS = 3000, TILT_HOLD_MS = 4000
    private var TILT_NOISE_K = 3.0, SAME_PLACE_MAX = 0.08, AREA_JUMP_MAX = 1.6
    private var ANGLE_MAX = 0.17, TILT_OVERFLOW = 0.15, EDGE_MARGIN = 0.02
    private var FLAT_DEG = 10.0, FLAT_MS = 800, MAX_HAND_PAUSES = 1, TABLE_CARD = true, TURN_DEG = 20.0
    private var BRIGHT_LIFT = 1.25, SUN_MAX = 3, STALL_MS = 6000

    // native-only (same values as Android, from the device logs)
    private static let BASELINE_MIN_POSES = 3
    private static let HOLD_STILL_TOL = 0.05
    private static let HOLD_FRONTAL_MAX = 0.25
    private static let HOLD_GLARE_MAX = 0.06
    private static let LIGHT_LOSS_FACTOR = 2.5
    private static let TORCH_CONFIRM_MS = 1000
    private static let RAW_LR_MAX = 0.45
    private static let RAW_TB_MAX = 0.80
    private static let MOVE_EPS = 0.01
    private static let BOTTOM_LIFT_SIGN = -1.0                       // lifting the bottom makes tb go NEGATIVE
    private static let SWEEP_FLAT_EPS = 0.04
    private static let TILT_NEED_MAX_FACTOR = 2.0                    // the tilt asked is at most 2 x tiltMin
    // re-anchor "flat" when the light-step reference is off: held still for REANCHOR_FRAMES frames, between
    // REANCHOR_FROM_MS and REANCHOR_UNTIL_MS after the tilt was asked, and flat never seen (device log: ref 0.156,
    // the page at rest read -0.07 -> "flat" never seen, the meter stayed at 0 and the try timed out)
    private static let REANCHOR_FRAMES = 8
    private static let REANCHOR_FROM_MS = 1000, REANCHOR_UNTIL_MS = 4000
    private static let RAW_PAGE_ASPECT_MIN = 1.0                     // raw outline: >= 1.0 photo page, < 1.0 booklet
    private static let OFF_REASK_MS = 250
    private static let MOTION_FRESH_MS = 1000
    private static let PAUSE_SHOW_MS = 3000, PAUSE_MAX_MS = 8000

    // orientation check (normal only: not upside down, not MRZ left / right)
    private static let MAX_ROLL_DEG = 30.0
    private static let WARP_W = 400, WARP_H = 282, CELL = 16, EDGE_MIN = 40
    private static let MRZ_ROW_FILL = 0.60, MRZ_MIN = 0.06, MRZ_MARGIN = 2.0

    // ---- this frame ----
    private var lastUpright: LivenessImage?
    private var curPixelBuffer: CVPixelBuffer?                      // this frame only (the liveness screen's image)
    private var lastQuad: [Double]?, lastPixelQuad: [Double]?, lastRawQuad: [Double]?
    private var lastPose: Pose?, lastRawPose: Pose?
    private var lastIsRaw = false, lastFlat = false, lastSharp = false
    private var lastSharpness = 0.0, lastGlareFrac = 0.0
    private var tiltStart = false
    private var tiltLayoutView: UIView?                             // the tilt drawing on screen (Guide), or nil
    private var steadySince = 0
    private var positionMisses = 0
    private var holdGraceUsed = false
    private var pendingReset = false
    private var orientWhy = ""

    // ---- phases (rc17: ends on the tilt) ----
    private enum Phase { case position, baseline, light, sweep, done }
    private var phase = Phase.position
    private var phaseStart = 0, lastSeen = 0

    // ---- per try / per visit ----
    private var engineAttempts = 0, restarts = 0, earlyRestarts = 0
    private var tryReasons: [String] = []
    private var retriesThisVisit = 0
    private var matteBefore = false

    // ---- baseline ----
    private var baseCount = 0, baseHoldSince = 0
    private var havePrev = false
    private var prevLr = 0.0, prevTb = 0.0, prevCx = 0.0, prevCy = 0.0, holdLr = 0.0, holdTb = 0.0
    private var baselineRawTbPage: [Double] = [], baselineRawTbSpread: [Double] = [], baselineAngles: [Double] = []
    private var baseAngle = Double.nan
    private var flatPhoto: Data?                                    // THE photo: flat and unlit (baseline end)

    // ---- light ----
    private var baseK = 0
    private var unlitImg: [UInt32]?, litImg: [UInt32]?
    private var iridBase: LivenessVision.IridBase?
    private var lightAvailable = false, lightEnded = false
    private var lightRequestedAt = 0
    private enum Light { case off, on, goingOff }
    private var lightState = Light.off
    private var offAskedAt = 0, offLastAskAt = 0, darkAt = -1_000_000
    private var lightSharp = 0
    private var reflection: LivenessGate.ReflectionAnalyzer?
    private var lightRawTbPage: [Double] = [], lightRawTbSpread: [Double] = []
    private var baseRawTbPage = Double.nan, baseRawTbSpread = Double.nan
    private var tiltMinEffective = 0.08

    // ---- sweep ----
    private var sweepFromPage = Double.nan, sweepFromSpread = Double.nan, sweepMoved = 0.0
    private var iridTilt: [[Double]] = []
    private var sweepGood = 0, sweepWrong = 0
    private var prevDelta = 0.0
    private var lastMoveAt = 0, reachedAt = 0
    private var sweepSawFlat = false
    private var sweepStill = 0                                      // still frames before any "flat" was seen
    private var sweepRefSet = false, sweepLastSeenAt = 0
    private var sweepRefX = 0.0, sweepRefY = 0.0, sweepRefLen = 0.0

    // ---- result / UI ----
    private var finalReady = false
    private var shownInstruction: PassportLivenessInstruction?
    private var livenessProgress = 0, shownProgress = -1
    private var livenessFrameGood = false

    // ---- hand / sun / stall (hand-and-sun-pauses.md, camera-torch.md) ----
    private let motionManager = CMMotionManager()
    private var phoneTiltDeg = Double.nan, phoneTiltAt = 0
    private var gravX = Double.nan, gravY = Double.nan, gravZ = Double.nan
    private var markX = Double.nan, markY = Double.nan, markZ = Double.nan
    private var flatSince = 0
    private var handPauses = 0, sunPauses = 0
    private var brightMiss = false
    private var flags: [String] = []
    private var pause: PassportLivenessInstruction?
    private var pauseAt = 0
    private var lastFrameAt = 0
    private var stallTimer: Timer?

    // ---- torch: the back camera (wide angle). Use CameraFeedManager's own device here if it exposes one. ----
    private lazy var torchDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

    init(configModel: ConfigModel!,
         environmentalConditions :EnvironmentalConditions,
         apiKey:String,
         scanPassportDelegate:ScanPassportDelegate,
         language: String,
         isManual: Bool
    ) {
        self.configModel = configModel;
        self.environmentalConditions = environmentalConditions;
        self.apiKey = apiKey;
        self.scanPassportDelegate = scanPassportDelegate;
        self.language = language
        self.isManual = isManual
        
        modelDataHandler?.customColor = ConstantsValues.DetectColor;
        
        BugsnagObject.initialize(configModel: configModel);
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    func setStepId(_ stepId: Int?) {
        self.stepId = stepId
        if self.stepId == nil {
            let steps = self.configModel?.stepDefinitions.filter { $0.stepDefinition == "IdentificationDocumentCapture" }
            
            if steps?.count == 1 {
                if let step = steps?.first {
                    self.stepId = step.stepId
                }
            } else {
                if self.stepId == nil {
                    fatalError("Step ID is required because multiple 'Identification Document Capture' steps are present.")
                }
            }
        }
        for item in self.configModel!.stepDefinitions {
            if let stepIdInt = self.stepId, stepIdInt == item.stepId {
                if performLivenessDocument == nil {
                    performLivenessDocument = item.customization.documentLiveness
                }
                if processMrz == nil {
                    processMrz = item.customization.processMrz
                }
                if storeCapturedDocument == nil {
                    storeCapturedDocument = item.customization.storeCapturedDocument
                }
                if saveCapturedVideoID == nil {
                    saveCapturedVideoID = item.customization.saveCapturedVideo
                }
            }
        }
        
    }
    
    
    public override func viewDidLoad() {
        guard modelDataHandler != nil else {
            fatalError("Failed to load model")
        }
        overlayView.clearsContextBeforeDrawing = true
        self.previewView = PreviewView();
        self.previewView.translatesAutoresizingMaskIntoConstraints = false
        self.previewView.contentMode = .scaleToFill
        view.addSubview(self.previewView)
        NSLayoutConstraint.activate([
            self.previewView.topAnchor.constraint(equalTo: view.topAnchor),
            self.previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            self.previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            self.previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        
        self.cameraFeedManager = CameraFeedManager(previewView: self.previewView,isFront: false)
        self.cameraFeedManager.checkCameraConfigurationAndStartSession()
        self.cameraFeedManager.delegate = self
        
        self.remoteProcessing = RemoteProcessing()
        
        if(environmentalConditions!.enableGuide){
            if(self.guide.cardSvgImageView == nil){
                self.guide.showCardGuide(view: self.view,forResource: "passport_background")
            }
            self.guide.changeCardColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
        }

        // the app going to the background interrupts the liveness (camera-torch.md)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startMotion()
        lastFrameAt = 0
        stallTimer?.invalidate()
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.checkStall() }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopMotion()
        stallTimer?.invalidate()
        stallTimer = nil
        interrupt()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stallTimer?.invalidate()
    }
    
    public  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    public  override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    public   override var shouldAutorotate: Bool {
        return false
    }
    
    
    func didCaptureCVPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        if(self.isManual){
            self.currentImage = pixelBuffer
            DispatchQueue.main.async {
                if(self.environmentalConditions!.enableGuide){
                    if(self.guide.cardSvgImageView == nil){
                        self.guide.showCardGuide(view: self.view,forResource: "passport_background")
                    }
                    self.guide.changeCardColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
                }
            }
            return
        }

        let configReady = ensureConfig()
        if pendingReset {                                           // set after a retry / the background
            pendingReset = false
            resetLiveness()
        }
        let livenessOn = performLivenessDocument == true && configReady && loadFinder()
        if livenessOn {
            processLiveness(pixelBuffer)
        } else {                                                    // the capture as before
            runModel(onPixelBuffer: pixelBuffer)
            openCvCheck(pixelBuffer: pixelBuffer)
        }
    }
    
    @objc func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {
        result = self.modelDataHandler?.runModel(onFrame: pixelBuffer)
        if (result?.inferences.count == 0) {
            motionRectF.removeAll()
            sendingFlagsMotion.removeAll()
            sendingFlagsZoom.removeAll()
            motion = MotionType.NO_DETECT;
            zoom = ZoomType.NO_DETECT;
        }
        guard let displayResult = result else {
            return
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        DispatchQueue.main.async {
            self.drawAfterPerformingCalculations(onInferences: displayResult.inferences, withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
        }
        
    }
    func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize:CGSize) {
        self.overlayView.objectOverlays = []
        self.overlayView.setNeedsDisplay()
        var objectOverlays: [ObjectOverlay] = []
        for inference in inferences {
            if(inference.className == "card"){
                motionRectF.append(inference.rect);
            }
            
            var convertedRect = inference.rect.applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width, y: self.overlayView.bounds.size.height / imageSize.height))
            if convertedRect.origin.x < 0 {
                convertedRect.origin.x = self.edgeOffset
            }
            if convertedRect.origin.y < 0 {
                convertedRect.origin.y = self.edgeOffset
            }
            if convertedRect.maxY > self.overlayView.bounds.maxY {
                convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
            }
            if convertedRect.maxX > self.overlayView.bounds.maxX {
                convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
            }
            
            if(inference.className == "card"){
                isRectFInsideTheScreen = detectIfRectFInsideTheScreen.isRectWithinMargins(rect: convertedRect);
            }
            
            let confidenceValue = Int(inference.confidence * 100.0)
            let string = "\(inference.className) (\(confidenceValue)%)"
            let size = string.size(usingFont: self.displayFont)
            let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect, nameStringSize: size, color: inference.displayColor, font: self.displayFont)
            objectOverlays.append(objectOverlay)
        }
        self.draw(objectOverlays: objectOverlays)
        
    }
    
    func draw(objectOverlays: [ObjectOverlay]) {
        self.overlayView.objectOverlays = objectOverlays
        self.overlayView.setNeedsDisplay()
        self.overlayView.frame = self.view.bounds
        self.overlayView.backgroundColor = UIColor.clear
        if(environmentalConditions!.enableDetect && start){
            self.view.addSubview(self.overlayView)
        }else{
            self.overlayView.removeFromSuperview()
        }
        
    }
    
    
    func openCvCheck(pixelBuffer: CVPixelBuffer){
        let cropRect = CGRect(x: 0, y: 0, width: 256, height: 256)
        let imageBrightnessChecker = cropPixelBuffer(pixelBuffer, toRect: cropRect)!.brightness;
        if motionRectF.count >= 2 {
            let rect1 = motionRectF[motionRectF.count - 2]
            let rect2 = motionRectF[motionRectF.count - 1]
            motion = calculatePercentageChange(rect1: rect1, rect2: rect2)
            zoom = calculatePercentageChangeWidth(rect: rect2,pixelBuffer: pixelBuffer)
            
        }
        
        if (motion == MotionType.SENDING && zoom == ZoomType.SENDING && isRectFInsideTheScreen && environmentalConditions!.checkConditions(
            brightness: imageBrightnessChecker)  == BrightnessEvents.Good) {
            modelDataHandler?.customColor = ConstantsValues.DetectColor;
            sendingFlagsMotion.append(MotionType.SENDING);
            sendingFlagsZoom.append(ZoomType.SENDING);
            if(environmentalConditions!.enableGuide){
                DispatchQueue.main.async {
                    if(self.guide.cardSvgImageView == nil){
                        self.guide.showCardGuide(view: self.view,forResource: "passport_background")
                    }
                    self.guide.changeCardColor(view: self.view,to:ConstantsValues.DetectColor,notTransmitting: self.start)
                }
            }
        } else {
            modelDataHandler?.customColor = environmentalConditions!.HoldHandColor;
            sendingFlagsMotion.removeAll();
            sendingFlagsZoom.removeAll();
            if(environmentalConditions!.enableGuide){
                DispatchQueue.main.async {
                    if(self.guide.cardSvgImageView == nil){
                        self.guide.showCardGuide(view: self.view,forResource: "passport_background")
                    }
                    self.guide.changeCardColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
                }
            }
        }
        
        if (environmentalConditions!.checkConditions(
            brightness: imageBrightnessChecker)  == BrightnessEvents.Good
            && motion == MotionType.SENDING  && zoom == ZoomType.SENDING && isRectFInsideTheScreen) {
            if (start && sendingFlagsMotion.count > environmentalConditions!.MotionLimit && sendingFlagsZoom.count > ZoomLimit) {
                if (hasFaceOrCard()) {
                    let dataImage = convertPixelToDataImage(pixelBuffer: pixelBuffer)!
                    DispatchQueue.main.async {
                        self.scanPassportDelegate?.onSend();
                        self.audioPlayer.playAudio(fileName: ConstantsValues.AudioCardSuccess)
                    }
                    sendToServer(dataImage, isManualCapture: false)
                    start = false;
                }
            }
            
            
        }
        DispatchQueue.main.async {
            self.scanPassportDelegate?.onEnvironmentalConditionsChange?(
                brightnessEvents: self.environmentalConditions!.checkConditions(
                    brightness: imageBrightnessChecker),
                motion: self.motion,zoom:self.zoom,isCentered: self.isRectFInsideTheScreen)
        }
        
    }

    /// The upload, shared by the old capture, the manual capture and the liveness (the flat, unlit photo).
    private func sendToServer(_ dataImage: Data, isManualCapture: Bool) {
        remoteProcessing?.starProcessingIDs(
            url: BaseUrls.signalRHub + HubConnectionFunctions.etHubConnectionFunction(blockType:BlockType.READ_PASSPORT),
            image: dataImage,
            stepIdString: String(self.stepId!),
            appConfiguration:self.configModel!,
            connectionId: "ConnectionId",
            clipsPath: "ClipsPath",
            checkForFace: true,
            processMrz: processMrz!,
            performLivenessDocument: performLivenessDocument!,
            saveCapturedVideo: saveCapturedVideoID!,
            storeCapturedDocument: storeCapturedDocument!,
            isVideo: false,
            storeImageStream: true,
            isManualCapture: isManualCapture,
            isAutoCapture: !isManualCapture,
            retryCount: retryCount,
            tag:getIDTag(configModel: self.configModel!, templateName: "ReadPassport"),
            processCivilExtractQrCode: false,
            onProgress: { progress in
                self.scanPassportDelegate?.onUploadingProgress(progress: progress);
            },
            completion: { result in
                switch result {
                case .success(let model):
                    self.onMessageReceived(eventName: model?.destinationEndpoint ?? "",remoteProcessingModel: model!)
                case .failure(_):
                    self.start = true;
                    self.onMessageReceived(eventName: HubConnectionTargets.ON_ERROR ,remoteProcessingModel: RemoteProcessingModel(
                        destinationEndpoint: HubConnectionTargets.ON_ERROR,
                        response: "",
                        error: "",
                        success: false
                    ))
                }
            })
    }
    
    
    func onMessageReceived(eventName: String, remoteProcessingModel : RemoteProcessingModel ) {
        DispatchQueue.main.async {
            self.motionRectF.removeAll()
            self.sendingFlagsMotion.removeAll()
            self.sendingFlagsZoom.removeAll()
            if eventName == HubConnectionTargets.ON_COMPLETE {
               
                let passportExtractedModel = PassportExtractedModel.fromJsonString(responseString:remoteProcessingModel.response!,transformedProperties: [:]);
                self.passportResponseModel = PassportResponseModel(
                    destinationEndpoint: remoteProcessingModel.destinationEndpoint,
                    passportExtractedModel: passportExtractedModel,
                    error: remoteProcessingModel.error,
                    success: remoteProcessingModel.success
                )
                
                let expired: Bool = (self.passportResponseModel?
                    .passportExtractedModel?
                    .identificationDocumentCapture?
                    .IsExpired as? Bool) ?? false
                
                
                if(expired){
                    self.retryCount = self.retryCount + 1;
                    remoteProcessingModel.error = EventsErrorMessages.OnExpiredPassportMessage
                    self.scanPassportDelegate?.onRetry(dataModel:remoteProcessingModel )
                    self.start = true
                }else{
                    self.start = false
                    if(self.language == Language.NON){
                        self.scanPassportDelegate?.onComplete(dataModel:self.passportResponseModel! )
                    }else{
                        let transformed = LanguageTransformation(apiKey: self.apiKey,languageTransformationDelegate: self)
                        transformed.languageTransformation(
                            langauge: self.language,
                            transformationModel: preparePropertiesToTranslate(language: self.language, properties: passportExtractedModel?.outputProperties)
                        )
                    }
                    
                }
               
            } else if eventName == HubConnectionTargets.ON_RETRY{
                self.retryCount = self.retryCount + 1;
                remoteProcessingModel.error = EventsErrorMessages.OnRetryCardMessage
                self.scanPassportDelegate?.onRetry(dataModel:remoteProcessingModel )
                self.start = true
            } else{
                self.start = eventName == HubConnectionTargets.ON_ERROR
                switch eventName {
                case HubConnectionTargets.ON_ERROR:
                    remoteProcessingModel.error = EventsErrorMessages.OnErrorMessage
                    self.scanPassportDelegate?.onError(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_CLIP_PREPARATION_COMPLETE:
                    self.scanPassportDelegate?.onClipPreparationComplete?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_STATUS_UPDATE:
                    self.scanPassportDelegate?.onStatusUpdated?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_UPDATE:
                    self.scanPassportDelegate?.onUpdated?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_CARD_DETECTED:
                    self.scanPassportDelegate?.onCardDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_MRZ_EXTRACTED:
                    self.scanPassportDelegate?.onMrzExtracted?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_MRZ_DETECTED:
                    self.scanPassportDelegate?.onMrzDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_NO_MRZ_EXTRACTED:
                    self.scanPassportDelegate?.onNoMrzDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_FACE_DETECTED:
                    self.scanPassportDelegate?.onFaceDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_NO_FACE_DETECTED:
                    self.scanPassportDelegate?.onNoFaceDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_FACE_EXTRACTED:
                    self.scanPassportDelegate?.onFaceExtracted?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_QUALITY_CHECK_AVAILABLE:
                    self.scanPassportDelegate?.onQualityCheckAvailable?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_DOCUMENT_CAPTURED:
                    self.scanPassportDelegate?.onDocumentCaptured?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_DOCUMENT_CROPPED:
                    self.scanPassportDelegate?.onDocumentCropped?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_UPLOAD_FAILED:
                    self.scanPassportDelegate?.onUploadFailed?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_LIVENESS_UPDATE:
                    remoteProcessingModel.error = EventsErrorMessages.OnLivenessCardUpdateMessage
                    self.scanPassportDelegate?.onLivenessUpdate?(dataModel:remoteProcessingModel, image: nil)   // server: its URL
                    self.start = true
                case HubConnectionTargets.ON_WRONG_TEMPLATE:
                    remoteProcessingModel.error = EventsErrorMessages.OnWrongTemplateMessage
                    self.scanPassportDelegate?.onWrongTemplate(dataModel:remoteProcessingModel )
                    self.start = true
                default:
                    self.start = true
                    remoteProcessingModel.error = EventsErrorMessages.OnRetryCardMessage
                    self.scanPassportDelegate?.onRetry(dataModel:remoteProcessingModel )
                    break
                }
            }
            
            if self.start { self.pendingReset = true }              // a server retry: the liveness starts again
            
        }
    }
    
    
    func onVideCreated(videoBase64: String) {
        
    }
    
    func hasFaceOrCard() -> Bool {
        return hasFace() || hasCard()
    }
    
    func hasFace() -> Bool {
        var hasFace = false
        for item in result!.inferences {
            if item.className == "face" && environmentalConditions!.isPredictionValid(confidence: item.confidence) {
                hasFace = true
                break
            }
        }
        return hasFace
    }
    
    func hasCard() -> Bool {
        var hasCard = false
        for item in result!.inferences {
            if item.className == "card"  && environmentalConditions!.isPredictionValid(confidence: item.confidence) {
                hasCard = true
                break
            }
        }
        return hasCard
    }
    
    
    var nameKey = "";
    var nameWordCount = 0;
    var surnameKey = "";
    
    public func onTranslatedSuccess(properties: [String : String]?) {
        if let outputProperties = self.passportResponseModel!.passportExtractedModel?.outputProperties {
            let ignoredProperties = getIgnoredProperties(properties: outputProperties)
            var finalProperties : [String: Any] = [:]
            
            for (key, value) in outputProperties {
                if key.contains(IdentificationDocumentCaptureKeys.name) {
                    nameKey = key
                    if let stringValue = value as? String {
                        let trimmedValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        nameWordCount = trimmedValue.isEmpty ? 0 : trimmedValue.split(separator: " ").count
                    } else {
                        nameWordCount = 0
                    }
                }
                
                if key.contains(IdentificationDocumentCaptureKeys.surname) {
                    surnameKey = key
                }
            }
            
            
            for (key, value) in properties! {
                if (key == FullNameKey) {
                    if !nameKey.isEmpty {
                        let selectedWords = getSelectedWords(input: String(describing: value), numberOfWords: nameWordCount)
                        finalProperties[nameKey] = selectedWords
                    }
                    
                    if !surnameKey.isEmpty {
                        let remainingWords = getRemainingWords(input: String(describing: value), numberOfWords: nameWordCount)
                        finalProperties[surnameKey] = remainingWords
                    }
                    
                }else{
                    finalProperties[key] = value
                }
            }
            
            for (key, value) in ignoredProperties {
                finalProperties[key] = value
            }
            
            
            self.passportResponseModel!.passportExtractedModel?.transformedProperties?.removeAll()
            self.passportResponseModel!.passportExtractedModel?.extractedData?.removeAll()
            
            for (key, value) in finalProperties {
                self.passportResponseModel!.passportExtractedModel!.transformedProperties![key] =  "\(value)"
                let newKey = key.components(separatedBy: "IdentificationDocumentCapture_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
                self.passportResponseModel!.passportExtractedModel!.extractedData![newKey] =  "\(value)"
                
            }
            self.scanPassportDelegate?.onComplete(dataModel:self.passportResponseModel! )
        }
        
    }
    
    public func onTranslatedError(properties: [String : String]?) {
        self.scanPassportDelegate?.onComplete(dataModel:self.passportResponseModel! )
    }
    
    public func stopScanning(){
        audioPlayer.stopAudio();
        setTorch(false)
        stopMotion()
        stallTimer?.invalidate()
        stallTimer = nil
        self.previewView.stopSession();
        self.cameraFeedManager.stopSession();
    }
    
    public func takePicture(){
        if(start){
            result = self.modelDataHandler?.runModel(onFrame: self.currentImage!)
            if(hasFaceOrCard()){
                start = false;
                self.scanPassportDelegate?.onSend();
                let dataImage = convertPixelToDataImage(pixelBuffer: self.currentImage!)!
                sendToServer(dataImage, isManualCapture: true)
            }else{
                self.scanPassportDelegate?.onRetry(dataModel:RemoteProcessingModel(
                    destinationEndpoint: HubConnectionTargets.ON_RETRY,
                    response: "",
                    error: "",
                    success: false
                ) )
            }
            
        }
        
    }

    // #############################################################################################
    // #############################################################################################
    //
    //                                  Local Liveness Check
    //
    //   Port of ScanPassport.java (Android). rc17 spec (mobile-handover/02-core-spec):
    //   POSITION -> BASELINE (flat photo) -> LIGHT -> SWEEP (lift the bottom edge) -> verdict. The capture ends on the
    //   tilt (endOnTilt); the photo is the flat, unlit frame of the baseline.
    //   Checks: quality, reflection (enforce), laminate colours (enforce for lb_passport), decide().
    //
    // #############################################################################################
    // #############################################################################################

    /// The passport kind: "lb_passport" (or "lb") -> the Lebanese passport rules; anything else, nil included ->
    /// other_passport. Without a call the default is other_passport.
    public func setDocumentKind(_ kind: String?) {
        let t = kind?.trimmingCharacters(in: .whitespaces).lowercased()
        let k = (t == LivenessConfig.KIND_LB_PASSPORT || t == "lb") ? LivenessConfig.KIND_LB_PASSPORT
                                                                    : LivenessConfig.KIND_OTHER_PASSPORT
        if k != documentKind {                                      // a new document kind: a new visit
            retriesThisVisit = 0
            matteBefore = false
            handPauses = 0
            sunPauses = 0
            brightMiss = false
        }
        documentKind = k
        cfg = nil                                                   // reload on the next frame
    }

    /// Starts the liveness again after a "suspected_copy" / "inconclusive" verdict (the scan stopped and
    /// onLivenessUpdate was sent): call it from the liveness screen's retry button. Safe to call at any time.
    public func retryLiveness() {
        pendingReset = true
        start = true
    }

    /// Loads the config once and copies every threshold into the fields. false: the old capture is used.
    private func ensureConfig() -> Bool {
        if cfg != nil { return true }
        guard let c = try? LivenessConfig.load(kind: documentKind) else {
            log("could not load rectifier_config_file.json for \(documentKind): old capture")
            return false
        }
        cfg = c
        PASSPORT_ASPECT = c.profile.aspect
        RECT_H = LivenessVision.rectHeight(PASSPORT_ASPECT)
        FRAME_MARGIN_PX = c.frameMarginPx; MIN_QUAD_AREA_FRAC = c.minQuadAreaFrac
        FRONTAL_MAX = c.frontalMax; SHAPE_TOL = c.shapeTol
        STABLE_MS = c.stableMs; ANALYSIS_LONG_EDGE = c.analysisLongEdge
        LOSS_MS = c.lossMs; PHASE_TIMEOUT_MS = c.phaseTimeoutMs
        MAX_ATTEMPTS = c.maxAttempts; MAX_RESTARTS = c.maxRestarts; MAX_EARLY_RESTARTS = c.maxEarlyRestarts
        BASELINE_HOLD_MS = c.baselineHoldMs; SHARPNESS_MIN = c.sharpnessMin; GLARE_MAX = c.glareFracMax
        DRIFT_MAX = c.driftMax
        LIGHT_SETTLE_MS = c.light.settleMs; LIGHT_MAX_MS = c.light.maxMs; LIGHT_FRAMES = c.light.frames
        OFF_SETTLE_MS = c.light.offSettleMs; OFF_MAX_MS = c.light.offMaxMs
        BATTERY_LOW = c.batteryLowBelow
        TILT_MIN = c.tiltMinForPage(); SWEEP_FRAMES = c.holdFramesForPage()
        WRONG_WAY_FRAMES = c.wrongWayFrames; STUCK_MS = c.stuckMs; TILT_HOLD_MS = c.tiltHoldMs
        TILT_NOISE_K = c.tiltNoiseK; SAME_PLACE_MAX = c.samePlaceMax; AREA_JUMP_MAX = c.areaJumpMax
        ANGLE_MAX = c.angleMax; TILT_OVERFLOW = c.tiltOverflow; EDGE_MARGIN = c.edgeMargin
        FLAT_DEG = c.hands.flatDeg; FLAT_MS = c.hands.flatMs; MAX_HAND_PAUSES = c.hands.maxPauses
        TABLE_CARD = c.hands.tableCard; TURN_DEG = c.hands.turnDeg
        BRIGHT_LIFT = c.reflection.brightLift; SUN_MAX = Int(c.reflection.sunMax.rounded())
        STALL_MS = c.stallMs
        newTry()
        log("config \(c.policyVersion) profile=\(c.profile.id) aspect=\(PASSPORT_ASPECT) rect=\(LivenessVision.OPT_W)x\(RECT_H) "
            + "tiltMin=\(TILT_MIN) holdFrames=\(SWEEP_FRAMES) laminate=\(c.laminatePolicy()) spread=\(c.profile.spread)")
        return true
    }

    /// The finder model, once. false (model missing): the old capture is used.
    private func loadFinder() -> Bool {
        if finder != nil { return true }
        if finderFailed { return false }
        do {
            finder = try Finder(modelName: ScanPassport.FINDER_MODEL, threads: 2)
            return true
        } catch {
            finderFailed = true
            print("PassportLiveness: finder model could not be loaded: \(error). Old capture.")
            return false
        }
    }

    /// One camera frame in liveness mode.
    private func processLiveness(_ pixelBuffer: CVPixelBuffer) {
        curPixelBuffer = pixelBuffer                                // this frame only (the liveness screen's image)
        defer { curPixelBuffer = nil }
        let accepted = checkDocument(pixelBuffer)
        lastFrameAt = nowMs()                                       // stall watchdog
        pollLight(lastFrameAt)                                      // confirm the light going off
        if start {
            runLiveness(accepted, pixelBuffer)
            if finalReady {                                         // verdict "continue": send the flat, unlit photo
                finalReady = false
                sendFlatPhoto()
            }
        }
        updateLivenessColor()
    }

    /// The liveness passed: the flat, unlit photo of the baseline goes to the server (the done tick was played).
    private func sendFlatPhoto() {
        guard let photo = flatPhoto else { return }
        start = false
        DispatchQueue.main.async { self.scanPassportDelegate?.onSend() }
        sendToServer(photo, isManualCapture: false)
    }

    // =============================================================================================
    // The passport in this frame (finder head "passport_page")
    // =============================================================================================

    /// Detects the photo page AND runs the Position check. lastQuad != nil: found in this frame;
    /// true: found in consecutive frames for >= stableMs (Position passed).
    private func checkDocument(_ pb: CVPixelBuffer) -> Bool {
        let now = nowMs()
        lastUpright = nil; lastQuad = nil; lastPixelQuad = nil; lastPose = nil; lastFlat = false
        lastRawPose = nil; lastRawQuad = nil; lastIsRaw = false; lastSharp = false

        // the analysis frame (ANA), upright: sensor buffers are landscape, the phone is held in portrait
        let landscape = CVPixelBufferGetWidth(pb) > CVPixelBufferGetHeight(pb)
        guard let upright = LivenessVision.analysisFrame(pb, longEdge: ANALYSIS_LONG_EDGE, rotateClockwise: landscape),
              let finder = finder else { return false }
        let w = Double(upright.width), h = Double(upright.height)

        guard let r = try? finder.detect(upright, head: .passportPage), r.found, let model = r.corners else {
            positionMiss()
            noOutline("finder found no page")
            return false
        }
        let inferred = r.inferredCorner != nil

        // ---- SWEEP: track the RAW finder outline (SpreadFix / stabilizer drop tilted frames) ----
        if phase == .sweep {
            useRawFrame(model, upright, w, h, inferred)
            return false
        }

        // the photo page: lb_passport always cut from the open booklet; other_passport only when booklet-shaped
        guard let raw = photoPageOf(model),
              Geometry.isValidQuad(raw, w: w, h: h, frameMarginPx: FRAME_MARGIN_PX, minQuadAreaFrac: MIN_QUAD_AREA_FRAC) else {
            positionMiss()
            noOutline("no photo page / outline outside the picture / too small")
            return false
        }
        let rp = Geometry.poseOf(raw)
        let rightShape = rp.aspect >= 0.6 * PASSPORT_ASPECT && rp.aspect <= 1.6 * PASSPORT_ASPECT
        let notSkewed = abs(rp.lr) <= 0.45 && abs(rp.tb) <= 0.45
        if !rightShape || !notSkewed {
            positionMiss()
            noOutline(String(format: "bad shape aspect=%.2f (page %.2f) lr=%.3f tb=%.3f", rp.aspect, PASSPORT_ASPECT, rp.lr, rp.tb))
            return false
        }
        let s = stab.update(raw, w: w, h: h, inferred: inferred)
        guard let steadied = s.quad, s.status == "accepted" || s.status == "moved", s.poseReliable else {
            positionMiss()
            noOutline("stabiliser \(s.status)\(s.poseReliable ? "" : " (pose unreliable)")")
            return false
        }

        // normal orientation only (not upside down, not MRZ left / right), in Position
        if phase == .position && !isNormalOrientation(upright, steadied) {
            positionMiss()
            noOutline("orientation: \(orientWhy)")
            return false
        }

        // ---- found in this frame ----
        lastRawPose = Geometry.poseOf(model)
        lastRawQuad = model
        lastUpright = upright
        lastQuad = steadied                                         // steadied PHOTO page (pose)
        lastPixelQuad = raw                                         // unsmoothed PHOTO page (pixel checks)
        lastPose = Geometry.poseOf(steadied)
        lastFlat = Geometry.looksRight(steadied, docAspect: PASSPORT_ASPECT, frontalMax: FRONTAL_MAX, shapeTol: SHAPE_TOL)
        let q = LivenessVision.quality(upright, raw)
        lastSharpness = q.0
        lastGlareFrac = q.1
        lastSharp = lastSharpness >= SHARPNESS_MIN

        positionMisses = 0
        if steadySince == 0 { steadySince = now }
        return now - steadySince >= STABLE_MS
    }

    /// A bad frame in Position: the steady clock restarts only on the second bad frame in a row.
    private func positionMiss() {
        positionMisses += 1
        if positionMisses >= 2 { steadySince = 0 }
    }

    private func noOutline(_ why: String) {
        if phase == .position || phase == .baseline || phase == .light { log("no outline (\(phase)): \(why)") }
    }

    /// Raw finder outline for this frame (SWEEP). Rejects guessed corners and broken outlines.
    private func useRawFrame(_ model: [Double], _ upright: LivenessImage, _ w: Double, _ h: Double, _ inferred: Bool) {
        if inferred { return }                                      // a guessed corner (finger on the edge) fakes a tilt
        if !Geometry.isValidQuad(model, w: w, h: h, frameMarginPx: FRAME_MARGIN_PX, minQuadAreaFrac: MIN_QUAD_AREA_FRAC,
                                 outside: TILT_OVERFLOW) { return }
        let p = Geometry.poseOf(model)
        if abs(p.lr) > ScanPassport.RAW_LR_MAX || abs(p.tb) > ScanPassport.RAW_TB_MAX || (p.lr == 0 && p.tb == 0) { return }
        lastUpright = upright
        lastQuad = model
        lastPose = p
        lastRawPose = p
        lastRawQuad = model
        lastIsRaw = true
        lastPixelQuad = p.aspect >= ScanPassport.RAW_PAGE_ASPECT_MIN ? model : SpreadFix.photoPage(model, pageAspect: PASSPORT_ASPECT)
    }

    /// The photo page from the finder's outline (lb_passport: SpreadFix always; other_passport: when booklet-shaped).
    private func photoPageOf(_ model: [Double]) -> [Double]? {
        if isSpread() { return SpreadFix.photoPage(model, pageAspect: PASSPORT_ASPECT) }
        return Geometry.poseOf(model).aspect >= ScanPassport.RAW_PAGE_ASPECT_MIN
            ? model : SpreadFix.photoPage(model, pageAspect: PASSPORT_ASPECT)
    }

    private func isSpread() -> Bool { cfg?.profile.spread ?? false }

    /// Angle of the outline's bottom edge (BL -> BR).
    private static func bottomAngle(_ q: [Double]) -> Double {
        guard let o = orderCorners(q) else { return .nan }
        return atan2(o[5] - o[7], o[4] - o[6])
    }

    /// Reorders 4 corners as TL, TR, BR, BL using image position. nil if ambiguous.
    private static func orderCorners(_ q: [Double]) -> [Double]? {
        var tl = 0, tr = 0, br = 0, bl = 0
        var minSum = Double.greatestFiniteMagnitude, maxSum = -Double.greatestFiniteMagnitude
        var minDiff = Double.greatestFiniteMagnitude, maxDiff = -Double.greatestFiniteMagnitude
        for i in 0..<4 {
            let x = q[2 * i], y = q[2 * i + 1]
            let sum = x + y, diff = x - y
            if sum < minSum { minSum = sum; tl = i }
            if sum > maxSum { maxSum = sum; br = i }
            if diff > maxDiff { maxDiff = diff; tr = i }
            if diff < minDiff { minDiff = diff; bl = i }
        }
        if Set([tl, tr, br, bl]).count < 4 { return nil }
        return [q[2 * tl], q[2 * tl + 1], q[2 * tr], q[2 * tr + 1], q[2 * br], q[2 * br + 1], q[2 * bl], q[2 * bl + 1]]
    }

    private static func dist(_ o: [Double], _ a: Int, _ b: Int) -> Double {
        hypot(o[2 * a] - o[2 * b], o[2 * a + 1] - o[2 * b + 1])
    }

    /// True only if the photo page is landscape, roughly level, and the MRZ is at the bottom.
    private func isNormalOrientation(_ upright: LivenessImage, _ quad: [Double]) -> Bool {
        guard let o = ScanPassport.orderCorners(quad) else { orientWhy = "corners ambiguous"; return false }
        let top = ScanPassport.dist(o, 0, 1), right = ScanPassport.dist(o, 1, 2)
        let bottom = ScanPassport.dist(o, 2, 3), left = ScanPassport.dist(o, 3, 0)
        if left + right >= top + bottom { orientWhy = "page not landscape (MRZ left / right?)"; return false }
        let roll = atan2(o[3] - o[1], o[2] - o[0]) * 180 / Double.pi
        if abs(roll) > ScanPassport.MAX_ROLL_DEG { orientWhy = String(format: "page rotated %.0f deg", roll); return false }
        let mrz = ScanPassport.mrzScores(upright, o)
        let ok = mrz.1 >= ScanPassport.MRZ_MIN && mrz.1 >= mrz.0 * ScanPassport.MRZ_MARGIN
        if !ok { orientWhy = String(format: "MRZ not found at the bottom (bottom=%.3f top=%.3f)", mrz.1, mrz.0) }
        return ok
    }

    /// Straightens the page and measures how "MRZ-like" the top and bottom 25% strips are: (topBand, bottomBand).
    private static func mrzScores(_ img: LivenessImage, _ o: [Double]) -> (Double, Double) {
        let W = WARP_W, H = WARP_H
        let rect: [Double] = [0, 0, Double(W), 0, Double(W), Double(H), 0, Double(H)]
        guard let hm = LivenessVision.homography(rect, o) else { return (0, 0) }
        let bw = img.width, bh = img.height
        var gray = [Int](repeating: 0, count: W * H)
        for v in 0..<H {
            for u in 0..<W {
                let d = hm[6] * Double(u) + hm[7] * Double(v) + hm[8]
                let x = LivenessVision.clamp(LivenessVision.toInt(jsRound((hm[0] * Double(u) + hm[1] * Double(v) + hm[2]) / d)), 0, bw - 1)
                let y = LivenessVision.clamp(LivenessVision.toInt(jsRound((hm[3] * Double(u) + hm[4] * Double(v) + hm[5]) / d)), 0, bh - 1)
                let p = img.pixels[y * bw + x]
                gray[v * W + u] = (Int((p >> 16) & 255) * 77 + Int((p >> 8) & 255) * 150 + Int(p & 255) * 29) >> 8
            }
        }
        let band = Int(Double(H) * 0.25)
        return (longRowShare(gray, 0, band), longRowShare(gray, H - band, H))
    }

    /// Share of rows in [y0, y1) where text runs across >= 60% of the width (MRZ lines span the page).
    private static func longRowShare(_ g: [Int], _ y0: Int, _ y1: Int) -> Double {
        let cells = WARP_W / CELL
        var longRows = 0
        for y in y0..<y1 {
            let base = y * WARP_W
            var filled = 0
            for c in 0..<cells {
                let xs = c * CELL, xe = min(xs + CELL, WARP_W - 1)
                var x = xs
                while x < xe {
                    if abs(g[base + x + 1] - g[base + x]) >= EDGE_MIN { filled += 1; break }
                    x += 1
                }
            }
            if Double(filled) >= MRZ_ROW_FILL * Double(cells) { longRows += 1 }
        }
        return Double(longRows) / Double(y1 - y0)
    }

    /// This frame's photo page straightened to 480 x H with the baseline's corner roll.
    private func rectifyNow() -> [UInt32]? {
        guard let pq = lastPixelQuad, let up = lastUpright, let o = ScanPassport.orderCorners(pq) else { return nil }
        return LivenessVision.rectify(up, LivenessVision.roll(o, baseK), LivenessVision.OPT_W, RECT_H)
    }

    // =============================================================================================
    // Phases
    // =============================================================================================

    /// Green when the current frame is good for the liveness step, the "hold" colour otherwise; hidden in the tilt.
    private func updateLivenessColor() {
         guard environmentalConditions!.enableGuide else { return }
         let color = livenessFrameGood ? ConstantsValues.DetectColor : environmentalConditions!.HoldHandColor
         let inTilt = tiltStart
         let notTransmitting = start
         DispatchQueue.main.async {
             if inTilt {                                             // tilt: no guide on screen
                 self.guide.cardSvgImageView?.removeFromSuperview()
                 self.guide.cardSvgImageView = nil
                 return
             }
             if self.guide.cardSvgImageView == nil {                 // back after the tilt / a reset
                 self.guide.showCardGuide(view: self.view, forResource: "passport_background")
             }
             self.guide.changeCardColor(view: self.view, to: color, notTransmitting: notTransmitting)
         }
     }

    /// The tilt drawing (Guide): kept so it can be removed from the screen when the tilt ends.
    private func showTiltLayout() {
        tiltStart = true
        DispatchQueue.main.async {
            self.tiltLayoutView?.removeFromSuperview()              // never two on screen
            do {
                self.tiltLayoutView = try self.guide.showLbTiltPassportLayout(view: self.view)
            } catch {
                self.tiltLayoutView = nil                           // no drawing: the text and the meter still guide
                print("PassportLiveness: tilt drawing not shown: \(error)")
            }
        }
    }

    private func hideTiltLayout() {
        tiltStart = false
        DispatchQueue.main.async {
            self.tiltLayoutView?.removeFromSuperview()
            self.tiltLayoutView = nil
        }
    }

    /// Once per frame (only while start == true). Runs the current phase.
    private func runLiveness(_ accepted: Bool, _ pb: CVPixelBuffer) {
        let now = nowMs()
        if phase == .done { return }

        if let p = pause {                                          // a pause is shown: frames are dropped
            if !pauseDone(now) { hint(p); return }
            pause = nil
            markTurn()
            flatSince = 0
            hint(.placeDocument)
        }
        if notInHand(now) { return }

        if lastQuad != nil { lastSeen = now }
        if lastQuad == nil && lastSeen > 0 && now - lastSeen > LOSS_MS { livenessFrameGood = false }

        let watchedLoss = phase == .baseline || phase == .light
        let watchedTime = watchedLoss || phase == .sweep
        if phase == .sweep && now - lastSeen > LOSS_MS { hint(.placeDocument) }
        let lossGrace = phase == .light ? Int(Double(LOSS_MS) * ScanPassport.LIGHT_LOSS_FACTOR) : LOSS_MS
        if watchedLoss && lastSeen > 0 && now - lastSeen > lossGrace {
            restartTry("tracking_lost", now)
            return
        }
        if watchedTime && now - phaseStart > PHASE_TIMEOUT_MS {
            if phase == .sweep && reachedAt != 0 {                  // the tilt was reached: judge what we have
                // device log: a fake held open for the colours hit the 15 s limit and got a free restart instead of
                // a verdict (laminate absent). Once the tilt is reached there is enough to decide.
                log("timeout while held open for the colours: deciding now")
                finishTry(engineFailed: false)
                return
            }
            engineAttempts += 1
            if engineAttempts >= MAX_ATTEMPTS {
                tryReasons.append("attempts_exhausted")
                finishTry(engineFailed: true)
                return
            }
            restartTry("timeout", now)
            return
        }

        switch phase {
        case .position:
            hint(.placeDocument)
            if lastQuad != nil { livenessFrameGood = true }
            if accepted && photoReady(now) {
                enterPhase(.baseline, now)
                playSuccess()                                       // seen and steady: the flat hold starts
            }
        case .baseline:
            if checkBaseline(now) {
                flatPhoto = convertPixelToDataImage(pixelBuffer: pb)   // THE photo: flat, unlit, full camera size
                unlitImg = nil                                      // next frame = the unlit reference
                enterPhase(.light, now)
                hint(.doNotMove)
            }
        case .light:
            checkLight(now)
        case .sweep:
            checkSweep(now)
        case .done:
            break
        }
    }

    private func enterPhase(_ p: Phase, _ now: Int) {
        phase = p
        phaseStart = now
        if p != .sweep && p != .done { setProgress(0) }
    }

    /// The light is confirmed off and the picture had offSettleMs to settle.
    private func photoReady(_ now: Int) -> Bool { lightState == .off && now - darkAt >= OFF_SETTLE_MS }

    private func lightOff(_ now: Int) {
        if lightState == .off { return }
        if lightState == .on { offAskedAt = now }
        lightState = .goingOff
        offLastAskAt = now
        setTorch(false)
    }

    /// Every frame: the camera must report the light off; re-asked every 250 ms, for light.offMaxMs at most.
    private func pollLight(_ now: Int) {
        if lightState != .goingOff { return }
        if !isTorchOn() || now - offAskedAt >= OFF_MAX_MS {
            lightState = .off
            darkAt = now
            return
        }
        if now - offLastAskAt >= ScanPassport.OFF_REASK_MS {
            offLastAskAt = now
            setTorch(false)
        }
    }

    // ---- baseline: frontal, sharp, steady, no glare for baselineHoldMs and >= 3 poses -> flat photo ----

    private func checkBaseline(_ now: Int) -> Bool {
        guard let q = lastQuad, let pose = lastPose, let up = lastUpright, !lastIsRaw else {
            havePrev = false
            holdMiss()
            return false
        }
        let lr = pose.lr, tb = pose.tb
        let cx = (q[0] + q[2] + q[4] + q[6]) / 4, cy = (q[1] + q[3] + q[5] + q[7]) / 4
        let fw = Double(up.width)
        let centreStill = havePrev && hypot(cx - prevCx, cy - prevCy) < DRIFT_MAX * fw
        let tol = ScanPassport.HOLD_STILL_TOL
        let poseStill = baseCount == 0
            ? havePrev && abs(lr - prevLr) < tol && abs(tb - prevTb) < tol
            : abs(lr - holdLr) <= tol && abs(tb - holdTb) <= tol
        let steady = centreStill && poseStill
        prevLr = lr; prevTb = tb; prevCx = cx; prevCy = cy; havePrev = true

        let frontal = abs(lr) <= ScanPassport.HOLD_FRONTAL_MAX && abs(tb) <= ScanPassport.HOLD_FRONTAL_MAX
        let glare = lastGlareFrac > ScanPassport.HOLD_GLARE_MAX
        hint(!frontal ? .keepFlat : glare ? .adjustPosition : .keepSteady)
        log(String(format: "baseline lr=%.3f tb=%.3f steady=%d hold=%d sharp=%.1f(%d) glare=%.3f(%d) frontal=%d",
                   lr, tb, steady ? 1 : 0, baseCount, lastSharpness, lastSharp ? 1 : 0, lastGlareFrac, glare ? 1 : 0, frontal ? 1 : 0))

        if !steady || !lastSharp || !frontal || glare || !photoReady(now) {
            holdMiss()
            return false
        }
        livenessFrameGood = true
        holdGraceUsed = false
        if baseHoldSince == 0 {
            baseHoldSince = now
            holdLr = lr
            holdTb = tb
        }
        baseCount += 1
        if let rp = lastRawPose {
            if rp.aspect >= ScanPassport.RAW_PAGE_ASPECT_MIN { baselineRawTbPage.append(rp.tb) }
            else { baselineRawTbSpread.append(rp.tb) }
        }
        if let rq = lastRawQuad {
            let a = ScanPassport.bottomAngle(rq)
            if !a.isNaN { baselineAngles.append(a) }
        }
        if now - baseHoldSince >= BASELINE_HOLD_MS && baseCount >= ScanPassport.BASELINE_MIN_POSES {
            baseAngle = baselineAngles.isEmpty ? .nan : ScanPassport.median(baselineAngles)
            // the hand's shake, robust to a jumped outline (MAD), and never more than 2 x tiltMin (device log: one jumped
            // outline gave std 0.117 -> need 0.352, a tilt nobody could reach)
            let noise = max(ScanPassport.robustStd(baselineRawTbPage), ScanPassport.robustStd(baselineRawTbSpread))
            tiltMinEffective = min(max(TILT_MIN, TILT_NOISE_K * noise), ScanPassport.TILT_NEED_MAX_FACTOR * TILT_MIN)
            return true
        }
        return false
    }

    /// A bad frame in the flat hold: the first one is passed over, the second restarts it.
    private func holdMiss() {
        if baseCount > 0 && !holdGraceUsed { holdGraceUsed = true; return }
        resetBaselineHold()
    }

    private func resetBaselineHold() {
        holdGraceUsed = false
        baseCount = 0
        baseHoldSince = 0
        baselineRawTbPage.removeAll()
        baselineRawTbSpread.removeAll()
        baselineAngles.removeAll()
    }

    // ---- light: unlit reference, lit frames (reflection), then the lit reference for the tilt ----

    private func checkLight(_ now: Int) {
        guard let c = cfg else { return }
        hint(.doNotMove)

        // 1) unlit reference + light request
        if unlitImg == nil {
            guard let pq = lastPixelQuad, let up = lastUpright, let o = ScanPassport.orderCorners(pq),
                  let b = LivenessVision.makeBaseline(up, o, RECT_H) else { return }
            baseK = b.k
            unlitImg = b.img
            lightRequestedAt = now                                  // settle is counted from the REQUEST
            lightAvailable = setTorch(true)
            if lightAvailable { lightState = .on }
            log("light: unlit reference k=\(baseK) torch=\(lightAvailable)")
            return
        }

        // the torch must really come on, else the step settles at once
        if lightAvailable && !isTorchOn() && now - lightRequestedAt > ScanPassport.TORCH_CONFIRM_MS {
            lightAvailable = false
            lightOff(now)
        }
        if !lightAvailable {
            litImg = unlitImg                                       // no light: the unlit frame stays the reference
            iridBase = LivenessVision.iridBase(litImg!, LivenessVision.OPT_W, RECT_H)
            baseRawTbPage = ScanPassport.rawReference(lightRawTbPage, baselineRawTbPage)
            baseRawTbSpread = ScanPassport.rawReference(lightRawTbSpread, baselineRawTbSpread)
            goToSweep(now)
            return
        }

        let waited = now - lightRequestedAt
        if !lightEnded {
            if waited >= LIGHT_SETTLE_MS && lastPixelQuad != nil, let cur = rectifyNow(), let unlit = unlitImg {
                let sample = LivenessVision.pageResponse(unlit, cur, LivenessVision.OPT_W, RECT_H)
                reflection?.addLit(sample)
                lightSharp += 1
                livenessFrameGood = true
                if let rp = lastRawPose {
                    if rp.aspect >= ScanPassport.RAW_PAGE_ASPECT_MIN { lightRawTbPage.append(rp.tb) }
                    else { lightRawTbSpread.append(rp.tb) }
                }
                if let s = sample {
                    log(String(format: "light frame spec=%.4f chroma=%.4f flare=%.5f veil=%.3f", s[0], s[1], s[2], s[3]))
                }
            }
            let whitedOut = (reflection?.usable() ?? 0) < c.reflection.minLitFrames
            if (lightSharp >= LIGHT_FRAMES && !whitedOut) || waited > LIGHT_MAX_MS {
                lightEnded = true                                   // the next frame = the lit reference
                _ = tooBright(now)                                  // the sun check, before the tilt
            }
            return
        }

        // 4) lit reference for the tilt
        if pause != nil || phase != .light { return }               // the sun pause restarted the try
        guard let lit = rectifyNow() else { return }
        litImg = lit
        iridBase = LivenessVision.iridBase(lit, LivenessVision.OPT_W, RECT_H)
        baseRawTbPage = ScanPassport.rawReference(lightRawTbPage, baselineRawTbPage)
        baseRawTbSpread = ScanPassport.rawReference(lightRawTbSpread, baselineRawTbSpread)
        log(String(format: "light done: lit=%d usable=%d rawBase page=%.3f spread=%.3f tiltMin=%.3f",
                   lightSharp, reflection?.usable() ?? 0, baseRawTbPage, baseRawTbSpread, tiltMinEffective))
        goToSweep(now)
    }

    /// The sun check at the end of the light step: the page did not answer the light, or the last try missed with the
    /// light barely reaching it. Light off, TOO_BRIGHT pause, the try starts over. At most reflection.sunMax times.
    private func tooBright(_ now: Int) -> Bool {
        guard let c = cfg, let refl = reflection else { return false }
        if sunPauses >= SUN_MAX || !lightAvailable || isBatteryTooLow() { return false }
        let r = refl.result()
        let lift = r.litLift ?? 9
        let brightAgain = brightMiss && lift <= BRIGHT_LIFT
        if c.reflection.policy != "enforce" || !(r.state == "emissive" || brightAgain) { return false }
        sunPauses += 1
        brightMiss = false
        log("sun pause: \(brightAgain ? "bright_miss" : "no_response") lift=\(String(describing: r.litLift))")
        startPause(.tooBright, "too_bright", now)
        return true
    }

    private static func rawReference(_ light: [Double], _ baseline: [Double]) -> Double {
        if light.count >= 2 { return median(light) }
        if !baseline.isEmpty { return median(baseline) }
        return .nan
    }

    /// A spread that ignores outliers: 1.4826 x the median absolute deviation (= the std for normal noise).
    private static func robustStd(_ v: [Double]) -> Double {
        if v.count < 2 { return 0 }
        let m = median(v)
        return 1.4826 * median(v.map { abs($0 - m) })
    }

    private static func popStd(_ v: [Double]) -> Double {
        if v.count < 2 { return 0 }
        let m = v.reduce(0, +) / Double(v.count)
        return sqrt(v.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(v.count))
    }

    private static func median(_ values: [Double]) -> Double {
        let v = values.sorted()
        let n = v.count
        return n % 2 == 1 ? v[n / 2] : (v[n / 2 - 1] + v[n / 2]) / 2
    }

    // ---- sweep: lift the bottom edge (torch on); laminate colours per frame; held open up to tiltHoldMs ----

    private func goToSweep(_ now: Int) {
        resetSweep()
        markTurn()                                                  // the phone's own turn is counted from here
        lastMoveAt = now
        enterPhase(.sweep, now)
        showTiltLayout()
        hint(.liftBottom)
    }

    private func checkSweep(_ now: Int) {
        guard let c = cfg, let pose = lastPose, lastQuad != nil else { return }   // not in view: keep waiting

        if !isSameDocument(now) {                                   // anti-swap after a loss
            log("sweep: different document/place after loss -> restart")
            restartTry("continuity_lost", now)
            return
        }

        // laminate colours of this frame against the LIT flat reference
        if litImg != nil, let cur = rectifyNow(),
           let irid = LivenessVision.iridescence(iridBase, LivenessVision.chromaGrid(cur, LivenessVision.OPT_W, RECT_H)) {
            iridTilt.append(irid)
        }

        // tilt: compare page with page, booklet with booklet
        let pageShape = pose.aspect >= ScanPassport.RAW_PAGE_ASPECT_MIN
        let base = pageShape ? baseRawTbPage : baseRawTbSpread
        if base.isNaN { return }
        let tb = pose.tb
        let need = tiltMinEffective
        var d = ScanPassport.BOTTOM_LIFT_SIGN * (tb - base)         // + = bottom edge lifted toward the camera
        // the light-step reference can be off (a jumped outline): if "flat" is never seen but the page is held still
        // from the start of the tilt for ~1 s, that still position IS flat -> re-anchor on it (start of the tilt only)
        if !sweepSawFlat {
            sweepStill = abs(d - prevDelta) <= ScanPassport.MOVE_EPS ? sweepStill + 1 : 0
            let sinceAsked = now - phaseStart
            if sweepStill >= ScanPassport.REANCHOR_FRAMES
                && sinceAsked >= ScanPassport.REANCHOR_FROM_MS && sinceAsked <= ScanPassport.REANCHOR_UNTIL_MS {
                if pageShape { baseRawTbPage = tb } else { baseRawTbSpread = tb }
                sweepFromPage = .nan; sweepFromSpread = .nan
                log(String(format: "sweep: reference re-anchored %.3f -> %.3f (held still, never flat)", base, tb))
                d = 0
            }
        }
        if abs(d) <= ScanPassport.SWEEP_FLAT_EPS { sweepSawFlat = true }
        if abs(d - prevDelta) > ScanPassport.MOVE_EPS { lastMoveAt = now }
        prevDelta = d
        sweepMoved = max(sweepMoved, abs(d))

        // angleMax: a tilt with an in-plane turn of the page does not count
        var turned = false
        if let rq = lastRawQuad, !baseAngle.isNaN {
            let a = ScanPassport.bottomAngle(rq)
            if !a.isNaN { let t = a - baseAngle; turned = abs(atan2(sin(t), cos(t))) > ANGLE_MAX }
        }

        // the wrong edge: judged from where the page was when the tilt was asked
        if pageShape && sweepFromPage.isNaN { sweepFromPage = tb }
        if !pageShape && sweepFromSpread.isNaN { sweepFromSpread = tb }
        let from = pageShape ? sweepFromPage : sweepFromSpread
        sweepWrong = ScanPassport.BOTTOM_LIFT_SIGN * (tb - from) <= -need ? sweepWrong + 1 : 0

        let hit = !turned && d >= need && sweepSawFlat
        sweepGood = hit ? sweepGood + 1 : 0
        if hit { livenessFrameGood = true }
        if sweepGood >= SWEEP_FRAMES && reachedAt == 0 { reachedAt = now }

        let lam = LivenessGate.iridescenceResult(iridTilt, c.laminate)
        log(String(format: "sweep tb=%.3f base=%.3f toward=%.3f need=%.3f turned=%d good=%d | colours frames=%d lit=%d hues=%d peak=%.4f strong=%d",
                   tb, base, d, need, turned ? 1 : 0, sweepGood, lam.frames, lam.litFrames, lam.hues, lam.peakOr0, lam.strong ? 1 : 0))

        // tilt meter (capture.ts:331, passports): clamp(toward / (1.4 x need), 0, 1)
        let meter = sweepSawFlat ? max(0, min(1, d / (1.4 * need))) : 0
        setProgress(Int((100 * meter).rounded()))

        if reachedAt != 0 {
            // held open while the laminate colours DECIDE (lb_passport) and are not strong yet (tiltHoldMs)
            let coloursDecide = (lightAvailable ? c.laminatePolicy() : "shadow") == "enforce"
            let awaiting = c.profile.iridescent && coloursDecide && !lam.strong
            if awaiting && now - reachedAt < TILT_HOLD_MS {
                livenessFrameGood = true
                hint(atEdge() ? .holdThere : .moveALittleMore)
                return
            }
            playSuccess()                                           // the tilt is done
            finishTry(engineFailed: false)                          // endOnTilt
            return
        }

        if sweepWrong >= WRONG_WAY_FRAMES { hint(.otherSide) }
        else if now - phaseStart > STUCK_MS && sweepMoved < need / 2 { hint(.holdItUp) }
        else if d >= need && !sweepSawFlat { hint(.keepFlat) }
        else { hint(.liftBottom) }
    }

    /// A corner of the outline within edgeMargin of the picture's edge.
    private func atEdge() -> Bool {
        guard let q = lastQuad, let up = lastUpright else { return false }
        let w = Double(up.width), h = Double(up.height)
        for i in 0..<4 {
            let x = q[2 * i], y = q[2 * i + 1]
            if x < EDGE_MARGIN * w || x > (1 - EDGE_MARGIN) * w || y < EDGE_MARGIN * h || y > (1 - EDGE_MARGIN) * h { return true }
        }
        return false
    }

    /// Same document as before a loss? Compares the bottom edge (middle point + length) of the outline.
    private func isSameDocument(_ now: Int) -> Bool {
        guard let q = lastQuad, let up = lastUpright, let o = ScanPassport.orderCorners(q) else { return true }
        let fw = Double(up.width), fh = Double(up.height)
        let bx = (o[4] + o[6]) / 2 / fw, by = (o[5] + o[7]) / 2 / fh
        let len = ScanPassport.dist(o, 2, 3) / fw
        var same = true
        if sweepRefSet && now - sweepLastSeenAt > LOSS_MS {
            let maxLen = sqrt(AREA_JUMP_MAX)
            let ratio = len / max(sweepRefLen, 1e-6)
            same = hypot(bx - sweepRefX, by - sweepRefY) <= SAME_PLACE_MAX && ratio <= maxLen && ratio >= 1 / maxLen
        }
        sweepRefX = bx; sweepRefY = by; sweepRefLen = len
        sweepRefSet = true
        sweepLastSeenAt = now
        return same
    }

    private func resetSweep() {
        sweepGood = 0; sweepWrong = 0
        sweepSawFlat = false
        sweepStill = 0
        sweepRefSet = false
        sweepLastSeenAt = 0
        prevDelta = 0
        lastMoveAt = 0
        reachedAt = 0
        sweepFromPage = .nan; sweepFromSpread = .nan
        sweepMoved = 0
        iridTilt.removeAll()
        shownInstruction = nil
    }

    // =============================================================================================
    // Verdict (gate-policy.md)
    // =============================================================================================

    private func finishTry(engineFailed: Bool) {
        guard let c = cfg else { return }
        let now = nowMs()
        lightOff(now)
        hideTiltLayout()
        phase = .done

        // laminate + the passport rule (capture.ts:1589)
        let lam = LivenessGate.iridescenceResult(iridTilt, c.laminate)
        var laminate = lam.state
        if c.profile.page && c.laminate.passportStrong && laminate == "present"
            && (lam.hues < c.laminate.passportHues || lam.peakOr0 < c.laminate.strongPeak) {
            laminate = "absent"
        }
        let refl = (reflection ?? LivenessGate.ReflectionAnalyzer(c.reflection)).result()
        let batteryLow = isBatteryTooLow()

        let i = LivenessGate.GateInput()
        i.cameraOk = true
        i.enginePhase = engineFailed ? "failed" : "done"
        i.attempt = engineAttempts + retriesThisVisit
        i.challenge = engineFailed ? "not_observed" : "observed"
        i.optical = "not_configured"
        i.opticalPolicy = "shadow"
        i.reflection = refl.state
        i.reflectionPolicy = c.reflection.policy
        i.matteBefore = matteBefore
        i.lightAvailable = lightAvailable
        i.laminate = laminate
        i.laminatePolicy = lightAvailable ? c.laminatePolicy() : "shadow"
        i.laminateStrong = lam.strong
        i.laminateRequired = c.profile.iridescent
        i.matteNotEvidence = c.profile.page
        i.batteryLow = batteryLow
        i.photoOk = engineFailed ? nil : flatPhoto != nil

        let decision = LivenessGate.decide(i, maxAttempts: MAX_ATTEMPTS)
        let reasons = decision.reasons + tryReasons + flags
        print(String(format: "PassportLiveness: VERDICT %@ %@ | reflection=%@ (lit=%d flare=%@ lift=%@) laminate=%@ (frames=%d lit=%d hues=%d peak=%.4f strong=%d) attempt=%d",
                     decision.verdict, reasons.description, refl.state, refl.usable,
                     String(describing: refl.litFlare), String(describing: refl.litLift),
                     laminate, lam.frames, lam.litFrames, lam.hues, lam.peakOr0, lam.strong ? 1 : 0, i.attempt))

        // two misses in a row: a "_first" reason sets it; the neutral reasons keep it; else cleared
        let first = decision.reasons.contains { $0.hasSuffix("_first") }
        let neutral = decision.reasons.contains {
            $0 == "emblem_untested" || $0 == "no_response_to_light" || $0 == "reflection_matte_unproven"
        }
        matteBefore = first || (matteBefore && neutral)
        let lift = refl.litLift ?? 9
        brightMiss = decision.verdict == LivenessGate.RETRY && lift <= BRIGHT_LIFT && c.profile.page
        if decision.verdict != LivenessGate.CONTINUE { livenessFrameGood = false }

        switch decision.verdict {
        case LivenessGate.CONTINUE:
            setProgress(100)
            hint(.keepHolding)
            finalReady = true                                       // processLiveness sends the flat photo
        case LivenessGate.RETRY:
            retriesThisVisit += 1
            newTry()                                                // the camera keeps running: start again
        default:                                                    // suspected_copy / inconclusive
            start = false
            notifyLivenessFailed()
        }
    }

    /// suspected_copy / inconclusive / the camera stalled: the liveness screen (onLivenessUpdate). No server response.
    /// image: the passport as the camera saw it, the flat photo if the try got that far, else this frame (made now, on
    /// the camera thread, before the camera reuses its buffer; nil on a stall with no photo).
    private func notifyLivenessFailed() {
        let image = LivenessScreenImage.make(photo: flatPhoto, frame: curPixelBuffer)
        DispatchQueue.main.async {
            self.scanPassportDelegate?.onLivenessUpdate?(dataModel: RemoteProcessingModel(
                destinationEndpoint: HubConnectionTargets.ON_LIVENESS_UPDATE,
                response: "",
                error: EventsErrorMessages.OnLivenessCardUpdateMessage,
                success: false
            ), image: image)
        }
    }

    // =============================================================================================
    // Restarts and tries
    // =============================================================================================

    private func restartTry(_ reason: String, _ now: Int) {
        tryReasons.append(reason)
        let early = phase == .position || phase == .baseline || phase == .light
        if early { earlyRestarts += 1 } else { restarts += 1 }
        if restarts > MAX_RESTARTS || earlyRestarts > MAX_EARLY_RESTARTS {
            tryReasons.append("restarts_exhausted")
            finishTry(engineFailed: true)
            return
        }
        log("restart: \(reason) (early=\(earlyRestarts) late=\(restarts))")
        clearReadings(now)
    }

    private func newTry() {
        engineAttempts = 0; restarts = 0; earlyRestarts = 0
        tryReasons.removeAll()
        flags.removeAll()
        pause = nil
        flatSince = 0
        clearReadings(nowMs())
    }

    private func clearReadings(_ now: Int) {
        lightOff(now)
        livenessFrameGood = false
        steadySince = 0
        positionMisses = 0
        lastSeen = 0
        if tiltStart { hideTiltLayout() }
        havePrev = false
        resetBaselineHold()
        baseAngle = .nan
        flatPhoto = nil
        finalReady = false
        unlitImg = nil; litImg = nil; iridBase = nil
        baseK = 0
        lightAvailable = false; lightEnded = false
        lightRequestedAt = 0
        lightSharp = 0
        lightRawTbPage.removeAll(); lightRawTbSpread.removeAll()
        baseRawTbPage = .nan; baseRawTbSpread = .nan
        tiltMinEffective = TILT_MIN
        reflection = cfg.map { LivenessGate.ReflectionAnalyzer($0.reflection) }
        resetSweep()
        shownInstruction = nil
        stab = OutlineStabilizer(docAspect: PASSPORT_ASPECT)
        enterPhase(.position, now)
    }

    private func resetLiveness() {
        if cfg != nil { newTry() }
    }

    /// Sends the instruction + the tilt progress to the app, only when one of them changes.
    private func hint(_ instruction: PassportLivenessInstruction) {
        if instruction == shownInstruction && livenessProgress == shownProgress { return }
        shownInstruction = instruction
        shownProgress = livenessProgress
        let progress = livenessProgress
        DispatchQueue.main.async {
            self.scanPassportDelegate?.onLivenessInstruction?(instruction: instruction, progress: progress)
        }
    }

    /// Tilt progress 0..100 (0 before the tilt, 100 when the check passed); re-sends the current instruction.
    private func setProgress(_ p: Int) {
        livenessProgress = max(0, min(100, p))
        if let s = shownInstruction, livenessProgress != shownProgress { hint(s) }
    }

    /// AudioCardSuccess where the web plays its tick: passport seen and steady, and the tilt done.
    private func playSuccess() {
        DispatchQueue.main.async { self.audioPlayer.playAudio(fileName: ConstantsValues.AudioCardSuccess) }
    }

    // =============================================================================================
    // Pauses, stall, background
    // =============================================================================================

    private func startPause(_ card: PassportLivenessInstruction, _ reason: String, _ now: Int) {
        restartTry(reason, now)
        if phase == .done { return }                                // the restart budget ended the try
        pause = card
        pauseAt = now
        hint(card)
    }

    /// HOLD_IN_HAND: after 3 s, as soon as the phone is picked up; the others after 3 s; always after 8 s.
    private func pauseDone(_ now: Int) -> Bool {
        let shown = now - pauseAt
        if shown >= ScanPassport.PAUSE_MAX_MS { return true }
        if shown < ScanPassport.PAUSE_SHOW_MS { return false }
        if pause == .holdInHand {
            let flat = phoneFlat(now)
            return flat == nil || flat == false
        }
        return true
    }

    /// No analysed frame for stallMs ends the capture (vision_stalled). Runs on the main thread (Timer).
    private func checkStall() {
        guard cfg != nil, performLivenessDocument == true, start, phase != .done else { return }
        let last = lastFrameAt
        if last == 0 || nowMs() - last <= STALL_MS { return }
        log("vision_stalled: no frame for \(STALL_MS) ms")
        setTorch(false)
        lightState = .off
        darkAt = nowMs()
        hideTiltLayout()
        phase = .done
        start = false
        notifyLivenessFailed()
    }

    @objc private func appWillResignActive() { interrupt() }

    /// The app went to the background / the screen closed: the light off, the try starts over on the next frame.
    private func interrupt() {
        if cfg == nil { return }
        setTorch(false)
        lightState = .off
        darkAt = nowMs()
        pendingReset = true
    }

    private func markTurn() { markX = gravX; markY = gravY; markZ = gravZ }

    /// Degrees the phone is turned NOW compared with the mark (gravity direction); 0 when unknown.
    private func turnedSince() -> Double {
        if gravX.isNaN || markX.isNaN { return 0 }
        let dot = max(-1, min(1, gravX * markX + gravY * markY + gravZ * markZ))
        return acos(dot) * 180 / Double.pi
    }

    /// The passport must be held in the hand: table (phone flat in position / baseline / light) -> HOLD_IN_HAND;
    /// the phone itself turned in the tilt -> PHONE_TURNED. At most hands.maxPauses per visit.
    private func notInHand(_ now: Int) -> Bool {
        if handPauses >= MAX_HAND_PAUSES { return false }
        var why: String? = nil
        let early = phase == .position || phase == .baseline || phase == .light
        if lastQuad != nil && early {
            if phoneFlat(now) == true {
                if flatSince == 0 { flatSince = now }
                if now - flatSince >= FLAT_MS { why = "table" }
            } else {
                flatSince = 0
            }
        } else if phase == .sweep && turnedSince() >= TURN_DEG {
            why = "phone"
        }
        guard let w = why else { return false }
        let table = w == "table"
        if table && !TABLE_CARD {                                   // record only
            if !flags.contains("flag_on_table") { flags.append("flag_on_table") }
            flatSince = 0
            return false
        }
        handPauses += 1
        flatSince = 0
        let flag = table ? "flag_on_table" : "flag_phone_tilted"
        if !flags.contains(flag) { flags.append(flag) }
        log(String(format: "hand pause: %@ (phone %.1f deg from level, turned %.1f deg)", w, phoneTiltDeg, turnedSince()))
        markTurn()
        startPause(table ? .holdInHand : .phoneTurned, table ? "on_table" : "phone_tilted", now)
        return true
    }

    /// Phone within hands.flatDeg of level? nil when unknown or older than 1 s.
    private func phoneFlat(_ now: Int) -> Bool? {
        if phoneTiltDeg.isNaN || now - phoneTiltAt > ScanPassport.MOTION_FRESH_MS { return nil }
        return phoneTiltDeg < FLAT_DEG
    }

    /// Gravity from Core Motion (in g): the phone's tilt from level, and its direction for the turn check.
    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30
        motionManager.startDeviceMotionUpdates(to: OperationQueue()) { [weak self] m, _ in
            guard let self = self, let g = m?.gravity else { return }
            let n = sqrt(g.x * g.x + g.y * g.y + g.z * g.z)
            if n <= 0.4 { return }                                  // spec: only when |g| > 4 m/s²
            self.phoneTiltDeg = acos(min(1, abs(g.z) / n)) * 180 / Double.pi
            self.phoneTiltAt = self.nowMs()
            self.gravX = g.x / n; self.gravY = g.y / n; self.gravZ = g.z / n
        }
    }

    private func stopMotion() {
        if motionManager.isDeviceMotionActive { motionManager.stopDeviceMotionUpdates() }
    }

    /// Battery below batteryLowBelow and not charging.
    private func isBatteryTooLow() -> Bool {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        if level < 0 { return false }
        let charging = device.batteryState == .charging || device.batteryState == .full
        return !charging && Double(level) < BATTERY_LOW
    }

    // ---- torch (camera-torch.md): on, off, and is it really on ----

    @discardableResult
    private func setTorch(_ on: Bool) -> Bool {
        guard let d = torchDevice, d.hasTorch, d.isTorchAvailable else { return false }
        do {
            try d.lockForConfiguration()
            if on { try d.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel) } else { d.torchMode = .off }
            d.unlockForConfiguration()
            return true
        } catch {
            return false
        }
    }

    private func isTorchOn() -> Bool {
        guard let d = torchDevice, d.hasTorch else { return false }
        return d.torchMode == .on && d.isTorchActive
    }

    // ---- helpers ----

    private func nowMs() -> Int { Int(CACurrentMediaTime() * 1000) }

    private func log(_ s: @autoclosure () -> String) {
        if ScanPassport.DEBUG_LOGS { print("PassportLivenessDebug: \(s())") }
    }
}
