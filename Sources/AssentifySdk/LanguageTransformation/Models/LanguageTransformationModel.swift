import Foundation

public struct LanguageTransformationModel: Codable {
    let languageTransformationEnum: Int
    let key: String
    let value: String
    let language: String
    let dataType: String
    
    public init(languageTransformationEnum: Int, key: String, value: String, language: String, dataType: String) {
        self.languageTransformationEnum = languageTransformationEnum
        self.key = key
        self.value = value
        self.language = language
        self.dataType = dataType
    }
}

public struct TransformationModel: Codable {
    let languageTransformationModels: [LanguageTransformationModel]
    
    public init(languageTransformationModels: [LanguageTransformationModel]) {
        self.languageTransformationModels = languageTransformationModels
    }
}
