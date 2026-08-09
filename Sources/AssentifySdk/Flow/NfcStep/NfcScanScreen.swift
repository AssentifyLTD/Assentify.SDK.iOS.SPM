import SwiftUI
import UIKit

// MARK: - Events
struct NfcScanEvents {
    var onStart: (() -> Void)? = nil
    var onComplete: ((PassportResponseModel) -> Void)? = nil
    var onError: ((PassportResponseModel, String) -> Void)? = nil
}

// MARK: - Screen Events
enum NfcScreenEvent {
    case idle
    case sending
    case completed
    case error
}

// MARK: - Commands
final class NfcScanCommands: ObservableObject {
    @Published var triggerRetry: Int = 0
    @Published var triggerClose: Int = 0
}

public struct NfcScanScreen: View {
    
    @State private var feedbackText: String = FlowStrings.nfcPositionHint
    
    @State private var imageUrl: String = ""
    @State private var dataIDModel: PassportResponseModel?
    @State private var isComplete = false
    @StateObject private var commands = NfcScanCommands()
    @State private var screenEvent: NfcScreenEvent = .idle
    private let timeStarted :String = getCurrentDateTimeForTracking();
    private var assentifySdk = AssentifySdkObject.shared.get()
    private let flowController: FlowController
    private var showResultPage = false
    
    private var passportResponseModel: PassportResponseModel? {
        return  NfcPassportResponseModelObject.shared.get()
    }
    
    public init(flowController: FlowController) {
        self.flowController = flowController
        self.showResultPage =
        flowController.getCurrentStep()?
            .stepDefinition?
            .customization
            .showResultPage ?? false
    }
    
    private func onBack() {
        commands.triggerClose += 1
        self.flowController.backClick()
    }
    
    private func onNext() {
        if(isComplete){
            DispatchQueue.main.async { screenEvent = .idle }
            flowController.makeCurrentStepDone(extractedInformation: (dataIDModel?.passportExtractedModel!.transformedProperties)!,timeStarted: self.timeStarted)
            flowController.naveToNextStep();
        }else{
            DispatchQueue.main.async { screenEvent = .idle }
            flowController.makeCurrentStepDone(extractedInformation: (passportResponseModel?.passportExtractedModel!.transformedProperties)!,timeStarted: self.timeStarted)
            flowController.naveToNextStep();
        }
     
    }
    
    private func onSkip() {
        DispatchQueue.main.async { screenEvent = .completed }
    }
    
    
    public var body: some View {
        
        let events = NfcScanEvents(
            onStart: {
                DispatchQueue.main.async {
                    screenEvent = .sending
                    feedbackText = FlowStrings.nfcReading
                }
            },
            onComplete: { model in
                DispatchQueue.main.async {
                    dataIDModel = model;
                    isComplete = true
                    OnCompleteScreenData.shared.clear();
                    OnCompleteScreenData.shared.set(model.passportExtractedModel!.transformedProperties!)
                    imageUrl = model.passportExtractedModel!.imageUrl!
                    flowController.setImage(url: String(describing: model.passportExtractedModel?.faces?.first))
                    screenEvent = .completed
                    
                }
            },
            onError: { model, message in
                DispatchQueue.main.async {
                    screenEvent = .error
                    self.imageUrl = model.passportExtractedModel?.imageUrl ?? ""
                    feedbackText = message.isEmpty
                    ? FlowStrings.nfcConnectionLost
                    : message
                }
            }
        )
        BaseBackgroundContainer {
            VStack {
                
                NfcScanUIKitView(
                    flowController: flowController,
                    passportResponseModel: passportResponseModel,
                    language: FlowEnvironmentalConditionsObject.shared.get()?.extractedDataLanguage ?? "en",
                    events: events,
                    commands: commands
                ).frame(width: 0, height: 0)
                
                NfcScanScreenUI(
                    flowController: flowController,
                    screenEvent: screenEvent,
                    feedbackText: feedbackText,
                    imageUrl: imageUrl,
                    showResultPage: showResultPage,
                    onNext: { onNext() },
                    onRetry: {
                        DispatchQueue.main.async {
                            screenEvent = .idle
                            commands.triggerRetry += 1
                            feedbackText = FlowStrings.nfcPositionHint
                        }
                    },
                    onSkip: { onSkip() },
                    onBack:{onBack()}
                )
                
            }.topBarBackLogo { onBack() }
        }.modifier(InterceptSystemBack(action: onBack))
        
    }
}

// MARK: - SwiftUI UI (your final UI)
private struct NfcScanScreenUI: View {
    
    let flowController: FlowController
    let screenEvent: NfcScreenEvent
    let feedbackText: String
    let imageUrl: String
    let showResultPage: Bool
    let onNext: () -> Void
    let onRetry: () -> Void
    let onSkip: () -> Void
    let onBack: () -> Void
    
    private let steps = LocalStepsObject.shared.get()
    
    var body: some View {
        
        VStack(spacing: 0) {
            
            ProgressStepperView(steps: steps ?? [], bundle: .main,onBack: {onBack()})
                .padding(.top, 20)
            
            switch screenEvent {
                
            case .completed:
                if showResultPage {
                    OnCompleteScreen(imageUrl: imageUrl,showStper: false,ignoresSvg: true,
                                     onNext: {
                                      onNext()
                                  },
                                      onBack: {
                                      onBack()
                                    })
                } else {
                    OnNormalCompleteScreen(imageUrl: imageUrl,showStper: false,ignoresSvg: true,
                                           onNext: {
                                            onNext()
                                        },
                                            onBack: {
                                            onBack()
                                          })
                }
                
            case .error:
                scanContent
                
            default:
                scanContent
            }
            
        }
    }
    
