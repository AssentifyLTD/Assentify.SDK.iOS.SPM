import Foundation

/// The face step's customization, read ONCE while the face step is still the current step.
///
/// Child views (FaceResultScreen, SupportingDocResultScreen) are re-created on every redraw, so they
/// must not call flowController.getCurrentStep() themselves: after makeCurrentStepDone() it returns
/// the NEXT step, and the result screen would switch to that step's thresholds.
public struct FaceStepSettings {
    let supportingDocumentEnabled: Bool
    let passThreshold: Int
    let supportingDocumentFrom: Int
    let belowThresholdFlagAndPass: Bool
    let supportingDocumentAllowSkip: Bool

    init(customization: Customization?) {
        supportingDocumentEnabled   = customization?.supportingDocumentEnabled ?? false
        passThreshold               = customization?.faceMatchPassThreshold ?? 60
        supportingDocumentFrom      = customization?.supportingDocumentFrom ?? 20
        belowThresholdFlagAndPass   = customization?.belowThresholdFlagAndPass ?? false
        supportingDocumentAllowSkip = customization?.supportingDocumentAllowSkip ?? false
    }

    /// Reads the current step: call only from a step's init, never from a child view.
    init(flowController: FlowController) {
        self.init(customization: flowController.getCurrentStep()?.stepDefinition?.customization)
    }
}
