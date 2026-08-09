public struct FlowCompletedModel: Codable {
    
    public var stepData: [String: String]
    public var submitRequestModel: SubmitRequestModel?
    
    public init(
        stepData: [String: String],
        submitRequestModel: SubmitRequestModel?
    ) {
        self.stepData = stepData
        self.submitRequestModel = submitRequestModel
    }
}
