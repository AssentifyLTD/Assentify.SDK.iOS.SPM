import SwiftUI
import PDFKit
import UIKit

public struct BasePDFCardViewFomUrl: View {
    public let urlString: String?
    public let tintColor: UIColor
    public let onDownloadTap: (() -> Void)?
    public let onFullScreenTap: (() -> Void)?

    public init(
        urlString: String?,
        tintColor: UIColor,
        onDownloadTap: (() -> Void)? = nil,
        onFullScreenTap: (() -> Void)? = nil
    ) {
        self.urlString = urlString
        self.tintColor = tintColor
        self.onDownloadTap = onDownloadTap
        self.onFullScreenTap = onFullScreenTap
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            PDFKitURLView(urlString: urlString)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )

            HStack(spacing: 10) {
                CircleIconButton(systemName: "arrow.down", tint: tintColor) {
                    onDownloadTap?()
                }
                CircleIconButton(systemName: "arrow.up.left.and.arrow.down.right", tint: tintColor) {
                    onFullScreenTap?()
                }
            }
            .padding(12)
        }
    }
}

// MARK: - PDFKit UIViewRepresentable (Loads from URL)

public struct PDFKitURLView: UIViewRepresentable {
    public let urlString: String?

    public init(urlString: String?) {
        self.urlString = urlString
    }

    public func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.usePageViewController(true, withViewOptions: nil)
        v.backgroundColor = .clear
        return v
    }

    public func updateUIView(_ pdfView: PDFView, context: Context) {
        guard
            let s = urlString,
            let url = URL(string: s)
        else {
            pdfView.document = nil
            return
        }

        // Avoid reloading same url repeatedly
        if let loaded = (context.coordinator.currentURL), loaded == url { return }
        context.coordinator.currentURL = url

        // Load PDF (simple async)
        Task.detached {
            let doc = PDFDocument(url: url)
            await MainActor.run {
                pdfView.document = doc
            }
        }
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator {
        var currentURL: URL?
    }
}

// MARK: - Small circle button used for PDF actions

private struct CircleIconButton: View {
    let systemName: String
    let tint: UIColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(tint))
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}


public struct FullScreenPDFView: View {
    public let urlString: String?

    public init(urlString: String?) {
        self.urlString = urlString
    }

    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.03).ignoresSafeArea()

            PDFKitURLView(urlString: urlString)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
                    .padding(.top, 16)
                    .padding(.leading, 16)
            }
            .buttonStyle(.plain)
        }
    }
}

public struct ShareSheet: UIViewControllerRepresentable {
    public let items: [Any]

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    public func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
