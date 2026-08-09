import Foundation

// MARK: - InputTypes (Kotlin enum -> Swift enum)

public enum InputTypes: String, Codable, CaseIterable {
    case text                = "Text"
    case textArea            = "TextArea"
    case date                = "Date"
    case dropDown            = "DropDown"
    case email               = "Email"
    case radioButtonGroup    = "RadioButtonGroup"
    case nationality         = "Nationality"
    case phoneNumber         = "PhoneNumber"
    case phoneNumberWithOTP  = "PhoneNumberWithOTP"
    case emailWithOTP        = "EmailWithOTP"
    case checkbox             = "Checkbox"
    case checkboxGroup       = "CheckboxGroup"

    /// Kotlin: fromString(type: String?) -> InputTypes
    public static func fromString(_ type: String?) -> InputTypes {
        guard let type = type?.trimmingCharacters(in: .whitespacesAndNewlines),
              !type.isEmpty else { return .text }

        return Self.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(type) == .orderedSame }) ?? .text
    }
}

// MARK: - AssistedDataEntry Models

public struct AssistedDataEntryBaseModel: Codable {
    public let statusCode: Int
    public let data: AssistedDataEntryModel
}

public struct AssistedDataEntryModel: Codable {
    public let allowAssistedDataEntry: Bool
    public var assistedDataEntryPages: [AssistedDataEntryPage]
    public let header: String
    public let subHeader: String
    public let inputProperties: [InputProperty]
}

public struct AssistedDataEntryPage: Codable {
    public let title: String
    public let subTitle: String?
    public let svgLogoUrl: String?
    public let nextButtonTitle: String
    public let isNormalClick: Bool
    public var dataEntryPageElements: [DataEntryPageElement]
}

public struct DataEntryPageElement: Codable {
    public var value: String?
    public var isLocalOtpValid: Bool = false
    public var dataSourceValues: [String: String]? = [:]

    public let elementIdentifier: String
    public let endpointId: Int?
    public let dataSourceId: Int?
    public let inputType: String
    public let sizeByRows: Int?
    public let textTitle: String?
    public let inputKey: String?
    public let isDirtyKey: String?
    public let mandatory: Bool?
    public let allowAssistedEntry: Bool?
    public let sourceKStep: String?
    public let dataKeys: [String]?
    public let linkedControls: [String]?
    public var applyRegex: Bool?
    public let languageTransformation: Int?
    public let targetOutputLanguage: String?
    public var regexDescriptor: String?
    public let regexErrorMessage: String?
    public let showBasedOnParent: Bool?
    public let dataSourceType: Int?
    public let enableDatePicker: Bool?
    public let from: String?
    public let enableConstraints: Bool?
    public let constraintType: Int?
    public let to: String?
    public let dataSourceContent: String?
    public let linkedChildren: Bool?
    public let sendEmailVerificationLink: Bool?
    public let hasRelatedDataTypes: Bool?
    public let inputPropertyIdentifier: String?
    public let inputPropertyIdentifierList: [String]?
    public let isLocked: Bool?
    public let readOnly: Bool?
    public let isHidden: Bool?
    public let maxLength: Int?
    public let minLength: Int?
    public let otp: Bool?
    public let otpSize: Int?
    public let otpType: Int?
    public let otpExpiryTime: Double?
    public let additionalFeatures: Bool?
    public let children: [String: [DataEntryPageElement]]?
    public var defaultCountryCode: String?
    public let otpFormat: Int?
    public let smsProvider: Int?
    public let whatsappProvider: Int?

    enum CodingKeys: String, CodingKey {
        case value, isLocalOtpValid, dataSourceValues
        case elementIdentifier, endpointId, dataSourceId, inputType, sizeByRows, textTitle, inputKey, isDirtyKey
        case mandatory, allowAssistedEntry, sourceKStep, dataKeys, linkedControls, applyRegex, languageTransformation
        case targetOutputLanguage, regexDescriptor, regexErrorMessage, showBasedOnParent, dataSourceType, enableDatePicker
        case from, enableConstraints, constraintType, to, dataSourceContent, linkedChildren, sendEmailVerificationLink
        case hasRelatedDataTypes, inputPropertyIdentifier, inputPropertyIdentifierList, isLocked, readOnly,isHidden
        case maxLength, minLength, otp, otpSize, otpType, otpExpiryTime, additionalFeatures, children, defaultCountryCode,otpFormat,smsProvider,whatsappProvider
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        value = try c.decodeIfPresent(String.self, forKey: .value)
        isLocalOtpValid = try c.decodeIfPresent(Bool.self, forKey: .isLocalOtpValid) ?? false
        dataSourceValues = try c.decodeIfPresent([String: String].self, forKey: .dataSourceValues) ?? [:]

