import SwiftUI
import UIKit

// MARK: - Events (QR Scan)

struct QrScanEvents {
    var onStart: (() -> Void)? = nil
    var onProgress: ((Double) -> Void)? = nil
    var onComplete: ((IDResponseModel) -> Void)? = nil
    var onError: ((RemoteProcessingModel) -> Void)? = nil
}

enum QrScreenEvent {
    case idle
    case sending
    case completed
    case error
}

final class QrScanCommands: ObservableObject {
    @Published var triggerRetry: Int = 0
    @Published var triggerClose: Int = 0
    @Published var triggerCapture: Int = 0
}

// MARK: - SwiftUI Step

public struct QrScanStep: View {

    @State private var start: Bool = false
    @State private var uploadProgress: Int = 0
    @State private var screenEvent: QrScreenEvent = .idle

    @State private var imageUrl: String = ""

    @State private var errorMessage: String = ""

    @StateObject private var commands = QrScanCommands()

    private var assentifySdk = AssentifySdkObject.shared.get()
    private let flowController: FlowController
    @State private var dataIDModel: IDResponseModel?

    private let timeStarted :String = getCurrentDateTimeForTracking();
    private var showResultPage: Bool = false
    private let selectedTemplate: Templates?

    public init(flowController: FlowController) {
        self.flowController = flowController
        self.selectedTemplate = SelectedTemplatesObject.shared.get()
        self.showResultPage =
        flowController.getCurrentStep()?
            .stepDefinition?
            .customization
            .showResultPage ?? false
    }

    private var templatesByCountryValue: TemplatesByCountry? {
        guard
            let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId,
            let selectedCode = selectedTemplate?.sourceCountryCode
        else { return nil }

        let templates = AssentifySdkObject.shared.get()?.getTemplates(stepID: stepId) ?? []
        return templates.first(where: { $0.sourceCountryCode == selectedCode })
    }

    private func onBack() {
        commands.triggerClose += 1
        flowController.backClick()
    }

    private func onNext() {
        DispatchQueue.main.async { screenEvent = .idle }
        commands.triggerClose += 1

        flowController.makeCurrentStepDone(extractedInformation: dataIDModel!.iDExtractedModel!.transformedProperties!,timeStarted: self.timeStarted)
        flowController.naveToNextStep()
    }

