import Foundation

public protocol FlowDelegate  {
    
    func onStepCompleted(stepModel: FlowCompletedModel)

    func onFlowCompleted(flowData:[FlowCompletedModel])
}
