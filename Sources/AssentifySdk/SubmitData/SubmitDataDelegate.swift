
import Foundation

public protocol SubmitDataDelegate {
    func onSubmitError(message: String)
    func onSubmitSuccess()
}
