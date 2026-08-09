

import Foundation
import UIKit
import AVFoundation
import Accelerate
import CoreImage

public class FaceMatch :UIViewController, CameraSetupDelegate , RemoteProcessingDelegate {
    
    
    var guide : Guide = Guide();
    var countdownLabel : UIView?;
    var countdownTimer: Timer?
    var previewView: PreviewView!
    var cameraFeedManager:CameraFeedManager!
    private let overlayView = OverlayView()
    private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    private var modelDataHandler: ModelDataHandler? =
    ModelDataHandler(modelFileInfo: Yolov5.modelInfo, labelsFileInfo: Yolov5.labelsInfo,isFront: true)
    private var result: Result?
    var motionRectF: [CGRect] = []
    var sendingFlags: [MotionType] = []
    var sendingFlagsZoom: [ZoomType] = []
    
    private var faceMatchDelegate: FaceMatchDelegate?
    private var configModel: ConfigModel?
    private var environmentalConditions: EnvironmentalConditions?
    private var apiKey: String
    private var performLivenessFace: Bool?
    private var performPassiveLivenessFace: Bool?
    private var saveCapturedVideoFace: Bool?
    private var storeImageStream: Bool?
    private var secondImage: String?
    private var stepId:Int?;
    
    private var remoteProcessing: RemoteProcessing?
    private var motion:MotionType = MotionType.NO_DETECT;
    private var zoom:ZoomType = ZoomType.NO_DETECT;
    
    private var detectIfRectFInsideTheScreen = DetectIfRectInsideTheScreen();
    private var isRectFInsideTheScreen:Bool = false;
    private var showCountDown:Bool = true;
    private var isCountDownStarted:Bool = true;
    private var  start = true;
    private var  canCheckLive = true;
    private var  isManual = false;
    private var  startCollectingClips = false;
    
    
    private var faceQualityCheck = FaceQualityCheck()
    private var faceEvent = FaceEvents.NO_DETECT;
    private var eventCompletionList: [FaceEventStatus] = []
    private var audioPlayer = AssetsAudioPlayer();
    
    private var errorLiveView : UIView?
    private var successLiveView : UIView?
    private var activeLiveMove : UIView?
    private var  frameCounter = 0;
    private var  frameCounterLivness = 0;
    private var  processEveryNFrames = 2;
    private var  currentImage : CVPixelBuffer?;
    private var  livnessRetryCount = 0;
    
    var livenessCheckArray: [CVPixelBuffer] = [] {
           didSet {
               DispatchQueue.main.async {}
           }
       }
    private var  localLivenessLimit = 0;

