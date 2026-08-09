import SwiftUI
import CryptoKit
import PDFKit
import UIKit
import PencilKit

// =======================================================
// - Inline preview (renders page 0 to UIImage)
// - Fullscreen (PDFKit PDFView)
// - Download/share (exports cached temp pdf via ShareSheet)
// =======================================================
public struct PdfViewerFromBase64: View {
    public let base64Data: String
    public var cornerRadius: CGFloat = 12

    @State private var pdfFileURL: URL? = nil
    @State private var previewImage: UIImage? = nil
    @State private var isLoading: Bool = true
    @State private var showFullScreen: Bool = false
    @State private var showShare: Bool = false

    @State private var loadTask: Task<Void, Never>? = nil

    public init(base64Data: String, cornerRadius: CGFloat = 12) {
        self.base64Data = base64Data
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {

            content
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                )

            HStack(spacing: 10) {
                CircleIconButton(systemName: "arrow.down", tint: BaseTheme.baseTextColor) {
                    guard pdfFileURL != nil else { return }
                    showShare = true
                }
                CircleIconButton(systemName: "arrow.up.left.and.arrow.down.right", tint: BaseTheme.baseTextColor) {
                    guard pdfFileURL != nil else { return }
                    showFullScreen = true
                }
            }
            .padding(10)
        }
        .onAppear { load() }
        .onChange(of: base64Data) { _ in load() }
        .onDisappear { loadTask?.cancel() }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: pdfFileURL.map { [$0] } ?? [])
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenPDFView(urlString: pdfFileURL?.absoluteString)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ZStack {
                Color.white
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color(BaseTheme.baseTextColor))
            }
        } else if let img = previewImage {
            GeometryReader { geo in
                  Image(uiImage: img)
                      .resizable()
                      .scaledToFit() // ✅ fit is better for PDFs
                      .frame(width: geo.size.width, height: geo.size.height)
                      .background(Color.white)
              }
        } else {
            ZStack {
                Color.white
                Text(FlowStrings.failedToLoadPdf)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(BaseTheme.baseRedColor))
            }
        }
    }

    private func load() {
        // cancel any previous work
        loadTask?.cancel()

        isLoading = true
        previewImage = nil
        pdfFileURL = nil

        let rawBase64 = base64Data

        loadTask = Task {
            let cleaned = rawBase64
                .replacingOccurrences(of: "data:application/pdf;base64,", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !Task.isCancelled else { return }

            guard let data = Data(base64Encoded: cleaned, options: [.ignoreUnknownCharacters]) else {
                await MainActor.run { self.isLoading = false }
                return
            }

            guard !Task.isCancelled else { return }

            // ✅ stable filename based on SHA256 of bytes
            let fileName = "temp_pdf_\(sha256Hex(data)).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            do {
                // overwrite if exists
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
                try data.write(to: url, options: [.atomic])
            } catch {
                await MainActor.run { self.isLoading = false }
                return
            }

            guard !Task.isCancelled else { return }

            // Render first page preview (off-main is fine)
            let img = renderFirstPage(from: url)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.pdfFileURL = url
                self.previewImage = img
                self.isLoading = false
            }
        }
    }

    private func renderFirstPage(from fileURL: URL) -> UIImage? {
        guard let doc = PDFDocument(url: fileURL),
              let page = doc.page(at: 0) else { return nil }

        // ✅ Use cropBox (usually removes the huge margins)
        let pageRect = page.bounds(for: .cropBox)

        let targetWidth: CGFloat = 1200
        let scale = targetWidth / max(1, pageRect.width)
        let targetSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))

            ctx.cgContext.saveGState()

            // Move origin & flip
            ctx.cgContext.translateBy(x: 0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)

            // ✅ Draw using cropBox, and translate by cropBox origin
            ctx.cgContext.translateBy(x: -pageRect.minX, y: -pageRect.minY)
            page.draw(with: .cropBox, to: ctx.cgContext)

            ctx.cgContext.restoreGState()
        }
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
// Small circle button (same as you used in BasePDFCardViewFomUrl)
fileprivate struct CircleIconButton: View {
    let systemName: String
    let tint: UIColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(tint))
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// =======================================================
// MARK: - SignaturePad (Swift) using PencilKit
// - Draw with finger
// - Confirm => exports PNG with WHITE background + BLACK strokes
// - Gives base64 PNG (NO_WRAP style)
// =======================================================
import SwiftUI
import PencilKit

public struct SignaturePad: View {

    public var title: String = "Signature"
    var isLoading: Bool = false
    public let onConfirmBase64: (String) -> Void

    @State private var canvas = PKCanvasView()
    @State private var hasSignature: Bool = false

    private enum ConfirmState: Equatable {
        case idle
        case expanding
        case confirmed
    }
    @State private var confirmState: ConfirmState = .idle

    private let pillAnimDuration: TimeInterval = 0.45

