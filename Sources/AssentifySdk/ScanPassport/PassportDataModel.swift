
import Foundation
@objc public class PassportResponseModel : NSObject  {
    public  var destinationEndpoint: String?
    public  var passportExtractedModel: PassportExtractedModel?
    public  var error: String?
    public  var success: Bool?
    
    init(destinationEndpoint: String? = nil, passportExtractedModel: PassportExtractedModel? = nil, error: String? = nil, success: Bool? = nil) {
        self.destinationEndpoint = destinationEndpoint
        self.passportExtractedModel = passportExtractedModel
        self.error = error
        self.success = success
    }
    
}



@objc public class PassportExtractedModel : NSObject  {
    public var outputProperties: [String: Any]?
    public var transformedProperties: [String: String]?
    public var extractedData: [String: Any]?
    public var imageUrl: String?
    public var faces: [String]?
    public var identificationDocumentCapture: IdentificationDocumentCapture?

    init(outputProperties: [String: Any]? = nil,transformedProperties: [String: String]?, extractedData: [String: Any]? = nil, imageUrl: String? = nil, faces: [String]? = nil,identificationDocumentCapture:IdentificationDocumentCapture) {
        self.outputProperties = outputProperties
        self.extractedData = extractedData
        self.imageUrl = imageUrl
        self.faces = faces
        self.identificationDocumentCapture = identificationDocumentCapture
        self.transformedProperties = transformedProperties
    }
    
   static func fromJsonString(responseString: String,transformedProperties: [String: String]) -> PassportExtractedModel? {
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
       
       
       var transformedPropertiesResult: [String: String] = [:];
       
       if(transformedProperties.isEmpty){
           outputProperties?.forEach { (key, value) in
             transformedPropertiesResult[key] =  "\(value)"
           }
       }else{
           transformedPropertiesResult = transformedProperties;
       }
       
       var extractedData: [String: Any] = [:]
       transformedPropertiesResult.forEach { (key, value) in
           let keys = key.split(separator: "_").map { String($0) }
           let newKey = key.components(separatedBy: "IdentificationDocumentCapture_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
           extractedData[newKey] = value
       }
       
       
        var  identificationDocumentCapture = fillIdentificationDocumentCapture(outputProperties:outputProperties )
       return PassportExtractedModel(outputProperties: outputProperties,transformedProperties: transformedPropertiesResult, extractedData: extractedData, imageUrl: imageUrl, faces: faces,identificationDocumentCapture:identificationDocumentCapture)
    }

}
