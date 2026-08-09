import SwiftUI
import UIKit
import SVGKit

// MARK: - Theme

public struct StepperTheme {
    public let activeColor: Color
    public let doneColor: Color
    public let upcomingColor: Color

    public init() {
        self.activeColor = Color(BaseTheme.baseAccentColor)
        self.doneColor = Color(BaseTheme.baseGreenColor)
        self.upcomingColor = Color(BaseTheme.baseTextColor)
    }
}

public struct StepperPercentageTheme {
    public let activeColor: Color
    public let doneColor: Color
    public let upcomingColor: Color

    public init() {
        self.activeColor = Color(BaseTheme.baseAccentColor)
        self.doneColor = Color(BaseTheme.baseAccentColor)
        self.upcomingColor = Color(BaseTheme.fieldColor)
    }
}

public enum StepVisualState {
    case done, active, upcoming
}



public struct ProgressStepperView: View {

    private let steps: [LocalStepModel]
    private let bundle: Bundle
    let onBack: () -> Void

    public init(
        steps: [LocalStepModel],
        bundle: Bundle,
        onBack: @escaping () -> Void = {}
    ) {
        self.steps = steps.filter { $0.show }
        self.bundle = bundle
        self.onBack = onBack
    }

    public var body: some View {
        if BaseTheme.stepperType == .normal {
            NormalProgressStepper(steps: steps, bundle: bundle)
        } else {
            PercentageBasedProgressStepper(steps: steps, bundle: bundle, onBack: {onBack()})
        }
    }
 
}