        elementIdentifier = try c.decode(String.self, forKey: .elementIdentifier)
        endpointId = try c.decodeIfPresent(Int.self, forKey: .endpointId)
        dataSourceId = try c.decodeIfPresent(Int.self, forKey: .dataSourceId)
        inputType = try c.decode(String.self, forKey: .inputType)
        sizeByRows = try c.decodeIfPresent(Int.self, forKey: .sizeByRows)
        textTitle = try c.decodeIfPresent(String.self, forKey: .textTitle)
        inputKey = try c.decodeIfPresent(String.self, forKey: .inputKey)
        isDirtyKey = try c.decodeIfPresent(String.self, forKey: .isDirtyKey)
        mandatory = try c.decodeIfPresent(Bool.self, forKey: .mandatory)
        allowAssistedEntry = try c.decodeIfPresent(Bool.self, forKey: .allowAssistedEntry)
        sourceKStep = try c.decodeIfPresent(String.self, forKey: .sourceKStep)
        dataKeys = try c.decodeIfPresent([String].self, forKey: .dataKeys)
        linkedControls = try c.decodeIfPresent([String].self, forKey: .linkedControls)
        applyRegex = try c.decodeIfPresent(Bool.self, forKey: .applyRegex)
        languageTransformation = try c.decodeIfPresent(Int.self, forKey: .languageTransformation)
        targetOutputLanguage = try c.decodeIfPresent(String.self, forKey: .targetOutputLanguage)
        regexDescriptor = try c.decodeIfPresent(String.self, forKey: .regexDescriptor)
        regexErrorMessage = try c.decodeIfPresent(String.self, forKey: .regexErrorMessage)
        showBasedOnParent = try c.decodeIfPresent(Bool.self, forKey: .showBasedOnParent)
        dataSourceType = try c.decodeIfPresent(Int.self, forKey: .dataSourceType)
        enableDatePicker = try c.decodeIfPresent(Bool.self, forKey: .enableDatePicker)
        from = try c.decodeIfPresent(String.self, forKey: .from)
        enableConstraints = try c.decodeIfPresent(Bool.self, forKey: .enableConstraints)
        constraintType = try c.decodeIfPresent(Int.self, forKey: .constraintType)
        to = try c.decodeIfPresent(String.self, forKey: .to)
        dataSourceContent = try c.decodeIfPresent(String.self, forKey: .dataSourceContent)
        linkedChildren = try c.decodeIfPresent(Bool.self, forKey: .linkedChildren)
        sendEmailVerificationLink = try c.decodeIfPresent(Bool.self, forKey: .sendEmailVerificationLink)
        hasRelatedDataTypes = try c.decodeIfPresent(Bool.self, forKey: .hasRelatedDataTypes)
        inputPropertyIdentifier = try c.decodeIfPresent(String.self, forKey: .inputPropertyIdentifier)
        inputPropertyIdentifierList = try c.decodeIfPresent([String].self, forKey: .inputPropertyIdentifierList)
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked)
        readOnly = try c.decodeIfPresent(Bool.self, forKey: .readOnly)
        isHidden = try c.decodeIfPresent(Bool.self, forKey: .isHidden)
        maxLength = try c.decodeIfPresent(Int.self, forKey: .maxLength)
        minLength = try c.decodeIfPresent(Int.self, forKey: .minLength)
        otp = try c.decodeIfPresent(Bool.self, forKey: .otp)
        otpSize = try c.decodeIfPresent(Int.self, forKey: .otpSize)
        otpType = try c.decodeIfPresent(Int.self, forKey: .otpType)
        otpExpiryTime = try c.decodeIfPresent(Double.self, forKey: .otpExpiryTime)
        additionalFeatures = try c.decodeIfPresent(Bool.self, forKey: .additionalFeatures)
        children = try c.decodeIfPresent([String: [DataEntryPageElement]].self, forKey: .children)
        defaultCountryCode = try c.decodeIfPresent(String.self, forKey: .defaultCountryCode)
        otpFormat = try c.decodeIfPresent(Int.self, forKey: .otpFormat)
        smsProvider = try c.decodeIfPresent(Int.self, forKey: .smsProvider)
        whatsappProvider = try c.decodeIfPresent(Int.self, forKey: .whatsappProvider)
    }
}




// MARK: - InputType constants (Kotlin object -> Swift namespace)

public enum InputType {
    public static let text = "Text"
    public static let textArea = "TextArea"
    public static let date = "Date"
    public static let dropDown = "DropDown"
    public static let email = "Email"
    public static let radioButtonGroup = "RadioButtonGroup"
    public static let nationality = "Nationality"
    public static let phoneNumberWithOtp = "PhoneNumberWithOtp"
    public static let emailWithOtp = "EmailWithOtp"
    public static let phoneNumber = "PhoneNumber"
}
