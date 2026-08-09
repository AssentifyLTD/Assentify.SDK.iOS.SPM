
import Foundation


public protocol ContextAwareDelegate{
    func onHasTokens(templateId:Int,documentTokens: [TokensMappings], contextAwareSigningModel : ContextAwareSigningModel);
    func onCreateUserDocumentInstance(userDocumentResponseModel: CreateUserDocumentResponseModel);
    func onSignature(signatureResponseModel :SignatureResponseModel);
    func onError(message :String);
}
