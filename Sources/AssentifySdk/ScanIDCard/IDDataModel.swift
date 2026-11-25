import Foundation
@objc public class IDResponseModel : NSObject  {
    public  var destinationEndpoint: String?
    public  var iDExtractedModel: IDExtractedModel?
    public  var error: String?
    public  var success: Bool?
    
    init(destinationEndpoint: String? = nil, iDExtractedModel: IDExtractedModel? = nil, error: String? = nil, success: Bool? = nil) {
        self.destinationEndpoint = destinationEndpoint
        self.iDExtractedModel = iDExtractedModel
        self.error = error
        self.success = success
    }
    
}



@objc public class IDExtractedModel : NSObject  {
    public var outputProperties: [String: Any]?
    public var transformedProperties: [String: String]?
    public var extractedData: [String: Any]?
    public var imageUrl: String?
    public var faces: [String]?
    public var identificationDocumentCapture: IdentificationDocumentCapture?
    public var barcodeOcrChecked: Bool?
    public var barcodeOcrMismatch: Bool?

    init(outputProperties: [String: Any]? = nil, transformedProperties: [String: String],extractedData: [String: Any]? = nil, imageUrl: String? = nil, faces: [String]? = nil,identificationDocumentCapture:IdentificationDocumentCapture,barcodeOcrChecked: Bool?,barcodeOcrMismatch: Bool?) {
        self.outputProperties = outputProperties
        self.extractedData = extractedData
        self.imageUrl = imageUrl
        self.faces = faces
        self.identificationDocumentCapture = identificationDocumentCapture
        self.transformedProperties = transformedProperties
        self.barcodeOcrChecked = barcodeOcrChecked
        self.barcodeOcrMismatch = barcodeOcrMismatch
    }
    
   static func fromJsonString(responseString: String,transformedProperties: [String: String]) -> IDExtractedModel? {
        guard let  responseData = responseString.data(using: .utf8),
              let response = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] else {
            return nil
        }
       
       let barcodeOcrChecked = response["barcode_ocr_checked"] as? Bool?
       let barcodeOcrMismatch = response["barcode_ocr_mismatch"] as? Bool?

        var faces: [String] = []
        if let faceArray = response["faces"] as? [[String: Any]] {
            for face in faceArray {
                if let faceUrl = face["FaceUrl"] as? String {
                    faces.append(faceUrl)
                }
            }
        }

        let imageUrl = response["IdCardImageUrl"] as? String
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
       return IDExtractedModel(outputProperties: outputProperties,transformedProperties:transformedPropertiesResult, extractedData: extractedData, imageUrl: imageUrl, faces: faces,identificationDocumentCapture:identificationDocumentCapture,barcodeOcrChecked: barcodeOcrChecked ?? false , barcodeOcrMismatch : barcodeOcrMismatch ?? false)
    }

}
