//
//  DocumentCaptureStepScreen.swift
//  AssentifySdk
//
//  Swift port of DocumentCaptureStepActivity.kt
//  View model (DocumentCaptureDelegate + slot logic + merging) and the step screen.
//

import SwiftUI
import UIKit
import PDFKit
import ImageIO

public enum DocumentCaptureStepEventType {
    case onSend
    case onComplete
    case onError
}

// MARK: - View model (plays the role of the Android Activity)

@MainActor
final class DocumentCaptureStepViewModel: ObservableObject, DocumentCaptureDelegate {

    /// Android effectively shows validation errors straight away (validateAll() runs during
    /// composition for the Next button). true = same behaviour. false = errors only appear after
    /// the user touches a card or taps Next.
    static let showErrorsImmediately = true

    @Published private(set) var eventType: DocumentCaptureStepEventType = .onSend
    @Published private(set) var model: DocumentCaptureModel? = nil
    @Published private(set) var errorMessage: String = FlowStrings.somethingWentWrong
    /// One UI state per DocumentCaptures entry, keyed by DocumentCaptures.stateKey.
    @Published private(set) var slots: [String: DocumentItemState] = [:]

    private let flowController: FlowController
    private var documentCapture: DocumentCapture?
    private let timeStarted: String = getCurrentDateTimeForTracking()
    private var didStart = false
    private var isNavigating = false
    private var hasAppeared = false

    /// Final output of this step, handed to makeCurrentStepDone.
    private var resultMap: [String: String] = [:]

    /// In-flight combine task per slot, so a rapid add/remove cancels the stale one.
    private var mergeTasks: [String: Task<Void, Never>] = [:]

    /// What each slot is currently waiting on. Callbacks that don't match are stale and ignored.
    private enum UploadTarget {
        case individual(Set<String>)   // item ids
        case merged(String)            // synthetic merge id
    }
    private var activeUploads: [String: UploadTarget] = [:]

    nonisolated init(flowController: FlowController) {
        self.flowController = flowController
    }

    // MARK: Start

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true

        // Leftovers from a previous run of this step.
        try? FileManager.default.removeItem(
            at: FileManager.default.temporaryDirectory.appendingPathComponent("document_capture")
        )

        guard let currentStep = flowController.getCurrentStep() else {
            eventType = .onError
            return
        }

        flowController.trackProgress(
            currentStep: currentStep,
            inputData: flowController.outputPropertiesToMap(currentStep.stepDefinition!.outputProperties),
            response: nil,
            status: "InProgress"
        )