    private let cardHeight: CGFloat = 190
    private let pillCollapsedWidth: CGFloat = 52

    public init(title: String = "Signature",isLoading:Bool, onConfirmBase64: @escaping (String) -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.onConfirmBase64 = onConfirmBase64
    }

    public var body: some View {

        GeometryReader { geo in
            let padWidth = geo.size.width

            ZStack(alignment: .topTrailing) {

                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.10))

                if isLoading {
                    ZStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color(BaseTheme.baseTextColor))
                            .scaleEffect(1.2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }else{
                    VStack(alignment: .leading, spacing: 10) {
                        
                        HStack {
                            Text(title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(BaseTheme.baseTextColor))
                            Spacer()
                        }
                        .padding(.top, 12)
                        .padding(.horizontal, 14)
                        .opacity(confirmState == .confirmed ? 0 : 1)
                        .animation(.easeInOut(duration: 0.2), value: confirmState)

                        PencilCanvasView(
                            canvas: $canvas,
                            hasSignature: $hasSignature,
                            isEnabled: confirmState == .idle
                        )
                        .frame(height: 180)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                    .padding(.trailing, 12)

                    // ✅ Confirm pill: NO padding BEFORE and AFTER (touches edges always)
                    confirmControl(padWidth: padWidth, cardHeight: cardHeight)
                }
                
            }
            .frame(width: padWidth, height: cardHeight, alignment: .topTrailing)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
        }
        .frame(height: cardHeight)
    }

    // MARK: - Confirm Control (touch edges before & after + solid color when confirmed)
    private func confirmControl(padWidth: CGFloat, cardHeight: CGFloat) -> some View {

        let isExpanded = (confirmState == .expanding || confirmState == .confirmed)

        let targetWidth: CGFloat = isExpanded ? padWidth : pillCollapsedWidth
        let targetHeight: CGFloat = cardHeight

        // ✅ Color behavior:
        // - Before confirm: normal accent
        // - During expanding: normal accent
        // - After animation (confirmed): SOLID accent (no opacity)
        let fillColor: Color = {
            if confirmState == .confirmed {
                return Color(BaseTheme.baseAccentColor) // ✅ solid
            }
            return hasSignature
                ? Color(BaseTheme.baseAccentColor)     // normal
                : Color(BaseTheme.fieldColor)
        }()

        return Button {
            guard hasSignature, confirmState == .idle else { return }

            let b64 = exportBase64BlackOnWhite(canvas: canvas)
            onConfirmBase64(b64)

            withAnimation(.spring(response: pillAnimDuration, dampingFraction: 0.85)) {
                confirmState = .expanding
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + pillAnimDuration) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    confirmState = .confirmed
                }
            }

        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(fillColor) // ✅ solid when confirmed

                Text(confirmState == .confirmed ? FlowStrings.confirmed : FlowStrings.confirm)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(BaseTheme.baseTextColor))
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .animation(.spring(response: pillAnimDuration, dampingFraction: 0.85), value: isExpanded)
            }
            .frame(width: targetWidth, height: targetHeight)
            .animation(.spring(response: pillAnimDuration, dampingFraction: 0.85), value: isExpanded)

            // ✅ NO padding at all, always touches card edges
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .buttonStyle(.plain)
        .disabled(!hasSignature || confirmState != .idle)
    }

    private func exportBase64BlackOnWhite(canvas: PKCanvasView) -> String {
        let drawing = canvas.drawing
        let bounds = drawing.bounds.isEmpty
            ? CGRect(x: 0, y: 0, width: canvas.bounds.width, height: canvas.bounds.height)
            : drawing.bounds.insetBy(dx: -2, dy: -2) // small padding so strokes aren’t clipped

        let scale: CGFloat = 2.0
        let img = drawing.image(from: bounds, scale: scale)

        let outSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: outSize)

        let final = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: outSize)

            // 1) White background
            UIColor.white.setFill()
            ctx.fill(rect)

            // 2) Fill BLACK only where the signature pixels are (mask)
            if let mask = img.cgImage {
                ctx.cgContext.saveGState()
                ctx.cgContext.clip(to: rect, mask: mask)
                UIColor.black.setFill()
                ctx.fill(rect)
                ctx.cgContext.restoreGState()
            }
        }

        return (final.pngData() ?? Data()).base64EncodedString()
    }
}


fileprivate struct PencilCanvasView: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    @Binding var hasSignature: Bool
    let isEnabled: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput

        // keep pen white on screen
        let ink = PKInk(.pen, color: .white)
        canvas.tool = PKInkingTool(ink: ink, width: 4)

        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = isEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hasSignature: $hasSignature)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var hasSignature: Bool
        init(hasSignature: Binding<Bool>) { _hasSignature = hasSignature }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            hasSignature = !canvasView.drawing.strokes.isEmpty
        }
    }
}
