import Foundation

public struct TrackProgressRequest: Codable {

    func prettyPrint() -> String {
          var lines: [String] = []
          lines.append("TrackProgressRequest {")
          lines.append("  stepDefinition: \(stepDefinition)")
          lines.append("  stepId: \(stepId)")
          lines.append("  stepTypeId: \(stepTypeId)")
          lines.append("  status: \(status)")
          lines.append("  timestamp: \(timestamp)")
          lines.append("  deviceName: \(deviceName)")
          lines.append("  userAgent: \(userAgent)")
          lines.append("  language: \(language)")

          if let inputData {
              lines.append("  inputData: \(inputData.prettyString().replacingOccurrences(of: "\n", with: "\n  "))")
          } else {
              lines.append("  inputData: nil")
          }

          if let response {
              lines.append("  response: \(response.prettyString().replacingOccurrences(of: "\n", with: "\n  "))")
          } else {
              lines.append("  response: nil")
          }

          lines.append("  customPropertiesCount: \(customProperties.count)")
          lines.append("}")

          return lines.joined(separator: "\n")
      }
    
    public let tenantIdentifier: String
    public let flowIdentifier: String
    public let flowInstanceId: String
    public let applicationId: String
    public let blockIdentifier: String
    public let instanceHash: String
    public let flowName: String
    public let stepDefinition: String
    public let stepId: Int
    public let stepTypeId: Int
    public let status: String
    public let deviceName: String
    public let userAgent: String
    public let timestamp: String
    public let language: String
    public let inputData: AnyCodable?
    public let response: AnyCodable?
    public let customProperties: [AnyCodable]

    enum CodingKeys: String, CodingKey {
        case tenantIdentifier = "TenantIdentifier"
        case flowIdentifier = "FlowIdentifier"
        case flowInstanceId = "FlowInstanceId"
        case applicationId = "ApplicationId"
        case blockIdentifier = "BlockIdentifier"
        case instanceHash = "InstanceHash"
        case flowName = "FlowName"
        case stepDefinition = "StepDefinition"
        case stepId = "StepId"
        case stepTypeId = "StepTypeId"
        case status = "Status"
        case deviceName = "DeviceName"
        case userAgent = "UserAgent"
        case timestamp = "Timestamp"
        case language = "Language"
        case inputData = "InputData"
        case response = "Response"
        case customProperties = "CustomProperties"
    }

    public init(
        tenantIdentifier: String,
        flowIdentifier: String,
        flowInstanceId: String,
        applicationId: String,
        blockIdentifier: String,
        instanceHash: String,
        flowName: String,
        stepDefinition: String,
        stepId: Int,
        stepTypeId: Int,
        status: String,
        deviceName: String,
        userAgent: String,
        timestamp: String,
        language: String,
        inputData: Any? = nil,
        response: Any? = nil,
        customProperties: [Any] = []
    ) {
        self.tenantIdentifier = tenantIdentifier
        self.flowIdentifier = flowIdentifier
        self.flowInstanceId = flowInstanceId
        self.applicationId = applicationId
        self.blockIdentifier = blockIdentifier
        self.instanceHash = instanceHash
        self.flowName = flowName
        self.stepDefinition = stepDefinition
        self.stepId = stepId
        self.stepTypeId = stepTypeId
        self.status = status
        self.deviceName = deviceName
        self.userAgent = userAgent
        self.timestamp = timestamp
        self.language = language
        self.inputData = inputData != nil ? AnyCodable(inputData) : nil
        self.response = response != nil ? AnyCodable(response) : nil
        self.customProperties = customProperties.map { AnyCodable($0) }
    }
}


public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any?) {
        self.value = value ?? ()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictionaryValue = try? container.decode([String: AnyCodable].self) {
            value = dictionaryValue.mapValues { $0.value }
        } else {
            value = ()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictionaryValue as [String: Any]:
            try container.encode(dictionaryValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}


import Foundation

extension Encodable {
    func prettyJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? "\(self)"
        } catch {
            return "❌ Failed to encode JSON: \(error)"
        }
    }
}

extension AnyCodable {
    /// Best-effort pretty string for debugging
    func prettyString() -> String {
        if JSONSerialization.isValidJSONObject(value) {
            do {
                let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
                return String(data: data, encoding: .utf8) ?? "\(value)"
            } catch {
                return "\(value)"
            }
        }
        return "\(value)"
    }
}
