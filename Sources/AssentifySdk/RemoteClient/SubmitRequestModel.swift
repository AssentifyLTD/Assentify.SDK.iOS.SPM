
import Foundation

public struct SubmitRequestModel : Codable{
   public var stepId: Int
   public var stepDefinition: String
   public var extractedInformation: [String: String]
    
    public  init(stepId: Int, stepDefinition: String, extractedInformation: [String: String]) {
        self.stepId = stepId
        self.stepDefinition = stepDefinition
        self.extractedInformation = extractedInformation
    }
}


