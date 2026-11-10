import Foundation
import UIKit
import AVFoundation
import Accelerate
import CoreImage
import CoreMotion

public class ScanIDCard :UIViewController, CameraSetupDelegate , RemoteProcessingDelegate ,LanguageTransformationDelegate{
    
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
   
    let templatesByCountry:TemplatesByCountry;
    var selectedTemplates:[String] = []
    var isLastPage:Bool = false;
    var classifiedTemplate:String = "";

    private var scanIDCardDelegate: ScanIDCardDelegate?
    private var configModel: ConfigModel?
    private var environmentalConditions: EnvironmentalConditions?
    private var apiKey: String
    private var processMrz: Bool?
    private var performLivenessDocument: Bool?
    private var saveCapturedVideoID: Bool?
    private var storeCapturedDocument: Bool?
    private var language: String?
    private var stepId:Int?;
    
    private var remoteProcessing: RemoteProcessing?
    private var motion:MotionType = MotionType.NO_DETECT;
    private var zoom:ZoomType = ZoomType.NO_DETECT;

    private var iDResponseModel:IDResponseModel?;
    
    private var detectIfRectFInsideTheScreen = DetectIfRectInsideTheScreen();
    private var isRectFInsideTheScreen:Bool = false;
    
    private var audioPlayer = AssetsAudioPlayer();
    
    private var  retryCount = 0;
    private var  isManual = false;
    private var  currentImage : CVPixelBuffer?;
    
    private var  start = true;

    // =============================================================================================
    // Local card liveness: fields (the section itself is at the bottom of the class)
    // =============================================================================================

    private static let DEBUG_LOGS = false                            // TEMP: set false for release
    private static let FINDER_MODEL = "finder_fp32"                 // the same finder as the passport

    // ---- which card (classification.tflite), decided before the liveness of each side ----
    private static let KIND_ID_FRONT = "lb_civil_id"
    private static let KIND_ID_BACK = "lb_civil_id_back"
    private static let KIND_LICENCE = "lb_driving_licence"
    private static let KIND_PERMIT = "lb_residence_permit"
    private var docClassifier: DocumentClassifier?
    private var classifierFailed = false
    private var kindDecided = false                                 // the classifier answered for this side
    private var livenessKind: String? = nil                         // nil = no local liveness for this card
    private var backShownLayout = false                             // the classifier saw a "back" class: back guide
    private var classifyStart = 0                                   // when a card was first seen for this side
    // The FIRST frame whose top class is one of the four supported cards decides (any confidence above
    // CLASSIFY_MIN_CONF; "back" needs CLASSIFY_BACK_MIN_CONF, because a front taken as the back would switch the
    // front's checks off). No supported card within CLASSIFY_MAX_MS of the first card seen: no local liveness.
    private static let CLASSIFY_MIN_CONF: Float = 0.20
    private static let CLASSIFY_BACK_MIN_CONF: Float = 0.50         // safeguard for "back"; 0 to turn it off
    private static let CLASSIFY_MAX_MS = 6000

    // ---- finder ----
    private var finder: Finder?
    private var finderFailed = false

    // ---- config (rectifier_config_file.json) ----
    private var cfg: LivenessConfig?
    private var cfgKind: String? = nil                              // the kind cfg was loaded for
    private var isFront = false, isBack = false, isLaminateCard = false   // ID front / ID back / licence or permit

    private var CARD_ASPECT = 1.585185185185185
    private lazy var stab = OutlineStabilizer(docAspect: CARD_ASPECT)
    private var RECT_H = 303
    private var FRAME_MARGIN_PX = 4.0, MIN_QUAD_AREA_FRAC = 0.08
    private var STABLE_MS = 300, ANALYSIS_LONG_EDGE = 720, LOSS_MS = 1500, PHASE_TIMEOUT_MS = 15000
    private var MAX_ATTEMPTS = 3, MAX_RESTARTS = 8, MAX_EARLY_RESTARTS = 40, BASELINE_HOLD_MS = 400
    private var SHARPNESS_MIN = 60.0, DRIFT_MAX = 0.03
    private var LIGHT_SETTLE_MS = 300, LIGHT_MAX_MS = 2500, OFF_SETTLE_MS = 500, OFF_MAX_MS = 4000, LIGHT_FRAMES = 5
    private var BATTERY_LOW = 0.05
    private var TILT_MIN = 0.05                                     // ID front: tiltMin (lr); licence: upDown.tiltMin (tb)
    private var SWEEP_FRAMES = 3                                    // ID front: sweepFrames; licence: upDown.holdFrames
    private var HOLD_MS = 8000                                      // ID front: emblem.holdMs; licence: drivingLicence.holdMs
    private var TILT_SHARE = 0.6                                    // licence tilt meter: tilt part
    private var WRONG_WAY_FRAMES = 4, STUCK_MS = 3000
    private var TILT_NOISE_K = 3.0, SAME_PLACE_MAX = 0.08, AREA_JUMP_MAX = 1.6
    private var ANGLE_MAX = 0.17, TILT_OVERFLOW = 0.15, EDGE_MARGIN = 0.02
    private var BRIGHT_LIFT = 1.25, SUN_MAX = 3, STALL_MS = 6000
    private var FLAT_DEG = 10.0, FLAT_MS = 800, MAX_HAND_PAUSES = 1, TABLE_CARD = true, TURN_DEG = 20.0
    // the ID front's rectangles (fractions of the upright card)
    private var emblemCell: [Double]?, emblemInner: [Double]?, emblemOuter: [Double]?
    private var orientRoi: [Double]?                                // [x, y, w, h, hueLo, hueHi, minSat]
    private var staticFeature: [Double]?                            // [x, y, w, h, hueLo, hueHi, minSat] or nil

    // native-only (same values as the passport, from the device logs)
    private static let BASELINE_MIN_POSES = 3
    private static let HOLD_STILL_TOL = 0.05
    private static let HOLD_FRONTAL_MAX = 0.25
    private static let HOLD_GLARE_MAX = 0.06
    private static let LIGHT_LOSS_FACTOR = 2.5
    private static let TORCH_CONFIRM_MS = 1000
    private static let RAW_SKEW_MAX = 0.80
    private static let MOVE_EPS = 0.01
    private static let SWEEP_FLAT_EPS = 0.04
    private static let OFF_REASK_MS = 250
    private static let MOTION_FRESH_MS = 1000
    private static let PAUSE_SHOW_MS = 3000, PAUSE_MAX_MS = 8000

    // ---- this frame ----
    private var lastUpright: LivenessImage?
    private var curPixelBuffer: CVPixelBuffer?                      // the full camera frame (cut edge, barcode, liveness screen image), this frame only
    private var lastQuad: [Double]?, lastPixelQuad: [Double]?, lastRawQuad: [Double]?
    private var lastPose: Pose?, lastRawPose: Pose?
    private var lastIsRaw = false, lastSharp = false
    private var lastSharpness = 0.0, lastGlareFrac = 0.0
    private var steadySince = 0
    private var positionMisses = 0
    private var pendingReset = false

    // ---- phases ----
    private enum Phase { case position, baseline, light, sweep, barcode, done }
    private var phase = Phase.position
    private var phaseStart = 0, lastSeen = 0

    // ---- per try / per visit ----
    private var engineAttempts = 0, restarts = 0, earlyRestarts = 0
    private var tryReasons: [String] = []
    private var retriesThisVisit = 0
    private var matteBefore = false

    // ---- baseline ----
    private var baseCount = 0, baseHoldSince = 0
    private var havePrev = false, holdGraceUsed = false
    private var prevLr = 0.0, prevTb = 0.0, prevCx = 0.0, prevCy = 0.0, holdLr = 0.0, holdTb = 0.0
    private var baselineAxis: [Double] = []                         // raw pose on the tilt axis while held flat
    private var baselineAngles: [Double] = []
    private var baseAngle = Double.nan
    private var flatPhoto: Data?                                    // THE photo: flat, unlit, full camera size

    // ---- light ----
    private var baseK = 0
    private var unlitImg: [UInt32]?, litImg: [UInt32]?
    private var iridBase: CardLivenessVision.IridBase?
    private var lightAvailable = false, lightEnded = false, litEarlyCut = false
    private var lightRequestedAt = 0
    private enum Light { case off, on, goingOff }
    private var lightState = Light.off
    private var offAskedAt = 0, offLastAskAt = 0, darkAt = -1_000_000
    private var lightSharp = 0
    private var reflection: LivenessGate.ReflectionAnalyzer?
    private var lightAxis: [Double] = []                            // raw pose on the tilt axis with the torch on
    private var emblemLit: [[Double]] = []                          // ID front: [now, base] per lit frame
    private var cutReadings: [Double] = []                          // ID front: overlay cut-edge scores
    private var axisRef = Double.nan, tiltMinEffective = 0.05

    // ---- sweep ----
    private var direction = "right"                                 // right (ID front) | top | bottom (licence, random)
    private var axisLr = true
    private var sign = -1.0
    private var sweepFrom = Double.nan, sweepMoved = 0.0, prevDelta = 0.0, meterFrom = Double.nan
    private var sweepGood = 0, sweepWrong = 0
    private var lastMoveAt = 0, reachedAt = 0
    private var sweepSawFlat = false
    private var iridTilt: [[Double]] = []                           // licence / permit: laminate colours per frame
    private var emblemTilt: [[Double]] = []                         // ID front: [absolute lr, emblem now] per frame
    private var sweepRefSet = false, sweepLastSeenAt = 0
    private var sweepRefX = 0.0, sweepRefY = 0.0, sweepRefLen = 0.0

    // ---- ID back: the PDF417 barcode (checks/barcode-qr.md), recorded + the ID number check ----
    private let barcodeQueue = DispatchQueue(label: "ScanIDCard.barcode")
    private var barcodeBusy = false
    private var barcodeRead = false
    private var barcodeToken = 0                                    // a late read of an earlier try is ignored
    private var lastBarcodeAt = 0
    private var barcodeAttempts = 0
    private var BARCODE_EVERY_MS = 250, BARCODE_WAIT_MS = 8000, BARCODE_LIGHT_MS = 3000
    // the ID number check: the back's barcode number against the front's document number (either side first)
    private var readNumber: String? = nil                           // the barcode's number in THIS try of the back
    private var backNumber: String? = nil                           // the number of the back that passed (was sent)
    private var frontNumber: String? = nil                          // the front's document number from the server
    private var sentKind: String? = nil                             // the liveness kind of the side just sent

