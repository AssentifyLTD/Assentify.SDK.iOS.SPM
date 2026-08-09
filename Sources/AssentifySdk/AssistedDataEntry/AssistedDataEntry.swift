import Foundation


public final class AssistedDataEntry {
    
    private let apiKey: String
    private let configModel: ConfigModel
    
    public  var delegate: AssistedDataEntryDelegate?
    private var stepID: String?
    
    public init(apiKey: String, configModel: ConfigModel,delegate:AssistedDataEntryDelegate) {
        self.apiKey = apiKey
        self.configModel = configModel
        self.delegate = delegate
    }
    
    
    
    /// Kotlin: setStepId(stepId: String?)
    public func setStepId(_ stepId: String?) {
        self.stepID = stepId
        
        if self.stepID == nil {
            let assistedSteps = configModel.stepDefinitions.filter {
                $0.stepDefinition == "AssistedDataEntry"
            }
            
            if assistedSteps.count == 1,
               let step = assistedSteps.first {
                
                self.stepID = String(step.stepId)   // ← assuming stepId exists
                getAssistedDataEntryStepFromConfigFile()
                return
            }
            
            
            delegate?.onAssistedDataEntryError(
                message: "Step ID is required because multiple 'Assisted Data Entry' steps are present."
            )
            return
        }
        
        // stepId provided
        getAssistedDataEntryStepFromConfigFile()
    }
    
    // MARK: - Network
    
    private func getAssistedDataEntryStepFromConfigFile() {
        let id = Int(self.stepID ?? "0") ?? 0;
        let stepDefinitions = configModel.stepDefinitions
        stepDefinitions.forEach { step in
            if step.stepId == id  {
                let assistedDataEntryModel = step.customization.toAssistedDataEntryModel()
                self.delegate?.onAssistedDataEntrySuccess(assistedDataEntryModel: assistedDataEntryModel)
            }
        }
    }
    
 
}


extension Customization {
    func toAssistedDataEntryModel() -> AssistedDataEntryModel {
        return AssistedDataEntryModel(
            allowAssistedDataEntry: self.allowAssistedDataEntry ?? false,
            assistedDataEntryPages: self.assistedDataEntryPages ?? [],
            header: self.header ?? "",
            subHeader: self.subHeader ?? "",
            inputProperties: self.inputProperties ?? []
        )
    }
}
