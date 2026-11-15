import SwiftUI
import UIKit

/// The supporting ID card scan (front + back), then face compare + identity match, then the result.
/// Kotlin: SupportingIDCardScanActivity + IDCardScanScreen.
struct SupportingIDCardScanStep: View {

    @State private var start = false
    @State private var feedbackText = ""
    @State private var imageUrl = ""
    @State private var livenessImage: UIImage? = nil            // the local liveness's image (nil = use imageUrl)
    @State private var uploadProgress = 0
    @State private var screenEvent: IDScreenEvent = .idle

    @State private var classifiedTemplate = ""
    @State private var kycDocumentDetails: [KycDocumentDetails] = []

    // collected across the card's pages (front + back)
    @State private var extractedInformation: [String: String] = [:]
    @State private var docFace = ""

    // supporting-document result
    @State private var faceResult: CompareFacesResponse?
    @State private var identityResult: IdentityMatchResponse?
    @State private var selfieImage = ""
    @State private var supportingDocImage = ""

    // card liveness: the tilt meter (0..100) and who owns the instruction text
    @State private var tiltProgress = 0
    @State private var tiltProgressVisible = false
    @State private var livenessActive = false

    // "Hold the card in your hand": shown when the scan opens, until Continue
    @State private var showHoldPopup = true
    @State private var isNavigating = false

    @StateObject private var commands = IDScanCommands()
    private let timeStarted: String = getCurrentDateTimeForTracking()
    private let assentifySdk = AssentifySdkObject.shared.get()
    private let flowController: FlowController
    private let templatesByCountry: TemplatesByCountry?
    private let faceSettings: FaceStepSettings          // read once: the face step is still current here

    init(flowController: FlowController) {
        self.flowController = flowController
        self.faceSettings = FaceStepSettings(flowController: flowController)

        let accepted = flowController.getCurrentStep()?.stepDefinition?
            .customization.supportingDocumentAcceptedDocuments ?? []
        self.templatesByCountry = AssentifySdkObject.shared.get()?
            .getTemplatesForSupportingDoc(supportingDocumentAcceptedDocuments: accepted)
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

        let outputs = SupportingDocChecks.outputProperties(
            isSkip: isSkip,
            faceResult: faceResult,
            identityResult: identityResult,
            documentProperties: extractedInformation
        )
        flowController.makeCurrentStepDone(extractedInformation: outputs, timeStarted: timeStarted)
        flowController.naveToNextStep()
    }

