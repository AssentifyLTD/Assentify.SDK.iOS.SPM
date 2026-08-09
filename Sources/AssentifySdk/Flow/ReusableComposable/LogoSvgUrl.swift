import SwiftUI
import UIKit
import SVGKit

struct LogoSvgUrl: View {
    let url: String
    var contentDescription: String? = nil

    @State private var svgImage: SVGKImage? = nil
    @State private var loadedUrl: String = ""
    @State private var loadError: Bool = false

    var body: some View {
        ZStack {
            if let svgImage {
                GeometryReader { geo in
                    SVGImageView(image: svgImage, size: geo.size)
                }
            } else if loadError {
                Image(systemName: "photo.slash")
                    .resizable()
                    .scaledToFit()
            }
        }
        .accessibilityLabel(contentDescription ?? "")
        .task(id: url) {
            await load()
        }
    }

    @MainActor
    private func load() async {
        guard !url.isEmpty, loadedUrl != url, let u = URL(string: url) else { return }

        let cacheKey = url as NSString

        if let cached = SvgImageCache.shared.object(forKey: cacheKey) {
            self.svgImage = cached
            self.loadedUrl = url
            return
        }

        do {
            let data: Data
            if let cachedData = SvgDataCache.shared.object(forKey: cacheKey) {
                data = cachedData as Data
            } else {
                let (downloaded, _) = try await URLSession.shared.data(from: u)
                SvgDataCache.shared.setObject(downloaded as NSData, forKey: cacheKey)
                data = downloaded
            }

            let parsed = try await Task.detached(priority: .userInitiated) {
                guard let svgString = String(data: data, encoding: .utf8),
                      svgString.contains("<svg") else {
                    throw URLError(.cannotDecodeContentData)
                }
                guard let img = SVGKImage(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }
                return img
            }.value

            guard !Task.isCancelled else { return }

            SvgImageCache.shared.setObject(parsed, forKey: cacheKey)
            self.svgImage = parsed
            self.loadedUrl = url

        } catch {
            loadError = true
            print("LogoSvgUrl load error: \(error)")
        }
    }
}
