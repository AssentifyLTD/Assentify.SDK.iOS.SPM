
import Foundation

public protocol  AssistedDataEntryDelegate  {
    func onAssistedDataEntryError(message: String)
    func onAssistedDataEntrySuccess(assistedDataEntryModel: AssistedDataEntryModel)
}
