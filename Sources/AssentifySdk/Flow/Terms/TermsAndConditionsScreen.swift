import SwiftUI

public struct TermsAndConditionsScreen: View {
    
    
    
    @Environment(\.dismiss) private var dismiss
    
    private let flowController: FlowController
    private var defaultTitle: String = "";
    
    private let steps = LocalStepsObject.shared.get()
    private let apiKey = ApiKeyObject.shared.get()
    private let configModel = ConfigModelObject.shared.get()
    
    @State private var isLoading: Bool = true
    @State private var termsModel: TermsConditionsModel? = nil
    
    @State private var showFullScreenPDF = false
    @State private var showShare = false
    @State private var shareItems: [Any] = []
    @State private var sharePayload: SharePayload?
    private let timeStarted :String = getCurrentDateTimeForTracking();
    public init(flowController: FlowController) {
        self.flowController = flowController
        
        /** Track Progress **/
        let currentStep = flowController.getCurrentStep()
        flowController.trackProgress(
            currentStep : currentStep!,
            inputData : flowController.outputPropertiesToMap(currentStep!.stepDefinition!.outputProperties),
            response : nil,
            status : "InProgress"
        )
        /**/
         defaultTitle = configModel!
            .stepDefinitions
            .first(where: { $0.stepId == currentStep!.stepDefinition!.stepId })!
            .customization.header ?? ""
        
        
    }
    
    private func onBack() {
        flowController.backClick()
    }
    
    
    
    
    private func onNext(value:Bool) {
        if let step = flowController.getCurrentStep(),
           let stepDefinition = step.stepDefinition,
           let firstProperty = stepDefinition.outputProperties.first {
            let confirmationKey = firstProperty.key
            let extractedInformation: [String: String] = [
                confirmationKey: String(describing: value)
            ]
            flowController.makeCurrentStepDone(extractedInformation:extractedInformation,timeStarted: self.timeStarted)
            flowController.naveToNextStep()
        }
        
    }
    
    public var body: some View {
        BaseBackgroundContainer {
            VStack(spacing: 0) {
                
                ProgressStepperView(steps: steps ?? [], bundle: .main,onBack: {onBack()})
                .padding(.top, 20)
                
                
                if(termsModel?.data.header != nil && termsModel?.data.subHeader != nil && termsModel?.data.svgLogoUrl != nil ){
                    LogoSvgUrl(url: termsModel?.data.svgLogoUrl ?? "").frame(width: 80, height: 80) .padding(.top, 5)
                    Text(termsModel?.data.header ?? FlowStrings.termsAndConditions)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 5)
                        .padding(.horizontal, 20)
                    if(termsModel?.data.subHeader != nil){
                        Text((termsModel?.data.subHeader)!)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 5)
                            .padding(.horizontal, 20)
                    }
                }else{
                    Text(termsModel?.data.header ?? FlowStrings.termsAndConditions)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 18)
                        .padding(.horizontal, 20)
                }
                
                  
                
                    
                    
                    
                    // Divider line
                    Rectangle()
                        .fill(Color(BaseTheme.baseTextColor).opacity(0.2))
                        .frame(height: 1)
                        .padding(.top, 10)
                        .padding(.horizontal, 20)
                    
                    // PDF Card
                    ZStack {
                        BasePDFCardViewFomUrl(
                            urlString: termsModel?.data.file,
                            tintColor: BaseTheme.baseTextColor,
                            onDownloadTap: { onDownloadPDF() },
                            onFullScreenTap: { showFullScreenPDF = true }
                        )
                        .padding(.top, 14)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Bottom buttons
                    HStack(spacing: 16) {
                        
                      
                        
                        
                        if termsModel?.data.isNormalClick == true {
                            Button {
                                if (termsModel?.data.confirmationRequired == true) {
                                    onBack()
                                } else {
                                    onNext(value: false)
                                }
                            } label: {
                                Text(FlowStrings.decline)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color(BaseTheme.baseAccentColor))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 28)
                                            .stroke(Color(BaseTheme.baseAccentColor), lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                            
                            BaseClickButton(title: termsModel?.data.nextButtonTitle ?? FlowStrings.next,verticalPadding:18,) {
                                onNext(value: true)
                                
                            }
                            .frame(maxWidth: .infinity)
                        }else{
                            BaseSliderClick(
                                onNext: {onNext(value: true)},
                                label: termsModel?.data.nextButtonTitle ?? FlowStrings.next,
                                icon: "checkmark",
                                isActive: true
                            ).frame(maxWidth: .infinity)
                               
                        }
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
            } 
            .topBarBackLogo {
                onBack()
            }
        } .modifier(InterceptSystemBack(action: onBack))
            .task { await loadTerms() }
            .sheet(isPresented: $showFullScreenPDF) {
                FullScreenPDFView(urlString: termsModel?.data.file)
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
    }
    
    private struct SharePayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }
    
    // MARK: - Download
    
    private func onDownloadPDF() {
        guard let s = termsModel?.data.file, let url = URL(string: s) else { return }
        sharePayload = SharePayload(items: [url])
    }
    
    // MARK: - API
    
    @MainActor
    private func loadTerms() async {
        guard let apiKey, let configModel else {
            isLoading = false
            return
        }
        
        isLoading = true
        termsModel = nil
        
        let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId
        
        getTermsConditionsStepFromConfigFile(
            configModel: configModel,
            ID: stepId!
        ) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                if case .success(let model) = result {
                    self.termsModel = model
                }
            }
        }
    }
}