    // ---- result / UI ----
    private var finalReady = false
    private var shownInstruction: IdLivenessInstruction?
    private var livenessProgress = 0, shownProgress = -1
    private var livenessFrameGood = false
    private var tiltStart = false                                   // a tilt drawing is shown: the guide is removed
    private var tiltLayoutView: UIView?                             // the tilt drawing on screen (Guide), or nil
    private var barcodeLayoutShown = false                          // the barcode drawing is shown: the guide is removed
    private var barcodeLayoutView: UIView?                          // main thread: the barcode drawing on screen, or nil
    private var shownGuideResource: String?                         // main thread: the guide on screen

    // ---- hand / sun / stall ----
    private let motionManager = CMMotionManager()
    private var phoneTiltDeg = Double.nan, phoneTiltAt = 0
    private var gravX = Double.nan, gravY = Double.nan, gravZ = Double.nan
    private var markX = Double.nan, markY = Double.nan, markZ = Double.nan
    private var flatSince = 0
    private var handPauses = 0, sunPauses = 0
    private var brightMiss = false
    private var flags: [String] = []
    private var pause: IdLivenessInstruction?
    private var pauseAt = 0
    private var lastFrameAt = 0
    private var stallTimer: Timer?

    private lazy var torchDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

    init(configModel: ConfigModel!,
         environmentalConditions :EnvironmentalConditions,
         apiKey:String,
         scanIDCardDelegate:ScanIDCardDelegate,
         templatesByCountry:TemplatesByCountry,
         language: String,
         isManual:Bool
    ) {
        self.configModel = configModel;
        self.environmentalConditions = environmentalConditions;
        self.apiKey = apiKey;
        self.scanIDCardDelegate = scanIDCardDelegate;
        self.templatesByCountry = templatesByCountry;
        self.language = language;
        self.isManual = isManual;
        
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
        
        for template in templatesByCountry.templates {
            for kycDocument in template.kycDocumentDetails {
                selectedTemplates.append(
                    kycDocument.templateProcessingKeyInformation
                )
            }
        }
        
        if(environmentalConditions!.enableGuide){
            showGuide(color: self.environmentalConditions!.HoldHandColor, notTransmitting: self.start, inTilt: false)
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

    // =============================================================================================
    // The guide: front ("card_background") or back ("card_back_background"); removed while a tilt drawing is shown
    // =============================================================================================

    /// The guide for this side: the back once the classifier saw a "back" class, the front otherwise.
    private var guideResource: String { backShownLayout ? "card_back_background" : "card_background" }

    /// Shows / recolours the guide (main thread). In the tilt the guide is removed; it comes back after it.
    private func showGuide(color: String, notTransmitting: Bool, inTilt: Bool) {
        guard environmentalConditions!.enableGuide else { return }
        let resource = guideResource
        let work = {
            if inTilt {                                             // tilt: no guide on screen
                self.guide.cardSvgImageView?.removeFromSuperview()
                self.guide.cardSvgImageView = nil
                self.shownGuideResource = nil
                return
            }
            if self.guide.cardSvgImageView == nil || self.shownGuideResource != resource {
                self.guide.cardSvgImageView?.removeFromSuperview()  // another side: load its guide
                self.guide.cardSvgImageView = nil
                self.guide.showCardGuide(view: self.view, forResource: resource)
                self.shownGuideResource = resource
            }
            self.guide.changeCardColor(view: self.view, to: color, notTransmitting: notTransmitting)
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
     
    // =============================================================================================
    // Frames
    // =============================================================================================
    
    func didCaptureCVPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        if(self.isManual){
            self.currentImage = pixelBuffer
            if(self.environmentalConditions!.enableGuide){
                showGuide(color: self.environmentalConditions!.HoldHandColor, notTransmitting: self.start, inTilt: false)
            }
            return
        }

        if pendingReset {                                           // a new side, a retry, or back from the background
            pendingReset = false
            resetKind()
            resetLiveness()
        }

        // local liveness when the step's document liveness is on, and only for the cards it is defined for
        let localAllowed = performLivenessDocument == true && loadFinder()
        if localAllowed && start && !kindDecided {
            decideKind(pixelBuffer)
            if !kindDecided {                                       // still looking: no capture of any kind yet
                showGuide(color: environmentalConditions!.HoldHandColor, notTransmitting: start, inTilt: false)
                return
            }
        }
        let livenessOn = localAllowed && livenessKind != nil && ensureConfig()
        if !livenessOn {                                            // the capture as before
            runModel(onPixelBuffer: pixelBuffer)
            openCvCheck(pixelBuffer: pixelBuffer)
            return
        }
        processLiveness(pixelBuffer)
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
    
    /// The capture as before (YOLO + motion / zoom / brightness): no local liveness for this card.
    func openCvCheck(pixelBuffer: CVPixelBuffer){
        let cropRect = CGRect(x: 0, y: 0, width: 256, height: 256)
        let imageBrightnessChecker = cropPixelBuffer(pixelBuffer, toRect: cropRect)!.brightness;
        if motionRectF.count >= 2 {
            let rect1 = motionRectF[motionRectF.count - 2]
            let rect2 = motionRectF[motionRectF.count - 1]
            motion = calculatePercentageChange(rect1: rect1, rect2: rect2)
            zoom = calculatePercentageChangeWidth(rect: rect1,pixelBuffer: pixelBuffer)
        }
        
        if (motion == MotionType.SENDING && zoom == ZoomType.SENDING && isRectFInsideTheScreen && environmentalConditions!.checkConditions(
            brightness: imageBrightnessChecker)  == BrightnessEvents.Good) {
            modelDataHandler?.customColor =  ConstantsValues.DetectColor;
            sendingFlagsMotion.append(MotionType.SENDING);
            sendingFlagsZoom.append(ZoomType.SENDING);
            showGuide(color: ConstantsValues.DetectColor, notTransmitting: self.start, inTilt: false)
        } else {
            modelDataHandler?.customColor = environmentalConditions!.HoldHandColor;
            sendingFlagsMotion.removeAll();
            sendingFlagsZoom.removeAll();
            showGuide(color: self.environmentalConditions!.HoldHandColor, notTransmitting: self.start, inTilt: false)
        }
        
        if (environmentalConditions!.checkConditions(
            brightness: imageBrightnessChecker)  == BrightnessEvents.Good
            && motion == MotionType.SENDING  && zoom == ZoomType.SENDING && isRectFInsideTheScreen) {
            if (start && sendingFlagsMotion.count > environmentalConditions!.MotionLimit && sendingFlagsZoom.count > ZoomLimit) {
                if (hasFaceOrCard()) {
                    DispatchQueue.main.async {
                        self.scanIDCardDelegate?.onSend();
                        self.audioPlayer.playAudio(fileName: ConstantsValues.AudioCardSuccess)
                    }
                    let dataImage = convertPixelToDataImage(pixelBuffer:pixelBuffer)!
                    sentKind = nil                                  // no local liveness: no ID number check
                    start = false;
                    sendToServer(dataImage, isManualCapture: false)
                }
            }
        }
        DispatchQueue.main.async {
            self.scanIDCardDelegate?.onEnvironmentalConditionsChange?(
                brightnessEvents: self.environmentalConditions!.checkConditions(
                    brightness: imageBrightnessChecker),
                motion: self.motion,zoom: self.zoom,isCentered: self.isRectFInsideTheScreen)
        }
    }

    /// The upload, shared by the old capture, the manual capture and the liveness (the flat, unlit photo).
    private func sendToServer(_ dataImage: Data, isManualCapture: Bool) {
        remoteProcessing?.starProcessingIDs(
            url: BaseUrls.signalRHub + HubConnectionFunctions.etHubConnectionFunction(blockType:BlockType.ID_CARD),
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
            tag:getIDTag(configModel: self.configModel!, templateName: self.templatesByCountry.name),
            processCivilExtractQrCode: false,
            templatesByCountry: self.selectedTemplates,
            onProgress: { progress in
                self.scanIDCardDelegate?.onUploadingProgress(progress: progress);
            },
        )  { result in
            switch result {
            case .success(let model):
                self.onMessageReceived(eventName: model?.destinationEndpoint ?? "",remoteProcessingModel: model!)
            case .failure(_):
                self.onMessageReceived(eventName: HubConnectionTargets.ON_ERROR ,remoteProcessingModel: RemoteProcessingModel(
                    destinationEndpoint: HubConnectionTargets.ON_ERROR,
                    response: "",
                    error: EventsErrorMessages.OnErrorMessage,
                    success: false,
                 ))
            }
        }
    }
    
    /// The next side (the flip screen's button): the classifier and the liveness start again for it.
    public func changeTemplateId() {
        DispatchQueue.main.async {
            if !self.classifiedTemplate.isEmpty {
                for template in self.templatesByCountry.templates {
                    let details = template.kycDocumentDetails
                    for kyc in details {
                        if kyc.templateProcessingKeyInformation == self.classifiedTemplate {
                            if details.count == 2 {
                                for item in details {
                                    if item.templateProcessingKeyInformation != self.classifiedTemplate {
                                        self.selectedTemplates.removeAll()
                                        self.selectedTemplates.append(item.templateProcessingKeyInformation)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
                self.isLastPage = true
            }
            self.retryCount = 0;
            self.motionRectF.removeAll()
            self.sendingFlagsMotion.removeAll()
            self.sendingFlagsZoom.removeAll()
            self.pendingReset = true                                // the next side: the classifier decides again
            self.start = true;
        }
    }
    
    private func isFrontPage() -> Bool {
        var result = false
        if !classifiedTemplate.isEmpty {
            for template in templatesByCountry.templates {
                let details = template.kycDocumentDetails
                for kyc in details {
                    if kyc.templateProcessingKeyInformation == classifiedTemplate {
                        if details.count > 1 {
                            result = details.first?
                                .templateProcessingKeyInformation == classifiedTemplate
                        } else {
                            isLastPage = true
                            result = true
                        }
                        break
                    }
                }
            }
        }
        return result
    }

    func onMessageReceived(eventName: String, remoteProcessingModel : RemoteProcessingModel ) {
        DispatchQueue.main.async {
            self.motionRectF.removeAll()
            self.sendingFlagsMotion.removeAll()
            self.sendingFlagsZoom.removeAll()
            if let template = remoteProcessingModel.classifiedTemplate,
               !template.isEmpty {
                self.classifiedTemplate = template
            }

            if eventName == HubConnectionTargets.ON_COMPLETE {
                self.start = false
                let iDExtractedModel = IDExtractedModel.fromJsonString(responseString:remoteProcessingModel.response!,transformedProperties: [:]);
                self.iDResponseModel = IDResponseModel(
                    destinationEndpoint: remoteProcessingModel.destinationEndpoint,
                    iDExtractedModel: iDExtractedModel,
                    error: remoteProcessingModel.error,
                    success: remoteProcessingModel.success
                )

                // the ID number check, when the side that just passed is the civil ID front
                if self.sentKind == ScanIDCard.KIND_ID_FRONT {
                    let number = ScanIDCard.documentNumberOf(iDExtractedModel?.outputProperties)
                    if number == nil {
                        self.log("IdBarcode: front done: no document number in the answer (not checked)")
                    } else if let back = self.backNumber, !ScanIDCard.sameIdNumber(back, number!) {
                        // the back came first and its barcode holds another number: scan the front again
                        self.log("IdBarcode: front REJECTED: document number \(number!) is not the back's barcode number \(back) -> onRetry")
                        self.frontNumber = nil
                        self.retryCount += 1
                        self.start = false                          // the retry button starts the side again
                        self.pendingReset = true
                        remoteProcessingModel.error = EventsErrorMessages.OnRetryCardMessage
                        self.scanIDCardDelegate?.onRetry(dataModel: remoteProcessingModel)
                        return
                    } else {
                        self.frontNumber = number                   // kept for the back (or already matches it)
                        self.log("IdBarcode: front done: document number \(number!)"
                                 + (self.backNumber != nil ? " = the back's barcode number" : " (the back is checked against it)"))
                    }
                }
                
                if(self.language == Language.NON){
                    self.scanIDCardDelegate?.onComplete(dataModel:self.iDResponseModel!,isFrontPage: self.isFrontPage(),isLastPage: self.isLastPage,classifiedTemplate: self.classifiedTemplate )
                    self.start = false
                }else{
                    let transformed = LanguageTransformation(apiKey: self.apiKey,languageTransformationDelegate: self)
                       transformed.languageTransformation(
                           langauge: self.language!,
                           transformationModel: preparePropertiesToTranslate(language: self.language!, properties: iDExtractedModel?.outputProperties)
                       )
                }
                
            }  else if eventName == HubConnectionTargets.ON_RETRY{
                self.retryCount = self.retryCount + 1;
                remoteProcessingModel.error = EventsErrorMessages.OnRetryCardMessage
                self.scanIDCardDelegate?.onRetry(dataModel:remoteProcessingModel )
                self.start = true
            } else {
                self.start =  eventName == HubConnectionTargets.ON_ERROR
                switch eventName {
                case HubConnectionTargets.ON_ERROR:
                    remoteProcessingModel.error =  EventsErrorMessages.OnErrorMessage
                    self.scanIDCardDelegate?.onError(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_CLIP_PREPARATION_COMPLETE:
                    self.scanIDCardDelegate?.onClipPreparationComplete?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_STATUS_UPDATE:
                    self.scanIDCardDelegate?.onStatusUpdated?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_UPDATE:
                    self.scanIDCardDelegate?.onUpdated?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_CARD_DETECTED:
                    self.scanIDCardDelegate?.onCardDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_MRZ_EXTRACTED:
                    self.scanIDCardDelegate?.onMrzExtracted?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_MRZ_DETECTED:
                    self.scanIDCardDelegate?.onMrzDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_NO_MRZ_EXTRACTED:
                    self.scanIDCardDelegate?.onNoMrzDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_FACE_DETECTED:
                    self.scanIDCardDelegate?.onFaceDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_NO_FACE_DETECTED:
                    self.scanIDCardDelegate?.onNoFaceDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_FACE_EXTRACTED:
                    self.scanIDCardDelegate?.onFaceExtracted?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_QUALITY_CHECK_AVAILABLE:
                    self.scanIDCardDelegate?.onQualityCheckAvailable?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_DOCUMENT_CAPTURED:
                    self.scanIDCardDelegate?.onDocumentCaptured?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_DOCUMENT_CROPPED:
                    self.scanIDCardDelegate?.onDocumentCropped?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_UPLOAD_FAILED:
                    self.scanIDCardDelegate?.onUploadFailed?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_LIVENESS_UPDATE:
                    remoteProcessingModel.error = EventsErrorMessages.OnLivenessCardUpdateMessage
                    self.scanIDCardDelegate?.onLivenessUpdate?(dataModel:remoteProcessingModel, image: nil)   // server: its URL
                    self.start = true
                case HubConnectionTargets.ON_WRONG_TEMPLATE:
                    remoteProcessingModel.error = EventsErrorMessages.OnWrongTemplateMessage
                    self.scanIDCardDelegate?.onWrongTemplate(dataModel:remoteProcessingModel )
                    self.start = true
                default:
                    self.start = true
                    remoteProcessingModel.error = EventsErrorMessages.OnWrongTemplateMessage
                    self.scanIDCardDelegate?.onWrongTemplate(dataModel:remoteProcessingModel )
                }
            }

            // a retry-like screen is shown: the camera waits for its button (retryLiveness), then the side starts again.
            // (Not started at once: the torch and the tilt must not run behind the screen.)
            if self.start {
                self.start = false
                self.pendingReset = true
            }
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
        if let outputProperties = self.iDResponseModel!.iDExtractedModel?.outputProperties {
            let ignoredProperties = getIgnoredProperties(properties: outputProperties)
            var finalProperties = [String: Any]()

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

            self.iDResponseModel!.iDExtractedModel!.transformedProperties?.removeAll()
            self.iDResponseModel!.iDExtractedModel!.extractedData?.removeAll()

            for (key, value) in finalProperties {
                self.iDResponseModel!.iDExtractedModel!.transformedProperties![key] =  "\(value)"
                let newKey = key.components(separatedBy: "IdentificationDocumentCapture_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
                self.iDResponseModel!.iDExtractedModel!.extractedData![newKey] =  "\(value)"
            }
            
            DispatchQueue.main.async {
                self.scanIDCardDelegate?.onComplete(dataModel:self.iDResponseModel!,isFrontPage: self.isFrontPage(),isLastPage: self.isLastPage,classifiedTemplate: self.classifiedTemplate )
            }
            self.start = false
        }
    }
    
    public func onTranslatedError(properties: [String : String]?) {
        DispatchQueue.main.async {
            self.scanIDCardDelegate?.onComplete(dataModel:self.iDResponseModel!,isFrontPage: self.isFrontPage(),isLastPage: self.isLastPage,classifiedTemplate: self.classifiedTemplate )
        }
        self.start = false
    }
    
    public func stopScanning(){
        audioPlayer.stopAudio();
        setTorch(false)
        stopMotion()
        stallTimer?.invalidate()
        stallTimer = nil
        barcodeToken += 1
        hideBarcodeLayout()
        self.previewView.stopSession();
        self.cameraFeedManager.stopSession();
    }
    
    public func takePicture(){
        if(start){
            result = self.modelDataHandler?.runModel(onFrame: self.currentImage!)
            if(hasFaceOrCard()){
                start = false;
                self.scanIDCardDelegate?.onSend();
                let dataImage = convertPixelToDataImage(pixelBuffer: self.currentImage!)!
                sentKind = nil
                sendToServer(dataImage, isManualCapture: true)
            }else{
                self.scanIDCardDelegate?.onRetry(dataModel:RemoteProcessingModel(
                    destinationEndpoint: HubConnectionTargets.ON_RETRY,
                    response: "",
                    error: EventsErrorMessages.OnRetryCardMessage,
                    success: false
                ) )
            }
        }
    }

    // #############################################################################################
    // #############################################################################################
    //
    //                                  Local Card Liveness Check
    //
    //   Port of ScanIDCard.java (Android). rc17 spec (mobile-handover/02-core-spec, 03-documents/civil-id,
    //   driving-licence-residence-permit):
    //    - lb_civil_id (front): POSITION -> BASELINE (flat photo) -> LIGHT -> lift the RIGHT edge -> verdict.
    //      Enforced: cedar emblem (lit, then dark on the tilt), overlay cut edge, reflection.
    //    - lb_civil_id_back: POSITION -> BASELINE (flat photo) -> [BARCODE: light on, wait up to idBarcode.waitMs] -> done.
    //      No tilt. The PDF417 barcode is read: recorded, and its number is checked against the front's.
    //    - lb_driving_licence / lb_residence_permit: POSITION -> BASELINE (flat photo) -> LIGHT -> lift the TOP or
    //      BOTTOM edge (random) -> held open while the laminate colours are read -> verdict. Enforced: laminate, reflection.
    //   Only when the step's document liveness is on, and only for those four cards (DocumentClassifier).
    //
    // #############################################################################################
    // #############################################################################################

    /// The retry buttons (and the liveness screen's): this side starts again from Position (the classifier decides again).
    public func retryLiveness() {
        pendingReset = true
        start = true
    }

    /// The finder model, once. false (missing): the old capture is used.
    private func loadFinder() -> Bool {
        if finder != nil { return true }
        if finderFailed { return false }
        do {
            finder = try Finder(modelName: ScanIDCard.FINDER_MODEL, threads: 2)
            return true
        } catch {
            finderFailed = true
            print("IdLiveness: finder model could not be loaded: \(error). Old capture.")
            return false
        }
    }

    // =============================================================================================
    // Which card: DocumentClassifier
    // =============================================================================================

    /// The classifier on frames with a card in view. The FIRST frame whose top class is one of the four supported cards
    /// (civil ID front / back, driving licence, residence permit) decides, at any confidence above CLASSIFY_MIN_CONF
    /// ("back" needs CLASSIFY_BACK_MIN_CONF). Nothing supported within CLASSIFY_MAX_MS of the first card seen: no local
    /// liveness (the capture as before).
    private func decideKind(_ pb: CVPixelBuffer) {
        let landscape = CVPixelBufferGetWidth(pb) > CVPixelBufferGetHeight(pb)
        guard let upright = CardLivenessVision.analysisFrame(pb, longEdge: ANALYSIS_LONG_EDGE, rotateClockwise: landscape),
              let finder = finder else { return }
        let w = Double(upright.width), h = Double(upright.height)
        guard let fr = try? finder.detect(upright, head: .card), fr.found, let c = fr.corners,
              Geometry.isValidQuad(c, w: w, h: h, frameMarginPx: FRAME_MARGIN_PX, minQuadAreaFrac: MIN_QUAD_AREA_FRAC) else {
            return                                                  // no card in view: nothing to classify yet
        }
        let now = nowMs()
        if classifyStart == 0 { classifyStart = now }
        if docClassifier == nil && !classifierFailed {
            do {
                docClassifier = try DocumentClassifier()
            } catch {
                classifierFailed = true
                print("IdLiveness: document classifier could not be loaded: \(error)")
            }
        }
        guard let classifier = docClassifier else {
            applyKind(nil, "classifier unavailable")
            return
        }
        guard let r = try? classifier.classify(upright) else { return }

        let kind = DocumentClassifier.kindFor(r.label)
        let supported = kind == ScanIDCard.KIND_ID_FRONT || kind == ScanIDCard.KIND_ID_BACK
            || kind == ScanIDCard.KIND_LICENCE || kind == ScanIDCard.KIND_PERMIT
        // a class with "back" in its name (civil ID back, residence permit back, Syrian / Palestinian ID back ...)
        let back = r.label.lowercased().contains("back")
        let bar = back ? ScanIDCard.CLASSIFY_BACK_MIN_CONF : ScanIDCard.CLASSIFY_MIN_CONF
        let waited = now - classifyStart
        log("classifier: \(r) supported=\(supported) bar=\(bar) waited=\(waited)ms")

        if supported && r.confidence >= bar {                       // one of the four: decide now
            backShownLayout = back
            applyKind(kind, "\(r) after \(waited) ms")
        } else if waited > ScanIDCard.CLASSIFY_MAX_MS {             // nothing supported in time: no local liveness
            applyKind(nil, "no supported card after \(ScanIDCard.CLASSIFY_MAX_MS) ms (last \(r))")
        }
        // otherwise: keep trying on the next frame
    }

    /// Only the civil ID (front / back), the driving licence and the residence permit get the local liveness.
    private func applyKind(_ kind: String?, _ why: String) {
        let supported = kind == ScanIDCard.KIND_ID_FRONT || kind == ScanIDCard.KIND_ID_BACK
            || kind == ScanIDCard.KIND_LICENCE || kind == ScanIDCard.KIND_PERMIT
        livenessKind = supported ? kind : nil
        kindDecided = true
        print("IdLiveness: card: \(why) -> " + (supported ? "kind \(kind!), local liveness ON"
                                                : "local liveness SKIPPED" + (kind != nil ? " (\(kind!))" : "")))
    }

    private func resetKind() {
        kindDecided = false
        livenessKind = nil
        backShownLayout = false
        classifyStart = 0
    }

    // =============================================================================================
    // Config
    // =============================================================================================

    /// Loads (or reloads, for another card) the config and copies the thresholds of this card's kind.
    private func ensureConfig() -> Bool {
        guard let kind = livenessKind else { return false }
        if cfg != nil && kind == cfgKind { return true }
        if cfgKind != nil && kind != cfgKind {                      // another card: a new visit
            retriesThisVisit = 0
            matteBefore = false
            handPauses = 0
            sunPauses = 0
            brightMiss = false
        }
        guard let c = try? LivenessConfig.load(kind: kind) else {
            print("IdLiveness: could not load rectifier_config_file.json for \(kind): old capture")
            livenessKind = nil
            return false
        }
        cfg = c
        cfgKind = kind
        isFront = kind == ScanIDCard.KIND_ID_FRONT
        isBack = kind == ScanIDCard.KIND_ID_BACK
        isLaminateCard = kind == ScanIDCard.KIND_LICENCE || kind == ScanIDCard.KIND_PERMIT

        CARD_ASPECT = c.profile.aspect
        RECT_H = CardLivenessVision.rectHeight(CARD_ASPECT)
        FRAME_MARGIN_PX = c.frameMarginPx; MIN_QUAD_AREA_FRAC = c.minQuadAreaFrac
        STABLE_MS = c.stableMs; ANALYSIS_LONG_EDGE = c.analysisLongEdge
        LOSS_MS = c.lossMs; PHASE_TIMEOUT_MS = c.phaseTimeoutMs
        MAX_ATTEMPTS = c.maxAttempts; MAX_RESTARTS = c.maxRestarts; MAX_EARLY_RESTARTS = c.maxEarlyRestarts
        BASELINE_HOLD_MS = c.baselineHoldMs; SHARPNESS_MIN = c.sharpnessMin; DRIFT_MAX = c.driftMax
        LIGHT_SETTLE_MS = c.light.settleMs; LIGHT_MAX_MS = c.light.maxMs; LIGHT_FRAMES = c.light.frames
        OFF_SETTLE_MS = c.light.offSettleMs; OFF_MAX_MS = c.light.offMaxMs
        BATTERY_LOW = c.batteryLowBelow
        WRONG_WAY_FRAMES = c.wrongWayFrames; STUCK_MS = c.stuckMs
        TILT_NOISE_K = c.tiltNoiseK; SAME_PLACE_MAX = c.samePlaceMax; AREA_JUMP_MAX = c.areaJumpMax
        ANGLE_MAX = c.angleMax; TILT_OVERFLOW = c.tiltOverflow; EDGE_MARGIN = c.edgeMargin
        BRIGHT_LIFT = c.reflection.brightLift; SUN_MAX = Int(c.reflection.sunMax.rounded())
        STALL_MS = c.stallMs
        BARCODE_EVERY_MS = c.idBarcode.everyMs; BARCODE_WAIT_MS = c.idBarcode.waitMs; BARCODE_LIGHT_MS = c.light.barcodeMs
        FLAT_DEG = c.hands.flatDeg; FLAT_MS = c.hands.flatMs; MAX_HAND_PAUSES = c.hands.maxPauses
        TABLE_CARD = c.hands.tableCard; TURN_DEG = c.hands.turnDeg

        // the tilt (capture.ts:773): ID front = right edge on lr, tiltMin / sweepFrames, held open emblem.holdMs;
        // licence / permit = top or bottom (random) on tb, upDown.tiltMin / upDown.holdFrames, held open holdMs
        if isFront {
            TILT_MIN = c.tiltMin
            SWEEP_FRAMES = c.sweepFrames
            HOLD_MS = c.emblem.holdMs
        } else {
            TILT_MIN = c.upDown.tiltMin
            SWEEP_FRAMES = c.upDown.holdFrames
            HOLD_MS = kind == ScanIDCard.KIND_LICENCE ? c.drivingLicence.holdMs : c.residencePermit.holdMs
            TILT_SHARE = kind == ScanIDCard.KIND_LICENCE ? c.drivingLicence.tiltShare : c.residencePermit.tiltShare
        }

        // the ID front's rectangles from the profile
        emblemCell = nil; emblemInner = nil; emblemOuter = nil
        orientRoi = nil; staticFeature = nil
        let raw = c.profile.raw
        if let em = raw["emblem"] as? [String: Any] {
            emblemCell = ScanIDCard.rect(em["cell"])
            emblemInner = ScanIDCard.rect(em["inner"])
            emblemOuter = ScanIDCard.rect(em["outer"])
        }
        if let or = raw["orient"] as? [String: Any] {
            orientRoi = ScanIDCard.hueRect(or["roi"], or["hue"], ScanIDCard.num(or["minSaturation"]) ?? 0)
        }
        if let fe = raw["feature"] as? [String: Any], fe["staticHue"] != nil {
            staticFeature = ScanIDCard.hueRect(fe["roi"], fe["staticHue"], ScanIDCard.num(fe["minSaturation"]) ?? 0)
        }

        newTry()
        log("config \(c.policyVersion) profile=\(c.profile.id) aspect=\(CARD_ASPECT) tilt=\(isBack ? "none" : isFront ? "right" : "top/bottom") "
            + "tiltMin=\(TILT_MIN) frames=\(SWEEP_FRAMES) holdMs=\(HOLD_MS) emblem=\(emblemCell != nil) laminate=\(c.laminatePolicy())")
        return true
    }

    private static func num(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let n = v as? NSNumber { return n.doubleValue }
        return nil
    }

    private static func rect(_ v: Any?) -> [Double]? {
        guard let o = v as? [String: Any] else { return nil }
        return [num(o["x"]) ?? 0, num(o["y"]) ?? 0, num(o["w"]) ?? 0, num(o["h"]) ?? 0]
    }

    private static func hueRect(_ roi: Any?, _ hue: Any?, _ minSat: Double) -> [Double]? {
        guard let r = rect(roi), let h = hue as? [Any], h.count >= 2 else { return nil }
        return [r[0], r[1], r[2], r[3], num(h[0]) ?? 0, num(h[1]) ?? 0, minSat]
    }

    // =============================================================================================
    // One frame in liveness mode
    // =============================================================================================

    private func processLiveness(_ pb: CVPixelBuffer) {
        curPixelBuffer = pb                                         // this frame only (cut edge, barcode, screen image)
        defer { curPixelBuffer = nil }
        let accepted = checkCard(pb)
        lastFrameAt = nowMs()
        pollLight(lastFrameAt)
        if start {
            runLiveness(accepted, pb)
            if finalReady {                                         // verdict "continue": send the flat, unlit photo
                finalReady = false
                sendFlatPhoto()
            }
        }
        updateLivenessColor()
    }

    /// The liveness passed: the flat, unlit photo goes to the server (the liveness played its sound).
    private func sendFlatPhoto() {
        guard let photo = flatPhoto else { return }
        start = false
        sentKind = cfgKind                                          // the side sent (for the ID number check)
        DispatchQueue.main.async { self.scanIDCardDelegate?.onSend() }
        sendToServer(photo, isManualCapture: false)
    }

    // =============================================================================================
    // The card in this frame (finder head "card")
    // =============================================================================================

    /// Finds the card AND runs the Position check. lastQuad != nil: found in this frame; true: steady for stableMs.
    private func checkCard(_ pb: CVPixelBuffer) -> Bool {
        let now = nowMs()
        lastUpright = nil; lastQuad = nil; lastPixelQuad = nil; lastRawQuad = nil; lastPose = nil; lastRawPose = nil
        lastIsRaw = false; lastSharp = false

        let landscape = CVPixelBufferGetWidth(pb) > CVPixelBufferGetHeight(pb)
        guard let upright = CardLivenessVision.analysisFrame(pb, longEdge: ANALYSIS_LONG_EDGE, rotateClockwise: landscape),
              let finder = finder else { return false }
        let w = Double(upright.width), h = Double(upright.height)

        guard let r = try? finder.detect(upright, head: .card), r.found, let model = r.corners else {
            positionMiss()
            noOutline("finder found no card")
            return false
        }
        let inferred = r.inferredCorner != nil

        // tilt: the raw outline (the stabilizer drops tilted frames)
        if phase == .sweep {
            useRawFrame(model, upright, w, h, inferred)
            return false
        }

        if !Geometry.isValidQuad(model, w: w, h: h, frameMarginPx: FRAME_MARGIN_PX, minQuadAreaFrac: MIN_QUAD_AREA_FRAC) {
            positionMiss()
            noOutline("outline outside the picture / too small")
            return false
        }
        let rp = Geometry.poseOf(model)
        let rightShape = rp.aspect >= 0.6 * CARD_ASPECT && rp.aspect <= 1.6 * CARD_ASPECT
        let notSkewed = abs(rp.lr) <= 0.45 && abs(rp.tb) <= 0.45
        if !rightShape || !notSkewed {
            positionMiss()
            noOutline(String(format: "bad shape aspect=%.2f (card %.2f) lr=%.3f tb=%.3f", rp.aspect, CARD_ASPECT, rp.lr, rp.tb))
            return false
        }
        let s = stab.update(model, w: w, h: h, inferred: inferred)
        guard let steadied = s.quad, s.status == "accepted" || s.status == "moved", s.poseReliable else {
            positionMiss()
            noOutline("stabiliser \(s.status)\(s.poseReliable ? "" : " (pose unreliable)")")
            return false
        }

        lastRawPose = rp
        lastRawQuad = model
        lastUpright = upright
        lastQuad = steadied
        lastPixelQuad = model
        lastPose = Geometry.poseOf(steadied)
        let q = CardLivenessVision.quality(upright, model)
        lastSharpness = q.0
        lastGlareFrac = q.1
        lastSharp = lastSharpness >= SHARPNESS_MIN

        positionMisses = 0
        if steadySince == 0 { steadySince = now }
        return now - steadySince >= STABLE_MS
    }

    private func positionMiss() {
        positionMisses += 1
        if positionMisses >= 2 { steadySince = 0 }
    }

    private func noOutline(_ why: String) {
        if phase != .sweep && phase != .done { log("no outline (\(phase)): \(why)") }
    }

    private func useRawFrame(_ model: [Double], _ upright: LivenessImage, _ w: Double, _ h: Double, _ inferred: Bool) {
        if inferred { return }                                      // a guessed corner (finger on the edge) fakes a tilt
        if !Geometry.isValidQuad(model, w: w, h: h, frameMarginPx: FRAME_MARGIN_PX, minQuadAreaFrac: MIN_QUAD_AREA_FRAC,
                                 outside: TILT_OVERFLOW) { return }
        let p = Geometry.poseOf(model)
        if abs(p.lr) > ScanIDCard.RAW_SKEW_MAX || abs(p.tb) > ScanIDCard.RAW_SKEW_MAX || (p.lr == 0 && p.tb == 0) { return }
        lastUpright = upright
        lastQuad = model
        lastPixelQuad = model
        lastRawQuad = model
        lastPose = p
        lastRawPose = p
        lastIsRaw = true
    }

    /// The raw pose on the tilt axis of this card (lr for the ID front, tb for the licence / permit).
    private func axisOf(_ p: Pose) -> Double { axisLr ? p.lr : p.tb }

    private static func bottomAngle(_ q: [Double]) -> Double {
        guard let o = orderCorners(q) else { return .nan }
        return atan2(o[5] - o[7], o[4] - o[6])
    }

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

    /// This frame's card straightened to 480 x H with the baseline's corner roll.
    private func rectifyNow() -> [UInt32]? {
        guard let pq = lastPixelQuad, let up = lastUpright, let o = ScanIDCard.orderCorners(pq) else { return nil }
        return CardLivenessVision.rectify(up, CardLivenessVision.roll(o, baseK), CardLivenessVision.OPT_W, RECT_H)
    }

    /// checks/overlay-cut-edge.md: the cut-edge score of the card in this FULL camera frame (ID front only).
    private func measureCut(_ when: String) {
        guard isFront, let pb = curPixelBuffer, let pq = lastPixelQuad, let up = lastUpright,
              let o = ScanIDCard.orderCorners(pq), let full = CardLivenessVision.fullUprightFrame(pb) else { return }
        let q = CardLivenessVision.roll(o, baseK)                       // top left (the emblem's corner) first, clockwise
        let sc = Double(full.width) / Double(up.width)
        let score = CardLivenessVision.cutEdgeOf(full, q.map { $0 * sc })
        cutReadings.append(score)
        log(String(format: "overlay cut edge (%@): %.2f", when, score))
    }

    // =============================================================================================
    // Phases
    // =============================================================================================

    private func updateLivenessColor() {
        let color = livenessFrameGood ? ConstantsValues.DetectColor : environmentalConditions!.HoldHandColor
        // a drawing on screen (the tilt, or the barcode scan): no guide under it
        showGuide(color: color, notTransmitting: start, inTilt: tiltStart || barcodeLayoutShown)
    }

    /// The tilt drawing for the asked edge (Guide). The view is kept, and removed from the screen when the tilt ends.
    private func showTiltLayout() {
        let dir = direction
        tiltStart = true
        DispatchQueue.main.async {
            self.tiltLayoutView?.removeFromSuperview()              // never two on screen
            let v: UIView?
            switch dir {
            case "right": v = try? self.guide.showTiltIDRightLayout(view: self.view)
            case "top": v = try? self.guide.showTiltIDTopLayout(view: self.view)
            default: v = try? self.guide.showTiltIDBottomLayout(view: self.view)
            }
            self.tiltLayoutView = v
            if v == nil { print("IdLiveness: tilt drawing (\(dir)) not shown") }
        }
    }

    private func hideTiltLayouts() {
        tiltStart = false
        DispatchQueue.main.async {
            self.tiltLayoutView?.removeFromSuperview()
            self.tiltLayoutView = nil
        }
    }

    /// ID back: the barcode drawing (Guide.showBarCodeGifLayout) while the barcode is being read after the photo.
    /// Shown once per BARCODE phase; the guide is removed under it (updateLivenessColor).
    private func showBarcodeLayout() {
        if barcodeLayoutShown { return }                            // already on screen
        barcodeLayoutShown = true
        DispatchQueue.main.async {
            guard self.barcodeLayoutShown else { return }           // hidden again before this ran
            self.barcodeLayoutView?.removeFromSuperview()           // never two on screen
            self.barcodeLayoutView = try? self.guide.showBarCodeGifLayout(view: self.view)
            if self.barcodeLayoutView == nil { print("IdLiveness: barcode drawing not shown") }
        }
    }

    /// Removes the barcode drawing (read / not read in time / a restart / a retry / the background / a stall / close).
    /// The guide comes back on the next frame.
    private func hideBarcodeLayout() {
        barcodeLayoutShown = false
        let work = {
            self.barcodeLayoutView?.removeFromSuperview()
            self.barcodeLayoutView = nil
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private func runLiveness(_ accepted: Bool, _ pb: CVPixelBuffer) {
        let now = nowMs()
        if phase == .done { return }

        if let p = pause {
            if !pauseDone(now) { hint(p); return }
            pause = nil
            markTurn()
            flatSince = 0
            hint(.placeCard)
        }
        if notInHand(now) { return }

        if lastQuad != nil { lastSeen = now }
        if lastQuad == nil && lastSeen > 0 && now - lastSeen > LOSS_MS { livenessFrameGood = false }

        let watchedLoss = phase == .baseline || phase == .light
        let watchedTime = watchedLoss || phase == .sweep
        if phase == .sweep && now - lastSeen > LOSS_MS { hint(.placeCard) }
        let lossGrace = phase == .light ? Int(Double(LOSS_MS) * ScanIDCard.LIGHT_LOSS_FACTOR) : LOSS_MS
        if watchedLoss && lastSeen > 0 && now - lastSeen > lossGrace {
            restartTry("tracking_lost", now)
            return
        }
        if watchedTime && now - phaseStart > PHASE_TIMEOUT_MS {
            if phase == .sweep && reachedAt != 0 {                  // the tilt was reached: judge what we have
                log("timeout while held open: deciding now")
                measureCut("tilt end")
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
            hint(.placeCard)
            if lastQuad != nil { livenessFrameGood = true }
            if accepted && photoReady(now) {
                enterPhase(.baseline, now)
                playSuccess()                                       // seen and steady: the flat hold starts
            }
        case .baseline:
            if isBack { readBarcode(now) }                          // the back held still: try the barcode
            if checkBaseline(now) { baselineDone(pb, now) }
        case .barcode:
            checkBarcodeWait(now)
        case .light:
            checkLight(now)
        case .sweep:
            checkSweep(now)
        case .done:
            break
        }
    }

    /// The flat hold ended: THE photo, the unlit reference (and its corner roll), the flat cut-edge reading.
    private func baselineDone(_ pb: CVPixelBuffer, _ now: Int) {
        flatPhoto = convertPixelToDataImage(pixelBuffer: pb)        // flat, unlit, full camera size
        if isBack {                                                 // back: no tilt; the photo is taken before the light
            if barcodeRead {
                playSuccess()
                finishTry(engineFailed: false)
                return
            }
            // not read yet: the light on (it helps the barcode), wait up to idBarcode.waitMs while it is read
            enterPhase(.barcode, now)
            lightRequestedAt = now
            lightAvailable = setTorch(true)
            if lightAvailable { lightState = .on }
            showBarcodeLayout()                                     // the barcode drawing while it is read
            hint(.readingBarcode)
            log("IdBarcode: photo taken, barcode not read yet: light on, waiting up to \(BARCODE_WAIT_MS) ms")
            return
        }
        var b: CardLivenessVision.Baseline? = nil
        if let pq = lastPixelQuad, let up = lastUpright, let o = ScanIDCard.orderCorners(pq) {
            if isFront, let orient = orientRoi {
                b = CardLivenessVision.makeBaselineOriented(up, o, RECT_H, orient, staticFeature)
            } else {
                b = CardLivenessVision.makeBaseline(up, o, RECT_H)
            }
        }
        guard let base = b else {                                   // no usable outline on this frame: hold again
            resetBaselineHold()
            return
        }
        baseK = base.k
        unlitImg = base.img
        measureCut("flat")
        enterPhase(.light, now)
        lightRequestedAt = now
        lightAvailable = setTorch(true)
        if lightAvailable { lightState = .on }
        hint(.doNotMove)
        log(String(format: "baseline done: k=%d torch=%d tiltMin=%.3f", baseK, lightAvailable ? 1 : 0, tiltMinEffective))
    }

    // ---- ID back: the PDF417 barcode ----

    /// After the back's photo: keep reading while the card is held, the light on for a while, then go on read or not.
    private func checkBarcodeWait(_ now: Int) {
        hint(barcodeRead ? .barcodeRead : .readingBarcode)
        if lastQuad != nil { livenessFrameGood = true }
        readBarcode(now)
        let waited = now - phaseStart
        if lightState == .on && waited > LIGHT_MAX_MS + BARCODE_LIGHT_MS { lightOff(now) }   // light.barcodeMs
        if barcodeRead || waited > BARCODE_WAIT_MS {
            if !barcodeRead { log("IdBarcode: not read after \(waited) ms (\(barcodeAttempts) attempts): going on") }
            hideBarcodeLayout()                                     // read or not: the drawing goes
            playSuccess()
            finishTry(engineFailed: false)
        }
    }

    /// One reading of the barcode every idBarcode.everyMs, in the background, on the card in the FULL frame.
    private func readBarcode(_ now: Int) {
        if !isBack || barcodeRead || barcodeBusy || now - lastBarcodeAt < BARCODE_EVERY_MS { return }
        guard let pb = curPixelBuffer, let pq = lastPixelQuad, let up = lastUpright, !lastIsRaw,
              let o = ScanIDCard.orderCorners(pq) else { return }   // held still only
        lastBarcodeAt = now
        guard let full = CardLivenessVision.fullUprightFrame(pb) else { return }   // copied: the camera reuses its buffer
        barcodeBusy = true
        barcodeAttempts += 1
        let sc = Double(full.width) / Double(up.width)
        let q = o.map { $0 * sc }                                   // the card in the full frame, TL first
        let token = barcodeToken
        let attempt = barcodeAttempts
        barcodeQueue.async { [weak self] in
            defer { self?.barcodeBusy = false }
            let names = ["lower band", "lower band sharpened", "lower band thresholded",
                         "upper band", "upper band sharpened", "upper band thresholded"]
            let tries = IdBackBarcode.tries(IdBackBarcode.toGray(full), q)
            for (t, img) in tries.enumerated() {
                guard let self = self, token == self.barcodeToken, !self.barcodeRead else { return }
                if let raw = IdBackBarcode.scanPdf417(img), !raw.isEmpty {
                    if token != self.barcodeToken { return }
                    self.barcodeRead = true
                    self.printBarcode(raw, names[t], attempt)
                    return
                }
            }
        }
    }

    /// Prints what the back's barcode holds (id-back.ts): the card number and the text fields.
    private func printBarcode(_ raw: Data, _ fromTry: String, _ attempt: Int) {
        let text = IdBackBarcode.decode(raw)
        let c = IdBackBarcode.read(text)
        readNumber = c?.number                                      // for the check against the front's number
        print("IdBarcode: ===== ID back barcode READ (\(fromTry), attempt \(attempt), \(raw.count) bytes) =====")
        if let c = c {
            print("IdBarcode: number: \(c.number ?? "-")")
            let textFields = c.textFields()
            for (i, f) in textFields.enumerated() { print("IdBarcode: field \(i + 1): \(f)") }
            print("IdBarcode: fields: \(c.fields.count) in total, \(textFields.count) text (the others are binary data)")
        } else {
            print("IdBarcode: no comma-separated fields; text: \(text)")
        }
        print("IdBarcode: raw (base64): \(IdBackBarcode.toBase64(raw))")
    }

    private func enterPhase(_ p: Phase, _ now: Int) {
        phase = p
        phaseStart = now
        if p != .sweep && p != .done { setProgress(0) }
    }

    private func photoReady(_ now: Int) -> Bool { lightState == .off && now - darkAt >= OFF_SETTLE_MS }

    private func lightOff(_ now: Int) {
        if lightState == .off { return }
        if lightState == .on { offAskedAt = now }
        lightState = .goingOff
        offLastAskAt = now
        setTorch(false)
    }

    private func pollLight(_ now: Int) {
        if lightState != .goingOff { return }
        if !isTorchOn() || now - offAskedAt >= OFF_MAX_MS {
            lightState = .off
            darkAt = now
            return
        }
        if now - offLastAskAt >= ScanIDCard.OFF_REASK_MS {
            offLastAskAt = now
            setTorch(false)
        }
    }

    // ---- baseline: frontal, sharp, steady, no glare for baselineHoldMs and >= 3 poses ----

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
        let tol = ScanIDCard.HOLD_STILL_TOL
        let poseStill = baseCount == 0
            ? havePrev && abs(lr - prevLr) < tol && abs(tb - prevTb) < tol
            : abs(lr - holdLr) <= tol && abs(tb - holdTb) <= tol
        let steady = centreStill && poseStill
        prevLr = lr; prevTb = tb; prevCx = cx; prevCy = cy; havePrev = true

        let frontal = abs(lr) <= ScanIDCard.HOLD_FRONTAL_MAX && abs(tb) <= ScanIDCard.HOLD_FRONTAL_MAX
        let glare = lastGlareFrac > ScanIDCard.HOLD_GLARE_MAX
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
        if let rp = lastRawPose { baselineAxis.append(axisOf(rp)) }
        if let rq = lastRawQuad {
            let a = ScanIDCard.bottomAngle(rq)
            if !a.isNaN { baselineAngles.append(a) }
        }
        if now - baseHoldSince >= BASELINE_HOLD_MS && baseCount >= ScanIDCard.BASELINE_MIN_POSES {
            baseAngle = baselineAngles.isEmpty ? .nan : ScanIDCard.median(baselineAngles)
            tiltMinEffective = max(TILT_MIN, TILT_NOISE_K * ScanIDCard.popStd(baselineAxis))
            return true
        }
        return false
    }

    private func holdMiss() {
        if baseCount > 0 && !holdGraceUsed { holdGraceUsed = true; return }
        resetBaselineHold()
    }

    private func resetBaselineHold() {
        holdGraceUsed = false
        baseCount = 0
        baseHoldSince = 0
        baselineAxis.removeAll()
        baselineAngles.removeAll()
    }

    // ---- light: lit frames against the unlit reference; the ID front's emblem is read here; then the lit reference ----

    private func checkLight(_ now: Int) {
        guard let c = cfg, let reflection = reflection else { return }
        hint(.doNotMove)
        if lightAvailable && !isTorchOn() && now - lightRequestedAt > ScanIDCard.TORCH_CONFIRM_MS {
            lightAvailable = false
            lightOff(now)
        }
        if !lightAvailable {                                        // no light: the unlit frame stays the reference
            litImg = unlitImg
            if let l = litImg { iridBase = CardLivenessVision.iridBase(l, CardLivenessVision.OPT_W, RECT_H) }
            axisRef = ScanIDCard.rawReference(lightAxis, baselineAxis)
            goToSweep(now)
            return
        }
        let waited = now - lightRequestedAt
        if !lightEnded {
            if waited >= LIGHT_SETTLE_MS && lastPixelQuad != nil, let cur = rectifyNow(), let unlit = unlitImg {
                let sample = CardLivenessVision.pageResponse(unlit, cur, CardLivenessVision.OPT_W, RECT_H)
                reflection.addLit(sample)
                lightSharp += 1
                livenessFrameGood = true
                if let rp = lastRawPose { lightAxis.append(axisOf(rp)) }
                if isFront, let cell = emblemCell, let inner = emblemInner, let outer = emblemOuter,
                   let e = CardLivenessVision.emblemReading(unlit, cur, CardLivenessVision.OPT_W, RECT_H, cell, inner, outer) {
                    emblemLit.append(e)
                }
                if !litEarlyCut {                                   // overlay: the first lit frame ("lit early")
                    litEarlyCut = true
                    measureCut("lit early")
                }
                if let s = sample {
                    log(String(format: "light frame spec=%.4f flare=%.5f veil=%.3f emblem=%@", s[0], s[2], s[3],
                               emblemLit.last.map { String(format: "%.1f/%.1f", $0[0], $0[1]) } ?? "-"))
                }
            }
            let whitedOut = reflection.usable() < c.reflection.minLitFrames
            let normalEnd = (lightSharp >= LIGHT_FRAMES && !whitedOut) || waited > LIGHT_MAX_MS
            // capture.ts:1386: the ID front keeps the light on while the emblem has not answered (up to emblem.extraMs)
            let waitEmblem = isFront && emblemCell != nil && lightSharp >= LIGHT_FRAMES
                && waited <= LIGHT_MAX_MS + c.emblem.extraMs
                && LivenessGate.emblemResult(emblemLit, configured: true, tilt: nil, tested: true, c.emblem).state != "present"
            if normalEnd && !waitEmblem {
                lightEnded = true
                _ = tooBright(now)
            }
            return
        }
        if pause != nil || phase != .light { return }
        guard let lit = rectifyNow() else { return }
        litImg = lit
        iridBase = CardLivenessVision.iridBase(lit, CardLivenessVision.OPT_W, RECT_H)
        axisRef = ScanIDCard.rawReference(lightAxis, baselineAxis)
        measureCut("light end")
        log(String(format: "light done: lit=%d usable=%d axisRef=%.3f", lightSharp, reflection.usable(), axisRef))
        goToSweep(now)
    }

    private func tooBright(_ now: Int) -> Bool {
        guard let c = cfg, let refl = reflection else { return false }
        if sunPauses >= SUN_MAX || !lightAvailable || isBatteryTooLow() { return false }
        let r = refl.result()
        let lift = r.litLift ?? 9
        let brightAgain = brightMiss && lift <= BRIGHT_LIFT
        if c.reflection.policy != "enforce" || !(r.state == "emissive" || brightAgain) { return false }
        sunPauses += 1
        brightMiss = false
        startPause(.tooBright, "too_bright", now)
        return true
    }

    private static func rawReference(_ light: [Double], _ baseline: [Double]) -> Double {
        if light.count >= 2 { return median(light) }
        if !baseline.isEmpty { return median(baseline) }
        return .nan
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

    // ---- sweep: ID front the RIGHT edge (lr, sign -1); licence / permit top (+1) or bottom (-1) on tb ----

    private func goToSweep(_ now: Int) {
        resetSweep()
        markTurn()
        if isFront {
            direction = "right"                                     // emblem.direction, forced
            axisLr = true
            sign = -1
        } else {
            direction = Double.random(in: 0..<1) < 0.5 ? "top" : "bottom"   // challenge-engine.ts:313
            axisLr = false
            sign = direction == "top" ? 1 : -1
        }
        lastMoveAt = now
        enterPhase(.sweep, now)
        showTiltLayout()
        hint(liftHint())
        log("tilt: lift the \(direction) edge")
    }

    private func liftHint() -> IdLivenessInstruction {
        direction == "right" ? .liftRight : direction == "top" ? .liftTop : .liftBottom
    }

    private func checkSweep(_ now: Int) {
        guard let c = cfg, let pose = lastPose, lastQuad != nil else { return }
        if !isSameDocument(now) {
            restartTry("continuity_lost", now)
            return
        }
        let v = axisOf(pose)
        if axisRef.isNaN { axisRef = v }                            // no reference yet: this frame is it
        let need = tiltMinEffective
        let d = sign * (v - axisRef)                                // toward: + = the asked edge lifted toward the camera
        if abs(d) <= ScanIDCard.SWEEP_FLAT_EPS { sweepSawFlat = true }
        if abs(d - prevDelta) > ScanIDCard.MOVE_EPS { lastMoveAt = now }
        prevDelta = d
        sweepMoved = max(sweepMoved, abs(d))
        if meterFrom.isNaN { meterFrom = pose.lr }

        // this frame's card readings
        let cur = litImg != nil ? rectifyNow() : nil
        if let cur = cur, let lit = litImg, isFront, let cell = emblemCell, let inner = emblemInner, let outer = emblemOuter {
            let e = CardLivenessVision.emblemReading(lit, cur, CardLivenessVision.OPT_W, RECT_H, cell, inner, outer)
            emblemTilt.append([pose.lr, e?[0] ?? .nan])
        }
        if let cur = cur, isLaminateCard,
           let irid = CardLivenessVision.iridescence(iridBase, CardLivenessVision.chromaGrid(cur, CardLivenessVision.OPT_W, RECT_H)) {
            iridTilt.append(irid)
        }

        let angleNow = lastRawQuad.map { ScanIDCard.bottomAngle($0) } ?? .nan
        var turned = false
        if !angleNow.isNaN && !baseAngle.isNaN {
            let t = angleNow - baseAngle
            turned = abs(atan2(sin(t), cos(t))) > ANGLE_MAX
        }
        if sweepFrom.isNaN { sweepFrom = v }
        sweepWrong = sign * (v - sweepFrom) <= -need ? sweepWrong + 1 : 0
        let hit = !turned && d >= need && sweepSawFlat
        sweepGood = hit ? sweepGood + 1 : 0
        if hit { livenessFrameGood = true }
        if sweepGood >= SWEEP_FRAMES && reachedAt == 0 { reachedAt = now }

        // tilt meter (capture.ts:331): ID front from the starting lr to tiltTarget; licence tilt + colours (tiltShare)
        let lam: LivenessGate.LaminateResult? = isLaminateCard ? LivenessGate.iridescenceResult(iridTilt, c.laminate) : nil
        var meter: Double
        if isFront {
            meter = (meterFrom - pose.lr) / max(0.08, meterFrom + c.emblem.tiltTarget)
        } else {
            let tiltPart = reachedAt != 0 ? 1 : (sweepSawFlat ? d / need : 0)
            meter = TILT_SHARE * max(0, min(1, tiltPart)) + (1 - TILT_SHARE) * colourProgress(lam)
        }
        setProgress(Int((100 * max(0, min(1, meter))).rounded()))

        var extra = ""
        if let l = lam { extra = String(format: " | colours frames=%d hues=%d peak=%.4f strong=%d", l.frames, l.hues, l.peakOr0, l.strong ? 1 : 0) }
        else if isFront, let last = emblemTilt.last { extra = String(format: " | emblem %.1f", last[1]) }
        log(String(format: "tilt %@ v=%.3f ref=%.3f toward=%.3f need=%.3f turned=%d good=%d%@",
                   direction, v, axisRef, d, need, turned ? 1 : 0, sweepGood, extra))

        if reachedAt != 0 {
            // held open while the reading is not there yet: the emblem lit but not dark yet / the colours not strong yet
            let awaiting: Bool
            if isFront {
                awaiting = emblemCell != nil && LivenessGate.emblemResult(emblemLit, configured: true,
                                                                          tilt: emblemWhenTilted(), tested: false, c.emblem).state == "untested"
            } else {
                let coloursDecide = (lightAvailable ? c.laminatePolicy() : "shadow") == "enforce"
                awaiting = c.profile.iridescent && coloursDecide && lam != nil && !lam!.strong
            }
            if awaiting && now - reachedAt < HOLD_MS {
                livenessFrameGood = true
                hint(atEdge() ? .holdThere : .aBitMore)
                return
            }
            measureCut("tilt end")
            playSuccess()
            finishTry(engineFailed: false)
            return
        }

        if sweepWrong >= WRONG_WAY_FRAMES { hint(.otherEdge) }
        else if now - phaseStart > STUCK_MS && sweepMoved < need / 2 { hint(.pickUp) }
        else if d >= need && !sweepSawFlat { hint(.keepFlat) }
        else { hint(liftHint()) }
    }

    /// capture.ts:1318 emblemWhenTilted: the emblem where the right edge is toward the camera (lr <= -tiltSide), else NaN.
    private func emblemWhenTilted() -> [Double] {
        guard let c = cfg else { return [] }
        return emblemTilt.map { $0[0] <= -c.emblem.tiltSide ? $0[1] : .nan }
    }

    /// capture.ts:1321 emblemTested: minTiltFrames rows in a row with lr <= -testTilt.
    private func emblemTested() -> Bool {
        guard let c = cfg else { return false }
        var run = 0
        for row in emblemTilt {
            run = row[0] <= -c.emblem.testTilt ? run + 1 : 0
            if run >= c.emblem.minTiltFrames { return true }
        }
        return false
    }

    private func colourProgress(_ r: LivenessGate.LaminateResult?) -> Double {
        guard let r = r, let peak = r.peak, let lc = cfg?.laminate else { return 0 }
        let p = min(min(Double(r.hues) / Double(lc.strongHues), peak / lc.strongPeak),
                    min(Double(r.litFrames) / Double(lc.minLitFrames), Double(r.frames) / Double(lc.minFrames)))
        return max(0, min(1, p))
    }

    private func atEdge() -> Bool {
        guard let q = lastQuad, let up = lastUpright else { return false }
        let w = Double(up.width), h = Double(up.height)
        for i in 0..<4 {
            let x = q[2 * i], y = q[2 * i + 1]
            if x < EDGE_MARGIN * w || x > (1 - EDGE_MARGIN) * w || y < EDGE_MARGIN * h || y > (1 - EDGE_MARGIN) * h { return true }
        }
        return false
    }

    private func isSameDocument(_ now: Int) -> Bool {
        guard let q = lastQuad, let up = lastUpright, let o = ScanIDCard.orderCorners(q) else { return true }
        let fw = Double(up.width), fh = Double(up.height)
        let bx = (o[4] + o[6]) / 2 / fw, by = (o[5] + o[7]) / 2 / fh, len = ScanIDCard.dist(o, 2, 3) / fw
        var same = true
        if sweepRefSet && now - sweepLastSeenAt > LOSS_MS {
            let maxLen = sqrt(AREA_JUMP_MAX), ratio = len / max(sweepRefLen, 1e-6)
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
        sweepRefSet = false
        sweepLastSeenAt = 0
        prevDelta = 0
        sweepMoved = 0
        sweepFrom = .nan
        meterFrom = .nan
        lastMoveAt = 0
        reachedAt = 0
        iridTilt.removeAll()
        emblemTilt.removeAll()
        shownInstruction = nil
    }

    // =============================================================================================
    // Verdict
    // =============================================================================================

    private func finishTry(engineFailed: Bool) {
        guard let c = cfg else { return }
        let now = nowMs()
        lightOff(now)
        hideTiltLayouts()
        hideBarcodeLayout()
        phase = .done

        let i = LivenessGate.GateInput()
        i.cameraOk = true
        i.enginePhase = engineFailed ? "failed" : "done"
        i.attempt = engineAttempts + retriesThisVisit
        i.challenge = engineFailed ? "not_observed" : "observed"
        i.optical = "not_configured"                                // optical cedar check: recorded only
        i.opticalPolicy = "shadow"
        i.matteBefore = matteBefore
        i.matteNotEvidence = c.profile.page
        i.batteryLow = isBatteryTooLow()
        i.photoOk = engineFailed ? nil : flatPhoto != nil

        var detail: String
        let refl = reflection?.result()
        if isBack {
            // the back: the photo only. Its reflection policy is back.policy (shadow) and no light was used.
            i.reflection = "unassessable"
            i.reflectionPolicy = c.back.policy
            i.lightAvailable = nil
            detail = "back: flat photo only"
        } else {
            i.reflection = refl?.state ?? "unassessable"
            i.reflectionPolicy = c.reflection.policy
            i.lightAvailable = lightAvailable
            if isFront {
                let em = LivenessGate.emblemResult(emblemLit, configured: emblemCell != nil,
                                                   tilt: emblemWhenTilted(), tested: emblemTested(), c.emblem)
                i.emblem = em.state
                i.emblemRequired = emblemCell != nil
                i.emblemPolicy = lightAvailable ? c.emblem.policy : "shadow"
                // overlay: the second highest of two or more readings against barSeveral, one against bar
                let all = cutReadings.sorted(by: >)
                let cut: Double? = all.count >= 2 ? all[1] : all.first
                i.cutEdge = cut == nil ? "unassessable" : cut! > (all.count >= 2 ? c.overlay.barSeveral : c.overlay.bar) ? "cut" : "clear"
                i.cutEdgePolicy = c.overlay.policy
                detail = "emblem=\(em.state) (lit=\(String(describing: em.lit)) jump=\(String(describing: em.jump)) "
                    + "low=\(String(describing: em.low)) frames=\(em.frames)) cut=\(i.cutEdge!) \(all)"
            } else {
                let lam = LivenessGate.iridescenceResult(iridTilt, c.laminate)
                i.laminate = lam.state
                i.laminatePolicy = lightAvailable ? c.laminatePolicy() : "shadow"
                i.laminateStrong = lam.strong
                i.laminateRequired = c.profile.iridescent
                detail = String(format: "laminate=%@ (frames=%d lit=%d hues=%d peak=%.4f strong=%d) tilt=%@",
                                lam.state, lam.frames, lam.litFrames, lam.hues, lam.peakOr0, lam.strong ? 1 : 0, direction)
            }
        }

        let decision = LivenessGate.decide(i, maxAttempts: MAX_ATTEMPTS)
        var reasons = decision.reasons + tryReasons + flags
        if isBack { reasons.append(barcodeRead ? "back_barcode_read" : "back_barcode_unread") }   // recorded only
        let reflText = refl.map { "\($0.state) (lit=\($0.usable) flare=\(String(describing: $0.litFlare)) lift=\(String(describing: $0.litLift)))" } ?? "-"
        print("IdLiveness: VERDICT \(decision.verdict) \(reasons) | kind=\(cfgKind ?? "-") reflection=\(reflText) \(detail) attempt=\(i.attempt)")

        let first = decision.reasons.contains { $0.hasSuffix("_first") }
        let neutral = decision.reasons.contains {
            $0 == "emblem_untested" || $0 == "no_response_to_light" || $0 == "reflection_matte_unproven"
        }
        matteBefore = first || (matteBefore && neutral)
        let lift = refl?.litLift ?? 9
        brightMiss = decision.verdict == LivenessGate.RETRY && lift <= BRIGHT_LIFT && c.profile.page
        if decision.verdict != LivenessGate.CONTINUE { livenessFrameGood = false }

        // the ID back: not read -> it goes on (recorded only); read -> its number must be the front's
        // (now, when the front is already done; otherwise when the front's answer arrives)
        var barcodeShown = false
        if isBack && decision.verdict == LivenessGate.CONTINUE {
            if !barcodeRead || readNumber == nil {
                backNumber = nil                                    // nothing to compare with the front
                print("IdBarcode: back accepted WITHOUT the barcode (not read): no number check")
            } else if let front = frontNumber, !ScanIDCard.sameIdNumber(readNumber!, front) {
                print("IdBarcode: back REJECTED: barcode number \(readNumber!) is not the front's document number \(front) -> onRetry")
                livenessFrameGood = false
                start = false
                notifyRetry()
                return
            } else {
                backNumber = readNumber                             // this back passes: its number is kept
                barcodeShown = true
                print("IdBarcode: back accepted, number \(backNumber!)"
                      + (frontNumber != nil ? " = the front's \(frontNumber!)" : " (the front is not done yet: checked then)"))
            }
        }

        switch decision.verdict {
        case LivenessGate.CONTINUE:
            setProgress(100)
            hint(barcodeShown ? .barcodeRead : .keepHolding)
            livenessFrameGood = true
            finalReady = true                                       // processLiveness sends the flat photo
        case LivenessGate.RETRY:
            retriesThisVisit += 1
            newTry()
        default:                                                    // suspected_copy / inconclusive
            start = false
            notifyLivenessFailed()
        }
    }

    /// The ID back failed its number check: the retry screen (onRetry).
    private func notifyRetry() {
        pendingReset = true
        DispatchQueue.main.async {
            self.scanIDCardDelegate?.onRetry(dataModel: RemoteProcessingModel(
                destinationEndpoint: HubConnectionTargets.ON_RETRY,
                response: "",
                error: EventsErrorMessages.OnRetryCardMessage,
                success: false))
        }
    }

    /// suspected_copy / inconclusive / the camera stalled: the liveness screen (onLivenessUpdate, no server response).
    /// image: the card as the camera saw it, the flat photo if the try got that far, else this frame (made now, on the
    /// camera thread, before the camera reuses its buffer; nil on a stall with no photo).
    private func notifyLivenessFailed() {
        pendingReset = true
        let image = LivenessScreenImage.make(photo: flatPhoto, frame: curPixelBuffer)
        DispatchQueue.main.async {
            self.scanIDCardDelegate?.onLivenessUpdate?(dataModel: RemoteProcessingModel(
                destinationEndpoint: HubConnectionTargets.ON_LIVENESS_UPDATE,
                response: "",
                error: EventsErrorMessages.OnLivenessCardUpdateMessage,
                success: false), image: image)
        }
    }

    /// The same ID number? Digits only (Arabic-Indic digits read as 0-9, separators dropped), leading zeros ignored:
    /// the barcode holds 12 digits ("000012345678"), the server may give the number without its zeros.
    private static func sameIdNumber(_ a: String, _ b: String) -> Bool {
        let x = idDigits(a), y = idDigits(b)
        return !x.isEmpty && x == y
    }

    private static func idDigits(_ s: String) -> String {
        var d = ""
        for u in s.unicodeScalars {
            switch u.value {
            case 0x30...0x39: d.append(Character(u))
            case 0x0660...0x0669: d.append(Character(UnicodeScalar(0x30 + u.value - 0x0660)!))   // Arabic-Indic
            case 0x06F0...0x06F9: d.append(Character(UnicodeScalar(0x30 + u.value - 0x06F0)!))   // Extended Arabic-Indic
            default: break
            }
        }
        while d.count > 1 && d.hasPrefix("0") { d.removeFirst() }
        return d
    }

    /// The front's document number from the server's answer (IdentificationDocumentCapture_Document_Number), or nil.
    private static func documentNumberOf(_ props: [String: Any]?) -> String? {
        guard let props = props else { return nil }
        for (k, v) in props {
            let key = k.lowercased().replacingOccurrences(of: "_", with: "")
            guard key.hasSuffix("documentnumber") else { continue }
            let s = String(describing: v).trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty && s.lowercased() != "null" && s.lowercased() != "<null>" { return s }
        }
        return nil
    }

    // =============================================================================================
    // Restarts, tries, pauses, stall, background
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
        if tiltStart { hideTiltLayouts() }
        if barcodeLayoutShown { hideBarcodeLayout() }
        livenessFrameGood = false
        steadySince = 0
        positionMisses = 0
        lastSeen = 0
        havePrev = false
        resetBaselineHold()
        baseAngle = .nan
        flatPhoto = nil
        finalReady = false
        unlitImg = nil; litImg = nil; iridBase = nil
        baseK = 0
        lightAvailable = false; lightEnded = false; litEarlyCut = false
        lightRequestedAt = 0
        lightSharp = 0
        lightAxis.removeAll()
        emblemLit.removeAll()
        cutReadings.removeAll()
        barcodeToken += 1                                           // a reading still running belongs to the old try
        barcodeRead = false
        readNumber = nil
        lastBarcodeAt = 0
        barcodeAttempts = 0
        axisRef = .nan
        tiltMinEffective = TILT_MIN
        axisLr = isFront                                            // licence: tb, ID front: lr (before the baseline)
        reflection = cfg.map { LivenessGate.ReflectionAnalyzer($0.reflection) }
        resetSweep()
        shownInstruction = nil
        stab = OutlineStabilizer(docAspect: CARD_ASPECT)
        enterPhase(.position, now)
    }

    private func resetLiveness() {
        if cfg != nil { newTry() }
    }

    private func hint(_ instruction: IdLivenessInstruction) {
        if instruction == shownInstruction && livenessProgress == shownProgress { return }
        shownInstruction = instruction
        shownProgress = livenessProgress
        let progress = livenessProgress
        DispatchQueue.main.async {
            self.scanIDCardDelegate?.onLivenessInstruction?(instruction: instruction, progress: progress)
        }
    }

    private func setProgress(_ p: Int) {
        livenessProgress = max(0, min(100, p))
        if let s = shownInstruction, livenessProgress != shownProgress { hint(s) }
    }

    private func playSuccess() {
        DispatchQueue.main.async { self.audioPlayer.playAudio(fileName: ConstantsValues.AudioCardSuccess) }
    }

    private func startPause(_ card: IdLivenessInstruction, _ reason: String, _ now: Int) {
        restartTry(reason, now)
        if phase == .done { return }
        pause = card
        pauseAt = now
        hint(card)
    }

    private func pauseDone(_ now: Int) -> Bool {
        let shown = now - pauseAt
        if shown >= ScanIDCard.PAUSE_MAX_MS { return true }
        if shown < ScanIDCard.PAUSE_SHOW_MS { return false }
        if pause == .holdInHand {
            let flat = phoneFlat(now)
            return flat == nil || flat == false
        }
        return true
    }

    /// No analysed frame for stallMs ends the capture (vision_stalled). Runs on the main thread (Timer).
    private func checkStall() {
        guard cfg != nil, livenessKind != nil, start, phase != .done else { return }
        let last = lastFrameAt
        if last == 0 || nowMs() - last <= STALL_MS { return }
        log("vision_stalled: no frame for \(STALL_MS) ms")
        setTorch(false)
        lightState = .off
        darkAt = nowMs()
        hideTiltLayouts()
        hideBarcodeLayout()
        phase = .done
        start = false
        notifyLivenessFailed()
    }

    @objc private func appWillResignActive() { interrupt() }

    private func interrupt() {
        if cfg == nil { return }
        setTorch(false)
        hideTiltLayouts()
        hideBarcodeLayout()
        lightState = .off
        darkAt = nowMs()
        pendingReset = true
    }

    private func markTurn() { markX = gravX; markY = gravY; markZ = gravZ }

    private func turnedSince() -> Double {
        if gravX.isNaN || markX.isNaN { return 0 }
        let dot = max(-1, min(1, gravX * markX + gravY * markY + gravZ * markZ))
        return acos(dot) * 180 / Double.pi
    }

    /// Hand pauses (not on the back): phone flat over a table in position / baseline / light, the phone turned in the tilt.
    private func notInHand(_ now: Int) -> Bool {
        if isBack || handPauses >= MAX_HAND_PAUSES { return false }
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
        if table && !TABLE_CARD {
            if !flags.contains("flag_on_table") { flags.append("flag_on_table") }
            flatSince = 0
            return false
        }
        handPauses += 1
        flatSince = 0
        let flag = table ? "flag_on_table" : "flag_phone_tilted"
        if !flags.contains(flag) { flags.append(flag) }
        markTurn()
        startPause(table ? .holdInHand : .phoneTurned, table ? "on_table" : "phone_tilted", now)
        return true
    }

    private func phoneFlat(_ now: Int) -> Bool? {
        if phoneTiltDeg.isNaN || now - phoneTiltAt > ScanIDCard.MOTION_FRESH_MS { return nil }
        return phoneTiltDeg < FLAT_DEG
    }

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

    private func isBatteryTooLow() -> Bool {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        if level < 0 { return false }
        let charging = device.batteryState == .charging || device.batteryState == .full
        return !charging && Double(level) < BATTERY_LOW
    }

    // ---- torch ----

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
        if ScanIDCard.DEBUG_LOGS { print("IdLivenessDebug: \(s())") }
    }
}
