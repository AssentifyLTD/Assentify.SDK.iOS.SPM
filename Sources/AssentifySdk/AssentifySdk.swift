

import Foundation
import UIKit
import SwiftUI

public class AssentifySdk {
    private let apiKey: String
    public let environmentalConditions: EnvironmentalConditions?
    private let assentifySdkDelegate : AssentifySdkDelegate?
    private var performActiveLivenessFace: Bool?
    private var isKeyValid: Bool = false
    private var configModel: ConfigModel?
    private var tenantThemeModel: TenantThemeModel?
    private var scanID: ScanIDCard?;
    private var templates: [TemplatesByCountry]?;
    private var timeStarted: String;
    private var flowController:FlowController?;
    private var configFileName:String?;
    private var initContentHash:String?;
    private var configFileManager: ConfigFileManager?;
    private var processJsonConfigFile: String = "";
    
    
    
    public init(apiKey: String, configFileName: String, environmentalConditions: EnvironmentalConditions?, assentifySdkDelegate: AssentifySdkDelegate?,  performActiveLivenessFace: Bool? = nil,processJsonConfigFile:String = "") {
        self.apiKey = apiKey
        self.environmentalConditions = environmentalConditions
        self.assentifySdkDelegate = assentifySdkDelegate
        self.performActiveLivenessFace = performActiveLivenessFace
        self.configFileName = configFileName
        self.processJsonConfigFile = processJsonConfigFile
        self.timeStarted = getTimeUTC()
        if apiKey.isEmpty {
            print("AssentifySdk Init Error: ApiKey must not be blank or nil")
        }
        if environmentalConditions == nil {
            print("AssentifySdk Init Error: EnvironmentalConditions must not be nil")
        }
        if assentifySdkDelegate == nil {
            print("AssentifySdk Init Error: assentifySdkDelegate must not be nil")
        }
        if !apiKey.isEmpty{
            loadLocalFile()
        }
        
    }
    
    
    private func loadLocalFile() {
        let fileName: String
        let unwrappedConfigFileName = configFileName ?? ""

        if processJsonConfigFile.isEmpty {
            fileName = "\(unwrappedConfigFileName)"
        } else {
            fileName = "AssentifySdk\(unwrappedConfigFileName)"
        }
        configFileManager = ConfigFileManager(fileName: fileName)
        configFileManager?.initFromBundleIfNeeded(processJsonConfigFile: self.processJsonConfigFile);
        self.configModel = configFileManager?.readEngagement();
        self.tenantThemeModel = configFileManager?.readTheme();
        self.initContentHash = configFileManager?.readContentHash();
        if let templates = self.configFileManager?.readTemplates() {
            self.getTemplatesByCountry(templates: templates)
        }
        
        startInitializeCheck();
        
    }
    
 
    func startInitializeCheck() {

        let currentContentHash = ContentHashObject.shared.get(
            instanceHash: configModel!.instanceHash
        ) ?? initContentHash ?? ""

        initializeCheck(
            pathContentHash: configModel!.instanceHash,
            queryContentHash: currentContentHash,
            tenantIdentifier: configModel!.tenantIdentifier,
            blockIdentifier: configModel!.blockIdentifier,
            instanceId: configModel!.instanceId,
            sourceAgent: "SDK",
            apiKey: apiKey,
            language: environmentalConditions?.flowUiLanguage ?? UiLanguage.English
        ) { [weak self] result in
            guard let self = self else { return }
            
            // capture before async
            let instanceHash = self.configModel?.instanceHash ?? ""

            switch result {
            case .failure(let error):
                self.isKeyValid = false
                self.assentifySdkDelegate?.onAssentifySdkInitError(message: error.localizedDescription)

            case .success(let bodyString):
                do {
                    self.isKeyValid = true
                    self.newInstance()

                    guard let data = bodyString.data(using: .utf8),
                          let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        throw NSError(domain: "Parse error", code: 0)
                    }

                
                    
                    // Has Changes check
                    if let hasChanges = json["hasChanges"] as? Bool {
                        let flowInstanceId = json["flowInstanceId"] as? String ?? ""
                        let instanceId     = json["instanceId"]     as? String ?? ""
                        let contentHash    = json["contentHash"]    as? String ?? ""

                       

                        self.configModel?.flowInstanceId = flowInstanceId
                        self.configModel?.instanceId     = instanceId

                        ContentHashObject.shared.clear(instanceHash: instanceHash)
                        ContentHashObject.shared.set(contentHash, instanceHash: instanceHash)

                        if !hasChanges {
                           
                            guard let config = self.configModel else { return }
                            self.assentifySdkDelegate?.onAssentifySdkInitSuccess(configModel: config)
                            return
                        }
                    }

                    // Has new file — update everything
                    ContentHashObject.shared.clear(instanceHash: instanceHash)
                    self.clearFlow()
                    self.configFileManager?.clear()
                    self.configFileManager?.write(bodyString)
                    self.configModel      = self.configFileManager?.readEngagement()
                    self.tenantThemeModel = self.configFileManager?.readTheme()
                    if let templates = self.configFileManager?.readTemplates() {
                        self.getTemplatesByCountry(templates: templates)
                    }

                    ContentHashObject.shared.set(
                        self.configFileManager?.readContentHash(),
                        instanceHash: instanceHash
                    )

                    guard let updatedConfig = self.configModel else {
                        throw NSError(domain: "Config missing after write", code: 0)
                    }
                    self.assentifySdkDelegate?.onAssentifySdkInitSuccess(configModel: updatedConfig)

                } catch {
                    self.isKeyValid = false
                    self.assentifySdkDelegate?.onAssentifySdkInitError(message: error.localizedDescription)
                }
            }
        }
    }
 
    
    public func startScanPassport(scanPassportDelegate:ScanPassportDelegate,language: String = Language.NON,stepId: Int? = nil)->ScanPassport?{
        if(isKeyValid){
            let scanPassport = ScanPassport(
                configModel:self.configModel,
                environmentalConditions:self.environmentalConditions!,
                apiKey:self.apiKey,
                scanPassportDelegate :scanPassportDelegate,
                language:language,
                isManual: self.isManual()
                
            )
            scanPassport.setStepId(stepId)
            return scanPassport;
            
        }else{
            NSException(name: NSExceptionName(rawValue: "Exception"), reason: "Invalid Keys", userInfo: nil).raise()
        }
        return nil;
    }
    
    public func startLocalScanPassport(scanPassportDelegate:ScanPassportDelegate,language: String = Language.NON,stepId: Int? = nil)->LocalScanPassport?{
        if(isKeyValid){
            let localScanPassport = LocalScanPassport(
                configModel:self.configModel,
                environmentalConditions:self.environmentalConditions!,
                apiKey:self.apiKey,
                scanPassportDelegate :scanPassportDelegate,
                language:language,
                
            )
            localScanPassport.setStepId(stepId)
            return localScanPassport;
            
        }else{
            NSException(name: NSExceptionName(rawValue: "Exception"), reason: "Invalid Keys", userInfo: nil).raise()
        }
        return nil;
    }
    
    
    
    public func startScanNfc(scanNfcDelegate:ScanNfcDelegate,language: String = Language.NON,stepId: Int? = nil)->ScanNfc?{
        if(isKeyValid){
            let scanNfc = ScanNfc(
                configModel:self.configModel,
                apiKey:self.apiKey,
                language:language,
                scanNfcDelegate:scanNfcDelegate
            )
            return scanNfc;
            
        }else{
            NSException(name: NSExceptionName(rawValue: "Exception"), reason: "Invalid Keys", userInfo: nil).raise()
        }
        return nil;
    }
    
    
    public func startScanOthers(scanOtherDelegate:ScanOtherDelegate,language: String = Language.NON,stepId: Int? = nil)->ScanOther?{
        if(isKeyValid){
            let scanOther = ScanOther(
                configModel:self.configModel,
                environmentalConditions:self.environmentalConditions!,
                apiKey:self.apiKey,
                scanOtherDelegate :scanOtherDelegate,
                language:language,
                isManual: self.isManual()
                
                
            )
            scanOther.setStepId(stepId)
            return scanOther;
            
        }else{
            NSException(name: NSExceptionName(rawValue: "Exception"), reason: "Invalid Keys", userInfo: nil).raise()
        }
        return nil;
    }
    
    
    public func startScanID(scanIDCardDelegate:ScanIDCardDelegate, templatesByCountry:TemplatesByCountry,language: String = Language.NON,stepId: Int? = nil)->ScanIDCard?{
        if(isKeyValid){
            scanID = ScanIDCard(
                configModel:self.configModel,
                environmentalConditions:self.environmentalConditions!,
                apiKey:self.apiKey,
                scanIDCardDelegate :scanIDCardDelegate,
                templatesByCountry:templatesByCountry,
                language:language,
                isManual: self.isManual()
                
            )
            scanID!.setStepId(stepId)
            return scanID;
            
        }else{
            NSException(name: NSExceptionName(rawValue: "Exception"), reason: "Invalid Keys", userInfo: nil).raise()
        }
        return nil;
    }
    
    
    public func startScanQr(scanQrDelegate:ScanQrDelegate, templatesByCountry:TemplatesByCountry,language: String = Language.NON,stepId: Int? = nil)->ScanQr?{
        if(isKeyValid){
            var  scanQr = ScanQr(
                configModel:self.configModel,
                environmentalConditions:self.environmentalConditions!,
                apiKey:self.apiKey,
                scanQrDelegate :scanQrDelegate,
                templatesByCountry:templatesByCountry,
                language:language,
                isManual: self.isManual()
                
            )
            scanQr.setStepId(stepId)
            return scanQr;
            
        }else{
            NSException(name: NSExceptionName(rawValue: "Exception"), reason: "Invalid Keys", userInfo: nil).raise()
        }
        return nil;
    }
    
    
    
    public func startFaceMatch(faceMatchDelegate:FaceMatchDelegate,secondImage:String,showCountDown:Bool = true,stepId: Int? = nil)->FaceMatch?{
        if(isKeyValid){
            let  faceMatch = FaceMatch(
                configModel:self.configModel,
                environmentalConditions:self.environmentalConditions!,
                apiKey:self.apiKey,
                performLivenessFace:  self.performActiveLivenessFace!,
                faceMatchDelegate :faceMatchDelegate,
                secondImage :secondImage,
                showCountDown: showCountDown,
                isManual: self.isManual()
            );
            faceMatch.setStepId(stepId)
            return faceMatch;
            
        }else{
            NSException(name: NSExceptionName(rawValue: "Exception"), reason: "Invalid Keys", userInfo: nil).raise()
        }
        return nil;
    }
    
    
    public func startContextAwareSigning(contextAwareDelegate:ContextAwareDelegate,stepId: Int? ,) -> ContextAwareSigning?{
        if(isKeyValid){
            return ContextAwareSigning(
                configModel:configModel,
                apiKey:apiKey,
                stepID:stepId!,
                tenantIdentifier:configModel!.tenantIdentifier,
                interaction:self.configModel!.instanceHash,
                contextAwareDelegate:contextAwareDelegate
            );
        }else{
            NSException(name: NSExceptionName(rawValue: "Exception"), reason: "Invalid Keys", userInfo: nil).raise()
        }
        return nil;
    }
    
    public func startAssistedDataEntry(assistedDataEntryDelegate:AssistedDataEntryDelegate,stepId: Int? = nil) -> AssistedDataEntry?{
        if(isKeyValid){
            let assistedDataEntry =  AssistedDataEntry(
                apiKey:apiKey,
                configModel:configModel!,
                delegate: assistedDataEntryDelegate,
            );
            assistedDataEntry.setStepId(stepId != nil ? String(stepId!) : nil)
            return assistedDataEntry;
        }else{
            NSException(name: NSExceptionName(rawValue: "Exception"), reason: "Invalid Keys", userInfo: nil).raise()
        }
        return nil;
    }
    
    
    
    public func startSubmitData(
        submitDataDelegate: SubmitDataDelegate,
        submitRequestModel: [SubmitRequestModel],
        customProperties: [String: String] = [:]
    ) -> SubmitData? {
        if (isKeyValid) {
            
            var submitList: [SubmitRequestModel] = []
            submitList.append(contentsOf: submitRequestModel)
            let initSteps = self.configModel!.stepDefinitions
            
            // MARK: - WrapUp
            var valuesWrapUp: [String: String] = [:]
            
            initSteps.forEach { item in
                if item.stepDefinition == StepsNames.wrapUp {
                    item.outputProperties.forEach { property in
                        if property.key.contains(WrapUpKeys.timeEnded) {
                            valuesWrapUp[property.key] = getTimeUTC()
                        }
                    }
                }
            }
            if !submitList.contains(where: { $0.stepDefinition == StepsNames.wrapUp }) {
                if let wrapUpStep = initSteps.first(where: { $0.stepDefinition == StepsNames.wrapUp }) {
                    let wrapUpSubmit = SubmitRequestModel(
                        stepId: wrapUpStep.stepId,
                        stepDefinition: StepsNames.wrapUp,
                        extractedInformation: valuesWrapUp
                    )
                    submitList.append(wrapUpSubmit)
                }
            }
            
            
            // MARK: - BlockLoader
            var valuesBlockLoader: [String: String] = [:]
            
            initSteps.forEach { item in
                if item.stepDefinition == StepsNames.blockLoader {
                    
                    // Fill from standard keys
                    item.outputProperties.forEach { property in
                        
                        if property.key.contains(BlockLoaderKeys.timeStarted) {
                            valuesBlockLoader[property.key] = timeStarted
                        }
                        
                        if property.key.contains(BlockLoaderKeys.deviceName) {
                            let deviceName = "\(UIDevice.current.model) \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
                            valuesBlockLoader[property.key] = deviceName
                        }
                        
                        if property.key.contains(BlockLoaderKeys.application) {
                            valuesBlockLoader[property.key] = self.configModel!.applicationId
                        }
                        
                        if property.key.contains(BlockLoaderKeys.flowName) {
                            valuesBlockLoader[property.key] = self.configModel!.flowName
                        }
                        
                        if property.key.contains(BlockLoaderKeys.instanceHash) {
                            valuesBlockLoader[property.key] = self.configModel!.instanceHash
                        }
                        
                        if property.key.contains(BlockLoaderKeys.userAgent) {
                            let userAgent = "iOS \(UIDevice.current.systemVersion); \(UIDevice.current.model)"
                            valuesBlockLoader[property.key] = userAgent
                        }
                        
                        if property.key.contains(BlockLoaderKeys.interactionID) {
                            valuesBlockLoader[property.key] = self.configModel!.instanceId
                        }
                    }
                    
                    // Override / extend with customProperties
                    item.outputProperties.forEach { property in
                        customProperties.forEach { key, value in
                            if property.key.contains(key) {
                                valuesBlockLoader[property.key] = String(describing: value)
                            }
                        }
                    }
                }
            }
            
            if !submitList.contains(where: { $0.stepDefinition == StepsNames.blockLoader }) {
                if let blockLoaderStep = initSteps.first(where: { $0.stepDefinition == StepsNames.blockLoader }) {
                    let blockLoaderSubmit = SubmitRequestModel(
                        stepId: blockLoaderStep.stepId,
                        stepDefinition: StepsNames.blockLoader,
                        extractedInformation: valuesBlockLoader
                    )
                    submitList.append(blockLoaderSubmit)
                }
            }
            
            return SubmitData(apiKey: apiKey,
                              submitDataDelegate:submitDataDelegate,
                              submitRequestModel:submitList,
                              configModel:configModel!)
        } else{
            NSException(name: NSExceptionName(rawValue: "Exception"), reason: "Invalid Keys", userInfo: nil).raise()
        }
        return nil;
    }
    
    func getTemplatesByCountry(templates : [Templates]?) {
        var filteredList = self.filterBySourceCountryCode(dataList:templates! )
        var templatesByCountry = [TemplatesByCountry]()
        
        for data in filteredList {
            
            let item = TemplatesByCountry(
                id: data.id,
                name: data.sourceCountry,
                sourceCountryCode: data.sourceCountryCode,
                flag: data.sourceCountryFlag,
                templates: self.filterTemplatesCountryCode(dataList: templates!, countryCode: data.sourceCountryCode)
            )
            templatesByCountry.append(item)
        }
        self.templates =  templatesByCountry ;
    }
    
    
    func filterBySourceCountryCode(dataList: [Templates]) -> [Templates] {
        var filteredList = [Templates]()
        var uniqueSourceCountryCodes = [String]()
        
        for data in dataList {
            if !uniqueSourceCountryCodes.contains(data.sourceCountryCode) {
                filteredList.append(data)
                uniqueSourceCountryCodes.append(data.sourceCountryCode)
            }
        }
        return filteredList
    }
    
    func filterTemplatesCountryCode(dataList: [Templates], countryCode: String) -> [Templates] {
        var filteredList = [Templates]()
        
        for data in dataList {
            if data.sourceCountryCode == countryCode {
                filteredList.append(data)
            }
        }
        return filteredList
    }
    
    func filterToSupportedCountries(dataList: [TemplatesByCountry]?,stepID: Int) -> [TemplatesByCountry]? {
        var selectedCountries: [String] = []
        var supportedIdCards: [String] = []
        
        for step in self.configModel!.stepDefinitions {
            if (step.stepId == stepID) {
                if step.stepDefinition == "IdentificationDocumentCapture" {
                    if let identificationDocuments = step.customization.identificationDocuments {
                        for docStep in identificationDocuments {
                            if docStep.key == "IdentificationDocument.IdCard" {
                                selectedCountries = docStep.selectedCountries!
                                supportedIdCards = docStep.supportedIdCards!
                            }
                        }
                    }
                }
            }
        }
        
        var filteredList = [TemplatesByCountry]()
        
        dataList?.forEach { data in
            if let foundCountry = selectedCountries.first(where: { $0 == data.sourceCountryCode }) {
                if !foundCountry.isEmpty {
                    filteredList.append(data)
                }
            }
        }
        
        if selectedCountries.isEmpty {
            return dataList
        }
        
        
        var filteredListByCards = [TemplatesByCountry]()
        
        filteredList.forEach(){
            card in
            var selectedTemplates : [Templates] = [];
            card.templates.forEach(){cardTemplates in
                if supportedIdCards.contains(String(cardTemplates.id)) {
                    selectedTemplates.append(cardTemplates)
                }
            }
            filteredListByCards.append(TemplatesByCountry(
                id: card.id,
                name: card.name,
                sourceCountryCode: card.sourceCountryCode,
                flag: card.flag,
                templates: selectedTemplates))
        }
        
        
        
        return filteredListByCards
    }
    
    public func languageTransformation(
        languageTransformationDelegate: LanguageTransformationDelegate,
        language: String,
        languageTransformationData: [LanguageTransformationModel]
    ) {
        if (isKeyValid) {
            let transformed = LanguageTransformation(apiKey: apiKey,languageTransformationDelegate: languageTransformationDelegate)
            transformed.languageTransformation(
                langauge: language,
                transformationModel: TransformationModel(languageTransformationModels: languageTransformationData)
            )
        } else{
            NSException(name: NSExceptionName(rawValue: "Exception"), reason: "Invalid Keys", userInfo: nil).raise()
        }
    }
    
    public func getTemplates(stepID: Int) -> [TemplatesByCountry] {
        let stepTemplates =  self.filterToSupportedCountries(dataList: self.templates,stepID:stepID)!;
        return stepTemplates;
    }
    
    public func isManual() -> Bool {
        let totalRamGB = getTotalRAMInGB()
        let cores = ProcessInfo.processInfo.processorCount
        
        
        return (totalRamGB < self.environmentalConditions!.minRam) || (cores < self.environmentalConditions!.minCPUCores)
    }
    
    private  func getTotalRAMInGB() -> UInt64 {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        return physicalMemory / (1024 * 1024 * 1024)
    }
    
    // Flow
    public func startFlow(from presenter: UIViewController,flowDelegate:FlowDelegate,flowEnvironmentalConditions:FlowEnvironmentalConditions) {
        if (isKeyValid) {
            if (flowEnvironmentalConditions.logoUrl.isEmpty) {
                flowEnvironmentalConditions.logoUrl = tenantThemeModel!.logoIcon!;
            }
            if (flowEnvironmentalConditions.svgBackgroundImageUrl.isEmpty) {
                flowEnvironmentalConditions.svgBackgroundImageUrl =
                "tenantThemeModel!!.svgBackgroundImageUrl!!";
            }
            if (flowEnvironmentalConditions.textColor.isEmpty) {
                flowEnvironmentalConditions.textColor = tenantThemeModel!.textColor;
            }
            if (flowEnvironmentalConditions.secondaryTextColor.isEmpty) {
                flowEnvironmentalConditions.secondaryTextColor = tenantThemeModel!.secondaryTextColor;
            }
            if (flowEnvironmentalConditions.backgroundCardColor.isEmpty) {
                flowEnvironmentalConditions.backgroundCardColor =
                tenantThemeModel!.backgroundCardColor;
            }
            if (flowEnvironmentalConditions.accentColor.isEmpty) {
                flowEnvironmentalConditions.accentColor = tenantThemeModel!.accentColor;
            }
            if (flowEnvironmentalConditions.backgroundColor == nil) {
                if (flowEnvironmentalConditions.backgroundType == BackgroundType.color) {
                    flowEnvironmentalConditions.backgroundColor =
                    BackgroundStyle.solid(hex:tenantThemeModel!.backgroundBodyColor)
                } else {
                    flowEnvironmentalConditions.backgroundColor =
                    BackgroundStyle.solid(hex:tenantThemeModel!.backgroundCardColor)
                }
            }
            if (flowEnvironmentalConditions.clickColor == nil) {
                flowEnvironmentalConditions.clickColor =
                BackgroundStyle.solid(hex:tenantThemeModel!.accentColor)
            }
            
            ApiKeyObject.shared.set(self.apiKey)
            FlowEnvironmentalConditionsObject.shared.set(flowEnvironmentalConditions)
            InteractionObject.shared.set(configModel!.instanceHash);
            
          
            if (ConfigModelObject.shared.get() != nil) {
                configModel = ConfigModelObject.shared.get();
                BugsnagObject.initialize(configModel: configModel!);
                AssentifySdkObject.shared.set(self)
            } else {
                ConfigModelObject.shared.set(
                    configModel!
                )
                BugsnagObject.initialize(configModel: configModel!);
                AssentifySdkObject.shared.set(self)
            }
            
            
            let nav = UINavigationController()
            nav.modalPresentationStyle = .fullScreen
            
            let controller = FlowController(navigationController: nav,flowDelegate: flowDelegate)
            self.flowController = controller

            controller.setRoot(animated: false)

            presenter.present(nav, animated: true)
        }
        
        
    }
    
    public func clearFlow() {
        InteractionObject.shared.set(self.configModel!.instanceHash);
        ConfigModelObject.shared.set(nil)
        CreateUserDocumentObject.shared.clear()
        SignatureResponseObject.shared.clear()
        HasSubmittedObject.shared.clear()
        AssistedDataEntryPagesObjectJson.shared.clear()
        LocalStepsObject.shared.set(
              []
           )
     }
    
    private func newInstance(){
        InteractionObject.shared.set(self.configModel!.instanceHash);
        ConfigModelObject.shared.set(nil)
    }
    
}
