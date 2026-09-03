import SwiftUI

import UIKit




public struct BaseTheme {
    
    private static var env: FlowEnvironmentalConditions {
        guard let value = FlowEnvironmentalConditionsObject.shared.get() else {
            fatalError("FlowEnvironmentalConditions not initialized")
        }
        return value
    }
    
    public static var baseTextColor: UIColor {
        UIColor.fromHex(env.textColor)
    }
    
    public static var baseSecondaryTextColor: UIColor {
        UIColor.fromHex(env.secondaryTextColor)
    }
    
    public static var fieldColor: UIColor {
        UIColor.fromHex(env.backgroundCardColor)
    }
    
    public static var baseAccentColor: UIColor {
        UIColor.fromHex(env.accentColor)
    }
    
    public static var baseGreenColor: UIColor {
        UIColor.fromHex(ConstantsValues.DetectColor)
    }
    
    public static var baseRedColor: UIColor {
        .red
    }
    
    
    public static var backgroundColor: BackgroundStyle? {
        env.backgroundColor
    }
    
    public static var baseClickColor: BackgroundStyle? {
        env.clickColor
    }
    
    public static var baseBackgroundType: BackgroundType {
        env.backgroundType
    }
    
    public static var baseBackgroundUrl: String {
        env.svgBackgroundImageUrl
    }
    
    
    public static var baseLogo: String {
        env.logoUrl
    }
    
    public static var stepperType: StepperType {
        env.stepperType
    }
    
    public static var rangeStart: Int {
        env.rangeStart
    }
    
    
    public static var rangeEnd: Int {
        env.rangeEnd
    }
    
    public static var stepperTitle: String {
        env.stepperTitle
    }
    
    public static var showCountDown: Bool {
        env.showCountDown
    }
    
    public static var baseUiLanguage: String {
        AssentifySdkObject.shared.get()?.environmentalConditions?.flowUiLanguage ?? UiLanguage.English;
    }
    
    public static var localMrzScan: Bool {
        env.localMrzScan
    }
}



struct BlockLoaderScreen: View {
    
    var firstInit = LocalStepsObject.shared.get().isEmpty

    
    var steps:[LocalStepModel]  = [];
    
    func onBack ()  {
        flowController.dismiss()
    }
    func onNext ()  {
        /** Track Progress **/
        if(firstInit){
            let steps = LocalStepsObject.shared.get()
            let currentStep = steps.first { $0.stepDefinition?.stepDefinition == StepsNames.blockLoader }
            flowController.trackProgress(
                currentStep : currentStep!,
                inputData : currentStep!.submitRequestModel!.extractedInformation,
                response : nil,
                status : "Completed"
            )
        }
       
        /**/
        flowController.naveToNextStep()
    }
    
    private let flowController: FlowController
    
    
    
    public init(flowController: FlowController) {
        
        self.flowController = flowController
        steps = buildStepsFromConfig(flowController: flowController);
        
    }
    
    var body: some View {
        BaseBackgroundContainer {
            VStack(spacing: 0) {
                
                
                if(!HasSubmittedObject.shared.get()){
                    Text(FlowStrings.completeOnboarding(count: steps.count))
                        .font(.system(size: 25, weight: .bold))
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 25)
                        .padding(.leading, 25)
                        .padding(.trailing, 20)
                    
                    Text(FlowStrings.onboardingSubtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 5)
                        .padding(.horizontal, 25)
                        .padding(.bottom, 10)
                    
                }else{
                    Text(FlowStrings.thankYou)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 15)
                        .padding(.leading, 25)
                        .padding(.trailing, 20)
                    
                    Text(FlowStrings.completedSteps(count: steps.count))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(BaseTheme.baseTextColor))
                        .multilineTextAlignment(.leading)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }
                // Header
               
                // Steps list
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(Array(steps.enumerated()), id: \.offset) {index, step in
                            StepCard(
                                step: step,
                                selectedColor: Color(BaseTheme.baseAccentColor),
                                unselectedColor: Color(BaseTheme.fieldColor),
                                onClick: { }
                            ).padding(.top, index == 0 ? 8 : 6)
                        }
                    }
                    .padding(.top, 4)
                }
                
                .frame(maxHeight: .infinity)
                
                if(!HasSubmittedObject.shared.get()){
                    BaseClickButton(title: FlowStrings.next) {
                        onNext()
                    }.padding(.vertical, 25)
                    .padding(.horizontal, 25)
                 
                }
              
            } .topBarBackLogo(logoUrl :BaseTheme.baseLogo,noStepper: true,) {
                onBack()
            }
            
        }
    }
}



