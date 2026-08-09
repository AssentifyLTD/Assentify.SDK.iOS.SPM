import SwiftUI
import UIKit


struct PassportScanEvents {
    var onSend: (() -> Void)? = nil
    var onProgress: ((Double) -> Void)? = nil
    var onComplete: ((PassportResponseModel) -> Void)? = nil
    var onError: ((RemoteProcessingModel) -> Void)? = nil
    var onRetry: ((RemoteProcessingModel) -> Void)? = nil
    var onLivenessUpdate: ((RemoteProcessingModel) -> Void)? = nil
    var onWrongTemplate: ((RemoteProcessingModel) -> Void)? = nil
    var onEnvironmental: ((BrightnessEvents, MotionType, ZoomType, Bool) -> Void)? = nil
}

enum PassportScreenEvent {
    case idle
    case sending
    case completed
    case error
    case retry
    case expired
    case liveness
    case wrongTemplate
}

final class PassportScanCommands: ObservableObject {
    @Published var triggerRetry: Int = 0
    @Published var triggerCapture: Int = 0
    @Published var triggerClose: Int = 0
}

public struct PassportScanStep: View {
    
    @State private var start: Bool = false
    @State private var feedbackText: String = ""
    @State private var imageUrl: String = ""
    @State private var dataIDModel: PassportResponseModel?
    @StateObject private var commands = PassportScanCommands()
    @State private var uploadProgress: Int = 0
    @State private var screenEvent: PassportScreenEvent = .idle
    private let timeStarted :String = getCurrentDateTimeForTracking();
    
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
        flowController.backClick()
    }
    
    private func onNext() {
        DispatchQueue.main.async {
            screenEvent = .idle
        }
        commands.triggerClose += 1
        if(FlowEnvironmentalConditionsObject.shared.get()!.enableNfc){
            self.flowController.push(NfcScanScreen(flowController: self.flowController))
        }else{
            flowController.makeCurrentStepDone(extractedInformation: (dataIDModel?.passportExtractedModel!.transformedProperties)!,timeStarted: self.timeStarted)
            flowController.naveToNextStep();
        }
    }
    
    
    
    public var body: some View {
        
        let events = PassportScanEvents(
            onSend: {
                DispatchQueue.main.async {
                    start = true;
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
            onError: { model in
                DispatchQueue.main.async {
                    start = false;
                    imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: model.response)
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
                    print("errorString")
                    print(model.error)
                    if(model.error == "Expired Passport Detected"){
                        start = false;
                        imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: model.response)
                        screenEvent = .expired
                        
                        /** Track Progress **/
                        let currentStep = flowController.getCurrentStep()
                        let errorString = model.responseJsonObject?["error"] as? String
                        let extracted = flowController.extractAfterDash(errorString)

                        let finalResponse = extracted.isEmpty
                            ? "Expired"
                            : "Expired  - \(extracted)"

                        flowController.trackProgress(
                            currentStep: currentStep!,
                            inputData: flowController.decodeToJsonObject(model.response),
                            response: finalResponse,
                            status: "InProgress"
                        )
                        /**/
                    }else{
                        start = false;
                        imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: model.response)
                        screenEvent = .retry
                        
                        /** Track Progress **/
                        let currentStep = flowController.getCurrentStep()
                        let errorString = model.responseJsonObject?["error"] as? String
                        let extracted = flowController.extractAfterDash(errorString)

                        let finalResponse = extracted.isEmpty
                            ? "Retry"
                            : "Retry - \(extracted)"

                        flowController.trackProgress(
                            currentStep: currentStep!,
                            inputData: flowController.decodeToJsonObject(model.response),
                            response: finalResponse,
                            status: "InProgress"
                        )
                        /**/
                    }
                    
                  
                }
            },
            onLivenessUpdate:{ model in
                DispatchQueue.main.async {
                    
                    start = false;
                    imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: model.response)
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
            onWrongTemplate: { model in
                DispatchQueue.main.async {
                    
                    start = false;
                    imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: model.response)
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
            
            onEnvironmental: { brightnessEvents, motion, zoom, isCentered in
                DispatchQueue.main.async {
                    
                        
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
            }
        )
        
        
        ZStack {
            
            PassportScanUIKitView(
                flowController: flowController,
                events: events,
                commands: commands
            )
            .ignoresSafeArea()
            
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
                    .background(Color.black.opacity(0.35).ignoresSafeArea()) // optional dim
                    .zIndex(999)
                    .allowsHitTesting(true) // blocks clicks behind
                    .transition(.opacity)
            case .completed:
                
                if(FlowEnvironmentalConditionsObject.shared.get()!.enableNfc){
                    OnNormalCompleteScreen(imageUrl:self.imageUrl,
                       onNext: {
                        onNext()
                    },
                        onBack: {
                        onBack()
                      })
                }else{
                    if(self.showResultPage){
                        
                        OnCompleteScreen(imageUrl:self.imageUrl
                                         ,
                                            onNext: {
                                             onNext()
                                         },
                                             onBack: {
                                             onBack()
                                           })
                    }else{
                        OnNormalCompleteScreen(imageUrl:self.imageUrl
                                               ,
                                                  onNext: {
                                                   onNext()
                                               },
                                                   onBack: {
                                                   onBack()
                                                 })
                    }
                }
                
            case .error:
                OnErrorScreen(imageUrl:self.imageUrl,onRetry:
                 {
                    DispatchQueue.main.async {
                        screenEvent = .idle
                        start = true;
                        commands.triggerRetry += 1
                    }
                },onBack: {
                    onBack()
                  })
                
            case .retry:
                OnErrorScreen(imageUrl:self.imageUrl,onRetry:
                  {
                    DispatchQueue.main.async {
                        screenEvent = .idle
                        start = true;
                        commands.triggerRetry += 1
                    }
                },onBack: {
                    onBack()
                  }
                )
            case .expired:
                OnPassportExpired(imageUrl:self.imageUrl,onRetry:
                {
                    DispatchQueue.main.async {
                        screenEvent = .idle
                        start = true;
                        commands.triggerRetry += 1
                    }
                },onBack: {
                    onBack()
                  })
            case .wrongTemplate:
                OnErrorScreen(imageUrl:self.imageUrl
                              ,onRetry: {
                    DispatchQueue.main.async {
                        screenEvent = .idle
                        start = true;
                        commands.triggerRetry += 1
                    }
                },onBack: {
                    onBack()
                  })
            case .liveness:
                OnLivenessScreen(imageUrl:self.imageUrl
                ,onRetry:  {
                    
                    DispatchQueue.main.async {
                        screenEvent = .idle
                        start = true;
                        commands.triggerRetry += 1
                    }
                    
                },onBack: {
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
        .modifier(InterceptSystemBack(action: onBack))
        
    }
}

// ✅ MUST be a struct (value type)
struct PassportScanUIKitView: UIViewControllerRepresentable {
    
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
        
        /**  Events  **/
        
        
        func onSend() {
            events.onSend?()
        }
        
        func onUploadingProgress(progress: Double) {
            events.onProgress?(progress)
        }
        
        func onComplete(dataModel: PassportResponseModel) {
            events.onComplete?(dataModel)
        }
        
        func onError(dataModel: RemoteProcessingModel) {
            events.onError?(dataModel)
        }
        
        func onRetry(dataModel: RemoteProcessingModel) {
            events.onRetry?(dataModel)
        }
        
        func onLivenessUpdate(dataModel: RemoteProcessingModel) {
            events.onLivenessUpdate?(dataModel)
        }
        
        func onWrongTemplate(dataModel: RemoteProcessingModel) {
            events.onWrongTemplate?(dataModel)
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
        
        weak var delegate: ScanPassportDelegate?
        var flowController: FlowController?
        
        private var passportVC: ScanPassport?
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
        
        private func retry() {
            
        }
        
        private func capture() {
            passportVC?.takePicture();
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
            
            guard let vc = assentifySdk?.startScanPassport(
                scanPassportDelegate: delegate,
                language: FlowEnvironmentalConditionsObject.shared.get()!.extractedDataLanguage,
                stepId: stepId
            ) else {
                assertionFailure("startScanPassport returned nil (sdk instance or config missing)")
                return
            }
            
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
