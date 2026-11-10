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
    var onLivenessUpdate: ((RemoteProcessingModel, UIImage?) -> Void)? = nil   // image: the local liveness's (nil = server)
    var onEnvironmental: ((BrightnessEvents, MotionType, ZoomType, Bool) -> Void)? = nil
    var onLivenessInstruction: ((IdLivenessInstruction, Int) -> Void)? = nil
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
    @State private var livenessImage: UIImage? = nil                // the local liveness's image (nil = use imageUrl)
    @State private var uploadProgress: Int = 0
    @State private var screenEvent: IDScreenEvent = .idle
    
    @State private var idModel: IDResponseModel?
    @State private var isFrontPage: Bool = true
    @State private var isLastPage: Bool = false
    @State private var classifiedTemplate: String = ""
    @State private var kycDocumentDetails: [KycDocumentDetails] = []
    @State private var templatesByCountry: TemplatesByCountry?
    @State private var extractedInformation: [String:String] = [:]

    // card liveness: the tilt meter (0..100) under the instruction, and who owns the instruction text
    @State private var tiltProgress: Int = 0
    @State private var tiltProgressVisible: Bool = false
    @State private var livenessActive: Bool = false

    // "Hold the card in your hand": shown on top of the camera when the scan opens, until Continue
    @State private var showHoldPopup: Bool = true
    
    @StateObject private var commands = IDScanCommands()
    private let timeStarted :String = getCurrentDateTimeForTracking();
    private var assentifySdk = AssentifySdkObject.shared.get()
    private let flowController: FlowController
    
    private var showResultPage: Bool = false
    private let selectedTemplate: Templates?
    @State private var isNavigating: Bool = false
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
        flowController.pop(animated: true)
    }
    
    private func onNext() {
        if (!isNavigating) {
            isNavigating = true
            commands.triggerClose += 1
            
            if (FlowEnvironmentalConditionsObject.shared.get()!.enableQr && kycDocumentDetails
                .first(where: { $0.templateProcessingKeyInformation == classifiedTemplate })!.hasQrCode) {
                self.flowController.push(HowToCaptureQrScreen(flowController: self.flowController))
            } else {
                flowController.makeCurrentStepDone(extractedInformation: extractedInformation,timeStarted: self.timeStarted)
                flowController.naveToNextStep();
            }
        }
    }

    /// Back to the camera after a retry / error / wrong template / liveness screen: the side starts again
    /// (HostVC.retry() -> ScanIDCard.retryLiveness(); the old capture and the manual capture restart the same way).
    private func retryScan() {
        DispatchQueue.main.async {
            screenEvent = .idle
            start = true
            feedbackText = ""
            livenessImage = nil
            tiltProgress = 0
            tiltProgressVisible = false
            livenessActive = false
            commands.triggerRetry += 1
        }
    }

    /// The flip screen's button: the back (the classifier and the liveness start again for it).
    private func flipToBack() {
        DispatchQueue.main.async {
            screenEvent = .idle
            start = true
            feedbackText = ""
            livenessImage = nil                                     // the back never shows the front's image
            tiltProgress = 0
            tiltProgressVisible = false
            livenessActive = false
            commands.triggerFlep += 1                               // ScanIDCard.changeTemplateId()
        }
    }

    /// Track Progress for the retry-like screens.
    private func track(_ model: RemoteProcessingModel, _ label: String) {
        let currentStep = flowController.getCurrentStep()
        let errorString = model.responseJsonObject?["error"] as? String
        let extracted = flowController.extractAfterDash(errorString)
        let finalResponse = extracted.isEmpty ? label : "\(label) - \(extracted)"
        flowController.trackProgress(
            currentStep: currentStep!,
            inputData: flowController.decodeToJsonObject(model.response),
            response: finalResponse,
            status: "InProgress"
        )
    }

    private func imageUrlOf(_ model: RemoteProcessingModel) -> String {
        guard let response = model.response, !response.isEmpty else { return "" }   // the local liveness has no image URL
        return getImageUrlFromBaseResponseDataModel(jsonString: response)
    }
    
    public var body: some View {
        
        let events = IDScanEvents(
            onSend: {
                DispatchQueue.main.async {
                    start = true
                    tiltProgressVisible = false
                }
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
                    if !classifiedTemplate.isEmpty, let tbc = self.templatesByCountry ?? templatesByCountryValue {
                        for template in tbc.templates {
                            for detail in template.kycDocumentDetails {
                                if detail.templateProcessingKeyInformation == classifiedTemplate {
                                    kycDocumentDetails = template.kycDocumentDetails
                                }
                            }
                        }
                    }
                    
                    var currentMap = extractedInformation
                    if let newProps = model.iDExtractedModel?.transformedProperties {
                        let filtered = newProps.filter { key, _ in
                            !key.isEmpty && currentMap[key] == nil
                        }
                        currentMap.merge(filtered) { current, _ in current }
                    }
                    extractedInformation = currentMap
                    
                    OnCompleteScreenData.shared.clear();
                    OnCompleteScreenData.shared.set(extractedInformation)

                    start = false
                    feedbackText = ""
                    uploadProgress = 0
                    tiltProgressVisible = false
                    livenessActive = false
                    
                    if(isLastPage){
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
                        screenEvent = .flip                         // the back starts when the flip screen's button is pressed
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
                    tiltProgressVisible = false
                    imageUrl = imageUrlOf(model)
                    screenEvent = .error
                    track(model, "Error")
                }
            },
            onRetry: { model in
                DispatchQueue.main.async {
                    start = false
                    tiltProgressVisible = false
                    imageUrl = imageUrlOf(model)
                    screenEvent = .retry
                    track(model, "onRetry")
                }
            },
            onWrongTemplate: { model in
                DispatchQueue.main.async {
                    start = false
                    tiltProgressVisible = false
                    imageUrl = imageUrlOf(model)
                    screenEvent = .wrongTemplate
                    track(model, "onWrongTemplate")
                }
            },
            // the server's liveness failure (image nil: its URL), or the LOCAL card liveness failed (the camera's image)
            onLivenessUpdate: { model, image in
                DispatchQueue.main.async {
                    livenessActive = false
                    start = false
                    tiltProgressVisible = false
                    livenessImage = image
                    imageUrl = image != nil ? "" : imageUrlOf(model)
                    screenEvent = .liveness
                    track(model, "onLivenessUpdate")
                }
            },
            onEnvironmental: { brightnessEvents, motion, zoom, isCentered in
                DispatchQueue.main.async {
                    if livenessActive { return }                    // the local liveness owns the text
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
            },
            // the local card liveness: what the user should do now, and the tilt meter (0..100)
            onLivenessInstruction: { instruction, progress in
                DispatchQueue.main.async {
                    livenessActive = instruction.livenessActive     // not after "keep holding" / "barcode read"
                    feedbackText = FlowStrings.idLivenessText(instruction)
                    tiltProgress = progress
                    tiltProgressVisible = instruction.showsTiltMeter
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
                        if !showHoldPopup {                         // the instructions start once the popup is closed
                            LivenessFeedbackView(
                                text: feedbackText,
                                progress: tiltProgress,
                                showProgress: tiltProgressVisible
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
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
                    .first(where: { $0.templateProcessingKeyInformation == classifiedTemplate })?.hasQrCode ?? false){
                    OnNormalCompleteScreen(imageUrl: self.imageUrl,
                                           onNext: { onNext() },
                                           onBack: { onBack() })
                }else{
                    if showResultPage {
                        OnCompleteScreen(imageUrl: self.imageUrl,
                                         onNext: { onNext() },
                                         onBack: { onBack() })
                    } else {
                        OnNormalCompleteScreen(imageUrl: self.imageUrl,
                                               onNext: { onNext() },
                                               onBack: { onBack() })
                    }
                }
                
            case .error , .retry :
                OnErrorScreen(imageUrl: self.imageUrl, onRetry: { retryScan() }, onBack: { onBack() })

            case .wrongTemplate:
                OnWrongTemplateScreen(imageUrl: self.imageUrl, expectedImageUrl: "", onRetry: { retryScan() }, onBack: { onBack() })
                
            case .liveness:
                OnLivenessScreen(imageUrl: self.imageUrl, image: self.livenessImage, onRetry: { retryScan() }, onBack: { onBack() })

            case .flip:
                OnFlipCardScreen(expectedImageUrl: kycDocumentDetails.first(where: { $0.templateProcessingKeyInformation != classifiedTemplate })?.templateSpecimen ?? "",
                                 onNext: { flipToBack() },
                                 onBack: { onBack() })
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

            // ---------- on top of everything: hold the card in your hand (auto scan only) ----------
            if showHoldPopup && screenEvent == .idle && !(assentifySdk?.isManual() ?? false) {
                HoldCardInHandPopup(
                    title: FlowStrings.holdCardTitle,
                    message: FlowStrings.holdCardMsg,
                    buttonText: FlowStrings.continueButton,
                    onContinue: { showHoldPopup = false }   // only closes the popup: the scan goes on as it is
                )
                .zIndex(1000)
            }
        }
        .onAppear{ isNavigating = false}
        .animation(.easeInOut(duration: 0.2), value: start)
        .animation(.easeInOut(duration: 0.2), value: showHoldPopup)
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
        
        /// The liveness failed: image nil from the server (its URL), the camera's image from the local liveness.
        func onLivenessUpdate(dataModel: RemoteProcessingModel, image: UIImage?) {
            events.onLivenessUpdate?(dataModel, image)
        }
        
        func onEnvironmentalConditionsChange(
            brightnessEvents: BrightnessEvents,
            motion: MotionType,
            zoom: ZoomType,
            isCentered: Bool
        ) {
            events.onEnvironmental?(brightnessEvents, motion, zoom, isCentered)
        }

        /// The local card liveness: what the user should do now, and the tilt meter (0..100).
        func onLivenessInstruction(instruction: IdLivenessInstruction, progress: Int) {
            events.onLivenessInstruction?(instruction, progress)
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
        
        /// The flip screen's button: the back (the classifier and the liveness start again).
        private func flep() {
            self.idVC?.changeTemplateId()
        }
        
        /// The retry buttons: this side starts again from Position (also the old and the manual capture).
        private func retry() {
            idVC?.retryLiveness()
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
