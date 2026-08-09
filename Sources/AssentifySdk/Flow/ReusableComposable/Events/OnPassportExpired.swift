import SwiftUI

public struct OnPassportExpired: View {

    let imageUrl: String
    let onRetry: () -> Void
    let onBack: () -> Void

    let steps: [LocalStepModel] = LocalStepsObject.shared.get()

    public init(
        imageUrl: String,
        onRetry: @escaping () -> Void,
        onBack: @escaping () -> Void,
    ) {
        self.imageUrl = imageUrl
        self.onRetry = onRetry
        self.onBack = onBack
    }

    public var body: some View {

        let accent = Color(BaseTheme.baseAccentColor)
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
                        SecureImage(imageUrl: imageUrl)
                            .frame(width: 300, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        SVGAssetIcon(
                            name: "ic_error",
                            size: CGSize(width: 70, height:70),
                            tintColor: BaseTheme.baseAccentColor
                        ).frame(width: 70, height:70)
                    }
                    .frame(height: 250)

                    Spacer().frame(height: 25)

                    Text(FlowStrings.expiredPassport)
                        .foregroundColor(text)
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 15)

                    Text(FlowStrings.expiredPassportHint)
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
