
import Foundation

struct HubConnectionTargets {
    static let ON_ERROR = "onError"
    static let ON_RETRY = "onRetry"
    static let ON_CLIP_PREPARATION_COMPLETE = "onClipPreparationComplete"
    static let ON_STATUS_UPDATE = "onStatusUpdated"
    static let ON_UPDATE = "onUpdated"
    static let ON_LIVENESS_UPDATE = "onLivenessUpdate"
    static let ON_COMPLETE = "onComplete"
    static let ON_CARD_DETECTED = "onCardDetected"
    static let ON_MRZ_EXTRACTED = "onMrzExtracted"
    static let ON_MRZ_DETECTED = "onMrzDetected"
    static let ON_NO_MRZ_EXTRACTED = "onNoMrzDetected"
    static let ON_FACE_DETECTED = "onFaceDetected"
    static let ON_NO_FACE_DETECTED = "onNoFaceDetected"
    static let ON_FACE_EXTRACTED = "onFaceExtracted"
    static let ON_QUALITY_CHECK_AVAILABLE = "onQualityCheckAvailable"
    static let ON_DOCUMENT_CAPTURED = "onDocumentCaptured"
    static let ON_DOCUMENT_CROPPED = "onDocumentCropped"
    static let ON_UPLOAD_FAILED = "onUploadFailed"
    static let ON_WRONG_TEMPLATE = "onWrongTemplate"
}

@objc public enum DoneFlags:Int {
    case Success
    case LivenessFailed
    case ExtractFailed
    case MatchFailed
    case WrongTemplate
}


