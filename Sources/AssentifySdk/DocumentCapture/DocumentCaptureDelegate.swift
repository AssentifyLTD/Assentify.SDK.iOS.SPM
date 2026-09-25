//
//  DocumentCapture.swift
//  AssentifySdk
//
//  Created by TariQ on 23/09/2026.
//

public protocol DocumentCaptureDelegate {
    func onDocumentCaptureCallbackError(message: String)
    func onDocumentCaptureCallbackSuccess(documentCaptureModel: DocumentCaptureModel)
    func onUploadDocumentCaptureCallbackSuccess(documentKey: String, itemId: String, data: [String: String])
    func onUploadDocumentCaptureCallbackError(documentKey: String, itemId: String, message: String)
}
