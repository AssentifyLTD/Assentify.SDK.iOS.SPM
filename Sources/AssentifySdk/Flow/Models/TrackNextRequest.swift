import Foundation

public struct TrackNextRequest: Codable {
    
    public let applicationId: String
    public let blockIdentifier: String
    public let blockType: String
    public let deviceName: String
    public let flowIdentifier: String
    public let flowInstanceId: String
    public let flowName: String
    public let instanceHash: String
    public let isSuccessful: Bool
    public let language: String
    public let nextStepDefinition: String
    public let nextStepId: Int
    public let nextStepTypeId: Int
    public let phoneNumber: String?
    public let statusCode: Int
    public let stepDefinition: String
    public let stepId: Int
    public let stepTypeId: Int
    public let tenantIdentifier: String
    public let timeStarted: String
    public let timeEnded: String
    public let userAgent: String

    enum CodingKeys: String, CodingKey {
        case applicationId = "ApplicationId"
        case blockIdentifier = "BlockIdentifier"
        case blockType = "BlockType"
        case deviceName = "DeviceName"
        case flowIdentifier = "FlowIdentifier"
        case flowInstanceId = "FlowInstanceId"
        case flowName = "FlowName"
        case instanceHash = "InstanceHash"
        case isSuccessful = "IsSuccessful"
        case language = "Language"
        case nextStepDefinition = "NextStepDefinition"
        case nextStepId = "NextStepId"
        case nextStepTypeId = "NextStepTypeId"
        case phoneNumber = "PhoneNumber"
        case statusCode = "StatusCode"
        case stepDefinition = "StepDefinition"
        case stepId = "StepId"
        case stepTypeId = "StepTypeId"
        case tenantIdentifier = "TenantIdentifier"
        case timeStarted = "TimeStarted"
        case timeEnded = "TimeEnded"
        case userAgent = "UserAgent"
    }
}


