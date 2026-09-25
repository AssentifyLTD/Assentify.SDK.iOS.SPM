

import Foundation


// MARK: - Document Capture Model
public struct DocumentCaptureModel: Codable {
    public let header: String?
    public let subHeader: String?
    public let svgLogoUrl: String?
    public let documentCaptures: [DocumentCaptures]?
    public let nextButtonTitle: String?
    public let isNormalClick: Bool?
}

// MARK: - Document Captures
public struct DocumentCaptures: Codable {
    public let id: String?
    public let documentNameKey: String?
    public let documentUploadTimeKey: String?
    public let keyIdentifier: String?
    public let documentTitle: String?
    public let mandatory: Bool?
    public let allowLiveCapture: Bool?
    public let maxLiveCaptureLength: Int?
    public let allowFileUpload: Bool?
    public let enableAutoCrop: Bool?
    public let allowedFormats: [String]?
    public let maxFileSize: Int?
    public let minLiveCaptureImages: Int?
    public let maxLiveCaptureImages: Int?
}


