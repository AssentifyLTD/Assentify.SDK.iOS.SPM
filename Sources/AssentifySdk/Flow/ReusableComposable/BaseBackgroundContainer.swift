import SwiftUI
import UIKit
import SVGKit


public extension BackgroundStyle {

    func toSwiftUIBackground() -> AnyView {
        switch self {
        case .solid(let hex):
            return AnyView(Color(UIColor.fromHex(hex)))

        case .gradient(let colorsHex, let angleDegrees, let holdUntil):
            let first = Color(UIColor.fromHex(colorsHex.first ?? "#000000"))
            let last  = Color(UIColor.fromHex(colorsHex.last ?? "#000000"))

            let t = max(0, min(1, holdUntil))

            let stops: [Gradient.Stop] = [
                .init(color: first, location: 0.0),
                .init(color: first, location: t),
                .init(color: last,  location: 1.0)
            ]

            let (start, end): (UnitPoint, UnitPoint) = {
                if angleDegrees == 90 {
                    return (.top, .bottom)
                } else if angleDegrees == 0 {
                    return (.leading, .trailing)
                } else {
                    return (.topLeading, .bottomTrailing)
                }
            }()

            return AnyView(
                LinearGradient(gradient: Gradient(stops: stops), startPoint: start, endPoint: end)
            )
        }
    }

    func firstUIColor() -> UIColor {
        switch self {
        case .solid(let hex):
            return UIColor.fromHex(hex)
        case .gradient(let colorsHex, _, _):
            return UIColor.fromHex(colorsHex.first ?? "#000000")
        }
    }
}

struct BaseBackgroundContainer<Content: View>: View {
    let content: () -> Content
    var ignoresSvg: Bool = false
    
    var body: some View {
        switch BaseTheme.baseBackgroundType {
        case .color:
            ZStack {
                if let bg = BaseTheme.backgroundColor {
                    bg.toSwiftUIBackground()
                        .ignoresSafeArea()

                } else {
                    Color.clear.ignoresSafeArea()
                }
                content()
            }

        case .image:
            if(ignoresSvg){
                content()
            }else{
                SvgUrlBackground(url: BaseTheme.baseBackgroundUrl) {
                    AnyView(content())
                }
            }
            
        }
    }
}



final class SvgDataCache {
    static let shared = NSCache<NSString, NSData>()
}

final class SvgImageCache {
    static let shared = NSCache<NSString, SVGKImage>()
}
struct SvgUrlBackground: View {
    let url: String
    let content: () -> AnyView

    @State private var svgImage: SVGKImage?
    @State private var loadedUrl: String = ""

    var body: some View {
        ZStack {
            if let svgImage {
                GeometryReader { geo in
                    SVGImageView(image: svgImage, size: geo.size)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            content()
        }
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
                print("SVG parsed size: \(img.size)")
                return img
            }.value

            guard !Task.isCancelled else { return }

            SvgImageCache.shared.setObject(parsed, forKey: cacheKey)
            self.svgImage = parsed
            self.loadedUrl = url

        } catch {
            print("SvgUrlBackground load error: \(error)")
        }
    }
}

struct SVGImageView: UIViewRepresentable {
    let image: SVGKImage
    let size: CGSize

    func makeUIView(context: Context) -> SVGKFastImageView {
        image.size = size
        let view = SVGKFastImageView(svgkImage: image) ?? SVGKFastImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: SVGKFastImageView, context: Context) {
        image.size = size
        uiView.image = image
        uiView.contentMode = .scaleAspectFill
    }
}
