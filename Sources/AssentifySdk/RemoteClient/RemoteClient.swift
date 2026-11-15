
import Foundation

public enum BaseResult<Success, Failure: Error> {
    case success(Success)
    case failure(Failure)
}




func initializeCheck(
    pathContentHash: String,
    queryContentHash: String,
    tenantIdentifier: String,
    blockIdentifier: String,
    instanceId: String,
    sourceAgent: String,
    apiKey: String,
    language: String,
    completion: @escaping (BaseResult<String, Error>) -> Void
) {
    let urlString = BaseUrls.baseURLGateway + "v1/Manager/Initialize/\(pathContentHash)/check?contentHash=\(queryContentHash)&language=\(language)"
    
  
    guard let url = URL(string: urlString) else {
        completion(.failure(NSError(domain: "Invalid URL", code: 0)))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(tenantIdentifier, forHTTPHeaderField: "x-tenant-identifier")
    request.setValue(blockIdentifier,  forHTTPHeaderField: "x-block-identifier")
    request.setValue(instanceId,       forHTTPHeaderField: "x-instance-id")
    request.setValue(sourceAgent,      forHTTPHeaderField: "x-source-agent")
    request.setValue(apiKey,           forHTTPHeaderField: "X-Api-Key")
    
    
//    print("🌐 URL: \(request.url?.absoluteString ?? "nil")")
//    print("📋 Headers:")
    request.allHTTPHeaderFields?.forEach { key, value in
        print("   \(key): \(value)")
    }
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        
//        if let data = data, let responseString = String(data: data, encoding: .utf8) {
//            print("📦 Response Body:\n\(responseString)")
//        }
        
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(NSError(domain: "Invalid response", code: 0)))
            return
        }
        
        guard httpResponse.statusCode == 200, let data = data else {
            completion(.failure(NSError(domain: "HTTP Error", code: httpResponse.statusCode)))
            return
        }
        
        guard let bodyString = String(data: data, encoding: .utf8) else {
            completion(.failure(NSError(domain: "No data", code: 0)))
            return
        }
        
        completion(.success(bodyString))
    }.resume()
}








