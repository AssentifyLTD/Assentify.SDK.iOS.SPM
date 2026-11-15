import SwiftUI
import UIKit

/// The supporting passport scan, then face compare + identity match, then the result.
/// Kotlin: SupportingPassportScanActivity + PassportScanScreen.
struct SupportingPassportScanStep: View {

    @State private var start = false
    @State private var feedbackText = ""
    @State private var imageUrl = ""
    @State private var livenessImage: UIImage? = nil            // the local liveness's image (nil = use imageUrl)
    @State private var uploadProgress = 0
    @State private var screenEvent: PassportScreenEvent = .idle
    @State private var passportModel: PassportResponseModel?

    // supporting-document result
    @State private var faceResult: CompareFacesResponse?
    @State private var identityResult: IdentityMatchResponse?
    @State private var selfieImage = ""
    @State private var supportingDocImage = ""

    // liveness: the tilt meter (0..100) and who owns the instruction text
    @State private var tiltProgress = 0
    @State private var tiltProgressVisible = false
    @State private var livenessActive = false

    // "Hold the passport in your hand": shown when the scan opens, until Continue
    @State private var showHoldPopup = true
    @State private var isNavigating = false

    @StateObject private var commands = PassportScanCommands()
    private let timeStarted: String = getCurrentDateTimeForTracking()
    private let assentifySdk = AssentifySdkObject.shared.get()
    private let flowController: FlowController
    private let faceSettings: FaceStepSettings          // read once: the face step is still current here

    init(flowController: FlowController) {
        self.flowController = flowController
        self.faceSettings = FaceStepSettings(flowController: flowController)
    }

    private var isManual: Bool { assentifySdk?.isManual() ?? false }

    // MARK: - Actions

    private func onBack() {
        commands.triggerClose += 1
        flowController.pop(animated: true)
    }

    /// Next / Skip on the result screen: write the keys and continue the flow.
    private func onNext(isSkip: Bool) {
        guard !isNavigating else { return }
        isNavigating = true
        commands.triggerClose += 1
        IDImageObject.shared.clear()

        let documentProperties: [String: String] =
            passportModel?.passportExtractedModel?.transformedProperties ?? [:]

        let outputs = SupportingDocChecks.outputProperties(
            isSkip: isSkip,
            faceResult: faceResult,
            identityResult: identityResult,
            documentProperties: documentProperties
        )
        flowController.makeCurrentStepDone(extractedInformation: outputs, timeStarted: timeStarted)
        flowController.naveToNextStep()
    }

    /// Back to the camera after an error / retry / liveness screen.
    private func retryScan() {
        DispatchQueue.main.async {
            screenEvent = .idle
            start = false
            feedbackText = ""
            uploadProgress = 0
            imageUrl = ""
            livenessImage = nil
            tiltProgress = 0
            tiltProgressVisible = false
            livenessActive = false
            faceResult = nil
            identityResult = nil
            selfieImage = ""
            supportingDocImage = ""
            commands.triggerRetry += 1
        }
    }

    /// The passport is read: run both checks while the sending screen stays up.
    private func runChecks(for model: PassportResponseModel) {
        let documentFace = model.passportExtractedModel?.faces?.first ?? ""
        let documentProperties: [String: String] =
            model.passportExtractedModel?.transformedProperties ?? [:]

        SupportingDocChecks.run(
            flowController: flowController,
            documentProperties: documentProperties,
            documentFace: documentFace,
            useCase: IdentityMatchUseCase.mrzViz
        ) { outcome in
            faceResult = outcome.faceResult
            identityResult = outcome.identityResult
            selfieImage = outcome.selfieImage
            supportingDocImage = documentFace
            passportModel = model
            imageUrl = model.passportExtractedModel?.imageUrl ?? ""
            start = false
            tiltProgressVisible = false
            livenessActive = false
            screenEvent = .completed
        }
    }

    private func imageUrlOf(_ model: RemoteProcessingModel) -> String {
        guard let response = model.response, !response.isEmpty else { return "" }
        return getImageUrlFromBaseResponseDataModel(jsonString: response)
    }

    // MARK: - Body

