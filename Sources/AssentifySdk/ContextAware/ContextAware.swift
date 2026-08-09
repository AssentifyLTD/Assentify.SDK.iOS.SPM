
import Foundation
import UIKit


public class ContextAwareSigning{
    
    private var contextAwareDelegate: ContextAwareDelegate?;
    private var contextAwareSigningModel: ContextAwareSigningModel?;
    private var tenantIdentifier: String;
    private var interaction: String?;
    private var stepID: Int?;
    private var configModel: ConfigModel?;
    private var apiKey: String;


    init(configModel: ConfigModel!,
         apiKey:String,
         stepID:Int,
         tenantIdentifier:String,
         interaction:String,
         contextAwareDelegate:ContextAwareDelegate
    ) {
        self.configModel = configModel;
        self.apiKey = apiKey;
        self.stepID = stepID;
        self.tenantIdentifier = tenantIdentifier;
        self.interaction = interaction;
        self.contextAwareDelegate = contextAwareDelegate;

        getContextAwareSigningStepFromConfigFile()
    }
    
    
  private func  getContextAwareSigningStepFromConfigFile(){
      
      let stepDefinitions = self.configModel!.stepDefinitions
      stepDefinitions.forEach { step in
          if step.stepId == self.stepID  {
              let contextAwareSigningModel = step.customization.toContextAwareSigningModel()
              self.contextAwareSigningModel = contextAwareSigningModel
              contextAwareSigningModel.data.selectedTemplates.forEach({ it in
                  self.getTokensMappings(templateId: it)
              })
          }
      }
    }
    
    private func  getTokensMappings(templateId:Int){
        let stepDefinitions = self.configModel!.stepDefinitions
        stepDefinitions.forEach { step in
            if step.stepId == self.stepID  {
                self.contextAwareDelegate?.onHasTokens(templateId: templateId,documentTokens: step.mappings!,contextAwareSigningModel:self.contextAwareSigningModel! );
            }
        }
       
    }
    

    
   public func createUserDocumentInstance(templateId:Int,data: [String: String]){
       let createUserDocumentRequestModel =
                 CreateUserDocumentRequestModel(
                    userId : "UserId",
                    documentTemplateId : templateId,
                    data:  data,
                    outputType:1
                 );
       remoteCreateUserDocumentInstance(tenantIdentifier: self.configModel!.tenantIdentifier,requestBody: createUserDocumentRequestModel){
            result in
            switch result {
            case .success(let createUserDocumentResponseModel):
                self.contextAwareDelegate?.onCreateUserDocumentInstance(
                    userDocumentResponseModel: createUserDocumentResponseModel
                       );
             case .failure(let error):
                self.contextAwareDelegate?.onError(message: error.localizedDescription);
            }
        }
    }
    
    public func signature(documentId:Int,documentInstanceId: Int,
                          signature: String,verifyOtpRequestOtpModel: VerifyOtpRequestOtpModel? = nil , signerName : String?,enableSignatureVisualVerifier:Bool?,faceImage:String?){
        var signatureRequestModel =
        SignatureRequestModel(
                     documentId : documentId,
                     documentInstanceId : documentInstanceId,
                     documentName : "documentName",
                     username : "UserId",
                     requiresAdditionalData : false,
                     signature : signature,
                  );
        
        
        if(verifyOtpRequestOtpModel != nil){
            
            let deviceName = "\(UIDevice.current.model) \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
            signatureRequestModel.otpCode = verifyOtpRequestOtpModel?.otp;
            signatureRequestModel.otpLine = verifyOtpRequestOtpModel?.token;
            signatureRequestModel.deviceLine = deviceName
            signatureRequestModel.signerName = signerName
            signatureRequestModel.hasOtp = true
            signatureRequestModel.signerContact = verifyOtpRequestOtpModel?.token;
            signatureRequestModel.enableVisualVerifier = enableSignatureVisualVerifier
            signatureRequestModel.faceImageUrl = faceImage
        }
       
        remoteSignature(tenantIdentifier: self.configModel!.tenantIdentifier,requestBody: signatureRequestModel){
             result in
             switch result {
             case .success(let signatureResponseModel):
                 self.contextAwareDelegate?.onSignature(signatureResponseModel: signatureResponseModel);
              case .failure(let error):
                 self.contextAwareDelegate?.onError(message: error.localizedDescription);
             }
         }
     }
    
    
}

extension Customization {
    func toContextAwareSigningModel() -> ContextAwareSigningModel {
        return ContextAwareSigningModel(
            statusCode: 200,
            data: DataModel(
                selectedTemplates: self.selectedTemplates ?? [],
                header: self.header,
                subHeader: self.subHeader,
                svgLogoUrl: self.svgLogoUrl,
                confirmationMessage: self.confirmationMessage,
                autoDownload: self.autoDownload ?? false,
                enableDigitalSignature: !(self.hideSignatureBoard ?? false),
                hideSignatureBoard: self.hideSignatureBoard ?? false,
                otpInputType: self.otpInputType ?? 1,
                enableOtp: self.enableOtp ?? false,
                otpSize: self.otpSize,
                otpExpiryTime: self.otpExpiryTime,
                otpTargets: self.otpTargets ?? [],
                autoGeneratedSignatureValues: self.autoGeneratedSignatureValues ?? [],
                enableSignatureVisualVerifier: self.enableSignatureVisualVerifier ?? false,
                faceImageSource: self.faceImageSource ?? "",
                isNormalClick: self.isNormalClick ?? true,
                otpFormat: self.otpFormat ?? 0,
                smsProvider: self.smsProvider ?? 0,
                whatsappProvider: self.whatsappProvider ?? 0,
            )
        )
    }
}
