//
//  DocumentCaptureItem.swift
//  AssentifySdk
//
//  Swift port of DocumentCaptureItem.kt
//  Slot state, the per-document card, camera / file pickers and file helpers.
//

import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

// ─────────────────────────── Config ───────────────────────────

/// `maxFileSize` from the config is assumed to be in MB. Change here if it is KB/bytes.
let bytesPerMaxFileSizeUnit: Int64 = 1024 * 1024

/// Captured / picked / combined files live in the app's temp dir, never the photo library.
func documentCaptureCacheDirectory() -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("document_capture", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

func documentCaptureTimestamp() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
}

// ─────────────────────────── Slot kind ───────────────────────────

/**
 What kind of content a slot currently holds. Drives the "slot contains → result" rules:
  - one file                → uploaded untouched
  - several IMAGE files     → stacked vertically, 10px gutter, written as PNG
  - several PDF files       → concatenated into one multi-page PDF, page order preserved
  - IMAGE + PDF in one slot → refused; the add is rejected, user must clear the slot first
 */
enum SlotKind: String {
    case image, pdf, other
}

func kindOf(_ mimeType: String) -> SlotKind {
    if mimeType.hasPrefix("image/") { return .image }
    if mimeType == "application/pdf" { return .pdf }
    return .other
}

// ─────────────────────────── State ───────────────────────────

enum UploadStatus { case uploading, uploaded, failed }

enum DocError { case uploadFailed, uploading, required, minCount }

enum PickerError: Error, Equatable {
    case formatNotAllowed, fileTooLarge, readFailed, cameraFailed, mixedType
}

struct CapturedItem: Identifiable {
    let id: String
    let fileURL: URL
    let displayName: String
    let mimeType: String
    /// Small pre-decoded thumbnail so rows never decode full-size photos while scrolling.
    let thumbnail: UIImage?

    var status: UploadStatus = .uploading
    var resultData: [String: String] = [:]
    var uploadedAt: String? = nil

    var isImage: Bool { mimeType.hasPrefix("image/") }
    var fileExtension: String { (displayName as NSString).pathExtension }
}

extension DocumentCaptures {
    /// Stable key used to route upload callbacks back to the right card.
    var stateKey: String {
        id.map { "\($0)" } ?? keyIdentifier.map { "\($0)" } ?? documentTitle ?? ""
    }
}

struct DocumentItemState {
    let doc: DocumentCaptures
    var items: [CapturedItem] = []
    var showError: Bool = false
    var pickerError: PickerError? = nil

    /// The kind of the items currently in this slot (nil when empty). Slots are kept homogeneous.
    var kind: SlotKind? { items.first.map { kindOf($0.mimeType) } }

    /// Total items (live captures + uploaded files) allowed on this card.
    /// NOTE: maxLiveCaptureLength is treated as "max number of items" (same as Android).
    var maxItems: Int { max(doc.maxLiveCaptureLength ?? 1, 1) }

    var minItems: Int {
        min(max(doc.minLiveCaptureImages ?? 0, doc.mandatory == true ? 1 : 0), maxItems)
    }

    var canAddMore: Bool { items.count < maxItems }

    var isUploading: Bool { items.contains { $0.status == .uploading } }

    func validationError() -> DocError? {
        if items.contains(where: { $0.status == .failed }) { return .uploadFailed }
        if items.contains(where: { $0.status == .uploading }) { return .uploading }
        if doc.mandatory == true && items.isEmpty { return .required }
        if !items.isEmpty && items.count < minItems { return .minCount }
        return nil
    }
}

// ─────────────────────────── Card ───────────────────────────

struct DocumentCaptureItemView: View {
    let state: DocumentItemState
    let onFileReady: (_ fileURL: URL, _ name: String, _ mimeType: String) -> Void
    let onPickerError: (PickerError?) -> Void
    let onRemove: (CapturedItem) -> Void
    let onRetry: (CapturedItem) -> Void

