import SwiftUI
import UIKit

// MARK: - Events (ID Scan)

struct IDScanEvents {
    var onSend: (() -> Void)? = nil
    var onProgress: ((Double) -> Void)? = nil
    var onComplete: ((IDResponseModel, Bool, Bool, String) -> Void)? = nil
    var onError: ((RemoteProcessingModel) -> Void)? = nil
    var onRetry: ((RemoteProcessingModel) -> Void)? = nil
    var onWrongTemplate: ((RemoteProcessingModel) -> Void)? = nil
    
    var onLivenessUpdate: ((RemoteProcessingModel) -> Void)? = nil
    
    var onEnvironmental: ((BrightnessEvents, MotionType, ZoomType, Bool) -> Void)? = nil
}

enum IDScreenEvent {
    case idle
    case sending
    case completed
    case error
    case retry
    case wrongTemplate
    case liveness
    case flip
}

final class IDScanCommands: ObservableObject {
    @Published var triggerRetry: Int = 0
    @Published var triggerCapture: Int = 0
    @Published var triggerFlep: Int = 0
    @Published var triggerClose: Int = 0
}


public struct IDCardScanStep: View {
    
    @State private var start: Bool = false
    @State private var feedbackText: String = ""
    @State private var imageUrl: String = ""
    @State private var uploadProgress: Int = 0
    @State private var screenEvent: IDScreenEvent = .idle
    
    @State private var idModel: IDResponseModel?
    @State private var isFrontPage: Bool = true
    @State private var isLastPage: Bool = false
    @State private var classifiedTemplate: String = ""
    @State private var kycDocumentDetails: [KycDocumentDetails] = []
    @State private var templatesByCountry: TemplatesByCountry?
    @State private var extractedInformation: [String:String] = [:]
    
    @StateObject private var commands = IDScanCommands()
    private let timeStarted :String = getCurrentDateTimeForTracking();
    private var assentifySdk = AssentifySdkObject.shared.get()
    private let flowController: FlowController
    
    private var showResultPage: Bool = false
    private let selectedTemplate: Templates?
    
    public init(flowController: FlowController) {
        self.flowController = flowController
        self.selectedTemplate = SelectedTemplatesObject.shared.get();
        self.showResultPage =
        flowController.getCurrentStep()?
            .stepDefinition?
            .customization
            .showResultPage ?? false
        
        /** Track Progress **/
        let currentStep = flowController.getCurrentStep()
        flowController.trackProgress(
            currentStep : currentStep!,
            inputData : flowController.outputPropertiesToMap(currentStep!.stepDefinition!.outputProperties),
            response : nil,
            status : "InProgress"
        )
        /**/
    }
    
    private func loadTemplates() {
        guard
            let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId,
            let selectedCode = selectedTemplate?.sourceCountryCode
        else { return }
        
        let templates = AssentifySdkObject.shared.get()?.getTemplates(stepID: stepId) ?? []
        templatesByCountry = templates.first(where: { $0.sourceCountryCode == selectedCode })
    }
    
    
    private var templatesByCountryValue: TemplatesByCountry? {
        guard
            let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId,
            let selectedCode = selectedTemplate?.sourceCountryCode
        else { return nil }
        
        let templates = AssentifySdkObject.shared.get()?.getTemplates(stepID: stepId) ?? []
        return  templates.first(where: { $0.sourceCountryCode == selectedCode })
    }
    
    
    private func onBack() {
        commands.triggerClose += 1
        flowController.backClick()
    }
    
    private func onNext() {
        DispatchQueue.main.async { screenEvent = .idle }
        commands.triggerClose += 1
        
        if (FlowEnvironmentalConditionsObject.shared.get()!.enableQr && kycDocumentDetails
            .first(where: { $0.templateProcessingKeyInformation == classifiedTemplate })!.hasQrCode) {
            self.flowController.push(HowToCaptureQrScreen(flowController: self.flowController))
        } else {
            flowController.makeCurrentStepDone(extractedInformation: extractedInformation,timeStarted: self.timeStarted)
            flowController.naveToNextStep();
        }
        
    }
    
