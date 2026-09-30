//
//  DocumentCapture.swift
//  AssentifySdk
//
//  Created by TariQ on 23/09/2026.
//

import Foundation


public final class Questionnaire {
    
    private let apiKey: String
    private let configModel: ConfigModel
    
    public  var delegate: QuestionnaireDelegate?
    private var stepID: String?
    
    public init(apiKey: String, configModel: ConfigModel,delegate:QuestionnaireDelegate) {
        self.apiKey = apiKey
        self.configModel = configModel
        self.delegate = delegate
    }
    
    
    
    /// Kotlin: setStepId(stepId: String?)
    public func setStepId(_ stepId: String?) {
        self.stepID = stepId
        
        if self.stepID == nil {
            let assistedSteps = configModel.stepDefinitions.filter {
                $0.stepDefinition == StepsNames.questionnaire
            }
            
            if assistedSteps.count == 1,
               let step = assistedSteps.first {
                
                self.stepID = String(step.stepId)   // ← assuming stepId exists
                getQuestionnaireFromConfigFile()
                return
            }
            
            
            delegate?.onQuestionnaireCallbackError(
                message: "Step ID is required because multiple 'Questionnaire' steps are present."
            )
            return
        }
        
        // stepId provided
        getQuestionnaireFromConfigFile()
    }
    
    // MARK: - Network
    
    private func getQuestionnaireFromConfigFile() {
        let id = Int(self.stepID ?? "0") ?? 0;
        let stepDefinitions = configModel.stepDefinitions
        stepDefinitions.forEach { step in
            if step.stepId == id  {
                let questionnaireModel = step.customization.toQuestionnaireModel()
                self.delegate?.onQuestionnaireCallbackSuccess(questionnaireModel: questionnaireModel)
            }
        }
    }
    
 
    

}



private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}


extension Customization {
    func toQuestionnaireModel() -> QuestionnaireModel {
        return QuestionnaireModel(
            header: self.header,
            subHeader: self.subHeader,
            svgLogoUrl: self.svgLogoUrl,
            questions: self.questions,
            nextButtonTitle: self.nextButtonTitle,
            isNormalClick: self.isNormalClick ?? false
        )
    }
}