    private var scanContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)
            
            Text(FlowStrings.nfcBasedCapture)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(BaseTheme.baseTextColor))
                .multilineTextAlignment(.center)
                .padding(.top, 16)
                .padding(.horizontal, 16)
            
            VStack(spacing: 14) {
                
                SVGAssetIcon(
                    name: "ic_nfc",
                    size: CGSize(width: 220, height: 220),
                    tintColor: UIColor(Color(BaseTheme.baseAccentColor))
                )
                .frame(width: 220, height: 220)
                
                if screenEvent == .sending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(BaseTheme.baseTextColor)))
                        .scaleEffect(1.6)
                        .frame(height: 34)
                } else {
                    Text(FlowStrings.nfcDetected)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .multilineTextAlignment(.center)
                }
                
                Text(feedbackText)
                    .font(.system(size: 10, weight: .thin))
                    .foregroundColor(Color(BaseTheme.baseTextColor))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            
            Spacer()
            
            if screenEvent == .error {
                Button(action: {
                    onRetry()
                    
                }) {
                    Text(FlowStrings.retry)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(
                            Color(BaseTheme.baseSecondaryTextColor)
                        )
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                }
                .background(
                    Color(BaseTheme.baseRedColor)
                )
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 25).padding(.bottom,10)
                
            } else {
                Spacer().frame(height: 20)
            }
            
            BaseClickButton(
                title: FlowStrings.skip,
                cornerRadius: 28,
                verticalPadding: 14,
                enabled: true,
                action: onSkip
            )
            .padding(.horizontal, 25)
            .padding(.bottom, 16)
            
                
            
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ✅ MUST be a struct (value type)
struct NfcScanUIKitView: UIViewControllerRepresentable {
    
    typealias UIViewControllerType = HostVC
    
    let flowController: FlowController
    let passportResponseModel: PassportResponseModel?
    let language: String
    let events: NfcScanEvents
    @ObservedObject var commands: NfcScanCommands
    
    func makeCoordinator() -> Coordinator {
        Coordinator(events: events)
    }
    
    func makeUIViewController(context: Context) -> HostVC {
        let vc = HostVC()
        vc.flowController = flowController
        vc.events = events
        vc.passportResponseModel = passportResponseModel
        vc.delegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: HostVC, context: Context) {
        uiViewController.apply(commands: commands)
    }
    
    // MARK: - Coordinator (Delegate lives here)
    final class Coordinator: NSObject, ScanNfcDelegate {
        
        let events: NfcScanEvents
        
        init(events: NfcScanEvents) {
            self.events = events
        }
        
        func onStartNfcScan() {
            events.onStart?()
        }
        
        func onCompleteNfcScan(dataModel: PassportResponseModel) {
            events.onComplete?(dataModel)
        }
        
        func onErrorNfcScan(dataModel: PassportResponseModel, message: String) {
            events.onError?(dataModel, message)
        }
    }
    
    // MARK: - UIKit Host VC
    final class HostVC: UIViewController {
        
        weak var delegate: ScanNfcDelegate?
        var flowController: FlowController?
        
        var events: NfcScanEvents?
        var passportResponseModel: PassportResponseModel?
        
        private var scanNfc: ScanNfc?
        private var assentifySdk = AssentifySdkObject.shared.get()
        
        private var lastRetryTrigger: Int = 0
        private var lastCloseTrigger: Int = 0
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            startNfcIfNeeded()
        }
        
        func apply(commands: NfcScanCommands) {
            if commands.triggerRetry != lastRetryTrigger {
                lastRetryTrigger = commands.triggerRetry
                retry()
            }
            
            if commands.triggerClose != lastCloseTrigger {
                lastCloseTrigger = commands.triggerClose
                close()
            }
        }
        
        private func startNfcIfNeeded() {
            guard scanNfc == nil else { return }
            
            guard let delegate else {
                assertionFailure("ScanNfcDelegate is nil")
                return
            }
            
            // if you want to pass stepId from flow:
            let stepId = flowController?.getCurrentStep()?.stepDefinition?.stepId ?? -1
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                self.scanNfc = self.assentifySdk?.startScanNfc(
                    scanNfcDelegate: delegate,
                    language: FlowEnvironmentalConditionsObject.shared.get()!.extractedDataLanguage,
                    stepId: stepId
                )
                
                if self.scanNfc?.isNfcAvailable() == true {
                    Task { [weak self] in
                        guard let self else { return }
                        guard let model = self.passportResponseModel else {
                            // no data model -> trigger error UI
                            self.events?.onError?(PassportResponseModel(), "PassportResponseModel is nil")
                            return
                        }
                        await self.scanNfc?.readPassport(dataModel: model)
                    }
                } else {
                    self.events?.onError?(PassportResponseModel(), "NFC Not supported on this device.")
                }
            }
        }
        
        private func retry() {
            scanNfc = nil
            startNfcIfNeeded()
        }
        
        
        
        private func close() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.scanNfc = nil
            }
        }
    }
}