    public var body: some View {
        
        let events = IDScanEvents(
            onSend: {
                DispatchQueue.main.async { start = true }
            },
            onProgress: { p in
                DispatchQueue.main.async {
                    screenEvent = .sending
                    uploadProgress = Int(p * 100)
                }
            },
            onComplete: { model, front, last, template in
                DispatchQueue.main.async {
                    idModel = model
                    isFrontPage = front
                    isLastPage = last
                    self.classifiedTemplate = template;
                    if !classifiedTemplate.isEmpty {
                        for template in self.templatesByCountry!.templates {
                            for detail in template.kycDocumentDetails {
                                if detail.templateProcessingKeyInformation == classifiedTemplate {
                                    kycDocumentDetails = template.kycDocumentDetails
                                }
                            }
                        }
                    }
                    
                    
                    var currentMap = extractedInformation
                    
                    if let newProps = model.iDExtractedModel?.transformedProperties {
                        for (k, v) in newProps {
                            currentMap[k] = v
                        }
                    }
                    
                    extractedInformation = currentMap
                    
                    
                    
                    
                    OnCompleteScreenData.shared.clear();
                    OnCompleteScreenData.shared.set(extractedInformation)
                    
                    if(isLastPage){
                        start = false
                        feedbackText = ""
                        uploadProgress = 0
                        screenEvent = .completed
                        /** Track Progress **/
                        let currentStep = flowController.getCurrentStep()
                       

                        flowController.trackProgress(
                            currentStep: currentStep!,
                            inputData: extractedInformation,
                            response: "Completed",
                            status: "InProgress"
                        )
                        /**/
                        
                    }else{
                        start = false
                        feedbackText = ""
                        uploadProgress = 0
                        screenEvent = .flip
                        commands.triggerFlep += 1
                    }
                    
                    if(isFrontPage){
                        QrIDResponseModelObject.shared.set(model)
                        imageUrl = model.iDExtractedModel!.imageUrl!
                        if let outputProperties = model.iDExtractedModel?.outputProperties {
                            let faceKey = flowController.getFaceMatchInputImageKey()
                            for (key, value) in outputProperties {
                                if key.contains(faceKey) {
                                    flowController.setImage(url: String(describing: value))
                                }
                            }
                        }
                    }
                    
                    
                    
                }
            },
            onError: { model in
                DispatchQueue.main.async {
                    start = false
                    do {
                        if let response = model.response {
                            imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: response)
                        } else {
                            imageUrl = ""
                        }
                    } catch {
                        imageUrl = ""
                    }
                    screenEvent = .error
                    
                    /** Track Progress **/
                    let currentStep = flowController.getCurrentStep()
                    let errorString = model.responseJsonObject?["error"] as? String
                    let extracted = flowController.extractAfterDash(errorString)

                    let finalResponse = extracted.isEmpty
                        ? "Error"
                        : "Error - \(extracted)"

                    flowController.trackProgress(
                        currentStep: currentStep!,
                        inputData: flowController.decodeToJsonObject(model.response),
                        response: finalResponse,
                        status: "InProgress"
                    )
                    /**/
                }
            },
            onRetry: { model in
                DispatchQueue.main.async {
                    start = false
                    do {
                        if let response = model.response {
                            imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: response)
                        } else {
                            imageUrl = ""
                        }
                    } catch {
                        imageUrl = ""
                    }
                    screenEvent = .retry
                    
                    /** Track Progress **/
                    let currentStep = flowController.getCurrentStep()
                    let errorString = model.responseJsonObject?["error"] as? String
                    let extracted = flowController.extractAfterDash(errorString)

                    let finalResponse = extracted.isEmpty
                        ? "onRetry"
                        : "onRetry - \(extracted)"

                    flowController.trackProgress(
                        currentStep: currentStep!,
                        inputData: flowController.decodeToJsonObject(model.response),
                        response: finalResponse,
                        status: "InProgress"
                    )
                    /**/
                }
            },
            onWrongTemplate: { model in
                DispatchQueue.main.async {
                    start = false
                    do {
                        if let response = model.response {
                            imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: response)
                        } else {
                            imageUrl = ""
                        }
                    } catch {
                        imageUrl = ""
                    }
                    screenEvent = .wrongTemplate
                    /** Track Progress **/
                    let currentStep = flowController.getCurrentStep()
                    let errorString = model.responseJsonObject?["error"] as? String
                    let extracted = flowController.extractAfterDash(errorString)

                    let finalResponse = extracted.isEmpty
                        ? "onWrongTemplate"
                        : "onWrongTemplate - \(extracted)"

                    flowController.trackProgress(
                        currentStep: currentStep!,
                        inputData: flowController.decodeToJsonObject(model.response),
                        response: finalResponse,
                        status: "InProgress"
                    )
                    /**/
                }
            },
            onLivenessUpdate: { model in
                DispatchQueue.main.async {
                    start = false
                    do {
                        if let response = model.response {
                            imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: response)
                        } else {
                            imageUrl = ""
                        }
                    } catch {
                        imageUrl = ""
                    }
                    screenEvent = .liveness
                    /** Track Progress **/
                    let currentStep = flowController.getCurrentStep()
                    let errorString = model.responseJsonObject?["error"] as? String
                    let extracted = flowController.extractAfterDash(errorString)

                    let finalResponse = extracted.isEmpty
                        ? "onLivenessUpdate"
                        : "onLivenessUpdate - \(extracted)"

                    flowController.trackProgress(
                        currentStep: currentStep!,
                        inputData: flowController.decodeToJsonObject(model.response),
                        response: finalResponse,
                        status: "InProgress"
                    )
                    /**/
                }
            },
            onEnvironmental: { brightnessEvents, motion, zoom, isCentered in
                DispatchQueue.main.async {
                    
                        
                        if zoom != .SENDING && zoom != .NO_DETECT {
                            
                            if zoom == .ZOOM_IN {
                                feedbackText = FlowStrings.moveIdCloser
                            } else if zoom == .ZOOM_OUT {
                                feedbackText = FlowStrings.moveIdFurther
                            } else {
                                feedbackText = ""
                            }

                        } else if motion != .SENDING && motion != .NO_DETECT {

                            feedbackText = FlowStrings.holdYourHand

                        } else if brightnessEvents != .Good {

                            if brightnessEvents == .TooDark {
                                feedbackText = FlowStrings.increaseLighting
                            } else if brightnessEvents == .TooBright {
                                feedbackText = FlowStrings.reduceLighting
                            } else {
                                feedbackText = ""
                            }

                        } else {

                            if motion == .SENDING && zoom == .SENDING && brightnessEvents == .Good {
                                feedbackText = FlowStrings.holdSteady
                            }

                            if motion == .NO_DETECT && zoom == .NO_DETECT {
                                feedbackText = FlowStrings.presentId2
                            } else if !isCentered {
                                feedbackText = FlowStrings.centerYourId
                            }
                        }
                        
                    
                }
                  
            }
        )
        
        ZStack {
            
            if let tbc = templatesByCountryValue {
                IDScanUIKitView(
                    flowController: flowController,
                    templatesByCountry: tbc,
                    events: events,
                    commands: commands
                )
                .ignoresSafeArea()
            } else {
                Color.clear
                    .ignoresSafeArea()
                
            }
            if screenEvent == .idle {
                VStack {
                    Spacer()
                    
                    if !(assentifySdk?.isManual() ?? false) {
                        Text(feedbackText)
                            .foregroundColor(Color(BaseTheme.baseAccentColor))
                            .font(.system(size: 15, weight: .light))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .padding(.bottom, 40)
                    } else {
                        BaseClickButton(
                            title: FlowStrings.takePhoto,
                            cornerRadius: 28,
                            verticalPadding: 15,
                            enabled: true
                        ) {
                            commands.triggerCapture += 1
                        }
                        .padding(.horizontal, 25)
                        .padding(.vertical, 25)
                    }
                }
                .zIndex(1)
            }
            
            switch screenEvent {
            case .idle:
                EmptyView()
                
            case .sending:
                OnSendScreen(progress: uploadProgress,onBack: {onBack()})
                    .ignoresSafeArea()
                    .background(Color.black.opacity(0.35).ignoresSafeArea())
                    .zIndex(999)
                    .allowsHitTesting(true)
                    .transition(.opacity)
            case .completed:
                if(kycDocumentDetails
                    .first(where: { $0.templateProcessingKeyInformation == classifiedTemplate })!.hasQrCode){
                    OnNormalCompleteScreen(imageUrl: self.imageUrl,
                                           onNext: {
                                            onNext()
                                        },
                                            onBack: {
                                            onBack()
                                          })
                }else{
                    if showResultPage {
                        OnCompleteScreen(imageUrl: self.imageUrl,
                                         onNext: {
                                          onNext()
                                      },
                                          onBack: {
                                          onBack()
                                        })
                    } else {
                        OnNormalCompleteScreen(imageUrl: self.imageUrl,
                                               onNext: {
                                                onNext()
                                            },
                                                onBack: {
                                                onBack()
                                              })
                    }
                }
                
                
            case .error , .retry :
                OnErrorScreen(imageUrl: self.imageUrl ,onRetry: {
                    DispatchQueue.main.async {
                        screenEvent = .idle
                        start = true
                        commands.triggerRetry += 1
                    }
                },
                              onBack: {
                              onBack()
                            })
            case .wrongTemplate:
                OnWrongTemplateScreen(imageUrl: self.imageUrl,expectedImageUrl: "",onRetry:  {
                    DispatchQueue.main.async {
                        screenEvent = .idle
                        start = true
                        commands.triggerRetry += 1
                    }
                },
                onBack: {
                onBack()
              })
                
            case .liveness:
                OnLivenessScreen(imageUrl: self.imageUrl,onRetry:  {
                    DispatchQueue.main.async {
                        screenEvent = .idle
                        start = true
                        commands.triggerRetry += 1
                    }
                },
                onBack: {
                onBack()
              })
            case .flip:
                OnFlipCardScreen(expectedImageUrl: kycDocumentDetails.first(where: { $0.templateProcessingKeyInformation != classifiedTemplate })!.templateSpecimen,
               onNext: {
                        DispatchQueue.main.async {
                            screenEvent = .idle
                            start = true
                            commands.triggerRetry += 1
                        }
                    },
                onBack: {
                onBack()
              })
                
                
            }
            if screenEvent == .idle || BaseTheme.stepperType == .normal{
               Color.clear
                    .topBarBackLogo(logoUrl : screenEvent == .idle || BaseTheme.stepperType == .normal ?  BaseTheme.baseLogo : "" ,noStepper: screenEvent == .idle || BaseTheme.stepperType == .normal  ?  true : false,) {
                        onBack()
                    }
            }else{
                Color.clear
                     .topBarBackLogo(logoUrl : "" ,noStepper: false,) {
                         onBack()
                     }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: start)
        .modifier(InterceptSystemBack(action: onBack)).onAppear {
            if templatesByCountry == nil {
                loadTemplates()
            }
        }
    }
}

