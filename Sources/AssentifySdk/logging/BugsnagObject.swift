import Foundation
import Bugsnag
import BugsnagPerformance
import UIKit

final class  BugsnagObject {

    private static var initialized = false

    static func  initialize(configModel: ConfigModel) {
        if !initialized {
             let errCfg = BugsnagConfiguration.loadConfig()
              errCfg.apiKey = ConstantsValues.BugsnagApiKey
              Bugsnag.start(with: errCfg)

            
            let perfCfg = BugsnagPerformanceConfiguration.loadConfig()
              perfCfg.apiKey = ConstantsValues.BugsnagApiKey
              BugsnagPerformance.start(configuration: perfCfg)

            logInfo(message: "Sdk started successfully", configModel: configModel)
            initialized = true
        }
    }

    static  func logInfo(message: String, configModel: ConfigModel) {
        Bugsnag.notifyError(NSError(domain: "BugsnagInfo",
                                    code: 0,
                                    userInfo: [NSLocalizedDescriptionKey: message])) { event in
            event.severity = .info
            event.context = extractConfigMap(message: message, configModel: configModel).description

            for (key, value) in extractConfigMap(message: message, configModel: configModel) {
                event.addMetadata(value, key: key, section: "configmodel")
            }
            return true
        }

    }

    static  func logError(exception: Error, configModel: ConfigModel) {
        Bugsnag.notifyError(exception) { event in
            if let message = exception.localizedDescription as String? {
                for (key, value) in extractConfigMap(message: message, configModel: configModel) {
                    event.addMetadata(value, key: key, section: "configmodel")
                }
            }
            return true
        }
    }

    static  func extractConfigMap(message: String, configModel: ConfigModel) -> [String: Any] {
        return [
            "message": message,
            "flowName": configModel.flowName,
            "blockName": configModel.blockIdentifier,
            "instanceHash": configModel.instanceHash,
            "flowInstanceId": configModel.flowInstanceId,
            "tenantIdentifier": configModel.tenantIdentifier,
            "blockIdentifier": configModel.blockIdentifier,
            "flowIdentifier": configModel.flowIdentifier,
            "instanceId": configModel.instanceId
        ]
    }
}