func  remoteCreateUserDocumentInstance(
    tenantIdentifier:String,
    requestBody: CreateUserDocumentRequestModel,completion: @escaping (BaseResult<CreateUserDocumentResponseModel, Error>) -> Void) {
        let urlString = BaseUrls.baseURLSigning + "Document/v2/CreateUserDocumentInstance"
        guard let url = URL(string: urlString) else {
            completion(BaseResult.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        guard let jsonData = try? JSONEncoder().encode(requestBody) else {
            completion(.failure(NSError(domain: "Failed to encode request body", code: 0, userInfo: nil)))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(tenantIdentifier, forHTTPHeaderField: "x-tenant-identifier")
        request.httpBody = jsonData
        
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            guard let httpResponse = response as? HTTPURLResponse else {
                
                completion(BaseResult.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
                return
            }
            
            if(httpResponse.statusCode == 200){
                guard let responseData = data else {
                    completion(BaseResult.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
                    return
                }
                if let responseString = String(data: responseData, encoding: .utf8) {
                }
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(CreateUserDocumentResponseModel.self, from: responseData)
                    completion(BaseResult.success(result))
                } catch {
                    completion(BaseResult.failure(error))
                }
            }
            
            
        }
        task.resume()
        
    }

func  remoteSignature(
    tenantIdentifier:String,
    requestBody: SignatureRequestModel,completion: @escaping (BaseResult<SignatureResponseModel, Error>) -> Void) {
        let urlString = BaseUrls.baseURLSigning + "Signature"
        guard let url = URL(string: urlString) else {
            completion(BaseResult.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        guard let jsonData = try? JSONEncoder().encode(requestBody) else {
            completion(.failure(NSError(domain: "Failed to encode request body", code: 0, userInfo: nil)))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(tenantIdentifier, forHTTPHeaderField: "x-tenant-identifier")
        request.httpBody = jsonData
        
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            guard let httpResponse = response as? HTTPURLResponse else {
                
                completion(BaseResult.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
                return
            }
            
            if(httpResponse.statusCode == 200){
                guard let responseData = data else {
                    completion(BaseResult.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
                    return
                }
                if let responseString = String(data: responseData, encoding: .utf8) {
                }
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(SignatureResponseModel.self, from: responseData)
                    completion(BaseResult.success(result))
                } catch {
                    completion(BaseResult.failure(error))
                }
            }
            
            
        }
        task.resume()
        
    }

func remoteSubmitData(apiKey: String,
                      configModel: ConfigModel,
                      submitRequestModel: [SubmitRequestModel],
                      completion: @escaping (BaseResult<Bool, Error>) -> Void) {
    let urlString = BaseUrls.baseURLGateway + "v1/Manager/Submit"
    guard let url = URL(string: urlString) else {
        let error = NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        completion(BaseResult.failure(error))
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
    request.setValue("SDK", forHTTPHeaderField: "X-Source-Agent")
    request.setValue(configModel.flowInstanceId, forHTTPHeaderField: "X-Flow-Instance-Id")
    request.setValue(configModel.tenantIdentifier, forHTTPHeaderField: "X-Tenant-Identifier")
    request.setValue(configModel.blockIdentifier, forHTTPHeaderField: "X-Block-Identifier")
    request.setValue(configModel.instanceId, forHTTPHeaderField: "X-Instance-Id")
    request.setValue(configModel.flowIdentifier, forHTTPHeaderField: "X-Flow-Identifier")
    request.setValue(configModel.instanceHash, forHTTPHeaderField: "X-Instance-Hash")
    
    do {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        let jsonData = try jsonEncoder.encode(submitRequestModel)
        request.httpBody = jsonData
        
        
        // Log request details
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            BugsnagObject.logInfo(message: "Data submission started. \(jsonString)", configModel:configModel)
            
        }
    } catch {
        completion(BaseResult.failure(error))
        return
    }
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            BugsnagObject.logInfo(message: "Data submission failed: \(error)", configModel:configModel)
            completion(BaseResult.failure(error))
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            let error = NSError(domain: "Invalid response", code: 0, userInfo: nil)
            BugsnagObject.logInfo(message: "Data submission failed: \(error)", configModel:configModel)
            completion(BaseResult.failure(error))
            return
        }
        
        // Log response details
        if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
            if(!responseString.isEmpty){
                BugsnagObject.logInfo(message: "Data submission Response Data: \(responseString)", configModel:configModel)
            }
        } else {
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
            BugsnagObject.logInfo(message: "Data submission success", configModel:configModel)
            completion(BaseResult.success(true))
        } else {
            let error = NSError(domain: "Server error", code: httpResponse.statusCode, userInfo: nil)
            BugsnagObject.logInfo(message: "Data submission failed \(error)", configModel:configModel)
            completion(BaseResult.failure(error))
        }
    }
    task.resume()
}



func transformData(apiKey: String, language: String, request: TransformationModel, completion: @escaping (BaseResult<[LanguageTransformationModel], Error>) -> Void) {
    let urlString = BaseUrls.languageTransformationUrl + "LanguageTransform/LanguageTransformation"
    guard let url = URL(string: urlString) else {
        completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
        return
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
    urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    urlRequest.setValue(language, forHTTPHeaderField: "accept-language")

    do {
        urlRequest.httpBody = try JSONEncoder().encode(request)
    } catch {
        completion(.failure(error))
        return
    }

    let task = BlobSession.shared.dataTask(with: urlRequest) { data, response, error in
        if let error = error {
            completion(.failure(error))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            completion(.failure(NSError(domain: "Invalid response",
                                        code: httpResponse.statusCode,
                                        userInfo: [NSLocalizedDescriptionKey: message])))
            return
        }

        guard let data = data, !data.isEmpty else {
            completion(.failure(NSError(domain: "No data", code: httpResponse.statusCode, userInfo: nil)))
            return
        }

        do {
            let result = try JSONDecoder().decode([LanguageTransformationModel].self, from: data)
            completion(.success(result))
        } catch {
            completion(.failure(error))
        }
    }
    task.resume()
}



enum WidgetsApiError: LocalizedError {
    case invalidURL
    case invalidResponse
    case http(Int)
    case emptyBody

    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "Invalid URL"
        case .invalidResponse:   return "Invalid response"
        case .http(let code):    return "HTTP Error (\(code))"
        case .emptyBody:         return "No data"
        }
    }
}

struct WidgetsHeaders {
    let blockIdentifier: String
    let flowIdentifier: String
    let flowInstanceId: String
    let instanceHash: String
    let instanceId: String
    let tenantIdentifier: String
}

func compareFacesByHash(
    headers: WidgetsHeaders,
    body: CompareFacesRequest,
    completion: @escaping (BaseResult<CompareFacesResponse, Error>) -> Void
) {
    // TODO: exact path from @POST on RemoteWidgetsService.compareFacesByHash
    postWidgets(path: "v3/api/IdentificationDocument/CompareFaces", headers: headers, body: body, completion: completion)
}

func identityMatch(
    headers: WidgetsHeaders,
    body: IdentityMatchRequest,
    completion: @escaping (BaseResult<IdentityMatchResponse, Error>) -> Void
) {
    // TODO: exact path from @POST on RemoteWidgetsService.identityMatch
    postWidgets(path: "api/IdentificationDocument/IdentityMatch", headers: headers, body: body, completion: completion)
}

private func postWidgets<Body: Encodable, Response: Decodable>(
    path: String,
    headers: WidgetsHeaders,
    body: Body,
    completion: @escaping (BaseResult<Response, Error>) -> Void
) {
    // TODO: use the base URL behind RemoteClient.remoteWidgetsService on Android
    guard let url = URL(string: BaseUrls.signalRHub + path) else {
        completion(.failure(WidgetsApiError.invalidURL))
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json",       forHTTPHeaderField: "Content-Type")
    request.setValue(headers.blockIdentifier,  forHTTPHeaderField: "x-block-identifier")
    request.setValue(headers.flowIdentifier,   forHTTPHeaderField: "x-flow-identifier")
    request.setValue(headers.flowInstanceId,   forHTTPHeaderField: "x-flow-instance-id")
    request.setValue(headers.instanceHash,     forHTTPHeaderField: "x-instance-hash")
    request.setValue(headers.instanceId,       forHTTPHeaderField: "x-instance-id")
    request.setValue(headers.tenantIdentifier, forHTTPHeaderField: "x-tenant-identifier")

    do {
        request.httpBody = try JSONEncoder().encode(body)
    } catch {
        completion(.failure(error))
        return
    }

    

    URLSession.shared.dataTask(with: request) { data, response, error in
       

        if let error = error {
            completion(.failure(error))
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(WidgetsApiError.invalidResponse))
            return
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            completion(.failure(WidgetsApiError.http(httpResponse.statusCode)))
            return
        }
        guard let data = data, !data.isEmpty else {
            completion(.failure(WidgetsApiError.emptyBody))
            return
        }
        do {
            completion(.success(try JSONDecoder().decode(Response.self, from: data)))
        } catch {
            #if DEBUG
            print("❌ [Widgets] Decoding \(Response.self) failed: \(error)")
            #endif
            completion(.failure(error))
        }
    }.resume()
}

/// Pretty-prints JSON data; falls back to a raw UTF-8 string if it isn't valid JSON.
private func prettyJSON(_ data: Data?) -> String {
    guard let data = data, !data.isEmpty else { return "<empty>" }
    if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
       let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
       let string = String(data: pretty, encoding: .utf8) {
        return string
    }
    return String(data: data, encoding: .utf8) ?? "<\(data.count) bytes, non-UTF8>"
}


