import SwiftUI

public struct AssistedDataEntryScreen: View, AssistedDataEntryDelegate {

    public func onAssistedDataEntryError(message: String) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.isError = true
        }
    }

    public func onAssistedDataEntrySuccess(assistedDataEntryModel: AssistedDataEntryModel) {
        DispatchQueue.main.async {
            if(AssistedDataEntryPagesObjectJson.shared.get(stepId: (flowController.getCurrentStep()?.stepDefinition!.stepId)!) == nil){
                AssistedDataEntryPagesObject.shared.clear()
                AssistedDataEntryPagesObject.shared.set(assistedDataEntryModel)
                self.isLoading = false
                self.isError = false
                self.assistedDataEntryModel = assistedDataEntryModel
            }else{
                AssistedDataEntryPagesObject.shared.clear()
                AssistedDataEntryPagesObject.shared.set(AssistedDataEntryPagesObjectJson.shared.get(stepId: (flowController.getCurrentStep()?.stepDefinition!.stepId)!)!)
                self.isLoading = false
                self.isError = false
                self.assistedDataEntryModel = AssistedDataEntryPagesObjectJson.shared.get(stepId: (flowController.getCurrentStep()?.stepDefinition!.stepId)!)
            }
          
        }
    }
    private var defaultTitle: String = "";
    private let flowController: FlowController
    private let steps = LocalStepsObject.shared.get()
    private let timeStarted :String = getCurrentDateTimeForTracking();

    @State private var isLoading: Bool = true
    @State private var isError: Bool = false
    @State private var assistedDataEntryModel: AssistedDataEntryModel? = nil
    @State private var didStart: Bool = false
    @State private var currentPage: Int = 0
    @State private var refreshTick: Int = 0
    @State private var status: String = "InProgress"
    private let configModel = ConfigModelObject.shared.get()

    private let timer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    
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

    private func startIfNeeded() {
        guard !didStart else { return }
        didStart = true

        isLoading = true
        isError = false
        assistedDataEntryModel = nil

        let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId
        _ = AssentifySdkObject.shared.get()?.startAssistedDataEntry(
            assistedDataEntryDelegate: self,
            stepId: stepId
        )
    }

    private func onBack() {
        flowController.backClick()
    }
    
    private func onNext(){

        var extractedInformation: [String: String] = [:]
        guard let model = AssistedDataEntryPagesObject.shared.get() else {
            fatalError("AssistedDataEntry model is nil")
        }

        let pages = model.assistedDataEntryPages

        for (index, page) in pages.enumerated() {
            for element in page.dataEntryPageElements {

                let key = element.inputKey
                let isDirtyKey = element.isDirtyKey
                let value = element.value ?? ""
                let fieldType = InputTypes.fromString(element.inputType)
                let phonePrefix = (element.defaultCountryCode ?? "")
                let phoneFullValue = phonePrefix + value
                let currentStep = flowController.getCurrentStep()

                if let key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                    if fieldType == .phoneNumber {
                        extractedInformation[key] = phoneFullValue
                        for property in currentStep!.stepDefinition!.outputProperties {
                            if property.key != key && property.key.hasPrefix(key.components(separatedBy: "_").first ?? key) {
                                let country = allCountries.first { $0.dialCode == element.defaultCountryCode }!
                                
                                if property.key.hasSuffix("Number") {
                                    extractedInformation[property.key] = value
                                }
                                if property.key.hasSuffix("Code") {
                                    extractedInformation[property.key] = element.defaultCountryCode!
                                }
                                if property.key.hasSuffix("Iso2") {
                                    extractedInformation[property.key] = country.code2
                                }
                                if property.key.hasSuffix("Iso3") {
                                    extractedInformation[property.key] = country.code3
                                }
                            }
                        }
                    } else if fieldType == .phoneNumberWithOTP {
                        extractedInformation[key] = value
                        for property in currentStep!.stepDefinition!.outputProperties {
                            if property.key != key && property.key.hasPrefix(key.components(separatedBy: "_").first ?? key) {
                                let country = allCountries.first { $0.dialCode == "+961" }!
                                
                                if property.key.hasSuffix("Number") {
                                    extractedInformation[property.key] = value.hasPrefix("+961") ? String(value.dropFirst(4)) : value
                                }
                                if property.key.hasSuffix("Code") {
                                    extractedInformation[property.key] = "+961"
                                }
                                if property.key.hasSuffix("Iso2") {
                                    extractedInformation[property.key] = country.code2
                                }
                                if property.key.hasSuffix("Iso3") {
                                    extractedInformation[property.key] = country.code3
                                }
                            }
                        }
                    }  else {
                        extractedInformation[key] = value
                    }
                }

                if let dirtyKey = isDirtyKey, !dirtyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let defultValue = AssistedFormHelper.getDefaultValueValueToCheckIsDirty(key!, index, flowController: flowController)
               
                    if(defultValue == value){
                        extractedInformation[dirtyKey] = "false"
                    }else{
                        extractedInformation[dirtyKey] = "true"
                    }
                }

                if let dataSourceValues = element.dataSourceValues, !dataSourceValues.isEmpty {
                    for (k, v) in dataSourceValues {
                        extractedInformation[k] = v
                    }
                }
            }
        }
        
        
        
        flowController.makeCurrentStepDone(extractedInformation: extractedInformation,timeStarted: self.timeStarted)
        flowController.naveToNextStep();
        
    }

    public var body: some View {
        BaseBackgroundContainer {
            VStack(spacing: 0) {

                ProgressStepperView(steps: steps ?? [], bundle: .main,onBack: {onBack()})
                    .padding(.top, 20)

                if isLoading {
                    VStack {
                        Text(defaultTitle)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(BaseTheme.baseTextColor))
                            .frame(maxWidth: .infinity, alignment: .leading)  .padding(.horizontal, 25)
                            .padding(.top, 10)
                            .padding(.bottom, 12)
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color(BaseTheme.baseTextColor))
                            .scaleEffect(1.2)
                        Spacer()
                    }
                } else {

                    if isError {
                        VStack(spacing: 12) {
                            Spacer()
                            Text(FlowStrings.somethingWentWrong)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color(BaseTheme.baseRedColor))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            Spacer()
                        }
                    } else {

                        if assistedDataEntryModel != nil {
                            Spacer()

                            AssistedDataEntryPager(
                                model: Binding(
                                    get: { assistedDataEntryModel! },
                                    set: { assistedDataEntryModel = $0 }
                                ),
                                currentPage: $currentPage,
                                flowController: self.flowController,
                                onFieldChanged: {
                                    assistedDataEntryModel = AssistedDataEntryPagesObject.shared.get();
                                    refreshTick += 1
                                    
                                    
                                }
                            )
                            
                            let islast = (currentPage == assistedDataEntryModel!.assistedDataEntryPages.count - 1)
                            if(assistedDataEntryModel!.assistedDataEntryPages[currentPage].isNormalClick || islast==false){
                                BaseClickButton(
                                    title: assistedDataEntryModel!.assistedDataEntryPages[currentPage].nextButtonTitle,
                                    verticalPadding: 18,
                                    enabled :AssistedFormHelper.validatePage(currentPage),

                                ) {
                                    let last = (currentPage == assistedDataEntryModel!.assistedDataEntryPages.count - 1)
                                    if last {
                                        if(AssistedFormHelper.validatePage(currentPage)){
                                            status = "Completed"
                                            onNext()
                                        }
                                      
                                    } else {
                                        if(AssistedFormHelper.validatePage(currentPage)){
                                            currentPage += 1
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }else{
                                BaseSliderClick(
                                    onNext: {
                                        let last = (currentPage == assistedDataEntryModel!.assistedDataEntryPages.count - 1)
                                        if last {
                                            if(AssistedFormHelper.validatePage(currentPage)){
                                                status = "Completed"
                                                onNext()
                                            }
                                          
                                        } else {
                                            if(AssistedFormHelper.validatePage(currentPage)){
                                                currentPage += 1
                                            }
                                        }
                                    },
                                    label: assistedDataEntryModel!.assistedDataEntryPages[currentPage].nextButtonTitle,
                                    icon: "checkmark",
                                    isActive: AssistedFormHelper.validatePage(currentPage),
                                ) .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }

                           
                        }
                    }
                }
            }
            
            .topBarBackLogo { onBack() }
        }.onReceive(timer) { _ in
            callTrackProgress()
        }
        .onDisappear {
            callTrackProgress()
        }
        .modifier(InterceptSystemBack(action: onBack))
        .task { startIfNeeded() }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    func callTrackProgress(){
        
        if( status != "Completed"){
            var extractedInformation: [String: String] = [:]
            guard let model = AssistedDataEntryPagesObject.shared.get() else {
                fatalError("AssistedDataEntry model is nil")
            }

            let pages = model.assistedDataEntryPages
            
            for (index, page) in pages.enumerated() {
                for element in page.dataEntryPageElements {

                    let key = element.inputKey
                    let isDirtyKey = element.isDirtyKey
                    let value = element.value ?? ""
                    let fieldType = InputTypes.fromString(element.inputType)
                    let phonePrefix = (element.defaultCountryCode ?? "")
                    let phoneFullValue = phonePrefix + value
                    let currentStep = flowController.getCurrentStep()

                    if let key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                        if fieldType == .phoneNumber {
                            extractedInformation[key] = phoneFullValue
                            for property in currentStep!.stepDefinition!.outputProperties {
                                if property.key != key && property.key.hasPrefix(key.components(separatedBy: "_").first ?? key) {
                                    let country = allCountries.first { $0.dialCode == element.defaultCountryCode }!
                                    
                                    if property.key.hasSuffix("Number") {
                                        extractedInformation[property.key] = value
                                    }
                                    if property.key.hasSuffix("Code") {
                                        extractedInformation[property.key] = element.defaultCountryCode!
                                    }
                                    if property.key.hasSuffix("Iso2") {
                                        extractedInformation[property.key] = country.code2
                                    }
                                    if property.key.hasSuffix("Iso3") {
                                        extractedInformation[property.key] = country.code3
                                    }
                                }
                            }
                        } else if fieldType == .phoneNumberWithOTP {
                            extractedInformation[key] = value
                            for property in currentStep!.stepDefinition!.outputProperties {
                                if property.key != key && property.key.hasPrefix(key.components(separatedBy: "_").first ?? key) {
                                    let country = allCountries.first { $0.dialCode == "+961" }!
                                    
                                    if property.key.hasSuffix("Number") {
                                        extractedInformation[property.key] = value.hasPrefix("+961") ? String(value.dropFirst(4)) : value
                                    }
                                    if property.key.hasSuffix("Code") {
                                        extractedInformation[property.key] = "+961"
                                    }
                                    if property.key.hasSuffix("Iso2") {
                                        extractedInformation[property.key] = country.code2
                                    }
                                    if property.key.hasSuffix("Iso3") {
                                        extractedInformation[property.key] = country.code3
                                    }
                                }
                            }
                        } else {
                            extractedInformation[key] = value
                        }
                    }

                    if let dirtyKey = isDirtyKey, !dirtyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let defultValue = AssistedFormHelper.getDefaultValueValueToCheckIsDirty(key!, index, flowController: flowController)
                   
                        if(defultValue == value){
                            extractedInformation[dirtyKey] = "false"
                        }else{
                            extractedInformation[dirtyKey] = "true"
                        }
                    }

                    if let dataSourceValues = element.dataSourceValues, !dataSourceValues.isEmpty {
                        for (k, v) in dataSourceValues {
                            extractedInformation[k] = v
                        }
                    }
                }
            }
            
            /** Track Progress **/
            let currentStep = flowController.getCurrentStep()
           

            flowController.trackProgress(
                currentStep: currentStep!,
                inputData: extractedInformation,
                response: status,
                status: status
            )
            /**/
        }
        
        
        
    }
}



