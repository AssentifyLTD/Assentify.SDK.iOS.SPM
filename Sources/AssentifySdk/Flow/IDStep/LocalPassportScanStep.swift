import SwiftUI
import UIKit



public struct LocalPassportScanStep: View {
    
    @State private var start: Bool = false
    @State private var feedbackText: String = ""
    @State private var imageUrl: String = ""
    @State private var livenessImage: UIImage? = nil                // the local liveness's image
    @State private var dataIDModel: PassportResponseModel?
    @StateObject private var commands = PassportScanCommands()
    @State private var uploadProgress: Int = 0
    @State private var screenEvent: PassportScreenEvent = .idle
    private let timeStarted :String = getCurrentDateTimeForTracking();
    @State private var isNavigating: Bool = false

    // liveness: the tilt meter (0..100) under the instruction, and who owns the instruction text
    @State private var tiltProgress: Int = 0
    @State private var tiltProgressVisible: Bool = false
    @State private var livenessActive: Bool = false

    // "Hold the passport in your hand": shown on top of the camera when the scan opens, until Continue
    @State private var showHoldPopup: Bool = true

    private var assentifySdk = AssentifySdkObject.shared.get()
    private let flowController: FlowController
    private var showResultPage = false
    public init(flowController: FlowController) {
        self.flowController = flowController
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
    
    private func onBack() {
        commands.triggerClose += 1
        flowController.pop(animated: true)
    }
    
    private func onNext() {
        if (!isNavigating) {
            isNavigating = true
            commands.triggerClose += 1
            if(FlowEnvironmentalConditionsObject.shared.get()!.enableNfc){
                self.flowController.push(NfcScanScreen(flowController: self.flowController))
            }else{
                flowController.makeCurrentStepDone(extractedInformation: (dataIDModel?.passportExtractedModel!.transformedProperties)!,timeStarted: self.timeStarted)
                flowController.naveToNextStep();
            }
        }
    }

    /// Back to the camera after a retry / expired / liveness screen: the liveness starts again (HostVC.retry()).
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

    /// The liveness instruction as text (same texts as PassportScanStep / Android).
    private func livenessText(_ i: PassportLivenessInstruction) -> String {
        switch i {
        case .placeDocument: return FlowStrings.livenessPlaceDocument
        case .keepSteady, .keepFlat, .adjustPosition, .doNotMove: return FlowStrings.livenessKeepSteady
        case .liftBottom: return FlowStrings.livenessLiftBottom
        case .moveALittleMore: return FlowStrings.livenessMoveLittleMore     // tilt reached, colours awaited
        case .holdThere: return FlowStrings.livenessHoldThere
        case .otherSide: return FlowStrings.livenessOtherSide
        case .holdItUp: return FlowStrings.livenessHoldItUp
        case .placeFlatAgain: return FlowStrings.livenessPlaceFlatAgain
        case .keepHolding: return FlowStrings.livenessKeepHolding
        case .holdInHand: return FlowStrings.livenessHoldInHand
        case .phoneTurned: return FlowStrings.livenessPhoneTurned
        case .tooBright: return FlowStrings.livenessTooBright
        @unknown default: return ""
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
    
    public var body: some View {
        
        let events = PassportScanEvents(
            onSend: {
                DispatchQueue.main.async {
                    start = true;
                    tiltProgressVisible = false
                }
            },
            onProgress: { p in
                DispatchQueue.main.async {
                    screenEvent = .sending
                    uploadProgress = Int(p * 100)
                }
            },
            onComplete: { model in
                DispatchQueue.main.async {
                    OnCompleteScreenData.shared.clear();
                    OnCompleteScreenData.shared.set(model.passportExtractedModel!.transformedProperties!)
                    NfcPassportResponseModelObject.shared.set(model)
                    dataIDModel = model
                    start = false;
                    imageUrl = model.passportExtractedModel!.imageUrl!
                    if let outputProperties = model.passportExtractedModel?.outputProperties {
                        let faceKey = flowController.getFaceMatchInputImageKey()
                        for (key, value) in outputProperties {
                            if key.contains(faceKey) {
                                flowController.setImage(url: String(describing: value))
                            }
                        }
                    }
                    
                    screenEvent = .completed
                    
                    /** Track Progress **/
                    let currentStep = flowController.getCurrentStep()
                    flowController.trackProgress(
                        currentStep: currentStep!,
                        inputData: model.passportExtractedModel?.transformedProperties,
                        response: "Completed",
                        status: "InProgress"
                    )
                    /**/
                }
            },
            onError: { model in},
            onRetry: { model in
                DispatchQueue.main.async {
                    start = false;
                    imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: model.response)
                    if(model.error == EventsErrorMessages.OnExpiredPassportMessage || model.error == "Expired Passport Detected"){
                        screenEvent = .expired
                        track(model, "Expired")
                    }else{
                        screenEvent = .retry
                        track(model, "Retry")
                    }
                }
            },
            onLivenessUpdate:{ model, image in                      // local verdict: suspected_copy / inconclusive / stalled
                DispatchQueue.main.async {
                    start = false;
                    livenessImage = image                           // the camera's image of the try
                    imageUrl = ""                                   // the local flow has no server image
                    tiltProgressVisible = false
                    screenEvent = .liveness
                    track(model, "onLivenessUpdate")
                }
            },
            onWrongTemplate: { model in
                DispatchQueue.main.async {
                    start = false;
                    imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: model.response)
                    screenEvent = .wrongTemplate
                    track(model, "onWrongTemplate")
                }
            },
            
            // only the old capture (no finder model / config) sends these; the liveness has its own texts
            onEnvironmental: { brightnessEvents, motion, zoom, isCentered in
                DispatchQueue.main.async {
                    if livenessActive { return }
                    if zoom != .SENDING && zoom != .NO_DETECT {
                        if zoom == .ZOOM_IN {
                            feedbackText = FlowStrings.movePassportCloser
                        } else if zoom == .ZOOM_OUT {
                            feedbackText = FlowStrings.movePassportFurther
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
                            feedbackText = FlowStrings.pleasePresentPassport
                        } else if !isCentered {
                            feedbackText = FlowStrings.centerYourCard
                        }
                    }
                }
            },

            onLivenessInstruction: { instruction, progress in
                DispatchQueue.main.async {
                    livenessActive = true                           // the liveness owns the text from now on
                    feedbackText = livenessText(instruction)
                    tiltProgress = progress
                    switch instruction {
                    case .liftBottom, .moveALittleMore, .holdThere, .otherSide, .holdItUp, .keepHolding:
                        tiltProgressVisible = true                  // shows 100% at the end
                    default:
                        tiltProgressVisible = false                 // hidden in the pauses and before the tilt
                    }
                }
            }
        )
        
        
        ZStack {
            
            LocalPassportScanUIKitView(
                flowController: flowController,
                events: events,
                commands: commands
            )
            .ignoresSafeArea()
            
            if screenEvent == .idle && !showHoldPopup {             // the instructions start once the popup is closed
                VStack {
                    Spacer()
                    LivenessFeedbackView(
                        text: feedbackText,
                        progress: tiltProgress,
                        showProgress: tiltProgressVisible
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
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
                
                if(FlowEnvironmentalConditionsObject.shared.get()!.enableNfc){
                    OnNormalCompleteScreen(imageUrl:self.imageUrl,
                                           onNext: { onNext() },
                                           onBack: { onBack() })
                }else{
                    if(self.showResultPage){
                        OnCompleteScreen(imageUrl:self.imageUrl,
                                         onNext: { onNext() },
                                         onBack: { onBack() })
                    }else{
                        OnNormalCompleteScreen(imageUrl:self.imageUrl,
                                               onNext: { onNext() },
                                               onBack: { onBack() })
                    }
                }
                
            case .error:
                OnErrorScreen(imageUrl:self.imageUrl, onRetry: { retryScan() }, onBack: { onBack() })
                
            case .retry:
                OnErrorScreen(imageUrl:self.imageUrl, onRetry: { retryScan() }, onBack: { onBack() })

            case .expired:
                OnPassportExpired(imageUrl:self.imageUrl, onRetry: { retryScan() }, onBack: { onBack() })

            case .wrongTemplate:
                OnErrorScreen(imageUrl:self.imageUrl, onRetry: { retryScan() }, onBack: { onBack() })

            case .liveness:
                OnLivenessScreen(imageUrl:self.imageUrl, image: self.livenessImage, onRetry: { retryScan() }, onBack: { onBack() })
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

            // ---------- on top of everything: hold the passport in your hand ----------
            if showHoldPopup && screenEvent == .idle {
                HoldCardInHandPopup(
                    title: FlowStrings.holdPassportTitle,
                    message: FlowStrings.holdPassportMsg,
                    buttonText: FlowStrings.continueButton,
                    onContinue: { showHoldPopup = false }   // only closes the popup: the scan goes on as it is
                )
                .zIndex(1000)
            }
        }
        .onAppear{ isNavigating = false}
        .animation(.easeInOut(duration: 0.2), value: start)
        .animation(.easeInOut(duration: 0.2), value: showHoldPopup)
        .modifier(InterceptSystemBack(action: onBack))
    }
}

// ✅ MUST be a struct (value type)
struct LocalPassportScanUIKitView: UIViewControllerRepresentable {
    
    typealias UIViewControllerType = HostVC
    
    let flowController: FlowController
    let events: PassportScanEvents
    @ObservedObject var commands: PassportScanCommands
    
    func makeCoordinator() -> Coordinator {
        Coordinator(flowController: flowController, events: events)
    }
    
    func makeUIViewController(context: Context) -> HostVC {
        let vc = HostVC()
        vc.flowController = flowController
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: HostVC, context: Context) {
        uiViewController.apply(commands: commands)
    }
    
    // MARK: - Coordinator (Delegate lives here)
    final class Coordinator: NSObject, ScanPassportDelegate {
        
        let flowController: FlowController
        let events: PassportScanEvents
        
        init(flowController: FlowController, events: PassportScanEvents) {
            self.flowController = flowController
            self.events = events
        }
        
        func onSend() {
            events.onSend?()
        }
        
        func onUploadingProgress(progress: Double) {
            events.onProgress?(progress)
        }
        
        func onComplete(dataModel: PassportResponseModel) {
            events.onComplete?(dataModel)
        }
        
        func onRetry(dataModel: RemoteProcessingModel) {
            events.onRetry?(dataModel)
        }
        
        func onError(dataModel: RemoteProcessingModel) {
            //events.onError?(dataModel)
        }
        
        /// The local liveness verdict (suspected_copy / inconclusive / stalled): the liveness screen, with its image.
        func onLivenessUpdate(dataModel: RemoteProcessingModel, image: UIImage?) {
            events.onLivenessUpdate?(dataModel, image)
        }
        
        func onWrongTemplate(dataModel: RemoteProcessingModel) {
           // events.onWrongTemplate?(dataModel)
        }
        
        func onEnvironmentalConditionsChange(
            brightnessEvents: BrightnessEvents,
            motion: MotionType,
            zoom: ZoomType,
            isCentered: Bool
        ) {
            events.onEnvironmental?(brightnessEvents, motion, zoom, isCentered)
        }

        /// The local liveness: what the user should do now, and the tilt meter (0..100).
        func onLivenessInstruction(instruction: PassportLivenessInstruction, progress: Int) {
            events.onLivenessInstruction?(instruction, progress)
        }
    }
    
    // MARK: - UIKit Host VC
    final class HostVC: UIViewController {
        
        weak var delegate: ScanPassportDelegate?
        var flowController: FlowController?
        
        private var passportVC: LocalScanPassport?
        private var assentifySdk = AssentifySdkObject.shared.get()
        private var lastRetryTrigger: Int = 0
        private var lastCaptureTrigger: Int = 0
        private var lastCloserigger: Int = 0
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            startPassportIfNeeded()
        }
        
        func apply(commands: PassportScanCommands) {
            if commands.triggerRetry != lastRetryTrigger {
                lastRetryTrigger = commands.triggerRetry
                retry()
            }
            if commands.triggerCapture != lastCaptureTrigger {
                lastCaptureTrigger = commands.triggerCapture
                capture()
            }
            if commands.triggerClose != lastCloserigger {
                lastCloserigger = commands.triggerClose
            }
        }
        
        /// The retry buttons: the liveness starts again from Position (also after no MRZ / expired).
        private func retry() {
            passportVC?.retryLiveness()
        }
        
        private func capture() {
        }
        
        private func close() {
            DispatchQueue.main.async {
                self.passportVC?.stopScanning();
                self.passportVC?.willMove(toParent: nil)
                self.passportVC?.view.removeFromSuperview()
                self.passportVC?.removeFromParent()
                self.passportVC = nil
            }
        }
        
        private func startPassportIfNeeded() {
            guard passportVC == nil else { return }
            
            guard let delegate else {
                assertionFailure("ScanPassportDelegate is nil")
                return
            }
            
            guard
                let stepId = flowController?
                    .getCurrentStep()?
                    .stepDefinition?
                    .stepId
            else {
                assertionFailure("stepId is nil")
                return
            }
            
            guard let vc = assentifySdk?.startLocalScanPassport(
                scanPassportDelegate: delegate,
                language: FlowEnvironmentalConditionsObject.shared.get()!.extractedDataLanguage,
                stepId: stepId
            ) else {
                assertionFailure("startLocalScanPassport returned nil (sdk instance or config missing)")
                return
            }

            // the passport kind: "lb" / "lb_passport" -> the Lebanese rules, anything else -> other_passport
            vc.setDocumentKind(SelectedTemplatesObject.shared.get()?.sourceCountryCode)
            
            passportVC = vc
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
