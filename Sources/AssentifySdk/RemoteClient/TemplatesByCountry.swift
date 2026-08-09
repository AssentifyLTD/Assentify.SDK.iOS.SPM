//
//  TemplatesByCountry.swift
//  AssentifyDemoApp
//
//  Created by TariQ on 21/02/2024.
//

import Foundation



public struct TemplatesByCountry :Codable{
    public  let id: Int
    public  let name: String
    public  let sourceCountryCode: String
    public  let flag: String
    public  let templates: [Templates]
}

public struct KycDocumentDetails : Codable {
    public let name: String
    public let order: Int
    public let templateProcessingKeyInformation: String
    public let templateSpecimen: String
    public let hasQrCode: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        order = try container.decode(Int.self, forKey: .order)
        templateProcessingKeyInformation = try container.decode(String.self, forKey: .templateProcessingKeyInformation)
        templateSpecimen = try container.decode(String.self, forKey: .templateSpecimen)
        hasQrCode = try container.decodeIfPresent(Bool.self, forKey: .hasQrCode) ?? false
    }

    public init(name: String, order: Int, templateProcessingKeyInformation: String, templateSpecimen: String, hasQrCode: Bool) {
        self.name = name
        self.order = order
        self.templateSpecimen = templateSpecimen
        self.templateProcessingKeyInformation = templateProcessingKeyInformation
        self.hasQrCode = hasQrCode
    }
}

public struct Templates : Codable {
    public let id: Int
    public let sourceCountryFlag: String
    public let sourceCountryCode: String
    public let kycDocumentType: String
    public let sourceCountry: String
    public let kycDocumentDetails: [KycDocumentDetails]
}



public func encodeTemplatesByCountryToJson(data: [TemplatesByCountry]) -> String {
    let encoder = JSONEncoder()
    do {
        let jsonData = try encoder.encode(data)
        return String(data: jsonData, encoding: .utf8) ?? ""
    } catch {
        return "\(error.localizedDescription)"
    }
}