    init(configModel: ConfigModel!,
         environmentalConditions :EnvironmentalConditions,
         apiKey:String,
         performLivenessFace:Bool,
         faceMatchDelegate:FaceMatchDelegate,
         secondImage:String,
         showCountDown:Bool,
         isManual:Bool
    ) {
        self.configModel = configModel;
        self.environmentalConditions = environmentalConditions;
        self.apiKey = apiKey;
        self.performLivenessFace = performLivenessFace;
        self.faceMatchDelegate = faceMatchDelegate;
        self.secondImage = secondImage;
        self.showCountDown = showCountDown;
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
            let steps = self.configModel?.stepDefinitions.filter { $0.stepDefinition == "FaceImageAcquisition" }

            if steps?.count == 1 {
                if let step = steps?.first {
                    self.stepId = step.stepId
                }
            } else {
                if self.stepId == nil {
                    fatalError("Step ID is required because multiple 'FaceImage Acquisition' steps are present.")
                }
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
        
        
        if(self.performPassiveLivenessFace!){
                   localLivenessLimit = 12;
               }else{
                   localLivenessLimit = 0;
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
        
        
        self.cameraFeedManager = CameraFeedManager(previewView: self.previewView,isFront: true)
        self.cameraFeedManager.checkCameraConfigurationAndStartSession()
        self.cameraFeedManager.delegate = self
        
        self.remoteProcessing = RemoteProcessing()
        
        
        if(self.isManual){
            if(environmentalConditions!.enableGuide){
                if(self.guide.faceSvgImageView == nil){
                    self.guide.showFaceGuide(view: self.view)
                }
                self.guide.changeFaceColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
            }
        }else{
            if (self.performLivenessFace! && self.environmentalConditions?.activeLiveType != ActiveLiveType.NONE && environmentalConditions?.activeLivenessCheckCount != 0) {
                self.fillCompletionMap();
            } else {
                eventCompletionList = []
            }
            
            
            if(environmentalConditions!.enableGuide && !self.performLivenessFace!){
                if(self.guide.faceSvgImageView == nil){
                    self.guide.showFaceGuide(view: self.view)
                }
                self.guide.changeFaceColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
            }
        }
       
        
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
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
            if(environmentalConditions!.enableGuide){
                DispatchQueue.main.async {
                    if(self.guide.faceSvgImageView == nil){
                        self.guide.showFaceGuide(view: self.view)
                    }
                    self.guide.changeFaceColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
                }
            }
            if(self.startCollectingClips){
                if(self.performPassiveLivenessFace!){
                       if(livenessCheckArray.count < self.localLivenessLimit){
                           self.faceMatchDelegate?.onCollectingManualImages()
                           frameCounterLivness += 1
                             if frameCounterLivness % processEveryNFrames == 0 {
                                 DispatchQueue.global(qos: .background).async { [weak self] in
                                             guard let self = self else { return }
                                             if let copiedBuffer = copyPixelBuffer(pixelBuffer) {
                                                 DispatchQueue.main.async {
                                                     self.livenessCheckArray.append(copiedBuffer)
                                                 }
                                             }
                                         }
                                     }
                                   
                       }
                    if(livenessCheckArray.count == self.localLivenessLimit){
                        self.start = false;
                        self.startCollectingClips = false
                        self.faceMatchDelegate?.onSend();
                        
                        let converter = ParallelImageProcessing()
                        converter.setPixelBuffers(self.livenessCheckArray)
                        converter.convertBuffers {
                        ///
                        let clips = converter.getClips()
                        let selfieImage: Data
                        if !clips.isEmpty {
                                let middleIndex = clips.count / 2
                                selfieImage = clips[middleIndex]
                         } else {
                                selfieImage = convertPixelToDataImage(pixelBuffer: pixelBuffer)!
                        }
                        var secondDataImage = base64ToData(self.secondImage!)!
                        ///
                        self.remoteProcessing?.starProcessingFace(
                            url: BaseUrls.signalRHub +  HubConnectionFunctions.etHubConnectionFunction(blockType:BlockType.FACE_MATCH),
                            appConfiguration:self.configModel!,
                            stepIdString: String(self.stepId!),
                            selfieImage: selfieImage,
                            livenessFrames :clips,
                            secondImage:secondDataImage,
                            isLivenessEnabled: self.performPassiveLivenessFace!,
                            retryCount:self.livnessRetryCount,
                            isManualCapture:false,
                            isAutoCapture: true,
                            connectionId: "ConnectionId",
                            onProgress: { progress in
                                self.faceMatchDelegate?.onUploadingProgress(progress: progress);
                            },
                        ) { result in
                            switch result {
                            case .success(let model):
                                self.onMessageReceived(eventName: model?.destinationEndpoint ?? "",remoteProcessingModel: model!)
                            case .failure(let error):
                                self.start = true;
                                self.onMessageReceived(eventName: HubConnectionTargets.ON_ERROR ,remoteProcessingModel: RemoteProcessingModel(
                                    destinationEndpoint: HubConnectionTargets.ON_ERROR,
                                    response: "",
                                    error: EventsErrorMessages.OnErrorMessage,
                                    success: false
                                ))
                            }
                        }}
                        
                    }
                   }
            }
        }else{
            if (self.areAllEventsDone()) {
                self.faceMatchDelegate?.onCurrentLiveMoveChange!(activeLiveEvents: ActiveLiveEvents.GOOD);
            }
            
            if(self.areAllEventsDone()){
                DispatchQueue.main.async {
                    self.clearLiveUi();
                    if(self.errorLiveView != nil){
                        self.errorLiveView?.removeFromSuperview();
                    }
                    if(self.successLiveView != nil){
                        self.successLiveView?.removeFromSuperview();
                    }
                }
            }
            runModel(onPixelBuffer: pixelBuffer)
            openCvCheck(pixelBuffer: pixelBuffer)
            let cropRect = CGRect(x: 0, y: 0, width: 256, height: 256)
            let imageBrightnessChecker = cropPixelBuffer(pixelBuffer, toRect: cropRect)!.brightness;
            if motionRectF.count >= 2 {
                let rect1 = motionRectF[motionRectF.count - 2]
                let rect2 = motionRectF[motionRectF.count - 1]
                motion = calculateFaceMotion(rect1: rect1, rect2: rect2)
                zoom = calculatePercentageChangeWidth(rect: rect2,pixelBuffer: pixelBuffer)
            }
            
            DispatchQueue.main.async {
                self.faceMatchDelegate?.onEnvironmentalConditionsChange?(
                    brightnessEvents:self.environmentalConditions!.checkConditions(
                        brightness: imageBrightnessChecker),
                    motion: self.motion,faceEvents:!self.start && self.areAllEventsDone() ? FaceEvents.GOOD : self.faceEvent,zoom: self.zoom,detectedFaces: self.faces(),isCentered: self.isRectFInsideTheScreen)
            }
        }
       
    }
    
    
    @objc func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {
        result = self.modelDataHandler?.runModel(onFrame: pixelBuffer)
        if (result?.inferences.count == 0) {
            livenessCheckArray.removeAll()
            motionRectF.removeAll()
            sendingFlagsZoom.removeAll()
            sendingFlags.removeAll()
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
            if(inference.className == "face"){
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
            
            if(inference.className == "face"){
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
        if(environmentalConditions!.enableDetect && start && self.areAllEventsDone()){
            self.view.addSubview(self.overlayView)
        }else{
            self.overlayView.removeFromSuperview()
        }
        
    }
    
    
    func openCvCheck(pixelBuffer: CVPixelBuffer){
        
        let cropRect = CGRect(x: 0, y: 0, width: 256, height: 256)
        let cropPixelBuffer = cropPixelBuffer(pixelBuffer, toRect: cropRect)!;
        if motionRectF.count >= 2 {
            let rect1 = motionRectF[motionRectF.count - 2]
            let rect2 = motionRectF[motionRectF.count - 1]
            motion = calculateFaceMotion(rect1: rect1, rect2: rect2)
            zoom = calculatePercentageChangeWidth(rect: rect2,pixelBuffer: pixelBuffer)
        }
        
        
        frameCounter += 1
        if frameCounter % processEveryNFrames == 0 {
            if let downscaledBuffer = downscalePixelBuffer(pixelBuffer, scaleFactor: 0.3) {
                faceQualityCheck.checkQualityAction(pixelBuffer: downscaledBuffer) { faceEvent in
                    DispatchQueue.main.async {
                        self.faceEvent = faceEvent
                        if (self.performLivenessFace! && !self.areAllEventsDone() && self.environmentalConditions?.activeLiveType != ActiveLiveType.NONE && self.environmentalConditions?.activeLivenessCheckCount != 0) {
                            if(self.canCheckLive && self.environmentalConditions?.activeLiveType == ActiveLiveType.ACTIONS){
                                self.isSpecificItemFlagEqualToActions(targetEvent: faceEvent);
                            }
                            
                        }
                    }
                }
                
                if(self.environmentalConditions?.activeLiveType == ActiveLiveType.WINK || self.environmentalConditions?.activeLiveType == ActiveLiveType.BLINK  ){
                    faceQualityCheck.checkQualityWinkAndBLINK(pixelBuffer: downscaledBuffer) { faceEvent in
                        DispatchQueue.main.async {
                            if (self.performLivenessFace! && !self.areAllEventsDone() && self.environmentalConditions?.activeLiveType != ActiveLiveType.NONE && self.environmentalConditions?.activeLivenessCheckCount != 0) {
                                if(self.canCheckLive){
                                    self.isSpecificItemFlagEqualToWinkAndBLINK(targetEvent: faceEvent);
                                }
                                
                            }
                        }
                    }
                }
               
            }
        }
        
        
      
        
        if (motion == MotionType.SENDING && zoom == ZoomType.SENDING  && isRectFInsideTheScreen && environmentalConditions!.checkConditions(
            brightness: cropPixelBuffer.brightness) == BrightnessEvents.Good && self.faceEvent == FaceEvents.GOOD) {
            modelDataHandler?.customColor = ConstantsValues.DetectColor;
            sendingFlags.append(MotionType.SENDING);
            sendingFlagsZoom.append(ZoomType.SENDING);
            if(self.performPassiveLivenessFace!){
                   if(livenessCheckArray.count < self.localLivenessLimit){
                       frameCounterLivness += 1
                         if frameCounterLivness % processEveryNFrames == 0 {
                             DispatchQueue.global(qos: .background).async { [weak self] in
                                         guard let self = self else { return }
                                         if let copiedBuffer = copyPixelBuffer(pixelBuffer) {
                                             DispatchQueue.main.async {
                                                 self.livenessCheckArray.append(copiedBuffer)
                                             }
                                         }
                                     }
                                 }
                               
                           }
                       }
            if(environmentalConditions!.enableGuide && self.areAllEventsDone()){
                DispatchQueue.main.async {
                    if(self.guide.faceSvgImageView == nil){
                        self.guide.showFaceGuide(view: self.view)
                    }
                    self.guide.changeFaceColor(view: self.view,to:ConstantsValues.DetectColor,notTransmitting: self.start)
                }
            }
        } else {
            modelDataHandler?.customColor = environmentalConditions!.HoldHandColor;
            sendingFlags.removeAll();
            sendingFlagsZoom.removeAll();
            livenessCheckArray.removeAll()
            if(environmentalConditions!.enableGuide && self.areAllEventsDone()){
                DispatchQueue.main.async {
                    if(self.guide.faceSvgImageView == nil){
                        self.guide.showFaceGuide(view: self.view)
                    }
                    self.guide.changeFaceColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
                }
            }
        }
        
        if (self.showCountDown ) {
            if (!hasFace() || !isRectFInsideTheScreen ||  self.faceEvent != FaceEvents.GOOD  ||  self.zoom != ZoomType.SENDING) {
                DispatchQueue.main.async {
                    self.countdownLabel?.removeFromSuperview();
                    self.countdownTimer?.invalidate();
                    self.isCountDownStarted = true;
                }
            }
        }
        
        if (environmentalConditions!.checkConditions(
            brightness: cropPixelBuffer.brightness) == BrightnessEvents.Good
            && motion == MotionType.SENDING && zoom == ZoomType.SENDING  && isRectFInsideTheScreen && self.faceEvent == FaceEvents.GOOD) {
            if (start && sendingFlags.count > environmentalConditions!.MotionLimitFace && sendingFlagsZoom.count > FaceZoomLimit && livenessCheckArray.count == self.localLivenessLimit) {
                if (hasFace()) {
                    if(self.start){
                        if(self.showCountDown){
                            if(self.isCountDownStarted){
                                self.isCountDownStarted = false;
                                DispatchQueue.main.async {
                                    (self.countdownLabel, self.countdownTimer) = self.guide.showFaceTimer(view: self.view, initialTextColorHex:self.environmentalConditions!.CountDownNumbersColor) {
                                        self.isCountDownStarted = true;
                                        self.start = false;
                                        self.faceMatchDelegate?.onSend();
                                        
                                        let converter = ParallelImageProcessing()
                                        converter.setPixelBuffers(self.livenessCheckArray)
                                        converter.convertBuffers {
                                        ///
                                        let clips = converter.getClips()
                                        let selfieImage: Data
                                        if !clips.isEmpty {
                                                let middleIndex = clips.count / 2
                                                selfieImage = clips[middleIndex]
                                         } else {
                                                selfieImage = convertPixelToDataImage(pixelBuffer: pixelBuffer)!
                                        }
                                        var secondDataImage = base64ToData(self.secondImage!)!
                                        ///
                                        self.remoteProcessing?.starProcessingFace(
                                            url: BaseUrls.signalRHub +  HubConnectionFunctions.etHubConnectionFunction(blockType:BlockType.FACE_MATCH),
                                            appConfiguration:self.configModel!,
                                            stepIdString: String(self.stepId!),
                                            selfieImage: selfieImage,
                                            livenessFrames :clips,
                                            secondImage:secondDataImage,
                                            isLivenessEnabled: self.performPassiveLivenessFace!,
                                            retryCount:self.livnessRetryCount,
                                            isManualCapture:false,
                                            isAutoCapture: true,
                                            connectionId: "ConnectionId",
                                            onProgress: { progress in
                                                self.faceMatchDelegate?.onUploadingProgress(progress: progress);
                                            },
                                        ) { result in
                                            switch result {
                                            case .success(let model):
                                                self.onMessageReceived(eventName: model?.destinationEndpoint ?? "",remoteProcessingModel: model!)
                                            case .failure(let error):
                                                self.start = true;
                                                self.onMessageReceived(eventName: HubConnectionTargets.ON_ERROR ,remoteProcessingModel: RemoteProcessingModel(
                                                    destinationEndpoint: HubConnectionTargets.ON_ERROR,
                                                    response: "",
                                                    error: EventsErrorMessages.OnErrorMessage,
                                                    success: false
                                                ))
                                            }
                                        }}
                                        
                                        
                                    }
                                }
                            }
                        }else
                        {
                            self.start = false;
                            self.faceMatchDelegate?.onSend();
                            let converter = ParallelImageProcessing()
                            converter.setPixelBuffers(self.livenessCheckArray)
                            converter.convertBuffers {
                            ///
                             let clips = converter.getClips()
                             let selfieImage: Data
                              if !clips.isEmpty {
                                        let middleIndex = clips.count / 2
                                        selfieImage = clips[middleIndex]
                                 } else {
                                        selfieImage = convertPixelToDataImage(pixelBuffer: pixelBuffer)!
                                }
                            var secondDataImage = base64ToData(self.secondImage!)!
                            ///
                            self.remoteProcessing?.starProcessingFace(
                                url: BaseUrls.signalRHub +  HubConnectionFunctions.etHubConnectionFunction(blockType:BlockType.FACE_MATCH),
                                appConfiguration:self.configModel!,
                                stepIdString: String(self.stepId!),
                                selfieImage: selfieImage,
                                livenessFrames :clips,
                                secondImage:secondDataImage,
                                isLivenessEnabled: self.performPassiveLivenessFace!,
                                retryCount:self.livnessRetryCount,
                                isManualCapture:false,
                                isAutoCapture: true,
                                connectionId: "ConnectionId",
                                onProgress: { progress in
                                    self.faceMatchDelegate?.onUploadingProgress(progress: progress);
                                },
                            ) { result in
                                switch result {
                                case .success(let model):
                                    self.onMessageReceived(eventName: model?.destinationEndpoint ?? "",remoteProcessingModel: model!)
                                case .failure(let error):
                                    self.start = true;
                                    self.onMessageReceived(eventName: HubConnectionTargets.ON_ERROR ,remoteProcessingModel: RemoteProcessingModel(
                                        destinationEndpoint: HubConnectionTargets.ON_ERROR,
                                        response: "",
                                        error: EventsErrorMessages.OnErrorMessage,
                                        success: false
                                    ))
                                }
                            }}
                            
                        }
                        
                    }
                    
                    
                    
                }
            }
            
            
        }
        
        
    }
    
    
    
    
    func onMessageReceived(eventName: String, remoteProcessingModel : RemoteProcessingModel ) {
        DispatchQueue.main.async {
            self.motionRectF.removeAll()
            self.sendingFlags.removeAll()
            self.sendingFlagsZoom.removeAll()
            self.livenessCheckArray.removeAll();

            if eventName == HubConnectionTargets.ON_COMPLETE {
                var faceExtractedModel = FaceExtractedModel.fromJsonString(responseString:remoteProcessingModel.response!);
                var faceResponseModel = FaceResponseModel(
                    destinationEndpoint: remoteProcessingModel.destinationEndpoint,
                    faceExtractedModel: faceExtractedModel,
                    error: remoteProcessingModel.error,
                    success: remoteProcessingModel.success
                )
                self.faceMatchDelegate?.onComplete(dataModel:faceResponseModel )
                self.start = false
            } else if eventName == HubConnectionTargets.ON_RETRY {
                self.start = true
                remoteProcessingModel.error = EventsErrorMessages.OnRetryFaceMessage
                self.faceMatchDelegate?.onRetry(dataModel:remoteProcessingModel )
            } else if eventName == HubConnectionTargets.ON_LIVENESS_UPDATE {
                
                self.livnessRetryCount = self.livnessRetryCount + 1;
                self.start = true
                remoteProcessingModel.error = EventsErrorMessages.OnLivenessFaceUpdateMessage
                self.faceMatchDelegate?.onLivenessUpdate?(dataModel:remoteProcessingModel )

                if(!self.isManual){
                    if(self.livnessRetryCount == self.environmentalConditions?.faceLivenessRetryCount){
                        self.livnessRetryCount = 0;
                        if(self.environmentalConditions?.activeLiveType == ActiveLiveType.NONE || self.environmentalConditions?.activeLivenessCheckCount == 0){
                            self.environmentalConditions?.activeLivenessCheckCount = 3;
                            self.environmentalConditions?.activeLiveType = ActiveLiveType.ACTIONS
                        }
                        self.performLivenessFace = true;
                        self.fillCompletionMap();
                        self.resetActiveLive();

                    }
                }
                
            } else{
                self.start = true
                switch eventName {
                case HubConnectionTargets.ON_ERROR:
                    remoteProcessingModel.error = EventsErrorMessages.OnErrorMessage
                    self.faceMatchDelegate?.onError(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_CLIP_PREPARATION_COMPLETE:
                    self.faceMatchDelegate?.onClipPreparationComplete?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_STATUS_UPDATE:
                    self.faceMatchDelegate?.onStatusUpdated?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_UPDATE:
                    self.faceMatchDelegate?.onUpdated?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_LIVENESS_UPDATE:
                    remoteProcessingModel.error = EventsErrorMessages.OnLivenessFaceUpdateMessage
                    self.faceMatchDelegate?.onLivenessUpdate?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_CARD_DETECTED:
                    self.faceMatchDelegate?.onCardDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_MRZ_EXTRACTED:
                    self.faceMatchDelegate?.onMrzExtracted?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_MRZ_DETECTED:
                    self.faceMatchDelegate?.onMrzDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_NO_MRZ_EXTRACTED:
                    self.faceMatchDelegate?.onNoMrzDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_FACE_DETECTED:
                    self.faceMatchDelegate?.onFaceDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_NO_FACE_DETECTED:
                    self.faceMatchDelegate?.onNoFaceDetected?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_FACE_EXTRACTED:
                    self.faceMatchDelegate?.onFaceExtracted?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_QUALITY_CHECK_AVAILABLE:
                    self.faceMatchDelegate?.onQualityCheckAvailable?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_DOCUMENT_CAPTURED:
                    self.faceMatchDelegate?.onDocumentCaptured?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_DOCUMENT_CROPPED:
                    self.faceMatchDelegate?.onDocumentCropped?(dataModel:remoteProcessingModel )
                case HubConnectionTargets.ON_UPLOAD_FAILED:
                    self.faceMatchDelegate?.onUploadFailed?(dataModel:remoteProcessingModel )
                default:
                    break
                }
            }
            
           
        }
    }
    
    
    func onVideCreated(videoBase64: String) {
        
    }
    
    func hasFace() -> Bool {
        return faces() == 1;
    }
    
    func faces() -> Int {
        let validFaces = self.result!.inferences.filter { item in
                item.className == "face" &&
            self.environmentalConditions!.isPredictionValid(confidence: item.confidence)
            }
        return validFaces.count;
    }
    
    
    func fillCompletionMap() {
        DispatchQueue.main.async {
            self.start = false
            self.canCheckLive = true
            self.eventCompletionList.removeAll();
            for event in getRandomEvents(activeLiveType: self.environmentalConditions!.activeLiveType,activeLivenessCheckCount: self.environmentalConditions!.activeLivenessCheckCount) {
                switch event {
                case .PITCH_UP:
                    self.eventCompletionList.append(FaceEventStatus(event: .PITCH_UP,isCompleted: false))
                case .PITCH_DOWN:
                    self.eventCompletionList.append(FaceEventStatus(event: .PITCH_DOWN,isCompleted: false))
                case .YAW_RIGHT:
                    self.eventCompletionList.append(FaceEventStatus(event: .YAW_RIGHT,isCompleted: false))
                case .YAW_LEFT:
                    self.eventCompletionList.append(FaceEventStatus(event: .YAW_LEFT,isCompleted: false))
                case .WINK_LEFT:
                    self.eventCompletionList.append(FaceEventStatus(event: .WINK_LEFT,isCompleted: false))
                case .WINK_RIGHT:
                    self.eventCompletionList.append(FaceEventStatus(event: .WINK_RIGHT,isCompleted: false))
                case .BLINK:
                    self.eventCompletionList.append(FaceEventStatus(event: .BLINK,isCompleted: false))
                case .GOOD:
                    break
                }
            }
            self.nextMove();
        }
    }
    
    
    func isSpecificItemFlagEqualToActions(targetEvent: FaceEvents) {
        if let firstUncompleted = eventCompletionList.first(where: { !$0.isCompleted }) {
            if firstUncompleted.event == targetEvent {
                firstUncompleted.isCompleted = true
                self.successActiveLive()
            } else {
                if targetEvent != .NO_DETECT &&
                    targetEvent != .GOOD &&
                    targetEvent != .BLINK &&
                    targetEvent != .ROLL_RIGHT &&
                    targetEvent != .ROLL_LEFT &&
                    targetEvent != .WINK_LEFT &&
                    targetEvent != .WINK_RIGHT
                {
                    if self.errorLiveView == nil {
                        resetActiveLive()
                    }
                }
            }
        }
    }

    
    func isSpecificItemFlagEqualToWinkAndBLINK(targetEvent: FaceEvents) {
        if let firstUncompleted = eventCompletionList.first(where: { !$0.isCompleted }) {
            let currentKey = firstUncompleted.event

            if currentKey == targetEvent {
                firstUncompleted.isCompleted = true
                self.successActiveLive()
            } else {
                if targetEvent != .NO_DETECT &&
                    targetEvent != .GOOD &&
                    targetEvent != .ROLL_RIGHT &&
                    targetEvent != .ROLL_LEFT &&
                    targetEvent != .PITCH_UP &&
                    targetEvent != .PITCH_DOWN &&
                    targetEvent != .YAW_LEFT &&
                    targetEvent != .YAW_RIGHT
                {
                    if self.errorLiveView == nil {
                        resetActiveLive()
                    }
                }
            }
        }
    }


    
    
    private func successActiveLive() {
        if(self.canCheckLive){
            self.canCheckLive = false;
            audioPlayer.playAudio(fileName: ConstantsValues.AudioFaceSuccess);
            DispatchQueue.main.async {
                self.clearLiveUi();
                self.successLiveView =  self.guide.showSuccessLiveCheck(view: self.view)
            }
            if areAllEventsDone() {
                self.clearLiveUi();
                if(self.successLiveView != nil){
                    self.successLiveView?.removeFromSuperview();
                }
                start = true
                DispatchQueue.main.async {
                    if(self.environmentalConditions!.enableGuide){
                        if(self.guide.faceSvgImageView == nil){
                            self.guide.showFaceGuide(view: self.view)
                        }
                        self.guide.changeFaceColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.canCheckLive = true;
                    self.nextMove();
                }
            }
        }
        
    }
    
    
    func resetActiveLive() {
        if(self.canCheckLive){
            self.canCheckLive = false
            audioPlayer.playAudio(fileName: ConstantsValues.AudioWrong);
            DispatchQueue.main.async {
                self.clearLiveUi();
                if(self.successLiveView != nil){
                    self.successLiveView?.removeFromSuperview();
                }
                self.errorLiveView =  self.guide.showErrorLiveCheck(view: self.view)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                DispatchQueue.main.async {
                    if(self.errorLiveView != nil){
                        self.errorLiveView?.removeFromSuperview();
                        self.errorLiveView  = nil
                    }
                }
                self.fillCompletionMap()
            }
        }
    }
    
    
    func nextMove() {
        DispatchQueue.main.async {
            if self.activeLiveMove == nil {
                self.errorLiveView?.removeFromSuperview()
                self.successLiveView?.removeFromSuperview()

                if let firstUncompleted = self.eventCompletionList.first(where: { !$0.isCompleted }) {
                    let key = firstUncompleted.event

                    switch key {
                    case .PITCH_UP:
                        self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .PITCH_UP)
                    case .PITCH_DOWN:
                        self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .PITCH_DOWN)
                    case .YAW_RIGHT:
                        self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .YAW_RIGHT)
                    case .YAW_LEFT:
                        self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .YAW_LEFT)
                    case .WINK_LEFT:
                        self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .WINK_LEFT)
                    case .WINK_RIGHT:
                        self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .WINK_RIGHT)
                    case .BLINK:
                        self.faceMatchDelegate?.onCurrentLiveMoveChange?(activeLiveEvents: .BLINK)
                    default:
                        break
                    }

                    self.activeLiveMove = self.guide.setActiveLiveMove(view: self.view, event: key)
                }
            }
        }
    }

    
    func areAllEventsDone() -> Bool {
        for status in eventCompletionList {
            if !status.isCompleted {
                return false
            }
        }
        return true
    }

    
    func clearLiveUi(){
        DispatchQueue.main.async {
            if(self.activeLiveMove != nil){
                self.activeLiveMove?.removeFromSuperview();
                self.activeLiveMove = nil
            }
        }
    }
    
    
    public func stopScanning(){
        audioPlayer.stopAudio();
        self.previewView.stopSession();
        self.cameraFeedManager.stopSession();
    }
    