    var body: some View {

        let events = PassportScanEvents(
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
            onComplete: { model in
                DispatchQueue.main.async {
                    screenEvent = .sending
                    runChecks(for: model)
                }
            },
            onError: { model in
                DispatchQueue.main.async {
                    start = false
                    tiltProgressVisible = false
                    imageUrl = imageUrlOf(model)
                    screenEvent = .error
                }
            },
            onRetry: { model in
                DispatchQueue.main.async {
                    start = false
                    tiltProgressVisible = false
                    imageUrl = imageUrlOf(model)
                    screenEvent = model.error == "Expired Passport Detected" ? .expired : .retry
                }
            },
            onLivenessUpdate: { model, image in
                // the server's liveness (image nil: its URL), or the local liveness (the camera's image)
                DispatchQueue.main.async {
                    livenessActive = false
                    start = false
                    tiltProgressVisible = false
                    livenessImage = image
                    imageUrl = image != nil ? "" : imageUrlOf(model)
                    screenEvent = .liveness
                }
            },
            onWrongTemplate: { model in
                DispatchQueue.main.async {
                    start = false
                    tiltProgressVisible = false
                    imageUrl = imageUrlOf(model)
                    screenEvent = .wrongTemplate
                }
            },
            onEnvironmental: { brightnessEvents, motion, zoom, isCentered in
                DispatchQueue.main.async {
                    if livenessActive { return }                    // the liveness owns the text
                    guard !start else {
                        feedbackText = ""
                        return
                    }
                    if zoom != .SENDING && zoom != .NO_DETECT {
                        if zoom == .ZOOM_IN {
                            feedbackText = FlowStrings.movePassportCloser
                        } else if zoom == .ZOOM_OUT {
                            feedbackText = FlowStrings.movePassportFurther
                        }
                    } else if motion != .SENDING && motion != .NO_DETECT {
                        feedbackText = FlowStrings.holdYourHand
                    } else if brightnessEvents != .Good {
                        if brightnessEvents == .TooDark {
                            feedbackText = FlowStrings.increaseLighting
                        } else if brightnessEvents == .TooBright {
                            feedbackText = FlowStrings.reduceLighting
                        }
                    } else {
                        if motion == .SENDING && zoom == .SENDING {
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
                    feedbackText = supportingPassportLivenessText(instruction)
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

            SupportingPassportScanUIKitView(
                flowController: flowController,
                events: events,
                commands: commands
            )
            .ignoresSafeArea()

            if screenEvent == .idle {
                VStack {
                    Spacer()
                    if !isManual {
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
                OnSendScreen(progress: uploadProgress, onBack: { onBack() })
                    .ignoresSafeArea()
                    .background(Color.black.opacity(0.35).ignoresSafeArea())
                    .zIndex(999)
                    .allowsHitTesting(true)
                    .transition(.opacity)

            case .completed:
                SupportingDocResultScreen(
                    settings: faceSettings,
                    selfieImage: selfieImage,
                    supportingDocImage: supportingDocImage,
                    faceResult: faceResult,
                    identityResult: identityResult,
                    onNext: { isSkip in onNext(isSkip: isSkip) },
                    onRetry: { onBack() },                          // back to the document picker
                    onBack: { onBack() }
                )

            case .expired:
                OnPassportExpired(imageUrl: imageUrl, onRetry: { retryScan() }, onBack: { onBack() })

            case .error, .retry, .wrongTemplate:
                OnErrorScreen(imageUrl: imageUrl, onRetry: { retryScan() }, onBack: { onBack() })

            case .liveness:
                OnLivenessScreen(imageUrl: imageUrl, image: livenessImage, onRetry: { retryScan() }, onBack: { onBack() })
            }

            let showLogo = screenEvent == .idle || BaseTheme.stepperType == .normal
            Color.clear
                .topBarBackLogo(logoUrl: showLogo ? BaseTheme.baseLogo : "", noStepper: showLogo) {
                    onBack()
                }

            // on top of everything: hold the passport in your hand (auto scan only)
            if showHoldPopup && screenEvent == .idle && !isManual {
                HoldCardInHandPopup(
                    title: FlowStrings.holdPassportTitle,
                    message: FlowStrings.holdPassportMsg,
                    buttonText: FlowStrings.continueButton,
                    onContinue: { showHoldPopup = false }
                )
                .zIndex(1000)
            }
        }
        .onAppear { isNavigating = false }
        .animation(.easeInOut(duration: 0.2), value: start)
        .animation(.easeInOut(duration: 0.2), value: showHoldPopup)
        .modifier(InterceptSystemBack(action: onBack))
    }
}

/// The liveness instruction as text (same mapping as PassportScanStep).
private func supportingPassportLivenessText(_ instruction: PassportLivenessInstruction) -> String {
    switch instruction {
    case .placeDocument: return FlowStrings.livenessPlaceDocument
    case .keepSteady, .keepFlat, .adjustPosition, .doNotMove: return FlowStrings.livenessKeepSteady
    case .liftBottom: return FlowStrings.livenessLiftBottom
    case .moveALittleMore: return FlowStrings.livenessMoveLittleMore
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

// MARK: - UIKit bridge (reuses PassportScanUIKitView.Coordinator)

struct SupportingPassportScanUIKitView: UIViewControllerRepresentable {

    let flowController: FlowController
    let events: PassportScanEvents
    @ObservedObject var commands: PassportScanCommands

    func makeCoordinator() -> PassportScanUIKitView.Coordinator {
        PassportScanUIKitView.Coordinator(flowController: flowController, events: events)
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

    final class HostVC: UIViewController {

        weak var delegate: ScanPassportDelegate?
        var flowController: FlowController?

        private var passportVC: ScanPassport?
        private let assentifySdk = AssentifySdkObject.shared.get()
        private var lastRetryTrigger = 0
        private var lastCaptureTrigger = 0
        private var lastCloseTrigger = 0

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            startPassportIfNeeded()
        }

        func apply(commands: PassportScanCommands) {
            if commands.triggerRetry != lastRetryTrigger {
                lastRetryTrigger = commands.triggerRetry
                passportVC?.retryLiveness()
            }
            if commands.triggerCapture != lastCaptureTrigger {
                lastCaptureTrigger = commands.triggerCapture
                passportVC?.takePicture()
            }
            if commands.triggerClose != lastCloseTrigger {
                lastCloseTrigger = commands.triggerClose
                close()
            }
        }

        private func close() {
            DispatchQueue.main.async {
                self.passportVC?.stopScanning()
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

            guard let stepId = flowController?.getCurrentStep()?.stepDefinition?.stepId else {
                assertionFailure("stepId is nil")
                return
            }

            // TODO: add `enableSupportingDocument` to startScanPassport if your Swift SDK doesn't have it
            guard let vc = assentifySdk?.startScanPassport(
                scanPassportDelegate: delegate,
                language: FlowEnvironmentalConditionsObject.shared.get()!.extractedDataLanguage,
                stepId: stepId,
                enableSupportingDocument: true
            ) else {
                assertionFailure("startScanPassport returned nil (sdk instance or config missing)")
                return
            }

            vc.setDocumentKind("")                          // Kotlin: setDocumentKind("")

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