        documentCapture = AssentifySdkObject.shared.get()?.startDocumentCapture(
            documentCaptureDelegate: self,
            stepId: currentStep.stepDefinition?.stepId
        )
        if documentCapture == nil {
            eventType = .onError
        }
    }

    /// Called every time the screen appears (first show AND coming back from the next step).
    func onAppear() {
        isNavigating = false

        // Coming back from the next step: the delegate was detached in onDisappear, so upload
        // callbacks would never reach us and items would spin on "uploading" forever. Reattach.
        documentCapture?.delegate = self

        // Anything that was mid-upload while we were detached lost its callback — redo it.
        if hasAppeared {
            for (key, state) in slots where state.isUploading {
                reprocessSlot(key)
            }
        }
        hasAppeared = true
    }

    /// DocumentCapture holds its delegate strongly; detach while off-screen to break the cycle.
    func onDisappear() {
        documentCapture?.delegate = nil
    }

    // MARK: SDK callbacks

    nonisolated func onDocumentCaptureCallbackError(message: String) {
        Task { @MainActor in
            self.errorMessage = message
            self.eventType = .onError
        }
    }

    nonisolated func onDocumentCaptureCallbackSuccess(documentCaptureModel: DocumentCaptureModel) {
        Task { @MainActor in
            self.handleConfigLoaded(documentCaptureModel)
        }
    }

    nonisolated func onUploadDocumentCaptureCallbackSuccess(documentKey: String, itemId: String, data: [String: String]) {
        Task { @MainActor in
            self.handleUploadSuccess(key: documentKey, itemId: itemId, data: data)
        }
    }

    nonisolated func onUploadDocumentCaptureCallbackError(documentKey: String, itemId: String, message: String) {
        // Keep the server's reason visible — it's the only way to tell size / format / network apart.
        print("[DocumentCapture] upload failed key=\(documentKey) item=\(itemId): \(message)")
        Task { @MainActor in
            self.handleUploadFailure(key: documentKey, itemId: itemId)
        }
    }

    private func handleConfigLoaded(_ documentCaptureModel: DocumentCaptureModel) {
        var newSlots = slots
        for doc in documentCaptureModel.documentCaptures ?? [] {
            if newSlots[doc.stateKey] == nil {
                var state = DocumentItemState(doc: doc)
                state.showError = Self.showErrorsImmediately
                newSlots[doc.stateKey] = state
            }
        }
        slots = newSlots
        model = documentCaptureModel
        eventType = .onComplete
    }

    private func handleUploadSuccess(key: String, itemId: String, data: [String: String]) {
        guard let target = activeUploads[key] else { return }
        let now = getCurrentDateTimeForTracking()

        mutate(key) { state in
            switch target {
            case .merged(let mergeId):
                // This upload represents the whole slot (combined images / concatenated PDF).
                // Fan the result out to every item currently displayed in the slot.
                guard mergeId == itemId else { return }
                for i in state.items.indices {
                    state.items[i].resultData = data
                    state.items[i].uploadedAt = now
                    state.items[i].status = .uploaded
                }
            case .individual(let ids):
                guard ids.contains(itemId),
                      let i = state.items.firstIndex(where: { $0.id == itemId }) else { return } // removed / stale
                state.items[i].resultData = data
                state.items[i].uploadedAt = now
                state.items[i].status = .uploaded
            }
        }
        rebuildResult()
    }

    private func handleUploadFailure(key: String, itemId: String) {
        guard let target = activeUploads[key] else { return }
        mutate(key) { state in
            switch target {
            case .merged(let mergeId):
                guard mergeId == itemId else { return }
                for i in state.items.indices { state.items[i].status = .failed }
            case .individual(let ids):
                guard ids.contains(itemId),
                      let i = state.items.firstIndex(where: { $0.id == itemId }) else { return }
                state.items[i].status = .failed
            }
        }
    }

    // MARK: Item actions

    func addAndUpload(key: String, fileURL: URL, name: String, mimeType: String) {
        guard var state = slots[key], state.canAddMore else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        // Images and PDFs in the same slot are refused — user must clear the slot and pick one kind.
        let newKind = kindOf(mimeType)
        if let existing = state.kind, existing != newKind {
            try? FileManager.default.removeItem(at: fileURL)
            state.pickerError = .mixedType
            slots[key] = state
            return
        }

        state.pickerError = nil
        state.showError = true
        state.items.append(
            CapturedItem(
                id: UUID().uuidString,
                fileURL: fileURL,
                displayName: name,
                mimeType: mimeType,
                thumbnail: makeThumbnail(for: fileURL, mimeType: mimeType)
            )
        )
        slots[key] = state
        reprocessSlot(key)
    }

    /// Retrying re-derives the whole slot's result (single/combined) rather than just one file,
    /// since a multi-image or multi-PDF slot's uploaded artifact is shared across its items.
    func retry(key: String) {
        reprocessSlot(key)
    }

    func removeItem(key: String, item: CapturedItem) {
        mutate(key) { state in
            state.items.removeAll { $0.id == item.id }
            state.showError = true
        }
        try? FileManager.default.removeItem(at: item.fileURL)
        reprocessSlot(key)
    }

    func setPickerError(_ error: PickerError?, key: String) {
        mutate(key) { $0.pickerError = error }
    }

    /**
     Re-derives what should be uploaded for a slot:
      - empty                 → nothing to upload
      - one file              → uploaded untouched
      - several images        → stacked vertically, 10px gutter, PNG (downsampled to fit maxFileSize)
      - several PDFs          → concatenated into one multi-page PDF, order preserved
      - several "other" files → uploaded individually, untouched
     Mixed image+PDF slots never get here: addAndUpload refuses the add.
     */
    private func reprocessSlot(_ key: String) {
        mergeTasks.removeValue(forKey: key)?.cancel()
        activeUploads.removeValue(forKey: key)

        guard var state = slots[key] else { return }

        // A "too large" error from a previous merge no longer applies once the slot changes.
        if state.pickerError == .fileTooLarge { state.pickerError = nil }

        if state.items.isEmpty {
            slots[key] = state
            rebuildResult()
            return
        }

        let kind = kindOf(state.items[0].mimeType)

        // Reset visible state, then decide how to (re)upload.
        for i in state.items.indices {
            state.items[i].status = .uploading
            state.items[i].resultData = [:]
            state.items[i].uploadedAt = nil
        }
        slots[key] = state
        rebuildResult()

        if state.items.count == 1 || kind == .other {
            activeUploads[key] = .individual(Set(state.items.map(\.id)))
            for item in state.items {
                upload(fileURL: item.fileURL, mimeType: item.mimeType, key: key, itemId: item.id)
            }
            return
        }

        // Several images, or several PDFs: build one combined artifact and upload it once.
        let files = state.items.map(\.fileURL)
        let stamp = documentCaptureTimestamp()
        let safeKey = key.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
        let outDir = documentCaptureCacheDirectory()
        let maxBytes: Int64? = state.doc.maxFileSize.flatMap {
            $0 > 0 ? Int64($0) * bytesPerMaxFileSizeUnit : nil
        }

        mergeTasks[key] = Task { [weak self] in
            do {
                let (combinedURL, combinedMime): (URL, String) = try await Task.detached(priority: .userInitiated) {
                    switch kind {
                    case .image:
                        let out = outDir.appendingPathComponent("combined_\(safeKey)_\(stamp).png")
                        return (try combineImagesVertically(files, out: out, maxBytes: maxBytes), "image/png")
                    case .pdf:
                        let out = outDir.appendingPathComponent("combined_\(safeKey)_\(stamp).pdf")
                        return (try concatenatePdfs(files, out: out, maxBytes: maxBytes), "application/pdf")
                    case .other:
                        throw MergeError.unsupported // unreachable, guarded above
                    }
                }.value

                guard let self, !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: combinedURL)
                    return
                }
                let mergeId = "merge_\(key)_\(stamp)"
                self.activeUploads[key] = .merged(mergeId)
                self.upload(fileURL: combinedURL, mimeType: combinedMime, key: key, itemId: mergeId)
            } catch {
                guard let self, !Task.isCancelled else { return }
                print("[DocumentCapture] merge failed for \(key): \(error)")
                self.mutate(key) { state in
                    for i in state.items.indices { state.items[i].status = .failed }
                    if case MergeError.tooLarge = error { state.pickerError = .fileTooLarge }
                }
            }
        }
    }

    /// Reads the file off the main thread, then hands the bytes to DocumentCapture.
    private func upload(fileURL: URL, mimeType: String, key: String, itemId: String) {
        guard let documentCapture else {
            handleUploadFailure(key: key, itemId: itemId)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let data = try? Data(contentsOf: fileURL)
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let data else {
                    self.handleUploadFailure(key: key, itemId: itemId)
                    return
                }
                documentCapture.uploadDocument(
                    data: data,
                    mimeType: mimeType,
                    documentKey: key,
                    itemId: itemId,
                    flowController: self.flowController
                )
            }
        }
    }

    /// Rebuilds the result map from everything currently uploaded, so removing an item
    /// also removes its values.
    private func rebuildResult() {
        var result: [String: String] = [:]
        for doc in model?.documentCaptures ?? [] {
            guard let state = slots[doc.stateKey] else { continue }
            for item in state.items where item.status == .uploaded {
                result.merge(item.resultData) { _, new in new }
            }
        }
        resultMap = result
    }

    // MARK: Validation / navigation

    /// Side-effect free — safe to read from `body`.
    var canProceed: Bool {
        guard let docs = model?.documentCaptures else { return false }
        return docs.allSatisfy { slots[$0.stateKey]?.validationError() == nil }
    }

    @discardableResult
    private func validateAll() -> Bool {
        for doc in model?.documentCaptures ?? [] {
            mutate(doc.stateKey) { $0.showError = true }
        }
        return canProceed
    }

    func onNext() {
        guard !isNavigating, validateAll() else { return }
        isNavigating = true

        flowController.makeCurrentStepDone(
            extractedInformation: resultMap,
            timeStarted: timeStarted
        )
        // Delegate is detached in onDisappear and reattached in onAppear, so coming back works.
        flowController.naveToNextStep()
    }

    func onBack() {
        flowController.backClick()
    }

    private func mutate(_ key: String, _ change: (inout DocumentItemState) -> Void) {
        guard var state = slots[key] else { return }
        change(&state)
        slots[key] = state
    }
}