// MARK: - UIKit Bridge (UIViewControllerRepresentable)

struct IDScanUIKitView: UIViewControllerRepresentable {
    
    typealias UIViewControllerType = HostVC
    
    let flowController: FlowController
    let templatesByCountry: TemplatesByCountry
    let events: IDScanEvents
    @ObservedObject var commands: IDScanCommands
    
    func makeCoordinator() -> Coordinator {
        Coordinator(flowController: flowController, events: events)
    }
    
    func makeUIViewController(context: Context) -> HostVC {
        let vc = HostVC()
        vc.flowController = flowController
        vc.templatesByCountry = templatesByCountry
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: HostVC, context: Context) {
        uiViewController.apply(commands: commands)
    }
    
    // MARK: - Coordinator (Delegate lives here)
    final class Coordinator: NSObject, ScanIDCardDelegate {
        
        let flowController: FlowController
        let events: IDScanEvents
        
        init(flowController: FlowController, events: IDScanEvents) {
            self.flowController = flowController
            self.events = events
        }
        
        func onSend() {
            events.onSend?()
        }
        
        @objc func onUploadingProgress(progress: Double) {
            events.onProgress?(progress)
        }
        
        func onComplete(
            dataModel: IDResponseModel,
            isFrontPage: Bool,
            isLastPage: Bool,
            classifiedTemplate: String
        ) {
            events.onComplete?(dataModel, isFrontPage, isLastPage, classifiedTemplate)
        }
        
