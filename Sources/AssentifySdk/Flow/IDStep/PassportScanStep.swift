import SwiftUI
import UIKit


struct PassportScanEvents {
    var onSend: (() -> Void)? = nil
    var onProgress: ((Double) -> Void)? = nil
    var onComplete: ((PassportResponseModel) -> Void)? = nil
    var onError: ((RemoteProcessingModel) -> Void)? = nil
    var onRetry: ((RemoteProcessingModel) -> Void)? = nil
    var onLivenessUpdate: ((RemoteProcessingModel, UIImage?) -> Void)? = nil   // image: the local liveness's (nil = server)
    var onWrongTemplate: ((RemoteProcessingModel) -> Void)? = nil
    var onEnvironmental: ((BrightnessEvents, MotionType, ZoomType, Bool) -> Void)? = nil
    var onLivenessInstruction: ((PassportLivenessInstruction, Int) -> Void)? = nil
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
    @State private var livenessImage: UIImage? = nil                // the local liveness's image (nil = use imageUrl)
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

    /// Back to the camera after an error / retry / liveness screen: the liveness starts again (HostVC.retry()).
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

    /// The liveness instruction as text (PassportScanActivity.onLivenessInstruction).
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
                    livenessActive = false
                    tiltProgressVisible = false
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
                    tiltProgressVisible = false
                    imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: model.response)
                    screenEvent = .error
                    track(model, "Error")
                }
            },
            onRetry: { model in
                DispatchQueue.main.async {
                    tiltProgressVisible = false
                    start = false;
                    imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: model.response)
                    if(model.error == "Expired Passport Detected"){
                        screenEvent = .expired
                        track(model, "Expired ")
                    }else{
                        screenEvent = .retry
                        track(model, "Retry")
                    }
                }
            },
            onLivenessUpdate:{ model, image in
                // the server's liveness (image nil: its URL), or the LOCAL liveness (suspected_copy / inconclusive):
                // the camera's image
                DispatchQueue.main.async {
                    start = false;
                    livenessActive = false
                    tiltProgressVisible = false
                    livenessImage = image
                    imageUrl = image != nil || (model.response ?? "").isEmpty ? "" : getImageUrlFromBaseResponseDataModel(jsonString: model.response)
                    screenEvent = .liveness
                    track(model, "onLivenessUpdate")
                }
            },
            onWrongTemplate: { model in
                DispatchQueue.main.async {
                    start = false;
                    tiltProgressVisible = false
                    imageUrl = getImageUrlFromBaseResponseDataModel(jsonString: model.response)
                    screenEvent = .wrongTemplate
                    track(model, "onWrongTemplate")
                }
            },
            
            onEnvironmental: { brightnessEvents, motion, zoom, isCentered in
                DispatchQueue.main.async {
                    if livenessActive { return }                    // the liveness owns the instruction text
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
                    livenessActive = instruction != .keepHolding    // the liveness owns the text while it runs
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

            // ---------- on top of everything: hold the passport in your hand (auto scan only) ----------
            if showHoldPopup && screenEvent == .idle && !(assentifySdk?.isManual() ?? false) {
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

// MARK: - The instruction box with the tilt meter (LivenessFeedback in PassportScanActivity.kt)

/// The instruction in a rounded box, with the tilt meter (0..100%) underneath while the passport is tilted.
struct LivenessFeedbackView: View {
    let text: String
    let progress: Int
    let showProgress: Bool

    @State private var pulse = false

    var body: some View {
        let accent = Color(BaseTheme.baseAccentColor)
        let percent = max(0, min(100, progress))
        let done = percent >= 100

        if !text.isEmpty || showProgress {
            VStack(spacing: 8) {
                // ---------- instruction ----------
                if !text.isEmpty {
                    HStack(spacing: 8) {
                        ZStack {                                    // a small dot that pulses while there is something to do
                            Circle().fill(accent).frame(width: 8, height: 8)
                                .scaleEffect(pulse && !done ? 1.6 : 1)
                                .opacity(done ? 0 : 0.35)
                            Circle().fill(accent).frame(width: 8, height: 8)
                        }
                        .frame(width: 14, height: 14)
                        Text(text)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .id(text)
                            .transition(.opacity)
                    }
                    .frame(maxWidth: .infinity)
                }

                // ---------- tilt meter ----------
                if showProgress {
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(accent.opacity(0.18))
                                Capsule()
                                    .fill(LinearGradient(colors: [accent.opacity(0.65), accent],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(percent) / 100)
                            }
                        }
                        .frame(height: 7)

                        HStack {
                            Text(done ? FlowStrings.livenessDone : FlowStrings.livenessTiltProgress)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.65))
                            Spacer()
                            HStack(spacing: 3) {
                                if done {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(accent)
                                }
                                Text("\(percent)%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(accent)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(accent.opacity(0.15)))
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.65)))   // ← your theme's field colour
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.30), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.25), radius: 6)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: percent)
            .animation(.easeInOut(duration: 0.22), value: text)
            .animation(.easeInOut(duration: 0.22), value: showProgress)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
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
        
        /// The liveness failed: image nil from the server (its URL), the camera's image from the local liveness.
        func onLivenessUpdate(dataModel: RemoteProcessingModel, image: UIImage?) {
            events.onLivenessUpdate?(dataModel, image)
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

        /// The local liveness: what the user should do now, and the tilt meter (0..100).
        func onLivenessInstruction(instruction: PassportLivenessInstruction, progress: Int) {
            events.onLivenessInstruction?(instruction, progress)
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
        
        /// The retry buttons: a stopped liveness (suspected_copy / inconclusive) starts again from Position.
        private func retry() {
            passportVC?.retryLiveness()
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
