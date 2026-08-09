import SwiftUI

public struct SecureImage: View {
    let imageUrl: String

    public init(imageUrl: String) {
        self.imageUrl = imageUrl
    }

    public var body: some View {
        AsyncImage(url: URL(string: imageUrl)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(BaseTheme.fieldColor))
                    .overlay(
                        ProgressView().tint(Color(BaseTheme.baseAccentColor))
                    )
            }
        }
        .clipped()
    }
}