    @State private var showCamera = false
    @State private var showFilePicker = false

    private var doc: DocumentCaptures { state.doc }
    private var accent: Color { Color(BaseTheme.baseAccentColor) }
    private var red: Color { Color(BaseTheme.baseRedColor) }
    private var secondaryText: Color { Color(BaseTheme.baseTextColor).opacity(0.5) }

    private var formatsLabel: String {
        (doc.allowedFormats ?? []).map { $0.uppercased() }.joined(separator: ", ")
    }

    private var errorText: String? {
        if let pickerError = state.pickerError {
            switch pickerError {
            case .formatNotAllowed: return FlowStrings.docFormatNotAllowed(formatsLabel)
            case .fileTooLarge:     return FlowStrings.docFileTooLarge(doc.maxFileSize ?? 0)
            case .readFailed:       return FlowStrings.docReadFailed
            case .cameraFailed:     return FlowStrings.docCameraFailed
            case .mixedType:        return FlowStrings.docMixedType(state.kind?.rawValue)
            }
        }
        guard state.showError else { return nil }
        switch state.validationError() {
        case .uploadFailed: return FlowStrings.docFixFailed
        case .uploading:    return FlowStrings.docWaitForUpload
        case .required:     return FlowStrings.docRequired
        case .minCount:     return FlowStrings.docMinCount(state.minItems)
        case nil:           return nil
        }
    }

    private var hint: String {
        var parts: [String] = []
        if !formatsLabel.isEmpty { parts.append(formatsLabel) }
        if let size = doc.maxFileSize, size > 0 { parts.append("max \(size) MB") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        // Locked while a previous item is still uploading, in addition to being at capacity.
        let canAdd = state.canAddMore && !state.isUploading
        let error = errorText

        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(spacing: 0) {
                Text(doc.documentTitle ?? "")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(BaseTheme.baseTextColor))
                if doc.mandatory == true {
                    Text(" *")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(red)
                }
                Spacer()
                if state.maxItems > 1 {
                    Text("\(state.items.count)/\(state.maxItems)")
                        .font(.system(size: 12))
                        .foregroundColor(secondaryText)
                }
            }

            Spacer().frame(height: 12)

            // Captured / uploaded items
            ForEach(state.items) { item in
                CapturedItemRow(
                    item: item,
                    accent: accent,
                    onRemove: { onRemove(item) },
                    onRetry: { onRetry(item) }
                )
            }

            // Actions
            VStack(spacing: 10) {
                if doc.allowLiveCapture == true {
                    ActionButton(
                        label: FlowStrings.docTakePicture,
                        systemImage: "camera.fill",
                        enabled: canAdd,
                        accent: accent
                    ) { launchCamera() }
                }
                if doc.allowFileUpload == true {
                    ActionButton(
                        label: FlowStrings.docUploadFile,
                        systemImage: "arrow.up.doc",
                        enabled: canAdd,
                        accent: accent
                    ) {
                        onPickerError(nil)
                        showFilePicker = true
                    }
                }
            }
            .padding(.horizontal, 12)

            // Hint for file uploads
            if doc.allowFileUpload == true && !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 11))
                    .foregroundColor(secondaryText)
                    .padding(.top, 8)
            }

            if let error {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16).fill(Color(BaseTheme.fieldColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(error != nil ? red : accent.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(isPresented: $showCamera) { image in
                saveCapturedPhoto(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showFilePicker) {
            DocumentFilePicker(
                isPresented: $showFilePicker,
                contentTypes: pickerContentTypes(doc.allowedFormats)
            ) { url in
                handlePicked(url)
            }
            .ignoresSafeArea()
        }
    }

    // ── Camera (full resolution, saved to temp dir, never the photo library) ──
    private func launchCamera() {
        onPickerError(nil)
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            onPickerError(.cameraFailed)
            return
        }
        showCamera = true
    }

    private func saveCapturedPhoto(_ image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = documentCaptureCacheDirectory()
                .appendingPathComponent("IMG_\(documentCaptureTimestamp()).jpg")
            var saved = false
            if let data = image.jpegData(compressionQuality: 0.95), !data.isEmpty {
                saved = (try? data.write(to: url, options: .atomic)) != nil
            }
            DispatchQueue.main.async {
                if saved {
                    onFileReady(url, url.lastPathComponent, "image/jpeg")
                } else {
                    try? FileManager.default.removeItem(at: url)
                    onPickerError(.cameraFailed)
                }
            }
        }
    }

    // ── File picker ──
    private func handlePicked(_ url: URL) {
        onPickerError(nil)
        let doc = self.doc
        DispatchQueue.global(qos: .userInitiated).async {
            let result = readPickedFile(url, doc: doc)
            DispatchQueue.main.async {
                switch result {
                case .success(let file): onFileReady(file.url, file.name, file.mime)
                case .failure(let error): onPickerError(error)
                }
            }
        }
    }
}