// MARK: - Merging (pure, run off the main actor)

private enum MergeError: Error {
    case unsupported
    case imageDecodeFailed(String)
    case imageEncodeFailed
    case pdfOpenFailed(String)
    case pdfWriteFailed
    case tooLarge
}

/// Longest side (px) tried for each image when stacking. If the PNG exceeds maxFileSize at one
/// size, the next smaller one is tried before giving up with `.tooLarge`.
private let mergeMaxSideSteps: [Int] = [2000, 1600, 1280, 1000]

/// Several images → stacked vertically on one canvas, 10px gutter, white background, PNG.
///
/// Why this is careful about memory/size:
///  - Images are decoded *downsampled* through ImageIO (never full 12MP bitmaps), with EXIF
///    orientation applied, so camera photos aren't rotated.
///  - The renderer is forced to 8-bit sRGB. The default (.automatic) switches to a 16-bit
///    extended-range canvas for Display-P3 camera photos, which doubles memory and produces
///    enormous PNGs that the server rejects.
///  - The result is checked against maxFileSize before upload; if too large, it is re-rendered
///    at the next smaller size.
private func combineImagesVertically(_ files: [URL], out: URL, maxBytes: Int64?) throws -> URL {
    var lastSize = 0
    for maxSide in mergeMaxSideSteps {
        try Task.checkCancellation()
        let data = try renderStackedPNG(files, maxSide: maxSide)
        lastSize = data.count
        if let maxBytes, Int64(data.count) > maxBytes { continue }
        try data.write(to: out, options: .atomic)
        return out
    }
    print("[DocumentCapture] combined PNG still \(lastSize) bytes at smallest size; limit \(maxBytes ?? -1)")
    throw MergeError.tooLarge
}

