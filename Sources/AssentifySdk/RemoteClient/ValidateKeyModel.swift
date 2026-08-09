
import Foundation

public struct ValidateKeyModel: Codable {
    public let message: String?
    public let statusCode: Int
    public let error: String?
    public let errorCode: String?
    public let data: DataResponse
    public let isSuccessful: Bool
    
    enum CodingKeys: String, CodingKey {
        case message
        case statusCode
        case error
        case errorCode
        case data
        case isSuccessful
    }
    
    public struct DataResponse: Codable {
        public  let tenantIdentifier: String
        public let key: String
    }
}
