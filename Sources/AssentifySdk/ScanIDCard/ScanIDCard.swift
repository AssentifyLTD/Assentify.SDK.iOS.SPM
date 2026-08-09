
import Foundation



import UIKit
import AVFoundation
import Accelerate
import CoreImage

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
            if(self.guide.cardSvgImageView == nil){
                self.guide.showCardGuide(view: self.view)
            }
            self.guide.changeCardColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
        }
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
                        self.guide.showCardGuide(view: self.view)
                    }
                    self.guide.changeCardColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
                }
            }
        }else{
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
            zoom = calculatePercentageChangeWidth(rect: rect1,pixelBuffer: pixelBuffer)
        }
        
      
        
        
        if (motion == MotionType.SENDING && zoom == ZoomType.SENDING && isRectFInsideTheScreen && environmentalConditions!.checkConditions(
            brightness: imageBrightnessChecker)  == BrightnessEvents.Good) {
            modelDataHandler?.customColor =  ConstantsValues.DetectColor;
            sendingFlagsMotion.append(MotionType.SENDING);
            sendingFlagsZoom.append(ZoomType.SENDING);
            if(environmentalConditions!.enableGuide){
                DispatchQueue.main.async {
                    if(self.guide.cardSvgImageView == nil){
                        self.guide.showCardGuide(view: self.view)
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
                        self.guide.showCardGuide(view: self.view)
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
                    DispatchQueue.main.async {
                        self.scanIDCardDelegate?.onSend();
                        self.audioPlayer.playAudio(fileName: ConstantsValues.AudioCardSuccess)
                    }
                    var dataImage = convertPixelToDataImage(pixelBuffer:pixelBuffer)!
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
                        isManualCapture: false,
                        isAutoCapture: true,
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
                        case .failure(let error):
                            self.start = true;
                            self.onMessageReceived(eventName: HubConnectionTargets.ON_ERROR ,remoteProcessingModel: RemoteProcessingModel(
                                destinationEndpoint: HubConnectionTargets.ON_ERROR,
                                response: "",
                                error: EventsErrorMessages.OnErrorMessage,
                                success: false,
                             ))
                        }
                    }
                    start = false;
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
                var iDExtractedModel = IDExtractedModel.fromJsonString(responseString:remoteProcessingModel.response!,transformedProperties: [:]);
                self.iDResponseModel = IDResponseModel(
                    destinationEndpoint: remoteProcessingModel.destinationEndpoint,
                    iDExtractedModel: iDExtractedModel,
                    error: remoteProcessingModel.error,
                    success: remoteProcessingModel.success
                )
                
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
                                    self.scanIDCardDelegate?.onLivenessUpdate?(dataModel:remoteProcessingModel )
                                    self.start = true
            case HubConnectionTargets.ON_WRONG_TEMPLATE:
                remoteProcessingModel.error = EventsErrorMessages.OnWrongTemplateMessage
                                  self.scanIDCardDelegate?.onWrongTemplate(dataModel:remoteProcessingModel )
                                  self.start = true
            default:
                self.start = true
                remoteProcessingModel.error = EventsErrorMessages.OnWrongTemplateMessage
                self.scanIDCardDelegate?.onWrongTemplate(dataModel:remoteProcessingModel )
                break
            }
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
                let keys = key.split(separator: "_").map { String($0) }
                let newKey = key.components(separatedBy: "IdentificationDocumentCapture_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
                self.iDResponseModel!.iDExtractedModel!.extractedData![newKey] =  "\(value)"
                
            }
            
            self.scanIDCardDelegate?.onComplete(dataModel:self.iDResponseModel!,isFrontPage: self.isFrontPage(),isLastPage: self.isLastPage,classifiedTemplate: self.classifiedTemplate )
             self.start = false
            
        }
        
        
      
    }
    
    public func onTranslatedError(properties: [String : String]?) {
        self.scanIDCardDelegate?.onComplete(dataModel:self.iDResponseModel!,isFrontPage: self.isFrontPage(),isLastPage: self.isLastPage,classifiedTemplate: self.classifiedTemplate )
        self.start = false
        
    }
    
    public func stopScanning(){
        audioPlayer.stopAudio();
        self.previewView.stopSession();
        self.cameraFeedManager.stopSession();
    }
    
    public func takePicture(){
        if(start){
            result = self.modelDataHandler?.runModel(onFrame: self.currentImage!)
            if(hasFaceOrCard()){
                start = false;
                self.scanIDCardDelegate?.onSend();
                var dataImage = convertPixelToDataImage(pixelBuffer: self.currentImage!)!
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
                    isManualCapture: true,
                    isAutoCapture: false,
                    retryCount: retryCount,
                    tag:getIDTag(configModel: self.configModel!, templateName:  self.templatesByCountry.name),
                    processCivilExtractQrCode: false,
                    templatesByCountry: self.selectedTemplates,
                    onProgress: { progress in
                        self.scanIDCardDelegate?.onUploadingProgress(progress: progress);
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
    
}
