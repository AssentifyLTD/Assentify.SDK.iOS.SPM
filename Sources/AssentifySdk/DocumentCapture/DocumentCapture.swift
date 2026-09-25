//
//  DocumentCapture.swift
//  AssentifySdk
//
//  Created by TariQ on 23/09/2026.
//

import Foundation


public final class DocumentCapture {
    
    private let apiKey: String
    private let configModel: ConfigModel
    
    public  var delegate: DocumentCaptureDelegate?
    private var stepID: String?
    
    public init(apiKey: String, configModel: ConfigModel,delegate:DocumentCaptureDelegate) {
        self.apiKey = apiKey
        self.configModel = configModel
        self.delegate = delegate
    }
    
    
    
    /// Kotlin: setStepId(stepId: String?)
    public func setStepId(_ stepId: String?) {
        self.stepID = stepId
        
        if self.stepID == nil {
            let assistedSteps = configModel.stepDefinitions.filter {
                $0.stepDefinition == "DocumentCapture"
            }
            
            if assistedSteps.count == 1,
               let step = assistedSteps.first {
                
                self.stepID = String(step.stepId)   // ← assuming stepId exists
                getDocumentCaptureStepFromConfigFile()
                return
            }
            
            
            delegate?.onDocumentCaptureCallbackError(
                message: "Step ID is required because multiple 'Document Capture' steps are present."
            )
            return
        }
        
        // stepId provided
        getDocumentCaptureStepFromConfigFile()
    }
    
    // MARK: - Network
    
    private func getDocumentCaptureStepFromConfigFile() {
        let id = Int(self.stepID ?? "0") ?? 0;
        let stepDefinitions = configModel.stepDefinitions
        stepDefinitions.forEach { step in
            if step.stepId == id  {
                let documentCaptureModel = step.customization.toDocumentCaptureModel()
                self.delegate?.onDocumentCaptureCallbackSuccess(documentCaptureModel: documentCaptureModel)
            }
        }
    }
    
 
    func uploadDocument(fileURL: URL, mimeType: String, documentKey: String, itemId: String,flowController:FlowController) {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            notifyError(documentKey: documentKey, itemId: itemId)
            return
        }
        uploadDocument(data: fileData, mimeType: mimeType, documentKey: documentKey, itemId: itemId,flowController:flowController)
    }

    func uploadDocument(data fileData: Data, mimeType: String, documentKey: String, itemId: String,flowController:FlowController) {
        let config = self.configModel

        guard let stepId = flowController.getCurrentStep()?.stepDefinition?.stepId else {
            notifyError(documentKey: documentKey, itemId: itemId)
            return
        }

        // Match Retrofit @Path encoding (slashes encoded too)
        var pathAllowed = CharacterSet.urlPathAllowed
        pathAllowed.remove("/")
        guard let encodedKey = documentKey.addingPercentEncoding(withAllowedCharacters: pathAllowed),
              let url = URL(string: "\(BaseUrls.blobUrl)v2/Document/UploadBulk/documentcapture/\(encodedKey)") else {
            notifyError(documentKey: documentKey, itemId: itemId)
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "accept")
        request.setValue("en", forHTTPHeaderField: "accept-language")
        request.setValue("https://platform.assentify.com/", forHTTPHeaderField: "referer")
        request.setValue(config.blockIdentifier, forHTTPHeaderField: "x-block-identifier")
        request.setValue(config.tenantIdentifier, forHTTPHeaderField: "x-tenant-identifier")
        request.setValue(config.flowIdentifier, forHTTPHeaderField: "x-flow-identifier")
        request.setValue(config.flowInstanceId, forHTTPHeaderField: "x-flow-instance-id")
        request.setValue(config.instanceHash, forHTTPHeaderField: "x-instance-hash")
        request.setValue(config.instanceId, forHTTPHeaderField: "x-instance-id")
        // request.setValue(self.apiKey, forHTTPHeaderField: "X-Api-Key") // if your Android interceptor adds it
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // File part: name "files", filename = documentKey
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"files\"; filename=\"\(documentKey)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n")

        // Repeated "additionalValues" parts, same order as Android
        let additionalValues: [String] = [
            "\(config.tenantIdentifier)",
            "\(config.blockIdentifier)",
            "\(config.flowIdentifier)",
            "\(stepId)",
            "\(config.instanceId)"
        ]
        for value in additionalValues {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"additionalValues\"\r\n")
            body.appendString("Content-Type: text/plain; charset=utf-8\r\n\r\n")
            body.appendString(value)
            body.appendString("\r\n")
        }

        body.appendString("--\(boundary)--\r\n")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.notifyError(documentKey: documentKey, itemId: itemId)
                return
            }

            // Equivalent of Map<String, String>
            let result = json.compactMapValues { value -> String? in
                if value is NSNull { return nil }
                return value as? String ?? "\(value)"
            }

            DispatchQueue.main.async {
                self.delegate?.onUploadDocumentCaptureCallbackSuccess(
                    documentKey: documentKey, itemId: itemId, data: result
                )
            }
        }.resume()
    }

    private func notifyError(documentKey: String, itemId: String) {
        DispatchQueue.main.async {
            self.delegate?.onUploadDocumentCaptureCallbackError(
                documentKey: documentKey, itemId: itemId, message: EventsErrorMessages.OnErrorMessage
            )
        }
    }

}



private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}


extension Customization {
    func toDocumentCaptureModel() -> DocumentCaptureModel {
        return DocumentCaptureModel(
            header: self.header,
            subHeader: self.subHeader,
            svgLogoUrl: self.svgLogoUrl,
            documentCaptures: self.documentCaptures,
            nextButtonTitle: self.nextButtonTitle,
            isNormalClick: self.isNormalClick ?? false
        )
    }
}
