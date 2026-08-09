
import Foundation
@objc public class RemoteProcessingModel : NSObject , Codable {
    public  var destinationEndpoint: String?
    public  var response: String?
    public  var error: String?
    public  var success: Bool?
    public  var classifiedTemplate: String?
    public var responseJsonObject: [String: AnyCodable]?
    
    init(destinationEndpoint: String? = nil, response: String? = nil, error: String? = nil, success: Bool? = nil,classifiedTemplate: String? = "", responseJsonObject: [String: AnyCodable]? = nil) {
        self.destinationEndpoint = destinationEndpoint
        self.response = response
        self.error = error
        self.success = success
        self.classifiedTemplate = classifiedTemplate
        self.responseJsonObject = responseJsonObject
    }
    
}

public func parseDataToRemoteProcessingModel(data: [String: Any]) -> RemoteProcessingModel {
    var success = false;
    var response = "";
    if let boolValue = data["success"] as? Bool {
            success = boolValue;
    }
    if let dictionaryResponse =  data["response"] as? [String: Any] {
        if let jsonString = dictionaryToString(dictionaryResponse) {
            response = jsonString
        }
    }
    return RemoteProcessingModel(
        destinationEndpoint: data["destinationEndpoint"] as? String ,
        response:response,
        error: data["error"] as? String ,
        success: success,
        classifiedTemplate: data["classifiedTemplate"] as? String ,
    )
}


public func dictionaryToString(_ dictionary: [String: Any]) -> String? {
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        let jsonString = String(data: jsonData, encoding: .utf8)
        return jsonString
    } catch {
        return nil
    }
}

func getImageUrlFromBaseResponseDataModel(jsonString: String?) -> String {
    
    guard
        let jsonString = jsonString,
        !jsonString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        let data = jsonString.data(using: .utf8)
    else {
        return ""
    }

    do {
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json["ImageUrl"] as? String ?? ""
        }
    } catch {
        return ""
    }

    return ""
}






