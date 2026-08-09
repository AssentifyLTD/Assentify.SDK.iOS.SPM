import SwiftUI

public struct OnFlipCardScreen: View {

    let expectedImageUrl: String
    let onNext: () -> Void
    let onBack: () -> Void
    
    // same base as your other screens
    let steps: [LocalStepModel] = LocalStepsObject.shared.get()

    public init(
        expectedImageUrl: String,
        onNext: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        self.expectedImageUrl = expectedImageUrl
        self.onNext = onNext
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

                    Spacer().frame(height: 30)

                    Text(FlowStrings.captureBackOfId)
                        .foregroundColor(text)
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 32)

                    SVGAssetIcon(
                        name: "ic_flip_card",
                        size: CGSize(width: 200, height: 150),
                        tintColor: BaseTheme.baseAccentColor
                    )
                    .frame(width: 150, height: 150)

                    Spacer().frame(height: 25)

                    Text(FlowStrings.flipCardHint)
                        .foregroundColor(text)
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 32)

                    // ✅ Expected card section (only if not empty)
                    if !expectedImageUrl.isEmpty {

                        Spacer().frame(height: 40)

                        SecureImage(imageUrl: expectedImageUrl)
                            .scaledToFit()
                            .frame(maxWidth: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))



                        Spacer().frame(height: 10)

                        Text(FlowStrings.expectedCardType)
                            .foregroundColor(text.opacity(0.85))
                            .font(.system(size: 10, weight: .thin))
                            .multilineTextAlignment(.center)

                        Spacer().frame(height: 30)
                    }

                    Spacer(minLength: 0)

                    // ✅ Bottom button (same style you use everywhere)
                    BaseClickButton(
                        title: FlowStrings.next,
                        cornerRadius: 28,
                        verticalPadding: 14,
                        enabled: true,
                        action: onNext
                    )
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                    .padding(.top, 24)
                }
            }
        }
        .ignoresSafeArea()
    }
}
