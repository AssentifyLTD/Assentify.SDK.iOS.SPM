

import Foundation

class RemoteProcessing {
    
    enum BaseResult<Success, Failure: Error> {
        case success(Success)
        case failure(Failure)
    }
    
    
    private var delegate: RemoteProcessingDelegate?
    
    private let eventNames: [String] = [
        HubConnectionTargets.ON_ERROR,
        HubConnectionTargets.ON_RETRY,
        HubConnectionTargets.ON_CLIP_PREPARATION_COMPLETE,
        HubConnectionTargets.ON_STATUS_UPDATE,
        HubConnectionTargets.ON_UPDATE,
        HubConnectionTargets.ON_LIVENESS_UPDATE,
        HubConnectionTargets.ON_COMPLETE,
        HubConnectionTargets.ON_CARD_DETECTED,
        HubConnectionTargets.ON_MRZ_EXTRACTED,
        HubConnectionTargets.ON_MRZ_DETECTED,
        HubConnectionTargets.ON_NO_MRZ_EXTRACTED,
        HubConnectionTargets.ON_FACE_DETECTED,
        HubConnectionTargets.ON_NO_FACE_DETECTED,
        HubConnectionTargets.ON_FACE_EXTRACTED,
        HubConnectionTargets.ON_QUALITY_CHECK_AVAILABLE,
        HubConnectionTargets.ON_DOCUMENT_CAPTURED,
        HubConnectionTargets.ON_DOCUMENT_CROPPED,
        HubConnectionTargets.ON_UPLOAD_FAILED
    ]
    
    
     
    
         
    
    
