import SwiftUI
import UIKit
import SVGKit

public struct SVGAssetIcon: UIViewRepresentable {

    public let name: String
    public let size: CGSize
    public let tintColor: UIColor?

    public init(name: String, size: CGSize = CGSize(width: 24, height: 24), tintColor: UIColor? = nil) {
        self.name = name
        self.size = size
        self.tintColor = tintColor
    }

    public func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        return iv
    }

    public func updateUIView(_ uiView: UIImageView, context: Context) {
        let cleanName = (name as NSString).deletingPathExtension

        guard let path = Bundle.module.path(forResource: cleanName, ofType: "svg"),
              let svg = SVGKImage(contentsOfFile: path) else {
            uiView.image = nil
            return
        }

        // Render at target size for crisp icons
        svg.size = size
        let img = svg.uiImage.withRenderingMode(.alwaysTemplate)

        uiView.image = img
        if let tintColor {
            uiView.tintColor = tintColor
        }
    }
}