        func onError(dataModel: RemoteProcessingModel) {
            events.onError?(dataModel)
        }
        
        func onRetry(dataModel: RemoteProcessingModel) {
            events.onRetry?(dataModel)
        }
        
        func onWrongTemplate(dataModel: RemoteProcessingModel) {
            events.onWrongTemplate?(dataModel)
        }
        
        func onLivenessUpdate(dataModel: RemoteProcessingModel) {
            events.onLivenessUpdate?(dataModel)
        }
        
        func onEnvironmentalConditionsChange(
            brightnessEvents: BrightnessEvents,
            motion: MotionType,
            zoom: ZoomType,
            isCentered: Bool
        ) {
            events.onEnvironmental?(brightnessEvents, motion, zoom, isCentered)
        }
    }
    
    // MARK: - UIKit Host VC
    final class HostVC: UIViewController {
        
        weak var delegate: ScanIDCardDelegate?
        var flowController: FlowController?
        var templatesByCountry: TemplatesByCountry?
        
        private var idVC: ScanIDCard?
        private var assentifySdk = AssentifySdkObject.shared.get()
        
        private var lastRetryTrigger: Int = 0
        private var lastCaptureTrigger: Int = 0
        private var lastCloseTrigger: Int = 0
        private var lastFlepTrigger: Int = 0
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            startIDIfNeeded()
        }
        