private func renderStackedPNG(_ files: [URL], maxSide: Int) throws -> Data {
    let gutter: CGFloat = 10

    let images: [CGImage] = try files.map { url in
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // applies EXIF orientation
            kCGImageSourceThumbnailMaxPixelSize: maxSide,       // never decode full-res
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw MergeError.imageDecodeFailed(url.lastPathComponent)
        }
        return cg
    }

    let sizes = images.map { CGSize(width: $0.width, height: $0.height) }
    let width = sizes.map(\.width).max() ?? 0
    let height = sizes.map(\.height).reduce(0, +) + gutter * CGFloat(max(images.count - 1, 0))
    guard width > 0, height > 0 else { throw MergeError.imageEncodeFailed }
    let canvasSize = CGSize(width: width, height: height)

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    format.preferredRange = .standard   // 8-bit sRGB, not 16-bit extended range
    let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

    let data: Data = autoreleasepool {
        renderer.pngData { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))

            var y: CGFloat = 0
            for (cg, size) in zip(images, sizes) {
                let x = (width - size.width) / 2
                UIImage(cgImage: cg).draw(in: CGRect(x: x, y: y, width: size.width, height: size.height))
                y += size.height + gutter
            }
        }
    }
    guard !data.isEmpty else { throw MergeError.imageEncodeFailed }
    return data
}

/// Several PDFs → one multi-page PDF, page order preserved (file order, then page order).
/// Uses PDFKit page copies, so text/vector content is kept (Android has to rasterize).
private func concatenatePdfs(_ files: [URL], out: URL, maxBytes: Int64?) throws -> URL {
    let merged = PDFDocument()

    for url in files {
        guard let source = PDFDocument(url: url), !source.isLocked else {
            throw MergeError.pdfOpenFailed(url.lastPathComponent)
        }
        for index in 0..<source.pageCount {
            guard let page = source.page(at: index)?.copy() as? PDFPage else {
                throw MergeError.pdfOpenFailed(url.lastPathComponent)
            }
            merged.insert(page, at: merged.pageCount)
        }
    }

    guard merged.write(to: out) else { throw MergeError.pdfWriteFailed }

    // Same limit as single uploads, so the user sees a clear message instead of a server failure.
    if let maxBytes,
       let size = (try? out.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init),
       size > maxBytes {
        try? FileManager.default.removeItem(at: out)
        throw MergeError.tooLarge
    }
    return out
}

