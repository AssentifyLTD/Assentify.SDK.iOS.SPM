

import UIKit
import AVFoundation
import Accelerate
import CoreImage

public class LocalScanPassport :UIViewController, CameraSetupDelegate ,LanguageTransformationDelegate {
    
    
    
    
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
    
    private var motion:MotionType = MotionType.NO_DETECT;
    private var zoom:ZoomType = ZoomType.NO_DETECT;
    
    private var passportResponseModel: PassportResponseModel?
    
    private var detectIfRectFInsideTheScreen = DetectIfRectInsideTheScreen();
    private var isRectFInsideTheScreen:Bool = false;
    
    private var  start = true;
    
    private var  currentImage : CVPixelBuffer?;
    
    init(configModel: ConfigModel!,
         environmentalConditions :EnvironmentalConditions,
         apiKey:String,
         scanPassportDelegate:ScanPassportDelegate,
         language: String,
    ) {
        self.configModel = configModel;
        self.environmentalConditions = environmentalConditions;
        self.apiKey = apiKey;
        self.scanPassportDelegate = scanPassportDelegate;
        self.language = language
        
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
        
        
        if(environmentalConditions!.enableGuide){
            if(self.guide.cardSvgImageView == nil){
                self.guide.showCardGuide(view: self.view,forResource: "passport_background")
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
        runModel(onPixelBuffer: pixelBuffer)
        openCvCheck(pixelBuffer: pixelBuffer)
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
            if (start ) {
                if (hasFaceOrCard()) {
                    
                    MrzPixelBufferScanner.scan(pixelBuffer: pixelBuffer, orientation: .right) { result in
                        switch result {
                        case .success(let mrz):
                            guard let mrz = mrz else {
                                return
                            }
                            if mrz.isComplete() && self.start {
                                DispatchQueue.main.async {
                                    self.scanPassportDelegate?.onSend();
                                    self.scanPassportDelegate?.onUploadingProgress(progress: 1);
                                }
                                self.start = false;
                                let timestamp = Int(Date().timeIntervalSince1970)
                                let fileName = "face_\(timestamp).jpg"
                                
                                self.uploadImage(
                                    pixelBuffer: pixelBuffer,
                                    fileName: fileName,
                                    mrzInfo: mrz.toOutputProperties()
                                )
                                
                            }
                        case .failure(let error):
                            self.start = true;
                            self.scanPassportDelegate?.onRetry(dataModel:RemoteProcessingModel(
                                destinationEndpoint: HubConnectionTargets.ON_RETRY,
                                response: "",
                                error: EventsErrorMessages.OnRetryCardMessage,
                                success: false))
                        }
                    }
                    
                    
                    
                    
                    
                    
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
    
    
    private func jpegData(from pixelBuffer: CVPixelBuffer, compressionQuality: CGFloat = 0.9) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: compressionQuality)
    }
    
    private func uploadImage(
        pixelBuffer: CVPixelBuffer,
        fileName: String,
        mrzInfo: [String: Any]
    ) {
        
        guard let config = self.configModel else {
            return
        }
        
        guard let faceImageData = jpegData(from: pixelBuffer, compressionQuality: 0.6) else {
            self.buildData(imageUrl: "", mrzInfo: mrzInfo)
            return
        }
        
        let fullPath = "\(config.tenantIdentifier)/\(config.blockIdentifier)/\(config.instanceId)/\(fileName)"
        guard let encodedPath = fullPath.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            self.buildData(imageUrl:"",mrzInfo: mrzInfo)
            return
        }
        
        let baseUrl = "\(BaseUrls.blobUrl)v2/Document/UploadFile/userfiles/\(encodedPath)?skipValidator=true"
        guard let url = URL(string: baseUrl) else {
            self.buildData(imageUrl:"",mrzInfo: mrzInfo)
            return
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(self.apiKey, forHTTPHeaderField: "X-Api-Key") // Note: Case-sensitive
        request.setValue(config.tenantIdentifier, forHTTPHeaderField: "x-tenant-identifier")
        request.setValue(config.blockIdentifier, forHTTPHeaderField: "x-block-identifier")
        request.setValue(config.instanceId, forHTTPHeaderField: "x-instance-id")
        request.setValue("text/plain", forHTTPHeaderField: "accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"asset\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(faceImageData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.buildData(imageUrl:"",mrzInfo: mrzInfo)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.buildData(imageUrl:"",mrzInfo: mrzInfo)
                return
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                self.buildData(imageUrl:"",mrzInfo: mrzInfo)
                return
            }
            
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let uploadedUrl = json["url"] as? String {
                       self.buildData(imageUrl:uploadedUrl,mrzInfo: mrzInfo)
                    }
                } catch {
                    self.buildData(imageUrl:"",mrzInfo: mrzInfo)
                }
            }
        }
        
        task.resume()
    }
    private func buildData(imageUrl: String,mrzInfo: [String: Any]){
        guard let configModel = self.configModel,
              let passportStep = configModel.stepDefinitions.first(where: { $0.stepId == self.stepId }) else {
            return
        }
        
        var passportExtractedModel = PassportExtractedModel.fromOutputProperties(passportImageUrl: imageUrl,transformedProperties: [:],stepOutputProperties: passportStep.outputProperties,
                                                                                 mrzInfo: mrzInfo)
        self.passportResponseModel = PassportResponseModel(
            destinationEndpoint: "ReadPassport",
            passportExtractedModel: passportExtractedModel,
            error: "",
            success: true
        )
        
        
        guard let identificationDocumentCapture = passportResponseModel!.passportExtractedModel?.identificationDocumentCapture,
              let expiryDateValue = identificationDocumentCapture.Expiry_Date else {
            fatalError("passportExtractedModel or identificationDocumentCapture or expiryDate was nil")
        }
        
        let rawExpiryDate = "\(expiryDateValue)"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        var expired = false
        
        if let expiryDate = dateFormatter.date(from: rawExpiryDate) {
            expired = expiryDate < Date()
        }
        
        
        if(expired){
            self.scanPassportDelegate?.onRetry(dataModel:RemoteProcessingModel(
                destinationEndpoint: HubConnectionTargets.ON_RETRY,
                response: "",
                error: EventsErrorMessages.OnExpiredPassportMessage,
                success: false))
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
                let keys = key.split(separator: "_").map { String($0) }
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
        self.previewView.stopSession();
        self.cameraFeedManager.stopSession();
    }
    
    
    
}
