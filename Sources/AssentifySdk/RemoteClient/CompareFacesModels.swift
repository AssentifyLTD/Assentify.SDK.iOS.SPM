

import Foundation

public struct CompareFacesRequest: Codable {
    let sourceImageHash: String
    let targetImageHash: String

    enum CodingKeys: String, CodingKey {
        case sourceImageHash = "SourceImageHash"
        case targetImageHash = "TargetImageHash"
    }
}

public struct CompareFacesResponse: Codable {
    let scanStatus: String?
    let status: Int?
    let matchScore: Int?
    let isLive: Bool?
    let error: String?
}
