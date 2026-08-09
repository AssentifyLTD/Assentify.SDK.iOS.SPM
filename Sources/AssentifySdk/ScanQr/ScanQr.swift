

import Foundation



import UIKit
import AVFoundation
import Accelerate
import CoreImage
import Vision
import CoreVideo

public class ScanQr :UIViewController, CameraSetupDelegate , RemoteProcessingDelegate ,LanguageTransformationDelegate{
   
    
    var guide : Guide = Guide();
    var previewView: PreviewView!
    var cameraFeedManager:CameraFeedManager!
    private let displayFont = UIFont.systemFont(ofSize: 14.0, weight: .medium)
    
    let templatesByCountry:TemplatesByCountry;
    var selectedTemplates:[String] = []
    
    
    private var scanQrDelegate: ScanQrDelegate?
    private var configModel: ConfigModel?
    private var environmentalConditions: EnvironmentalConditions?
    private var apiKey: String
    private var language: String?
    private var stepId:Int?;
    
    private var remoteProcessing: RemoteProcessing?

    
    private var iDResponseModel:IDResponseModel?;
    
    
    
    private var  start = true;
    private var  isManual = false;
    private var  currentImage : CVPixelBuffer?;
    
    init(configModel: ConfigModel!,
         environmentalConditions :EnvironmentalConditions,
         apiKey:String,
         scanQrDelegate:ScanQrDelegate,
         templatesByCountry:TemplatesByCountry,
         language: String,
         isManual: Bool
    ) {
        self.configModel = configModel;
        self.environmentalConditions = environmentalConditions;
        self.apiKey = apiKey;
        self.scanQrDelegate = scanQrDelegate;
        self.templatesByCountry = templatesByCountry;
        self.language = language;
        self.isManual = isManual;
        
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
            if(self.guide.qrSvgImageView == nil){
                self.guide.showQrGuide(view: self.view)
            }
            self.guide.changeQrColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
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
        }else{
            openCvCheck(pixelBuffer: pixelBuffer)
        }
    }
 
    func onVideCreated(videoBase64: String) {
        //
    }
    
    func openCvCheck(pixelBuffer: CVPixelBuffer){
     
           detectQRCode(from: pixelBuffer) { qrCode in
                if let url = qrCode {
                    if(self.start == true){
                        DispatchQueue.main.async {
                            self.start = false;
                            self.scanQrDelegate?.onStartQrScan();
                            if(self.environmentalConditions!.enableGuide){
                                if(self.guide.qrSvgImageView == nil){
                                    self.guide.showQrGuide(view: self.view)
                                }
                                self.guide.changeQrColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
                            }
                        }
                        var dataImage = convertPixelToDataImage(pixelBuffer:pixelBuffer)!
                        
                        self.remoteProcessing?.starQrProcessing(
                            url: BaseUrls.signalRHub + HubConnectionFunctions.etHubConnectionFunction(blockType:BlockType.QR),
                            image:dataImage,
                            appConfiguration:self.configModel!,
                            templatesByCountry : self.selectedTemplates,
                            connectionId: "ConnectionId",
                            stepIdString: String(self.stepId!),
                            metadata: url,
                            isManualCapture : false,
                            isAutoCapture:true,
                            onProgress: { progress in
                                self.scanQrDelegate?.onUploadingProgress(progress: progress);
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
                                    error: "",
                                    success: false
                                ))
                            }
                        }
                    }
              
                }
                
            }
        
       
    }
    


    func detectQRCode(from pixelBuffer: CVPixelBuffer, completion: @escaping (String?) -> Void) {
        let request = VNDetectBarcodesRequest { request, error in
            guard error == nil else {
                completion(nil)
                return
            }

            if let results = request.results as? [VNBarcodeObservation],
               let firstQR = results.first,
               let qrString = firstQR.payloadStringValue {
                completion(qrString)
            } else {
                completion(nil)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(nil)
            }
        }
    }

    
    
 
    
    func onMessageReceived(eventName: String, remoteProcessingModel : RemoteProcessingModel ) {
        DispatchQueue.main.async {
            if eventName == HubConnectionTargets.ON_COMPLETE {
                var iDExtractedModel = IDExtractedModel.fromJsonString(responseString:remoteProcessingModel.response!,transformedProperties: [:]);
                self.iDResponseModel = IDResponseModel(
                    destinationEndpoint: remoteProcessingModel.destinationEndpoint,
                    iDExtractedModel: iDExtractedModel,
                    error: remoteProcessingModel.error,
                    success: remoteProcessingModel.success
                )
                
                if(self.language == Language.NON){
                    self.scanQrDelegate?.onCompleteQrScan(dataModel:self.iDResponseModel!)
                }else{
                    let transformed = LanguageTransformation(apiKey: self.apiKey,languageTransformationDelegate: self)
                       transformed.languageTransformation(
                           langauge: self.language!,
                           transformationModel: preparePropertiesToTranslate(language: self.language!, properties: iDExtractedModel?.outputProperties)
                       )
                }
            
            } else {
                self.start = true;
                if(self.environmentalConditions!.enableGuide){
                    if(self.guide.qrSvgImageView == nil){
                        self.guide.showQrGuide(view: self.view)
                    }
                    self.guide.changeQrColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
                }
                
                self.scanQrDelegate?.onErrorQrScan(message: EventsErrorMessages.OnRetryCardMessage,dataModel: remoteProcessingModel)
            }
        }
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
            
            self.scanQrDelegate?.onCompleteQrScan(dataModel:self.iDResponseModel!)
            
        
        }
        
        
      
    }
    
    public func onTranslatedError(properties: [String : String]?) {
        self.scanQrDelegate?.onCompleteQrScan(dataModel:self.iDResponseModel!)
    }
    
    public func stopScanning(){
        self.previewView.stopSession();
        self.cameraFeedManager.stopSession();
    }
    
    
    public func takePicture(){
        if(start){
            detectQRCode(from: self.currentImage!) { qrCode in
                 if let url = qrCode {
                     if(self.start == true){
                         DispatchQueue.main.async {
                             self.start = false;
                             self.scanQrDelegate?.onStartQrScan();
                             if(self.environmentalConditions!.enableGuide){
                                 if(self.guide.qrSvgImageView == nil){
                                     self.guide.showQrGuide(view: self.view)
                                 }
                                 self.guide.changeQrColor(view: self.view,to:self.environmentalConditions!.HoldHandColor,notTransmitting: self.start)
                             }
                         }
                         var dataImage = convertPixelToDataImage(pixelBuffer: self.currentImage!)!
                         self.remoteProcessing?.starQrProcessing(
                             url: BaseUrls.signalRHub + HubConnectionFunctions.etHubConnectionFunction(blockType:BlockType.QR),
                             image:dataImage,
                             appConfiguration:self.configModel!,
                             templatesByCountry : self.selectedTemplates,
                             connectionId: "ConnectionId",
                             stepIdString: String(self.stepId!),
                             metadata: url,
                             isManualCapture : true,
                             isAutoCapture:false,
                             onProgress: { progress in
                                 self.scanQrDelegate?.onUploadingProgress(progress: progress);
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
                                     error: "",
                                     success: false
                                 ))
                             }
                         }
                     }
               
                 }
                 
             }
            
        }
       
    }
    
}