    func starProcessingFace(
        url: String,
        appConfiguration: ConfigModel,
        stepIdString: String,
        selfieImage: Data,
        livenessFrames:  [Data],
        secondImage:Data,
        isLivenessEnabled:Bool,
        retryCount: Int,
        isManualCapture: Bool,
        isAutoCapture: Bool,
        connectionId: String,
        onProgress: ((Double) -> Void)? = nil,
        completion: @escaping (BaseResult<RemoteProcessingModel?, Error>) -> Void
        
    ) {
        let traceIdentifier = UUID().uuidString
        let urlString = url
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        
        
        
        request.setValue(stepIdString, forHTTPHeaderField: "x-step-id")
        request.setValue(appConfiguration.blockIdentifier, forHTTPHeaderField: "x-block-identifier")
        request.setValue(appConfiguration.flowIdentifier, forHTTPHeaderField: "x-flow-identifier")
        request.setValue(appConfiguration.flowInstanceId, forHTTPHeaderField: "x-flow-instance-id")
        request.setValue(appConfiguration.instanceHash, forHTTPHeaderField: "x-instance-hash")
        request.setValue(appConfiguration.instanceId, forHTTPHeaderField: "x-instance-id")
        request.setValue(appConfiguration.tenantIdentifier, forHTTPHeaderField: "x-tenant-identifier")
        
        
        
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        
        
        let tryNumber = retryCount+1;
        var formData : [String: Any]  = [
            "tenantId": appConfiguration.tenantIdentifier,
            "blockId": appConfiguration.blockIdentifier,
            "instanceId": appConfiguration.instanceId,
            "isMobile": true,
            "IsLivenessEnabled": isLivenessEnabled,
            "callerConnectionId": connectionId,
            "IsManualCapture":String(isManualCapture),
            "IsAutoCapture":String(isAutoCapture),
            "TryNumber":String(tryNumber),
            "traceIdentifier": traceIdentifier,
        ]
        
        
        
        var files: [(name: String, filename: String, mimeType: String, data: Data)] = [
            ("selfieImage", "selfieImage.jpg", "image/jpeg", selfieImage),
            ("secondImage", "secondImage.jpg", "image/jpeg", secondImage)
        ]
        
        if !livenessFrames.isEmpty {
            files += datasToMultipartFiles(
                livenessFrames,
                partName: "livenessFrames",
                filePrefix: "frame",
                mimeType: "image/jpeg"
            )
        }
        
        
        let body = createMultipartBodyFace(
            parameters: formData,
            files: files,
            boundary: boundary
        )
      
        let delegate = UploadDelegate()
        delegate.onProgress = { progress in
            onProgress!(progress)
            
        }
        
        
      
        
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
        
        let task = session.uploadTask(with: request, from: body) { data, response, error in
            session.finishTasksAndInvalidate()
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
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
                    if let dictionary = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
                        let dataResult =  parseDataToRemoteProcessingModel(data: dictionary);
                        completion(BaseResult.success(dataResult))
                    } else {
                    }
                    
                    
                } catch {
                    completion(BaseResult.failure(error))
                }
            }else{
                completion(BaseResult.failure(NSError(domain: "Invalid Key", code: 0, userInfo: nil)))
            }
        }
        
        task.resume()
    }
    
    
    func createMultipartBodyFace(
        parameters: [String: Any],
        files: [(name: String, filename: String, mimeType: String, data: Data)],
        boundary: String
    ) -> Data {
        var body = Data()
        
        for (key, value) in parameters {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        for file in files {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n")
            body.append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            body.append("\r\n")
        }
        
        body.append("--\(boundary)--\r\n")
        return body
    }
    
    private func datasToMultipartFiles(
        _ datas: [Data],
        partName: String,
        filePrefix: String,
        mimeType: String
    ) -> [(name: String, filename: String, mimeType: String, data: Data)] {
        return datas.enumerated().map { index, data in
            let fileName = "\(filePrefix)_\(index).jpg"
            return (name: partName, filename: fileName, mimeType: mimeType, data: data)
        }
    }
    
    
    
    func starQrProcessing(
        url: String,
        image: Data,
        appConfiguration: ConfigModel,
        templatesByCountry : [String],
        connectionId: String,
        stepIdString: String,
        metadata: String,
        isManualCapture: Bool,
        isAutoCapture: Bool,
        onProgress: ((Double) -> Void)? = nil,
        completion: @escaping (BaseResult<RemoteProcessingModel?, Error>) -> Void
    ) {
        let traceIdentifier = UUID().uuidString
        let urlString = url
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        
        
        
        request.setValue(stepIdString, forHTTPHeaderField: "x-step-id")
        request.setValue(appConfiguration.blockIdentifier, forHTTPHeaderField: "x-block-identifier")
        request.setValue(appConfiguration.flowIdentifier, forHTTPHeaderField: "x-flow-identifier")
        request.setValue(appConfiguration.flowInstanceId, forHTTPHeaderField: "x-flow-instance-id")
        request.setValue(appConfiguration.instanceHash, forHTTPHeaderField: "x-instance-hash")
        request.setValue(appConfiguration.instanceId, forHTTPHeaderField: "x-instance-id")
        request.setValue(appConfiguration.tenantIdentifier, forHTTPHeaderField: "x-tenant-identifier")
        
        
        
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        
        
        var formData :[String : String] = [
            "tenantId": appConfiguration.tenantIdentifier,
            "blockId": appConfiguration.blockIdentifier,
            "instanceId": appConfiguration.instanceId,
            "isMobile": "true",
            "callerConnectionId": connectionId,
            "Metadata": metadata,
            "traceIdentifier": appConfiguration.tenantIdentifier,
            "IsManualCapture": String(isManualCapture),
            "IsAutoCapture": String(isAutoCapture),
        ]
        
        
        
        let body = createMultipartBody(
            parameters: formData,
            templateIds: templatesByCountry,
            files: [
                ("Image", "image.jpg", "image/jpeg", image)
            ],
            boundary: boundary
        )
        
        
        let delegate = UploadDelegate()
        delegate.onProgress = { progress in
            onProgress!(progress)
            
        }
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
        
        let task = session.uploadTask(with: request, from: body) { data, response, error in
            session.finishTasksAndInvalidate()
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
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
                    if let dictionary = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
                        let dataResult =  parseDataToRemoteProcessingModel(data: dictionary);
                        completion(BaseResult.success(dataResult))
                    } else {
                    }
                    
                    
                } catch {
                    completion(BaseResult.failure(error))
                }
            }else{
                completion(BaseResult.failure(NSError(domain: "Invalid Key", code: 0, userInfo: nil)))
            }
        }
        
        task.resume()
        
        
        
        
    }
    
    
    
    
    func starProcessingIDs(
        url: String,
        image: Data,
        stepIdString: String,
        appConfiguration: ConfigModel,
        connectionId: String,
        clipsPath: String,
        checkForFace: Bool,
        processMrz: Bool,
        performLivenessDocument: Bool,
        saveCapturedVideo: Bool,
        storeCapturedDocument: Bool,
        isVideo: Bool,
        storeImageStream: Bool,
        isManualCapture: Bool,
        isAutoCapture: Bool,
        retryCount: Int,
        tag: String,
        processCivilExtractQrCode: Bool,
        templatesByCountry : [String] = [],
        onProgress: ((Double) -> Void)? = nil,
        completion: @escaping (BaseResult<RemoteProcessingModel?, Error>) -> Void
        
    ) {
        let traceIdentifier = UUID().uuidString
        let urlString = url
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        
        
        
        request.setValue(stepIdString, forHTTPHeaderField: "x-step-id")
        request.setValue(appConfiguration.blockIdentifier, forHTTPHeaderField: "x-block-identifier")
        request.setValue(appConfiguration.flowIdentifier, forHTTPHeaderField: "x-flow-identifier")
        request.setValue(appConfiguration.flowInstanceId, forHTTPHeaderField: "x-flow-instance-id")
        request.setValue(appConfiguration.instanceHash, forHTTPHeaderField: "x-instance-hash")
        request.setValue(appConfiguration.instanceId, forHTTPHeaderField: "x-instance-id")
        request.setValue(appConfiguration.tenantIdentifier, forHTTPHeaderField: "x-tenant-identifier")
        
        
        
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        
        
        
        let tryNumber = retryCount+1;
        var formData : [String: Any]  = [
            "tenantId": appConfiguration.tenantIdentifier,
            "blockId": appConfiguration.blockIdentifier,
            "instanceId": appConfiguration.instanceId,
            "livenessCheckEnabled": String(performLivenessDocument),
            "processMrz": String(processMrz),
            "DisableDataExtraction": "false",
            "storeImageStream": String(storeImageStream),
            "isVideo":"false",
            "clipsPath": "clipsPath",
            "isMobile":"true",
            "checkForFace":  String(checkForFace),
            "callerConnectionId": connectionId,
            "saveCapturedVideo": String(saveCapturedVideo),
            "storeCapturedDocument":String(storeCapturedDocument),
            "TraceIdentifier":UUID().uuidString,
            "IsManualCapture":String(isManualCapture),
            "IsAutoCapture":String(isAutoCapture),
            "TryNumber":String(tryNumber),
            "Tag":tag,
            "ProcessCivilExtractQrCode":String(processCivilExtractQrCode),
            "RequireFaceExtraction":"false",
        ]
        
        
        
        
        
        let body = createMultipartBody(
            parameters: formData,
            templateIds: templatesByCountry,
            files: [
                ("Image", "image.jpg", "image/jpeg", image)
            ],
            boundary: boundary
        )
        
        
        let delegate = UploadDelegate()
        delegate.onProgress = { progress in
            onProgress!(progress)
            
        }
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: .main)
        
        let task = session.uploadTask(with: request, from: body) { data, response, error in
            session.finishTasksAndInvalidate()
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
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
                    if let dictionary = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
                        let dataResult =  parseDataToRemoteProcessingModel(data: dictionary);
                        completion(BaseResult.success(dataResult))
                    } else {
                    }
                    
                    
                } catch {
                    completion(BaseResult.failure(error))
                }
            }else{
                completion(BaseResult.failure(NSError(domain: "Invalid Key", code: 0, userInfo: nil)))
            }
        }
        
        task.resume()
    }
    
    
    func setDelegate(delegate: RemoteProcessingDelegate?) {
        self.delegate = delegate
    }
    
    
    func createBody(boundary: String, parameters: [String: Any]) -> Data {
        let lineBreak = "\r\n"
        var body = Data()
        
        for (key, value) in parameters {
            if let arrayValue = value as? [String] {
                for item in arrayValue {
                    if let stringDataBoundary = "--\(boundary + lineBreak)".data(using: .utf8) {
                        body.append(stringDataBoundary)
                    }
                    if let stringDataKey = "Content-Disposition: form-data; name=\"\(key)[]\"\(lineBreak + lineBreak)".data(using: .utf8) {
                        body.append(stringDataKey)
                    }
                    if let stringDataValue = "\(item + lineBreak)".data(using: .utf8) {
                        body.append(stringDataValue)
                    }
                }
            } else if let stringValue = value as? String {
                if let stringDataBoundary = "--\(boundary + lineBreak)".data(using: .utf8) {
                    body.append(stringDataBoundary)
                }
                if let stringDataKey = "Content-Disposition: form-data; name=\"\(key)\"\(lineBreak + lineBreak)".data(using: .utf8) {
                    body.append(stringDataKey)
                }
                if let stringDataValue = "\(stringValue + lineBreak)".data(using: .utf8) {
                    body.append(stringDataValue)
                }
            }
        }
        
        if let stringDataBoundary = "--\(boundary)--\(lineBreak)".data(using: .utf8) {
            body.append(stringDataBoundary)
        }
        
        return body
    }
    
    
    
    func createMultipartBody(
        parameters: [String: Any],
        templateIds: [String],
        files: [(name: String, filename: String, mimeType: String, data: Data)],
        boundary: String
    ) -> Data {
        var body = Data()
        
        for id in templateIds {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"TemplateId\"\r\n\r\n")
            body.append("\(id)\r\n")
        }
        
        for (key, value) in parameters {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        for file in files {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n")
            body.append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            body.append("\r\n")
        }
        
        body.append("--\(boundary)--\r\n")
        return body
    }
    
    
    
}

class UploadDelegate: NSObject, URLSessionTaskDelegate {
    var onProgress: ((Double) -> Void)?
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        onProgress?(progress)
    }
}


extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