    public var body: some View {


        let events = QrScanEvents(
            onStart: {
                DispatchQueue.main.async {
                    start = true
                }
            },
            onProgress: { p in
                DispatchQueue.main.async {
                    screenEvent = .sending
                    uploadProgress = Int(p * 100)
                }
            },
            onComplete: { model in
                DispatchQueue.main.async(execute: {

                    guard let finalModel = QrIDResponseModelObject.shared.get(),
                          let finalExtracted = finalModel.iDExtractedModel
                    else {
                        start = false
                        uploadProgress = 0
                        screenEvent = .completed
                        return
                    }

                    var finalMap: [String: String] = [:]

                    let finalTransformed = finalExtracted.transformedProperties ?? [:]
                    let dataTransformed  = model.iDExtractedModel?.transformedProperties ?? [:]

                    for (key, value) in finalTransformed {

                        if key.contains(IDQrKeys.image) ||
                           key.contains(IDQrKeys.ghostImage) ||
                           key.contains(IDQrKeys.faceCapture) ||
                           key.contains(IDQrKeys.capturedVideoFront) ||
                           key.contains(IDQrKeys.originalFrontImage) {

                            finalMap[key] = value

                        } else {
                            let suffix = key.substringAfter("_")
                            let matchedValue = dataTransformed.first(where: { $0.key.hasSuffix(suffix) })?.value
                            finalMap[key] = matchedValue ?? ""
                        }
                    }

                    finalModel.iDExtractedModel?.transformedProperties = finalMap
                    dataIDModel = finalModel

                    OnCompleteScreenData.shared.clear()
                    OnCompleteScreenData.shared.set(finalMap)

                    imageUrl = finalModel.iDExtractedModel?.imageUrl ?? ""

                    start = false
                    uploadProgress = 0
                    screenEvent = .completed
                    
                  
                })
            },

            onError: { model in
                DispatchQueue.main.async {
                    start = false
                    uploadProgress = 0
                    errorMessage = ""
                    screenEvent = .error
                  
                    
                }
            }
        )

        ZStack {

            if let tbc = templatesByCountryValue {
                QrScanUIKitView(
                    flowController: flowController,
                    templatesByCountry: tbc,
                    events: events,
                    commands: commands
                )
                .ignoresSafeArea()
            } else {
                Color.clear.ignoresSafeArea()
            }

            switch screenEvent {

            case .idle:
                VStack {
                    Spacer()

                    if (assentifySdk!.isManual()) {
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

            case .sending:
                OnSendScreen(progress: uploadProgress,onBack: {onBack()})
                    .ignoresSafeArea()
                    .background(Color.black.opacity(0.35).ignoresSafeArea())
                    .zIndex(999)
                    .allowsHitTesting(true)
                    .transition(.opacity)

            case .completed:
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

            case .error:
                OnErrorScreen(imageUrl: self.imageUrl,onRetry:  {
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
        .modifier(InterceptSystemBack(action: onBack))
    }
}

// MARK: - UIKit Bridge (UIViewControllerRepresentable)

struct QrScanUIKitView: UIViewControllerRepresentable {

    typealias UIViewControllerType = HostVC

    let flowController: FlowController
    let templatesByCountry: TemplatesByCountry
    let events: QrScanEvents
    @ObservedObject var commands: QrScanCommands

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
    final class Coordinator: NSObject, ScanQrDelegate {

        let flowController: FlowController
        let events: QrScanEvents

        init(flowController: FlowController, events: QrScanEvents) {
            self.flowController = flowController
            self.events = events
        }

        func onStartQrScan() {
            events.onStart?()
        }

        @objc func onUploadingProgress(progress: Double) {
            events.onProgress?(progress)
        }

        func onCompleteQrScan(dataModel: IDResponseModel) {
            events.onComplete?(dataModel)
        }

        func onErrorQrScan(message: String,dataModel: RemoteProcessingModel) {
            events.onError?(dataModel)
        }
    }

    // MARK: - UIKit Host VC
    final class HostVC: UIViewController {

        weak var delegate: ScanQrDelegate?
        var flowController: FlowController?
        var templatesByCountry: TemplatesByCountry?

        private var qrVC: ScanQr?
        private var assentifySdk = AssentifySdkObject.shared.get()

        private var lastRetryTrigger: Int = 0
        private var lastCloseTrigger: Int = 0
        private var lastCaptureTrigger: Int = 0


        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            startQrIfNeeded()
        }

        func apply(commands: QrScanCommands) {
            if commands.triggerRetry != lastRetryTrigger {
                lastRetryTrigger = commands.triggerRetry
                retry()
            }

            if commands.triggerClose != lastCloseTrigger {
                lastCloseTrigger = commands.triggerClose
                close()
            }
            if commands.triggerCapture != lastCaptureTrigger {
                lastCaptureTrigger = commands.triggerCapture
                capture()
            }
        }

        private func retry() {
       
        }
        
        private func capture() {
            self.qrVC?.takePicture()
        }

        private func close() {
            DispatchQueue.main.async {

                self.qrVC?.willMove(toParent: nil)
                self.qrVC?.view.removeFromSuperview()
                self.qrVC?.removeFromParent()
                self.qrVC = nil
            }
        }

        private func startQrIfNeeded() {
            guard qrVC == nil else { return }

            guard let delegate else {
                assertionFailure("ScanQrDelegate is nil")
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

            guard let vc = assentifySdk?.startScanQr(
                scanQrDelegate: delegate,
                templatesByCountry: templatesByCountry,
                language: FlowEnvironmentalConditionsObject.shared.get()!.extractedDataLanguage,
                stepId: stepId
            ) else {
                assertionFailure("startScanQr returned nil (sdk instance or config missing)")
                return
            }

            qrVC = vc
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

// MARK: - Helper
private extension String {
    func substringAfter(_ delimiter: Character) -> String {
        guard let idx = firstIndex(of: delimiter) else { return self }
        let next = index(after: idx)
        return next < endIndex ? String(self[next...]) : ""
    }
}
