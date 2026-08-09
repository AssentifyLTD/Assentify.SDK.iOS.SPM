

import Foundation


public struct DocumentTokensModel:Codable {
    public let id: Int
    public  let templateId: Int
    public let tokenValue: String
    public let displayName: String
    public let tokenTypeEnum: Int
}


public struct TokensMappings: Codable {
    public let   id: Int
    public let   tokenId: Int
    public let   aBlockIdentifier: String
    public let   stepId: Int
    public let   aFlowPropertyIdentifier: String
    public let   flowName: String
    public let   blockName: String
    public let   stepName: String
    public let   displayName: String
    public let   sourceKey: String
    public let   isDeleted: Bool
    public let   type: Int

    enum CodingKeys: String, CodingKey {
        case id
        case tokenId
        case aBlockIdentifier
        case stepId
        case aFlowPropertyIdentifier
        case flowName
        case blockName
        case stepName
        case displayName
        case sourceKey
        case isDeleted
        case type
    }
}
