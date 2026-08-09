

import Foundation



import UIKit
import AVFoundation
import Accelerate
import CoreImage
import Vision
import CoreVideo
import NFCPassportReader
import CoreNFC


public class ScanNfc :LanguageTransformationDelegate{
   
   
    


    private var scanNfcDelegate: ScanNfcDelegate?
    private var configModel: ConfigModel?
    private var apiKey: String
    private var language: String?
    private var passportResponseModel: PassportResponseModel?;
    
    
    
    
    init(configModel: ConfigModel!,
         apiKey:String,
         language: String,
         scanNfcDelegate:ScanNfcDelegate
    ) {
        self.configModel = configModel;
        self.apiKey = apiKey;
        self.language = language;
        self.scanNfcDelegate = scanNfcDelegate;
        
               
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
   public func isNfcAvailable() -> Bool {
        return NFCTagReaderSession.readingAvailable
    }
    

   public func readPassport(dataModel: PassportResponseModel) async {
       self.passportResponseModel = dataModel;
       let passportUtils = PassportUtils()
       let passportNumber = dataModel.passportExtractedModel?.identificationDocumentCapture?.Document_Number as? String
       let birthDate = self.formatDateToMRZ((dataModel.passportExtractedModel?.identificationDocumentCapture?.Birth_Date as? String)!)
       let expiryDate = self.formatDateToMRZ((dataModel.passportExtractedModel?.identificationDocumentCapture?.Expiry_Date as? String)!)
       let mrzKey = passportUtils.getMRZKey(
        passportNumber: passportNumber!,
        dateOfBirth: birthDate,
        dateOfExpiry:expiryDate)
       
       
        let reader = PassportReader()
        
   

    
        do {
            let passportModel = try await reader.readPassport(
                       mrzKey: mrzKey,tags: [.DG1, .DG2],
                       customDisplayMessage: { displayMessage in
                           switch displayMessage {
                           case .requestPresentPassport:
                               return "Hold your iPhone near an NFC enabled passport."
                           case .authenticatingWithPassport:
                               self.scanNfcDelegate?.onStartNfcScan();
                               return "Authenticating..."
                           case .successfulRead:
                               return "Reading ..."
                           case .error(let error):
                               self.scanNfcDelegate?.onErrorNfcScan(dataModel: self.passportResponseModel!, message: error.errorDescription!);
                               return "Error: \(error.localizedDescription)"
                           default:
                               return nil
                           }
                       }
                    
                   )
            if(!passportModel.documentNumber.isEmpty){
                self.nfcScanComplete(nFCPassportModel: passportModel);
             }
        } catch {
            print(error.localizedDescription)
        }
    }



   private func formatDateToMRZ(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "/")

        let day = parts[0].padding(toLength: 2, withPad: "0", startingAt: 0)
        let month = parts[1].padding(toLength: 2, withPad: "0", startingAt: 0)
        let year = parts[2].suffix(2)

        return "\(year)\(month)\(day)"
    }

   
    private func nfcScanComplete(nFCPassportModel:NFCPassportModel){
        if let dg2 = nFCPassportModel.dataGroupsRead[.DG2] as? DataGroup2 {
            let byteArray = dg2.imageData
            let faceImageData = Data(byteArray)

            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "face_\(timestamp).jpg"

            uploadImage(
                faceImageData: faceImageData,
                fileName: fileName,
                nFCPassportModel: nFCPassportModel
            )
        }

    }
    
   
    
    private func uploadImage(
        faceImageData: Data,
        fileName: String,
        nFCPassportModel: NFCPassportModel
    ) {

        guard let config = self.configModel else {
            return
        }

        let fullPath = "\(config.tenantIdentifier)/\(config.blockIdentifier)/\(config.instanceId)/\(fileName)"
        guard let encodedPath = fullPath.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
            return
        }