    public func takePicture(){
        if(start){
            result = self.modelDataHandler?.runModel(onFrame: self.currentImage!)
            if(hasFace()){
                if (self.performPassiveLivenessFace!) {
                    DispatchQueue.main.async {
                        self.startCollectingClips = true;
                    }
                } else {
                    self.start = false;
                    self.faceMatchDelegate?.onSend();
                    
                    
                        
                        var selfieImage = convertPixelToDataImage(pixelBuffer:self.currentImage!)!
                        var secondDataImage = base64ToData(self.secondImage!)!
                        
                        self.remoteProcessing?.starProcessingFace(
                            url: BaseUrls.signalRHub +  HubConnectionFunctions.etHubConnectionFunction(blockType:BlockType.FACE_MATCH),
                            appConfiguration:self.configModel!,
                            stepIdString: String(self.stepId!),
                            selfieImage: selfieImage,
                            livenessFrames : [],
                            secondImage:secondDataImage,
                            isLivenessEnabled: self.performPassiveLivenessFace!,
                            retryCount:self.livnessRetryCount,
                            isManualCapture:true,
                            isAutoCapture: false,
                            connectionId: "ConnectionId",
                            onProgress: { progress in
                                self.faceMatchDelegate?.onUploadingProgress(progress: progress);
                            },
                            
                        ) { result in
                            switch result {
                            case .success(let model):
                                self.onMessageReceived(eventName: model?.destinationEndpoint ?? "",remoteProcessingModel: model!)
                            case .failure(let error):
                                self.start = true;
                                self.onMessageReceived(eventName: HubConnectionTargets.ON_ERROR ,remoteProcessingModel: RemoteProcessingModel(
                                    destinationEndpoint: HubConnectionTargets.ON_ERROR,
                                    response: "",
                                    error: EventsErrorMessages.OnErrorMessage,
                                    success: false
                                ))
                            }
                        }
                    
                }
            
            }else{
                self.faceMatchDelegate?.onRetry(dataModel:RemoteProcessingModel(
                    destinationEndpoint: HubConnectionTargets.ON_RETRY,
                    response: "",
                    error: EventsErrorMessages.OnRetryFaceMessage,
                    success: false
                ) )
            }
            
        }
       
    }
    
    
    
}
