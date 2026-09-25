import SwiftUI

public struct SecureImage: View {
    let imageUrl: String
    let apiKey: String

    @State private var uiImage: UIImage?
    @State private var isLoading = true

    public init(imageUrl: String) {
        self.imageUrl = imageUrl
        self.apiKey = ApiKeyObject.shared.get()!
    }

    public var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(BaseTheme.fieldColor))
                    .overlay(
                        Group {
                            if isLoading {
                                ProgressView().tint(Color(BaseTheme.baseAccentColor))
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(Color(BaseTheme.baseAccentColor))
                            }
                        }
                    )
            }
        }
        .clipped()
        .task(id: imageUrl) {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true
        uiImage = nil

        guard let url = URL(string: imageUrl) else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")

        do {
            let (data, response) = try await BlobSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let image = UIImage(data: data) else {
                isLoading = false
                return
            }
            uiImage = image
        } catch {
            // Request cancelled or failed; the placeholder stays visible
        }
        isLoading = false
    }
}