// ─────────────────────────── Sub-views ───────────────────────────

fileprivate struct ActionButton: View {
    let label: String
    let systemImage: String
    let enabled: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 14, weight: BaseTheme.baseClickFontWeight))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundColor(Color(BaseTheme.baseTextColor).opacity(enabled ? 1 : 0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accent.opacity(enabled ? 1 : 0.3), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

fileprivate struct CapturedItemRow: View {
    let item: CapturedItem
    let accent: Color
    let onRemove: () -> Void
    let onRetry: () -> Void

    private var textColor: Color { Color(BaseTheme.baseTextColor) }

    var body: some View {
        HStack(spacing: 10) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                switch item.status {
                case .uploading:
                    Text(FlowStrings.docUploading)
                        .font(.system(size: 11))
                        .foregroundColor(textColor.opacity(0.5))
                case .uploaded:
                    Text(FlowStrings.docUploaded)
                        .font(.system(size: 11))
                        .foregroundColor(Color(BaseTheme.baseGreenColor))
                case .failed:
                    Text(FlowStrings.docUploadFailed)
                        .font(.system(size: 11))
                        .foregroundColor(Color(BaseTheme.baseRedColor))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            switch item.status {
            case .uploading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(accent)
                    .scaleEffect(0.8)
                    .frame(width: 18, height: 18)
            case .failed:
                Button(action: onRetry) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Color(BaseTheme.baseRedColor))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retry")
            case .uploaded:
                EmptyView()
            }

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .foregroundColor(textColor.opacity(0.7))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove")
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(textColor.opacity(0.05)))
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = item.thumbnail {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            let ext = String(item.fileExtension.uppercased().prefix(4))
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(accent.opacity(0.15))
                Text(ext.isEmpty ? "FILE" : ext)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(textColor)
            }
            .frame(width: 48, height: 48)
        }
    }
}

// ─────────────────────────── Pickers ───────────────────────────

struct CameraCaptureView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onCaptured: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCaptured(image)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

