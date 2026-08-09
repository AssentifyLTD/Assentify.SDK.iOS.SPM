import Foundation
import UIKit
import Clarity

// Hypothetical Clarity iOS SDK import
// import ClaritySDK

final class ClarityLogging {

    private static var initialized = false

    static func initialize() {
        guard !initialized else { return }

        let clarityConfig = ClarityConfig(projectId: ConstantsValues.ClarityProjectId,logLevel: .verbose)
        ClaritySDK.initialize(config: clarityConfig)
        initialized = true
    }
}
