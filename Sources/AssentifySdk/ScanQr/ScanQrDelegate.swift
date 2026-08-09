
import Foundation

@objc public protocol  ScanQrDelegate{
    
    func onStartQrScan()

    func onErrorQrScan(message: String,dataModel: RemoteProcessingModel)

    func onCompleteQrScan(dataModel: IDResponseModel)
    
    @objc func onUploadingProgress(progress:Double)
}
