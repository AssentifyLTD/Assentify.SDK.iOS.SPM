import SwiftUI

public struct OnWrongTemplateScreen: View {

    let imageUrl: String
    let expectedImageUrl: String
    let onRetry: () -> Void
    let onBack: () -> Void

    // same as your base screen
    let steps: [LocalStepModel] = LocalStepsObject.shared.get()

    public init(
        imageUrl: String,
        expectedImageUrl: String,
        onRetry: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        self.imageUrl = imageUrl
        self.expectedImageUrl = expectedImageUrl
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

                    // MAIN IMAGE + ICON OVERLAY (same style as OnLivenessScreen)
                    ZStack {
                        SecureImage(imageUrl: imageUrl)
                            .frame(width: 300, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        SVGAssetIcon(
                            name: "ic_wrong_template",
                            size: CGSize(width: 70, height: 70),
                            tintColor: BaseTheme.baseAccentColor
                        )
                        .frame(width: 70, height: 70)
                    }
                    .frame(height: 250)

                    Spacer().frame(height: 25)

                    Text(FlowStrings.wrongTemplate)
                        .foregroundColor(text)
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 15)

                    Text(FlowStrings.wrongTemplateHint(flowName: ConfigModelObject.shared.get()!.flowName))
                        .foregroundColor(text.opacity(0.85))
                        .font(.system(size: 10, weight: .thin))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)

                    // ✅ Expected card section (only if expectedImageUrl not empty)
                    if !expectedImageUrl.isEmpty {

                        Spacer().frame(height: 30)

                        SecureImage(imageUrl: expectedImageUrl)
                            .frame(width: 300, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Spacer().frame(height: 10)

                        Text(FlowStrings.expectedCardType)
                            .foregroundColor(text.opacity(0.9))
                            .font(.system(size: 10, weight: .light))
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: 30)
                    }

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
