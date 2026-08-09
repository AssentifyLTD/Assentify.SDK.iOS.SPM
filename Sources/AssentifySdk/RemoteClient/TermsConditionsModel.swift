import Foundation

public struct TermsConditionsModel: Codable {
    public let statusCode: Int
    public let data: TermsConditionsDataModel

    public init(statusCode: Int,
                data: TermsConditionsDataModel) {
        self.statusCode = statusCode
        self.data = data
    }
}

public struct TermsConditionsDataModel: Codable {
    public let header: String?
    public let subHeader: String?
    public let file: String?
    public let svgLogoUrl: String?
    public let nextButtonTitle: String?
    public let confirmationRequired: Bool?
    public let isNormalClick: Bool

    public init(header: String?,
                subHeader: String?,
                file: String?,
                svgLogoUrl: String?,
                nextButtonTitle: String?,
                confirmationRequired: Bool?,
                isNormalClick: Bool
    ) {
        self.header = header
        self.subHeader = subHeader
        self.file = file
        self.svgLogoUrl = svgLogoUrl
        self.nextButtonTitle = nextButtonTitle
        self.confirmationRequired = confirmationRequired
        self.isNormalClick = isNormalClick
    }
}