private func buildStepsFromConfig(flowController:FlowController) -> [LocalStepModel] {
    
    var tempList = LocalStepsObject.shared.get()
    
    if  tempList.isEmpty {
        
        /** BlockLoader **/
        let flowEnvironmentalConditions = FlowEnvironmentalConditionsObject.shared.get()
        let configModel = ConfigModelObject.shared.get()
        
        var values: [String: String] = [:]
        
        let initSteps = ConfigModelObject.shared.get()!.stepDefinitions
        
        for item in initSteps {
            if item.stepDefinition == StepsNames.blockLoader {
                
                for property in item.outputProperties {
                    
                    let key = property.key
                    
                    if key.contains(BlockLoaderKeys.timeStarted) {
                        values[key] =  getTimeUTC()
                    }
                    
                    if key.contains(BlockLoaderKeys.deviceName) {
                        let deviceName = "\(UIDevice.current.model) \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
                        values[key] = deviceName
                    }
                    
                    if key.contains(BlockLoaderKeys.application) {
                        values[key] = configModel?.applicationId ?? ""
                    }
                    
                    if key.contains(BlockLoaderKeys.flowName) {
                        values[key] = configModel?.flowName ?? ""
                    }
                    
                    if key.contains(BlockLoaderKeys.instanceHash) {
                        values[key] = configModel?.instanceHash ?? ""
                    }
                    
                    if key.contains(BlockLoaderKeys.userAgent) {
                        let userAgent = "iOS \(UIDevice.current.systemVersion); \(UIDevice.current.model)"
                        values[key] = userAgent
                    }
                    
                    if key.contains(BlockLoaderKeys.interactionID) {
                        values[key] = configModel?.instanceId ?? ""
                    }
                }
                
                // Override / extend with customProperties
                for property in item.outputProperties {
                    let propKey = property.key
                    for (key, value) in flowEnvironmentalConditions!.blockLoaderCustomProperties {
                        if propKey.contains(key) {
                            values[propKey] = String(describing: value)
                        }
                    }
                }
            }
        }
        
        // Find BlockLoader stepDefinition
        let blockLoaderDef = configModel?.stepDefinitions.first { $0.stepDefinition == StepsNames.blockLoader }
        
        if let blockLoaderDef = blockLoaderDef {
            tempList.append(
                LocalStepModel(
                    name: StepsNames.blockLoader,
                    show: false,
                    description: "",
                    iconAssetPath: "",
                    isDone: true,
                    stepDefinition: blockLoaderDef,
                    submitRequestModel: SubmitRequestModel(
                        stepId: blockLoaderDef.stepId,
                        stepDefinition: StepsNames.blockLoader,
                        extractedInformation: values
                    )
                )
            )
        }
        
        var displayCounter = 1
        
        for step in configModel!.stepMap {
            let def = step.stepDefinition
            
            if def == StepsNames.termsConditions ||
                def == StepsNames.identificationDocumentCapture ||
                def == StepsNames.faceImageAcquisition ||
                def == StepsNames.assistedDataEntry ||
                def == StepsNames.contextAwareSigning {
                
                guard let meta = getStepMeta(def) else { continue }
                
                guard let stepDef = configModel!.stepDefinitions.first(where: { $0.stepId == step.id }) else {
                    continue
                }
                
                tempList.append(
                    LocalStepModel(
                        name: FlowStrings.stepLabel(number: displayCounter, name: meta.name),
                        show: true,
                        description: meta.description,
                        iconAssetPath: meta.icon,
                        isDone: false,
                        stepDefinition: stepDef,
                        submitRequestModel: SubmitRequestModel(
                            stepId: stepDef.stepId,
                            stepDefinition: stepDef.stepDefinition,
                            extractedInformation: [:]
                        )
                    )
                )
                
                displayCounter += 1
            }
            
            let isSplit = def == StepsNames.split
            if(isSplit){
                guard let stepDef = configModel!.stepDefinitions.first(where: { $0.stepId == step.id }) else {
                    continue
                }
                tempList.append(
                    LocalStepModel(
                        name: "",
                        show: false,
                        description: "",
                        iconAssetPath: "",
                        isDone: false,
                        stepDefinition: stepDef,
                        submitRequestModel: SubmitRequestModel(
                            stepId: stepDef.stepId,
                            stepDefinition: stepDef.stepDefinition,
                            extractedInformation: [:]
                        )
                    )
                )
            }
            
            let isDataRelay = def == StepsNames.dataRelay
            if(isDataRelay){
                guard let stepDef = configModel!.stepDefinitions.first(where: { $0.stepId == step.id }) else {
                    continue
                }
                tempList.append(
                    LocalStepModel(
                        name: "",
                        show: false,
                        description: "",
                        iconAssetPath: "",
                        isDone: false,
                        stepDefinition: stepDef,
                        submitRequestModel: SubmitRequestModel(
                            stepId: stepDef.stepId,
                            stepDefinition: stepDef.stepDefinition,
                            extractedInformation: [:]
                        )
                    )
                )
            }

        }
        
        LocalStepsObject.shared.set(tempList)
        
        let steps = LocalStepsObject.shared.get()
        let currentStep = steps.first { $0.stepDefinition?.stepDefinition == StepsNames.blockLoader }
        
        /** Track Progress **/

        flowController.trackProgress(
            currentStep : currentStep!,
            inputData : currentStep!.submitRequestModel!.extractedInformation,
            response : nil,
            status : "InProgress"
        )
        /**/

        
    }
    
    return tempList.filter { $0.show }
}


public struct StepMeta {
    public let name: String
    public let description: String
    public let icon: String
}

public func getStepMeta(_ stepDefinition: String) -> StepMeta? {
    
    switch stepDefinition {
        
    case StepsNames.termsConditions:
        return StepMeta(
            name: FlowStrings.stepTermsName,
            description: FlowStrings.stepTermsDesc,
            icon: "ic_terms_step"
        )
        
    case StepsNames.identificationDocumentCapture:
        return StepMeta(
            name: FlowStrings.stepScanIdName,
            description: FlowStrings.stepScanIdDesc,
            icon: "ic_id_step"
        )
        
    case StepsNames.faceImageAcquisition:
        return StepMeta(
            name: FlowStrings.stepSelfieName,
            description: FlowStrings.stepSelfieDesc,
            icon: "ic_face_step"
        )
        
    case StepsNames.assistedDataEntry:
        return StepMeta(
            name: FlowStrings.stepDataEntryName,
            description: FlowStrings.stepDataEntryDesc,
            icon: "ic_data_entry_step"
        )
        
    case StepsNames.contextAwareSigning:
        return StepMeta(
            name: FlowStrings.stepSigningName,
            description: FlowStrings.stepSigningDesc,
            icon: "ic_signing_step"
        )
        
    default:
        return nil
    }
}