    /// Back to the camera after a retry / error / wrong template / liveness screen.
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
            commands.triggerRetry += 1
        }
    }

    /// The flip screen's button: the back (the classifier and the liveness start again).
    private func flipToBack() {
        DispatchQueue.main.async {
            screenEvent = .idle
            start = false
            feedbackText = ""
            uploadProgress = 0
            livenessImage = nil
            tiltProgress = 0
            tiltProgressVisible = false
            livenessActive = false
            commands.triggerFlep += 1
        }
    }

    /// The last page is read: run both checks while the sending screen stays up.
    private func runChecks() {
        let documentFace = docFace
        let documentProperties = extractedInformation

        SupportingDocChecks.run(
            flowController: flowController,
            documentProperties: documentProperties,
            documentFace: documentFace,
            useCase: IdentityMatchUseCase.supportingDoc
        ) { outcome in
            faceResult = outcome.faceResult
            identityResult = outcome.identityResult
            selfieImage = outcome.selfieImage
            supportingDocImage = documentFace
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
            onComplete: { model, isFrontPage, isLastPage, template in
                DispatchQueue.main.async {
                    classifiedTemplate = template

                    // the classified template's pages (the flip screen shows the other page)
                    if !template.isEmpty,
                       let match = templatesByCountry?.templates.first(where: { t in
                           t.kycDocumentDetails.contains { $0.templateProcessingKeyInformation == template }
                       }) {
                        kycDocumentDetails = match.kycDocumentDetails
                    }

                    // transformed properties, collected across pages (the first value of a key wins)
                    var collected = extractedInformation
                    for (key, value) in model.iDExtractedModel?.transformedProperties ?? [:]
                    where !key.isEmpty && collected[key] == nil {
                        collected[key] = value
                    }
                    extractedInformation = collected

                    // the face to compare with: from the front page, or the first page that has one
                    if isFrontPage || docFace.isEmpty,
                       let face = model.iDExtractedModel?.faces?.first,
                       !face.trimmingCharacters(in: .whitespaces).isEmpty {
                        docFace = face
                    }

                    tiltProgressVisible = false
                    livenessActive = false

                    if !isLastPage {
                        // front page done -> the flip screen
                        start = false
                        feedbackText = ""
                        uploadProgress = 0
                        screenEvent = .flip
                        return
                    }

                    // last page -> stay on the sending screen while both checks run
                    screenEvent = .sending
                    runChecks()
                }
            },
            onError: { model in
                DispatchQueue.main.async {
                    start = false
                    tiltProgressVisible = false
                    livenessActive = false
                    imageUrl = imageUrlOf(model)
                    screenEvent = .error
                }
            },
            onRetry: { model in
                DispatchQueue.main.async {
                    start = false
                    tiltProgressVisible = false
                    livenessActive = false
                    imageUrl = imageUrlOf(model)
                    screenEvent = .retry
                }
            },
            onWrongTemplate: { model in
                DispatchQueue.main.async {
                    start = false
                    tiltProgressVisible = false
                    livenessActive = false
                    imageUrl = imageUrlOf(model)
                    screenEvent = .wrongTemplate
                }
            },
            onLivenessUpdate: { model, image in
                // the server's liveness (image nil: its URL), or the local card liveness (the camera's image)
                DispatchQueue.main.async {
                    livenessActive = false
                    start = false
                    tiltProgressVisible = false
                    livenessImage = image
                    imageUrl = image != nil ? "" : imageUrlOf(model)
                    screenEvent = .liveness
                }
            },
            onEnvironmental: { brightnessEvents, motion, zoom, isCentered in
                DispatchQueue.main.async {
                    if livenessActive { return }                    // the local liveness owns the text
                    guard !start else {
                        feedbackText = ""
                        return
                    }
                    if zoom != .SENDING && zoom != .NO_DETECT {
                        if zoom == .ZOOM_IN {
                            feedbackText = FlowStrings.moveIdCloser
                        } else if zoom == .ZOOM_OUT {
                            feedbackText = FlowStrings.moveIdFurther
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
                        if motion == .SENDING && zoom == .SENDING && isCentered {
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

            if let templatesByCountry {
                SupportingIDScanUIKitView(
                    flowController: flowController,
                    templatesByCountry: templatesByCountry,
                    events: events,
                    commands: commands
                )
                .ignoresSafeArea()
            } else {
                Color.clear.ignoresSafeArea()
            }

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
                            .padding(.horizontal, 32)
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

            case .error, .retry:
                OnErrorScreen(imageUrl: imageUrl, onRetry: { retryScan() }, onBack: { onBack() })

            case .wrongTemplate:
                OnWrongTemplateScreen(imageUrl: imageUrl, expectedImageUrl: "", onRetry: { retryScan() }, onBack: { onBack() })

            case .liveness:
                OnLivenessScreen(imageUrl: imageUrl, image: livenessImage, onRetry: { retryScan() }, onBack: { onBack() })

            case .flip:
                OnFlipCardScreen(
                    expectedImageUrl: kycDocumentDetails
                        .first(where: { $0.templateProcessingKeyInformation != classifiedTemplate })?
                        .templateSpecimen ?? "",
                    onNext: { flipToBack() },
                    onBack: { onBack() }
                )
            }

            let showLogo = screenEvent == .idle || BaseTheme.stepperType == .normal
            Color.clear
                .topBarBackLogo(logoUrl: showLogo ? BaseTheme.baseLogo : "", noStepper: showLogo) {
                    onBack()
                }

            // on top of everything: hold the card in your hand (auto scan only)
            if showHoldPopup && screenEvent == .idle && !isManual {
                HoldCardInHandPopup(
                    title: FlowStrings.holdCardTitle,
                    message: FlowStrings.holdCardMsg,
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

// MARK: - UIKit bridge (reuses IDScanUIKitView.Coordinator)

struct SupportingIDScanUIKitView: UIViewControllerRepresentable {

    let flowController: FlowController
    let templatesByCountry: TemplatesByCountry
    let events: IDScanEvents
    @ObservedObject var commands: IDScanCommands

    func makeCoordinator() -> IDScanUIKitView.Coordinator {
        IDScanUIKitView.Coordinator(flowController: flowController, events: events)
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

    final class HostVC: UIViewController {

        weak var delegate: ScanIDCardDelegate?
        var flowController: FlowController?
        var templatesByCountry: TemplatesByCountry?

        private var idVC: ScanIDCard?
        private let assentifySdk = AssentifySdkObject.shared.get()
        private var lastRetryTrigger = 0
        private var lastCaptureTrigger = 0
        private var lastCloseTrigger = 0
        private var lastFlipTrigger = 0

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            startIDIfNeeded()
        }

        func apply(commands: IDScanCommands) {
            if commands.triggerRetry != lastRetryTrigger {
                lastRetryTrigger = commands.triggerRetry
                idVC?.retryLiveness()
            }
            if commands.triggerCapture != lastCaptureTrigger {
                lastCaptureTrigger = commands.triggerCapture
                idVC?.takePicture()
            }
            if commands.triggerClose != lastCloseTrigger {
                lastCloseTrigger = commands.triggerClose
                close()
            }
            if commands.triggerFlep != lastFlipTrigger {
                lastFlipTrigger = commands.triggerFlep
                idVC?.changeTemplateId()
            }
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

            let stepId = flowController?.getCurrentStep()?.stepDefinition?.stepId

            // TODO: add `enableSupportingDocument` to startScanID if your Swift SDK doesn't have it
            guard let vc = assentifySdk?.startScanID(
                scanIDCardDelegate: delegate,
                templatesByCountry: templatesByCountry,
                language: FlowEnvironmentalConditionsObject.shared.get()!.extractedDataLanguage,
                stepId: stepId,
                enableSupportingDocument: true
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
