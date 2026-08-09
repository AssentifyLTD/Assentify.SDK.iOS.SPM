import SwiftUI

public struct FaceResultScreen: View {

    public let faceModel: FaceResponseModel
    public let onNext: () -> Void
    public let onRetry: () -> Void
    public let onBack: () -> Void
    public let onIDChange: () -> Void

    let steps: [LocalStepModel] = LocalStepsObject.shared.get();

    public init(
        faceModel: FaceResponseModel,
        onNext: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {},
        onIDChange: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        self.faceModel = faceModel
        self.onNext = onNext
        self.onRetry = onRetry
        self.onIDChange = onIDChange
        self.onBack = onBack
    }

    // MARK: - Derived data (same logic as Kotlin)

    private var match: Int {
        faceModel.faceExtractedModel?.percentageMatch ?? 0
    }
    
    

    private var baseImage: String {
        faceModel.faceExtractedModel?.baseImageFace ?? ""
    }

    private var secondImage: String {
        faceModel.faceExtractedModel?.secondImageFace ?? ""
    }

    private var title: String {
        match > 50 ? FlowStrings.verificationSuccessful : FlowStrings.verificationUnsuccessful
    }

    private var subTitle: String {
        match > 50
        ? FlowStrings.verificationSuccessSubtitle
        : FlowStrings.verificationFailSubtitle
    }

    private var borderColor: Color {
        if match > 50 { return Color(BaseTheme.baseGreenColor) }
        if match > 30 { return Color(BaseTheme.baseAccentColor) }
        return Color(BaseTheme.baseRedColor)
    }

    public var body: some View {

        let text = Color(BaseTheme.baseTextColor)

        BaseBackgroundContainer {
            VStack(spacing: 0) {

                // TOP + MIDDLE CONTENT
                VStack(spacing: 0) {
                    
                        ProgressStepperView(
                            steps: steps,
                            bundle: .main,
                            onBack: {onBack()}
                        )
                        .padding(.top,
                                 BaseTheme.stepperType == .normal ?
                                 100 : 60)
                   

                    Text(title)
                        .foregroundColor(text)
                        .font(.system(size: 25, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                    Spacer().frame(height: 8)

                    Text(subTitle)
                        .foregroundColor(text)
                        .font(.system(size: 10, weight: .thin))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity).padding(.horizontal, 25)

                    Spacer().frame(height: 60)

                    VStack(spacing: 0) {

                        HStack(spacing: 0) {
                            
                            let imageWidth: CGFloat = 160
                            let imageHeight: CGFloat = 170
                            
                            HStack(spacing: 10) {
                                
                                ZStack {
                                    SecureImage(imageUrl: baseImage)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: imageWidth, height: imageHeight)
                                        .background(Color.black.opacity(0.05))
                                }
                                .frame(width: imageWidth, height: imageHeight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(borderColor, lineWidth: 1)
                                )
                                
                                ZStack {
                                    SecureImage(imageUrl: secondImage)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: imageWidth, height: imageHeight)
                                        .background(Color.black.opacity(0.05))
                                }
                                .frame(width: imageWidth, height: imageHeight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(borderColor, lineWidth: 1)
                                )
                            }
                        }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 30)


                        Spacer().frame(height: 25)

                        MatchProgressView(
                            percentage: match,
                            size: 100,
                            strokeWidth: 4
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)

                Spacer()
                bottomActions
                    .padding(.bottom, 20).padding(.horizontal, 25)
            }
            .padding(.top, 24)
        }
        .ignoresSafeArea()
    }

    // MARK: - Bottom actions

    @ViewBuilder
    private var bottomActions: some View {
        VStack(spacing: 10) {   // 👈 small clean spacing
            
            if match > 50 {
                
                BaseClickButton(
                    title: FlowStrings.next,
                    cornerRadius: 28,
                    verticalPadding: 18,
                    enabled: true,
                    action: onNext
                )

            } else if match > 30 {

                BaseClickButton(
                    title: FlowStrings.retry,
                    cornerRadius: 28,
                    verticalPadding: 18,
                    enabled: true,
                    action: onRetry
                )

                OutlineButton(
                    title: FlowStrings.confirmAndProceed,
                    cornerRadius: 28,
                    borderColor: Color(BaseTheme.baseAccentColor),
                    textColor: Color(BaseTheme.baseAccentColor),
                    height: 55,
                    action: onNext
                )

            } else {

                BaseClickButton(
                    title: FlowStrings.provideSupportingId,
                    cornerRadius: 28,
                    verticalPadding: 18,
                    enabled: true,
                    fontWeight: .bold,
                    action: onIDChange,
                )

                OutlineButton(
                    title: FlowStrings.overrideAndProceed,
                    cornerRadius: 28,
                    borderColor: Color(BaseTheme.baseRedColor),
                    textColor: Color(BaseTheme.baseRedColor),
                    height: 55,
                    action: onNext
                )
            }
        }
    }

}

// MARK: - Match Progress (SwiftUI version of Kotlin Canvas)

public struct MatchProgressView: View {

    public let percentage: Int
    public let size: CGFloat
    public let strokeWidth: CGFloat

    public init(
        percentage: Int,
        size: CGFloat = 100,
        strokeWidth: CGFloat = 2
    ) {
        self.percentage = max(0, min(100, percentage))
        self.size = size
        self.strokeWidth = strokeWidth
    }

    private var progressColor: Color {
        if percentage > 50 { return Color(BaseTheme.baseGreenColor) }
        if percentage > 30 { return Color(BaseTheme.baseAccentColor) }
        return Color(BaseTheme.baseRedColor)
    }

    private var trackColor: Color {
        Color(BaseTheme.baseTextColor)
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: CGFloat(percentage) / 100.0)
                .stroke(
                    progressColor,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(percentage)%")
                    .foregroundColor(progressColor)
                    .font(.system(size: 15, weight: .regular))

                Text(FlowStrings.matchLabel)
                    .foregroundColor(progressColor)
                    .font(.system(size: 18, weight: .regular))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Simple outline button (to match Compose border buttons)

private struct OutlineButton: View {

    let title: String
    let cornerRadius: CGFloat
    let borderColor: Color
    let textColor: Color
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .contentShape(Rectangle())
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
