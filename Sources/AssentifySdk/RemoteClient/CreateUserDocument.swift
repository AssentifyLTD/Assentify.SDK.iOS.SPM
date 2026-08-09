

import Foundation

public struct CreateUserDocumentRequestModel:Codable {
    public  let userId: String
    public  let documentTemplateId: Int
    public  let data: [String: String]
    public  let outputType: Int
}

public struct CreateUserDocumentResponseModel:Codable {
    public  let templateInstance: String
    public  let templateInstanceId: Int
    public  let documentId: Int
    public  let isPdf: Bool
}