        func apply(commands: IDScanCommands) {
            if commands.triggerRetry != lastRetryTrigger {
                lastRetryTrigger = commands.triggerRetry
                retry()
            }
            
            if commands.triggerCapture != lastCaptureTrigger {
                lastCaptureTrigger = commands.triggerCapture
                capture()
            }
            
            if commands.triggerClose != lastCloseTrigger {
                lastCloseTrigger = commands.triggerClose
                close()
            }
            if commands.triggerFlep != lastFlepTrigger {
                lastFlepTrigger = commands.triggerFlep
                flep()
            }
            
        }
        
        private func flep() {
            self.idVC?.changeTemplateId()
        }
        
        
        private func retry() {
        }
        
        private func capture() {
            idVC?.takePicture()
        }
        
        private func close() {
            DispatchQueue.main.async {
                self.idVC?.stopScanning()
                self.idVC?.willMove(toParent: nil)
                self.idVC?.view.removeFromSuperview()
                self.idVC?.removeFromParent()
                self.idVC = nil
            }
        }
        
        private func startIDIfNeeded() {
            guard idVC == nil else { return }
            
            guard let delegate else {
                assertionFailure("ScanIDCardDelegate is nil")
                return
            }
            
            guard let templatesByCountry else {
                assertionFailure("templatesByCountry is nil")
                return
            }
            
            let stepId = flowController?
                .getCurrentStep()?
                .stepDefinition?
                .stepId
            
            guard let vc = assentifySdk?.startScanID(
                scanIDCardDelegate: delegate,
                templatesByCountry: templatesByCountry,
                language: FlowEnvironmentalConditionsObject.shared.get()!.extractedDataLanguage,
                stepId: stepId
            ) else {
                assertionFailure("startScanID returned nil (sdk instance or config missing)")
                return
            }
            
            idVC = vc
            addChild(vc)
            view.addSubview(vc.view)
            
            vc.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                vc.view.topAnchor.constraint(equalTo: view.topAnchor),
                vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            vc.didMove(toParent: self)
        }
    }
}


