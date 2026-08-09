

import Foundation

@objc public protocol FaceMatchDelegate{
    func onError(dataModel: RemoteProcessingModel )

    func onSend()

    func onRetry(dataModel: RemoteProcessingModel )
    
    func onComplete(dataModel: FaceResponseModel )
    
    @objc func onUploadingProgress(progress:Double)
    @objc func onCollectingManualImages()

    
    @objc optional  func onClipPreparationComplete(dataModel: RemoteProcessingModel )

    @objc optional func onStatusUpdated(dataModel: RemoteProcessingModel )

    @objc optional func onUpdated(dataModel: RemoteProcessingModel )

    @objc optional func onLivenessUpdate(dataModel: RemoteProcessingModel )

    @objc optional func onCardDetected(dataModel: RemoteProcessingModel )

    @objc optional func onMrzExtracted(dataModel: RemoteProcessingModel )

    @objc optional func onMrzDetected(dataModel: RemoteProcessingModel )

    @objc optional func onNoMrzDetected(dataModel: RemoteProcessingModel )

    @objc optional func onFaceDetected(dataModel: RemoteProcessingModel )

    @objc optional func onNoFaceDetected(dataModel: RemoteProcessingModel )

    @objc optional func onFaceExtracted(dataModel: RemoteProcessingModel )

    @objc optional func onQualityCheckAvailable(dataModel: RemoteProcessingModel )

    @objc optional func onDocumentCaptured(dataModel: RemoteProcessingModel )

    @objc optional func onDocumentCropped(dataModel: RemoteProcessingModel )

    @objc optional func onUploadFailed(dataModel: RemoteProcessingModel )

    @objc optional func onEnvironmentalConditionsChange(
           brightnessEvents: BrightnessEvents,
           motion: MotionType,
           faceEvents: FaceEvents,
           zoom: ZoomType,
           detectedFaces:Int,
           isCentered: Bool,

    )
    
    @objc optional func onCurrentLiveMoveChange(
        activeLiveEvents: ActiveLiveEvents
    )
    
    
    

}
