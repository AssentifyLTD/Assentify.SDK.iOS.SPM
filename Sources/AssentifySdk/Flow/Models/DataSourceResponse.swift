import Foundation

public struct DataSourceResponse: Codable {
    public let message: String?
    public let statusCode: Int
    public let error: String?
    public let errorCode: String?
    public let data: DataSourceData?
    public let isSuccessful: Bool

    public init(
        message: String?,
        statusCode: Int,
        error: String?,
        errorCode: String?,
        data: DataSourceData?,
        isSuccessful: Bool
    ) {
        self.message = message
        self.statusCode = statusCode
        self.error = error
        self.errorCode = errorCode
        self.data = data
        self.isSuccessful = isSuccessful
    }
}

public struct DataSourceData: Codable {
    public let endpointId: Int
    public let stepId: Int
    public let elementIdentifier: String
    public let items: [DataSourceItem]
    public let outputKeys: [String: String]
    public let inputKeys: [String: String]
    public let filterKeys: [String]
    public let isLoaded: Bool

    public init(
        endpointId: Int,
        stepId: Int,
        elementIdentifier: String,
        items: [DataSourceItem],
        outputKeys: [String: String],
        inputKeys: [String: String],
        filterKeys: [String],
        isLoaded: Bool
    ) {
        self.endpointId = endpointId
        self.stepId = stepId
        self.elementIdentifier = elementIdentifier
        self.items = items
        self.outputKeys = outputKeys
        self.inputKeys = inputKeys
        self.filterKeys = filterKeys
        self.isLoaded = isLoaded
    }
}

public struct DataSourceItem: Codable {
    public let dataSourceAttributes: [DataSourceAttribute]

    public init(dataSourceAttributes: [DataSourceAttribute]) {
        self.dataSourceAttributes = dataSourceAttributes
    }
}

public struct DataSourceAttribute: Codable {
    public let id: Int
    public let propertyIdentifier: String
    public let value: String
    public let displayName: String
    public let mappedKey: String

    public init(
        id: Int,
        propertyIdentifier: String,
        value: String,
        displayName: String,
        mappedKey: String
    ) {
        self.id = id
        self.propertyIdentifier = propertyIdentifier
        self.value = value
        self.displayName = displayName
        self.mappedKey = mappedKey
    }
}

public struct DataSourceRequestBody: Codable {
    public let filterKeyValues: [String: String]
    public let inputKeyValues: [String: String]

    public init(
        filterKeyValues: [String: String] = [:],
        inputKeyValues: [String: String] = [:]
    ) {
        self.filterKeyValues = filterKeyValues
        self.inputKeyValues = inputKeyValues
    }
}
