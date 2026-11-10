import SwiftUI

/// The liveness failed.
///  - image:    the document as the phone's camera saw it (local liveness: suspected copy / inconclusive / stalled)
///  - imageUrl: the server's image, shown when image is nil (server liveness failure)
public struct OnLivenessScreen: View {

    let imageUrl: String
    let image: UIImage?
    let onRetry: () -> Void
    let onBack: () -> Void
    let steps: [LocalStepModel] = LocalStepsObject.shared.get()

    public init(
        imageUrl: String,
        image: UIImage? = nil,
        onRetry: @escaping () -> Void,
        onBack: @escaping () -> Void,
    ) {
        self.imageUrl = imageUrl
        self.image = image
        self.onRetry = onRetry
        self.onBack = onBack
    }

    public var body: some View {

        let text   = Color(BaseTheme.baseTextColor)

        BaseBackgroundContainer {
            VStack(spacing: 0) {
                    ProgressStepperView(
                        steps: steps,
                        bundle: .main,
                        onBack: {onBack()}
                    )
                    .padding(.top,
                             BaseTheme.stepperType == .normal ?
                             120 : 80)


                VStack(spacing: 0) {

                    Spacer().frame(height: 80)

                    ZStack {
                        if let local = image {
                            // the local liveness: the camera's image
                            Image(uiImage: local)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 300, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            // the server: its image URL
                            SecureImage(imageUrl: imageUrl)
                                .frame(width: 300, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        SVGAssetIcon(
                            name: "ic_error",
                            size: CGSize(width: 70, height:70),
                            tintColor: BaseTheme.baseAccentColor
                        ).frame(width: 70, height:70)
                    }
                    .frame(height: 250)

                    Spacer().frame(height: 25)

                    Text(FlowStrings.notRealId)
                        .foregroundColor(text)
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 15)

                    Text(FlowStrings.wrongTemplateHint(flowName: ConfigModelObject.shared.get()!.flowName))
                        .foregroundColor(text.opacity(0.85))
                        .font(.system(size: 10, weight: .thin))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)

                    Spacer(minLength: 0)

                    BaseClickButton(
                        title: FlowStrings.retry,
                        cornerRadius: 28,
                        verticalPadding: 14,
                        enabled: true,
                        action: onRetry
                    )
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                    .padding(.top, 24)
                }
            }
        }
        .ignoresSafeArea()
    }
}
