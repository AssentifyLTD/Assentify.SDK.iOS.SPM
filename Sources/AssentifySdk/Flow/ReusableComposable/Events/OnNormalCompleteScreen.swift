import SwiftUI

public struct OnNormalCompleteScreen: View {

    let imageUrl: String
    let showStper: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    var ignoresSvg: Bool = false
    let steps: [LocalStepModel] = LocalStepsObject.shared.get()

    public init(
        imageUrl: String,
        showStper: Bool  = true,
        ignoresSvg: Bool  = false,
        onNext: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self.imageUrl = imageUrl
        self.onNext = onNext
        self.showStper = showStper
        self.ignoresSvg = ignoresSvg
        self.onBack = onBack
    }

    public var body: some View {

        let accent = Color(BaseTheme.baseAccentColor)
        let text   = Color(BaseTheme.baseTextColor)

        BaseBackgroundContainer(ignoresSvg:ignoresSvg){
            VStack(spacing: 0) {

                if(showStper){
                        ProgressStepperView(
                            steps: steps,
                            bundle: .main,
                            onBack: {onBack()}
                        )
                        .padding(.top,
                                 BaseTheme.stepperType == .normal ?
                                 120 : 80)
                    
                }

                VStack(spacing: 0) {

                    Spacer().frame(height: 80)

                    ZStack {
                        SecureImage(imageUrl: imageUrl)
                            .frame(width: 300, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        SVGAssetIcon(
                            name: "ic_complete",
                            size: CGSize(width: 70, height:70),
                            tintColor: BaseTheme.baseAccentColor
                        ).frame(width: 70, height:70)
                    }
                    .frame(height: 250)

                    Spacer().frame(height: 25)

                    Text(FlowStrings.idProcessedSuccessfully)
                        .foregroundColor(text)
                        .font(.system(size: 20, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 15)

                 

                    Spacer(minLength: 0)

                   

                    BaseClickButton(
                        title: FlowStrings.next,
                        cornerRadius: 28,
                        verticalPadding: 14,
                        enabled: true,
                        action: onNext
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