        let baseUrl = "\(BaseUrls.blobUrl)v2/Document/UploadFile/userfiles/\(encodedPath)?skipValidator=true"
        guard let url = URL(string: baseUrl) else {
            self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
            return
        }


        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(self.apiKey, forHTTPHeaderField: "X-Api-Key") // Note: Case-sensitive
        request.setValue(config.tenantIdentifier, forHTTPHeaderField: "x-tenant-identifier")
        request.setValue(config.blockIdentifier, forHTTPHeaderField: "x-block-identifier")
        request.setValue(config.instanceId, forHTTPHeaderField: "x-instance-id")
        request.setValue("text/plain", forHTTPHeaderField: "accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"asset\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(faceImageData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body


        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
                return
            }


            if !(200...299).contains(httpResponse.statusCode) {
                self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
                return
            }

            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let uploadedUrl = json["url"] as? String {

                        var faces = self.passportResponseModel?.passportExtractedModel?.faces ?? []
                        faces.removeAll()
                        faces.append(uploadedUrl)
                        self.passportResponseModel?.passportExtractedModel?.faces = faces
                        self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
                    }
                } catch {
                    self.replaceDataWithNfcData(nFCPassportModel: nFCPassportModel)
                }
            }
        }
        
        task.resume()
    }



    
   
    private func replaceDataWithNfcData(nFCPassportModel: NFCPassportModel) {
        var outputProperties = [String: Any]()

        if let originalOutputProps = passportResponseModel?.passportExtractedModel?.outputProperties {
            for (key, value) in originalOutputProps {
                if key.contains(IdentificationDocumentCaptureKeys.name) {
                    outputProperties[key] = nFCPassportModel.firstName
                    passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.name = nFCPassportModel.firstName
                } else if key.contains(IdentificationDocumentCaptureKeys.surname) {
                    outputProperties[key] =  nFCPassportModel.lastName
                    passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.surname = nFCPassportModel.lastName
                } else if key.contains(IdentificationDocumentCaptureKeys.nationality) {
                    outputProperties[key] = nFCPassportModel.nationality
                    passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.Nationality = nFCPassportModel.nationality
                } else if key.contains(IdentificationDocumentCaptureKeys.documentNumber) {
                    outputProperties[key] = nFCPassportModel.documentNumber
                    passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.Document_Number = nFCPassportModel.documentNumber
                } else if key.contains(IdentificationDocumentCaptureKeys.sex) {
                    outputProperties[key] = nFCPassportModel.gender
                    passportResponseModel?.passportExtractedModel?.identificationDocumentCapture?.Sex = nFCPassportModel.gender
                } else {
                    outputProperties[key] = value
                }
            }
        }

        
        var extractedData = [String: Any]()
        for (key, value) in outputProperties {
            if let range = key.range(of: "IdentificationDocumentCapture_") {
                let newKey = key[range.upperBound...]
                    .replacingOccurrences(of: "_", with: " ")
                extractedData[newKey] = value
            }
        }

       
        passportResponseModel?.passportExtractedModel?.outputProperties = outputProperties
        passportResponseModel?.passportExtractedModel?.transformedProperties = outputProperties.mapValues { "\($0)" }
        passportResponseModel?.passportExtractedModel?.extractedData = extractedData

        if(self.language == Language.NON){
            self.scanNfcDelegate?.onCompleteNfcScan(dataModel:self.passportResponseModel! )
        }else{
            let transformed = LanguageTransformation(apiKey: self.apiKey,languageTransformationDelegate: self)
               transformed.languageTransformation(
                   langauge: self.language!,
                   transformationModel: preparePropertiesToTranslate(language: self.language!,
                                                                     properties: self.passportResponseModel!.passportExtractedModel?.outputProperties)
               )
        }
    }

    
    var nameKey = "";
    var nameWordCount = 0;
    var surnameKey = "";
    
    public func onTranslatedSuccess(properties: [String : String]?) {
        if let outputProperties = self.passportResponseModel!.passportExtractedModel?.outputProperties {
            let ignoredProperties = getIgnoredProperties(properties: outputProperties)
            var finalProperties : [String: Any] = [:]

            for (key, value) in outputProperties {
                if key.contains(IdentificationDocumentCaptureKeys.name) {
                    nameKey = key
                    if let stringValue = value as? String {
                        let trimmedValue = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        nameWordCount = trimmedValue.isEmpty ? 0 : trimmedValue.split(separator: " ").count
                    } else {
                        nameWordCount = 0
                    }
                }

                if key.contains(IdentificationDocumentCaptureKeys.surname) {
                    surnameKey = key
                }
            }
            
            
            for (key, value) in properties! {
                if (key == FullNameKey) {
                    if !nameKey.isEmpty {
                        let selectedWords = getSelectedWords(input: String(describing: value), numberOfWords: nameWordCount)
                        finalProperties[nameKey] = selectedWords
                    }

                    if !surnameKey.isEmpty {
                        let remainingWords = getRemainingWords(input: String(describing: value), numberOfWords: nameWordCount)
                        finalProperties[surnameKey] = remainingWords
                    }

                }else{
                    finalProperties[key] = value
                }
            }
            
            for (key, value) in ignoredProperties {
                finalProperties[key] = value
            }
        

            self.passportResponseModel!.passportExtractedModel?.transformedProperties?.removeAll()
            self.passportResponseModel!.passportExtractedModel?.extractedData?.removeAll()

            for (key, value) in finalProperties {
                    self.passportResponseModel!.passportExtractedModel!.transformedProperties![key] =  "\(value)"
                    let keys = key.split(separator: "_").map { String($0) }
                    let newKey = key.components(separatedBy: "IdentificationDocumentCapture_").last?.components(separatedBy: "_").joined(separator: " ") ?? ""
                    self.passportResponseModel!.passportExtractedModel!.extractedData![newKey] =  "\(value)"
               
            }
            self.scanNfcDelegate?.onCompleteNfcScan(dataModel:self.passportResponseModel! )
        }

    }
    
    public func onTranslatedError(properties: [String : String]?) {
        self.scanNfcDelegate?.onCompleteNfcScan(dataModel:self.passportResponseModel! )
    }
    
}



