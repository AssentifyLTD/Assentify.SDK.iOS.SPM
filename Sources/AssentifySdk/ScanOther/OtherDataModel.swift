
import Foundation
@objc public class OtherResponseModel : NSObject  {
    public  var destinationEndpoint: String?
    public  var otherExtractedModel: OtherExtractedModel?
    public  var error: String?
    public  var success: Bool?
    
    init(destinationEndpoint: String? = nil, otherExtractedModel: OtherExtractedModel? = nil, error: String? = nil, success: Bool? = nil) {
        self.destinationEndpoint = destinationEndpoint
        self.otherExtractedModel = otherExtractedModel
        self.error = error
        self.success = success
    }
    
}



@objc public class OtherExtractedModel : NSObject  {
    public var outputProperties: [String: Any]?
    public var transformedProperties: [String: String]?
    public var extractedData: [String: Any]?
    public var additionalDetails: [String: Any]?
    public var transformedDetails: [String: String]?
    public var imageUrl: String?
    public var faces: [String]?
    public var identificationDocumentCapture: IdentificationDocumentCapture?

    init(outputProperties: [String: Any]? = nil,transformedProperties: [String: String]?, extractedData: [String: Any]? = nil,additionalDetails: [String: Any]? = nil ,transformedDetails: [String: String]?, imageUrl: String? = nil, faces: [String]? = nil,identificationDocumentCapture:IdentificationDocumentCapture) {
        self.outputProperties = outputProperties
        self.extractedData = extractedData
        self.imageUrl = imageUrl
        self.faces = faces
        self.identificationDocumentCapture = identificationDocumentCapture
        self.additionalDetails = additionalDetails
        self.transformedProperties = transformedProperties
        self.transformedDetails = transformedDetails
    }
    
   static func fromJsonString(responseString: String,transformedProperties: [String: String],transformedDetails: [String: String]) -> OtherExtractedModel? {
        guard let  responseData = responseString.data(using: .utf8),
              let response = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] else {
            return nil
        }

        var faces: [String] = []
        if let faceArray = response["faces"] as? [[String: Any]] {
            for face in faceArray {
                if let faceUrl = face["FaceUrl"] as? String {
                    faces.append(faceUrl)
                }
            }
        }

        let imageUrl = response["ImageUrl"] as? String
        let outputProperties = response["OutputProperties"] as? [String: Any]
        let additionalDetails = response["AdditionalDetails"] as? [String: Any]
        
     
        var  identificationDocumentCapture = fillIdentificationDocumentCapture(outputProperties:outputProperties )
       
       var transformedPropertiesResult: [String: String] = [:];
       
       if(transformedProperties.isEmpty){
           outputProperties?.forEach { (key, value) in
             transformedPropertiesResult[key] =  "\(value)"
           }
       }else{
           transformedPropertiesResult = transformedProperties;
       }
       
       var transformedDetailsResult: [String: String] = [:];
       
       if(transformedDetails.isEmpty){
           additionalDetails?.forEach { (key, value) in
               transformedDetailsResult[key] =  "\(value)"
           }
       }else{
           transformedDetailsResult = transformedDetails;
       }
       
       var extractedData: [String: Any] = [:]
       transformedPropertiesResult.forEach { (key, value) in
           let keys = key.split(separator: "_").map { String($0) }
           let newKey = key.components(separatedBy: "IdentificationDocumentCapture_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
           extractedData[newKey] = value
       }
       
       
       return OtherExtractedModel(outputProperties: outputProperties,transformedProperties:transformedPropertiesResult  ,extractedData: extractedData,additionalDetails:additionalDetails,transformedDetails: transformedDetailsResult, imageUrl: imageUrl, faces: faces,identificationDocumentCapture:identificationDocumentCapture)
    }

}
