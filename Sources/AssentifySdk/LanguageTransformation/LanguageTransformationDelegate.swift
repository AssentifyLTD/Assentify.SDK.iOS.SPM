
import Foundation

public protocol  LanguageTransformationDelegate  {
    func onTranslatedSuccess(properties :[String: String]?)
    func onTranslatedError(properties :[String: String]?)
    
}
