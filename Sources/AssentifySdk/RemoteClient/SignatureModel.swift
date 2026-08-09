

import Foundation

public struct SignatureRequestModel:Codable {
    public   let documentId: Int
    public   let documentInstanceId: Int
    public   let documentName: String
    public   let username: String
    public   let requiresAdditionalData: Bool
    public   let signature: String
    public   var signerName: String?
    public   var otpCode: String?
    public   var otpLine: String?
    public   var deviceLine: String?
    public   var hasOtp: Bool?
    public   var signerContact: String?
    public   var enableVisualVerifier: Bool?
    public   var faceImageUrl: String?



}

public struct SignatureResponseModel:Codable {
    public   let signedDocument: String
    public   let fileName: String
    public   let signedDocumentUri: String
}
