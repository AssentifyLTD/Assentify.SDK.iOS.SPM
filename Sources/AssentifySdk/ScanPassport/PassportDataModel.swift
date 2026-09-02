
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
    
    
    
    
    static func fromOutputProperties(passportImageUrl: String,transformedProperties: [String: String]  ,stepOutputProperties: [OutputProperties],
                                     mrzInfo: [String: Any]) -> PassportExtractedModel? {
        
        

         var faces: [String] = []
         let imageUrl = passportImageUrl
        let outputProperties = buildOutputProperties(imageUrl: imageUrl, stepOutputProperties: stepOutputProperties, mrzResult: mrzInfo)
        
        
        var transformedPropertiesResult: [String: String] = [:];
        
        if(transformedProperties.isEmpty){
            outputProperties.forEach { (key, value) in
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
    
    
    static func buildOutputProperties(
        imageUrl: String,
        stepOutputProperties: [OutputProperties],
        mrzResult: [String: Any]
    ) -> [String: Any] {

        var outputPropertiesResult: [String: Any] = [:]

        stepOutputProperties.forEach { property in
            let key = property.key

            switch true {
            case key.contains(MrzKeys.KEY_FIRST_NAME):
                outputPropertiesResult[key] = mrzResult[MrzKeys.KEY_FIRST_NAME] ?? ""
            case key.contains(MrzKeys.KEY_LAST_NAME):
                outputPropertiesResult[key] = mrzResult[MrzKeys.KEY_LAST_NAME] ?? ""
            case key.contains(MrzKeys.KEY_BIRTH_DATE):
                outputPropertiesResult[key] = mrzResult[MrzKeys.KEY_BIRTH_DATE] ?? ""
            case key.contains(MrzKeys.KEY_DOCUMENT_NUMBER):
                outputPropertiesResult[key] = mrzResult[MrzKeys.KEY_DOCUMENT_NUMBER] ?? ""
            case key.contains(MrzKeys.KEY_SEX):
                outputPropertiesResult[key] = mrzResult[MrzKeys.KEY_SEX] ?? ""
            case key.contains(MrzKeys.KEY_EXPIRY_DATE):
                outputPropertiesResult[key] = mrzResult[MrzKeys.KEY_EXPIRY_DATE] ?? ""
            case key.contains(MrzKeys.KEY_COUNTRY):
                outputPropertiesResult[key] = mrzResult[MrzKeys.KEY_COUNTRY] ?? ""
            case key.contains(MrzKeys.KEY_NATIONALITY):
                outputPropertiesResult[key] = mrzResult[MrzKeys.KEY_COUNTRY] ?? ""
            case key.contains("IdentificationDocumentCapture_IDType"):
                outputPropertiesResult[key] = "Passport"
            case key.contains("OnBoardMe_IdentificationDocumentCapture_Image"):
                outputPropertiesResult[key] = imageUrl
            case key.contains(MrzKeys.KEY_DOCUMENT_TYPE):
                outputPropertiesResult[key] = "Passport"
            default:
                outputPropertiesResult[key] = ""
            }
        }

        return outputPropertiesResult
    }

}
