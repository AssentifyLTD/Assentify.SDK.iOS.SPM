import Foundation
@objc public class FaceResponseModel : NSObject  {
    public  var destinationEndpoint: String?
    public  var faceExtractedModel: FaceExtractedModel?
    public  var error: String?
    public  var success: Bool?
    
    init(destinationEndpoint: String? = nil, faceExtractedModel: FaceExtractedModel? = nil, error: String? = nil, success: Bool? = nil) {
        self.destinationEndpoint = destinationEndpoint
        self.faceExtractedModel = faceExtractedModel
        self.error = error
        self.success = success
    }
    
}



@objc public class FaceExtractedModel : NSObject  {
    public var outputProperties: [String: Any]?
    public var extractedData: [String: Any]?
    public var baseImageFace :String?
    public var secondImageFace:String?
    public var percentageMatch:Int?;
    public var isLive:Bool?;
    
    public var identificationDocumentCapture: IdentificationDocumentCapture?

    init(outputProperties: [String: Any]? = nil, extractedData: [String: Any]? = nil,
         baseImageFace: String? = nil,
         secondImageFace: String? = nil,
         percentageMatch: Int? = nil,
         isLive: Bool? = nil,
         identificationDocumentCapture:IdentificationDocumentCapture) {
        self.outputProperties = outputProperties
        self.extractedData = extractedData
        self.baseImageFace = baseImageFace
        self.secondImageFace = secondImageFace
        self.percentageMatch = percentageMatch
        self.isLive = isLive
    
        self.identificationDocumentCapture = identificationDocumentCapture
    }
    
    static func fromJsonString(responseString: String) -> FaceExtractedModel? {
        guard let responseData = responseString.data(using: .utf8),
              let response = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] else {
            return nil
        }

        let baseImageFaceObject = response["BaseImageFace"] as? [String: Any] ?? [:]
        let secondImageFaceObject = response["SecondImageFace"] as? [String: Any] ?? [:]

        let baseImageFace = baseImageFaceObject["FaceUrl"] as? String
        let secondImageFace = secondImageFaceObject["FaceUrl"] as? String

        var percentageMatch: Int?
        if let percentage = response["PercentageMatch"] as? Double {
            percentageMatch = Int(percentage)
        }

        let isLive = response["IsLive"] as? Bool

        let outputProperties = response["OutputProperties"] as? [String: Any] ?? [:]
        var extractedData: [String: Any] = [:]
        
        outputProperties.forEach { (key, value) in
            let keys = key.split(separator: "_").map { String($0) }
            let newKey = key.components(separatedBy: "FaceImageAcquisition_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
            extractedData[newKey] = value
        }
        
        

        var  identificationDocumentCapture = fillIdentificationDocumentCapture(outputProperties:outputProperties )
        return FaceExtractedModel(outputProperties: outputProperties,
                                  extractedData: extractedData,
                                  baseImageFace: baseImageFace,
                                  secondImageFace: secondImageFace,
                                  percentageMatch: percentageMatch,
                                  isLive: isLive, 
                                  identificationDocumentCapture: identificationDocumentCapture)
    }

}