// MARK: - Screen

public struct DocumentCaptureStepScreen: View {

    @StateObject private var viewModel: DocumentCaptureStepViewModel
    private let steps = LocalStepsObject.shared.get()

    public init(flowController: FlowController) {
        _viewModel = StateObject(wrappedValue: DocumentCaptureStepViewModel(flowController: flowController))
    }

    public var body: some View {
        BaseBackgroundContainer {
            VStack(spacing: 0) {

                // ── TOP (fixed) ──
                VStack(spacing: 10) {
                    ProgressStepperView(steps: steps ?? [], bundle: .main, onBack: { viewModel.onBack() })
                }
                .padding(.top, 20)

                // ── MIDDLE (scrollable) ──
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 10)

                        switch viewModel.eventType {
                        case .onSend:
                            loadingView
                        case .onError:
                            errorView
                        case .onComplete:
                            if let model = viewModel.model {
                                header(model)
                                Spacer().frame(height: 20)
                                cards(model)
                            }
                        }

                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, 10)
                }

                // ── BOTTOM (fixed) ──
                if viewModel.eventType == .onComplete, let model = viewModel.model {
                    nextButton(model)
                }
            }
            .topBarBackLogo { viewModel.onBack() }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .modifier(InterceptSystemBack(action: { viewModel.onBack() }))
        .task { viewModel.startIfNeeded() }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: Sections

    @ViewBuilder
    private func header(_ model: DocumentCaptureModel) -> some View {
        let hasLogoHeader = !(model.svgLogoUrl ?? "").isEmpty
            && !(model.header ?? "").isEmpty
            && !(model.subHeader ?? "").isEmpty

        if hasLogoHeader {
            VStack(spacing: 0) {
                LogoSvgUrl(url: model.svgLogoUrl ?? "")
                    .frame(width: 70, height: 70)

                Text(model.header ?? "")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundColor(Color(BaseTheme.baseTextColor))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)

                Text(model.subHeader ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(BaseTheme.baseTextColor).opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 3)
                    .padding(.horizontal, 20)
            }
        } else if let header = model.header, !header.isEmpty {
            Text(header)
                .font(.system(size: 23, weight: .bold))
                .foregroundColor(Color(BaseTheme.baseTextColor))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func cards(_ model: DocumentCaptureModel) -> some View {
        ForEach(model.documentCaptures ?? [], id: \.stateKey) { doc in
            let key = doc.stateKey
            if let state = viewModel.slots[key] {
                DocumentCaptureItemView(
                    state: state,
                    onFileReady: { url, name, mime in
                        viewModel.addAndUpload(key: key, fileURL: url, name: name, mimeType: mime)
                    },
                    onPickerError: { error in
                        viewModel.setPickerError(error, key: key)
                    },
                    onRemove: { item in
                        viewModel.removeItem(key: key, item: item)
                    },
                    onRetry: { _ in
                        viewModel.retry(key: key)
                    }
                )
                Spacer().frame(height: 12)
            }
        }
    }

    @ViewBuilder
    private func nextButton(_ model: DocumentCaptureModel) -> some View {
        let title = model.nextButtonTitle ?? FlowStrings.next
        let canProceed = viewModel.canProceed

        if model.isNormalClick == true {
            BaseClickButton(title: title, verticalPadding: 18, enabled: canProceed) {
                viewModel.onNext()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        } else {
            BaseSliderClick(
                onNext: { viewModel.onNext() },
                label: title,
                icon: "checkmark",
                isActive: canProceed
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer().frame(height: UIScreen.main.bounds.height * 0.25)
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color(BaseTheme.baseTextColor))
                .scaleEffect(1.2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 40)
            Text(viewModel.errorMessage)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(BaseTheme.baseRedColor))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }
}