struct DocumentFilePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let contentTypes: [UTType]
    let onPicked: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // asCopy: true → we get a private sandbox copy, no security-scoped bookkeeping needed.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: DocumentFilePicker
        init(_ parent: DocumentFilePicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { parent.onPicked(url) }
            parent.isPresented = false
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// ─────────────────────────── File helpers ───────────────────────────

struct PickedFile {
    let url: URL
    let name: String
    let mime: String
}

func normalizeFormats(_ allowed: [String]?) -> [String] {
    (allowed ?? [])
        .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        .map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
        .filter { !$0.isEmpty }
}

/// Resolve common extensions ourselves first, fall back to the system UTType table for the rest.
private let knownMimeTypes: [String: String] = [
    "pdf": "application/pdf",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "heic": "image/heic",
    "heif": "image/heif",
    "webp": "image/webp",
    "gif": "image/gif",
    "bmp": "image/bmp",
    "tif": "image/tiff",
    "tiff": "image/tiff",
    "doc": "application/msword",
    "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
]

func mimeTypeForExtension(_ ext: String) -> String? {
    knownMimeTypes[ext] ?? UTType(filenameExtension: ext)?.preferredMIMEType
}

/// Content types for the iOS document picker. If any configured format can't be mapped,
/// fall back to "anything" so valid files are never hidden — readPickedFile validates anyway.
func pickerContentTypes(_ allowed: [String]?) -> [UTType] {
    let list = normalizeFormats(allowed)
    guard !list.isEmpty else { return [.item] }

    var types: [UTType] = []
    for format in list {
        let type: UTType?
        if format.hasSuffix("/*") {
            switch format {
            case "image/*": type = .image
            case "video/*": type = .movie
            case "audio/*": type = .audio
            case "text/*":  type = .text
            default:        type = nil
            }
        } else if format.contains("/") {
            type = UTType(mimeType: format)
        } else {
            type = UTType(filenameExtension: format)
        }
        guard let type else { return [.item] }
        types.append(type)
    }
    return types
}

func isFormatAllowed(name: String, mime: String, allowed: [String]?) -> Bool {
    let list = normalizeFormats(allowed)
    if list.isEmpty { return true }
    let ext = (name as NSString).pathExtension.lowercased()
    let m = mime.lowercased()
    return list.contains { a in
        if a.hasSuffix("/*") { return m.hasPrefix(String(a.dropLast())) }
        if a.contains("/") { return a == m }
        if a == "jpg" || a == "jpeg" { return ext == "jpg" || ext == "jpeg" }
        return ext == a
    }
}

private func fileSize(_ url: URL) -> Int64? {
    (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) }
}

/// Runs off the main thread. Validates format + size and moves the file into our cache dir.
func readPickedFile(_ source: URL, doc: DocumentCaptures) -> Swift.Result<PickedFile, PickerError> {
    let scoped = source.startAccessingSecurityScopedResource()
    defer { if scoped { source.stopAccessingSecurityScopedResource() } }

    let rawName = source.lastPathComponent
    let name = rawName.isEmpty ? "document_\(documentCaptureTimestamp())" : rawName
    let ext = (name as NSString).pathExtension.lowercased()
    let mime = mimeTypeForExtension(ext) ?? "application/octet-stream"

    guard isFormatAllowed(name: name, mime: mime, allowed: doc.allowedFormats) else {
        return .failure(.formatNotAllowed)
    }

    var maxSize: Int64? = nil
    if let limit = doc.maxFileSize, limit > 0 {
        maxSize = Int64(limit) * bytesPerMaxFileSizeUnit
    }
    if let maxSize, let size = fileSize(source), size > maxSize {
        return .failure(.fileTooLarge)
    }

    let safeName = name.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
    let out = documentCaptureCacheDirectory()
        .appendingPathComponent("\(documentCaptureTimestamp())_\(safeName)")

    do {
        // The picker already gave us a private copy, so move it rather than duplicate the bytes.
        do { try FileManager.default.moveItem(at: source, to: out) }
        catch { try FileManager.default.copyItem(at: source, to: out) }
    } catch {
        return .failure(.readFailed)
    }

    // Size may have been unknown up-front.
    if let maxSize, let size = fileSize(out), size > maxSize {
        try? FileManager.default.removeItem(at: out)
        return .failure(.fileTooLarge)
    }

    return .success(PickedFile(url: out, name: name, mime: mime))
}

/// Memory-friendly thumbnail via ImageIO (respects EXIF orientation). Nil for non-images.
func makeThumbnail(for url: URL, mimeType: String, maxPixelSize: Int = 144) -> UIImage? {
    guard mimeType.hasPrefix("image/"),
          let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}
