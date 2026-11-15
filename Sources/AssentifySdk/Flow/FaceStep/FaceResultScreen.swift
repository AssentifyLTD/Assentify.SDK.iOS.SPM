import SwiftUI

// MARK: - Outcome (one place for the Kotlin decision logic)

private enum FaceResultOutcome {
    case passed          // match >= threshold                         -> Next (green)
    case skippable       // below threshold, belowThresholdFlagAndPass -> Skip (accent)
    case supportingDoc   // supporting doc enabled, match >= from      -> Provide supporting ID (accent)
    case failed          // anything else                              -> Retry (red)
}

public struct FaceResultScreen: View {

    public let faceModel: FaceResponseModel
    public let onNext: (_ isSkip: Bool) -> Void
    public let onRetry: () -> Void
    public let onIDChange: () -> Void
    public let onBack: () -> Void

    let steps: [LocalStepModel] = LocalStepsObject.shared.get()

    // The face step's customization, passed in by FaceMatchStep (read once in its init)
    private let supportingDocumentEnabled: Bool
    private let passThreshold: Int
    private let supportingDocumentFrom: Int
    private let belowThresholdFlagAndPass: Bool

    public init(
        settings: FaceStepSettings,
        faceModel: FaceResponseModel,
        onNext: @escaping (_ isSkip: Bool) -> Void = { _ in },
        onRetry: @escaping () -> Void = {},
        onIDChange: @escaping () -> Void = {},
        onBack: @escaping () -> Void = {}
    ) {
        self.faceModel = faceModel
        self.onNext = onNext
        self.onRetry = onRetry
        self.onIDChange = onIDChange
        self.onBack = onBack

        // Never read getCurrentStep() here: this view is re-created on every redraw,
        // and after makeCurrentStepDone() the current step is the next one.
        self.supportingDocumentEnabled = settings.supportingDocumentEnabled
        self.passThreshold             = settings.passThreshold
        self.supportingDocumentFrom    = settings.supportingDocumentFrom
        self.belowThresholdFlagAndPass = settings.belowThresholdFlagAndPass
    }

    // MARK: - Derived data

    private var match: Int {
        faceModel.faceExtractedModel?.percentageMatch ?? 0
    }

    private var baseImage: String {
        faceModel.faceExtractedModel?.baseImageFace ?? ""
    }

    private var secondImage: String {
        faceModel.faceExtractedModel?.secondImageFace ?? ""
    }

    private var outcome: FaceResultOutcome {
        if match >= passThreshold { return .passed }
        if supportingDocumentEnabled {
            return match >= supportingDocumentFrom ? .supportingDoc : .failed
        }
        return belowThresholdFlagAndPass ? .skippable : .failed
    }

    private var isPassed: Bool { outcome == .passed }

    private var title: String {
        isPassed ? FlowStrings.verificationSuccessful : FlowStrings.verificationUnsuccessful
    }

    private var subTitle: String {
        isPassed ? FlowStrings.verificationSuccessSubtitle : FlowStrings.verificationFailSubtitle
    }

    private var borderColor: Color {
        switch outcome {
        case .passed:                    return Color(BaseTheme.baseGreenColor)
        case .skippable, .supportingDoc: return Color(BaseTheme.baseAccentColor)
        case .failed:                    return Color(BaseTheme.baseRedColor)
        }
    }

    // MARK: - Body

    public var body: some View {
        let text = Color(BaseTheme.baseTextColor)

        BaseBackgroundContainer {
            VStack(spacing: 0) {

                VStack(spacing: 0) {

                    ProgressStepperView(
                        steps: steps,
                        bundle: .main,
                        onBack: { onBack() }
                    )
                    .padding(.top, BaseTheme.stepperType == .normal ? 100 : 60)

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
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 25)

                    Spacer().frame(height: 60)

                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            faceImage(baseImage)
                            faceImage(secondImage)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 30)

                        Spacer().frame(height: 25)

                        MatchProgressView(
                            percentage: match,
                            progressColor: borderColor,
                            size: 100,
                            strokeWidth: 4
                        )
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)

                Spacer()

                bottomAction
                    .padding(.bottom, 20)
                    .padding(.horizontal, 25)
            }
            .padding(.top, 24)
        }
        .ignoresSafeArea()
    }

    private func faceImage(_ url: String) -> some View {
        let width: CGFloat = 160
        let height: CGFloat = 170
        return SecureImage(imageUrl: url)
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
            .background(Color.black.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    // MARK: - Bottom action (one button, like Kotlin)

    @ViewBuilder
    private var bottomAction: some View {
        switch outcome {
        case .passed:
            FilledButton(title: FlowStrings.next,
                         color: Color(BaseTheme.baseGreenColor),
                         action: { onNext(false) })

        case .skippable:
            FilledButton(title: FlowStrings.skip,
                         color: Color(BaseTheme.baseAccentColor),
                         action: { onNext(true) })

        case .supportingDoc:
            FilledButton(title: FlowStrings.provideSupportingId,
                         color: Color(BaseTheme.baseAccentColor),
                         action: onIDChange)

        case .failed:
            FilledButton(title: FlowStrings.retry,
                         color: Color(BaseTheme.baseRedColor),
                         action: onRetry)
        }
    }
}

// MARK: - Match Progress

public struct MatchProgressView: View {

    public let percentage: Int
    public let progressColor: Color
    public let size: CGFloat
    public let strokeWidth: CGFloat

    public init(
        percentage: Int,
        progressColor: Color,
        size: CGFloat = 100,
        strokeWidth: CGFloat = 2
    ) {
        self.percentage = max(0, min(100, percentage))
        self.progressColor = progressColor
        self.size = size
        self.strokeWidth = strokeWidth
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color(BaseTheme.baseTextColor), lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: CGFloat(percentage) / 100.0)
                .stroke(progressColor,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
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

// MARK: - Filled button (Compose Button with colored background)

private struct FilledButton: View {

    let title: String
    let color: Color
    var cornerRadius: CGFloat = 28
    var height: CGFloat = 55
    var reactivationDelay: TimeInterval = 1.0
    let action: () -> Void

    @State private var isProcessing = false

    var body: some View {
        Button(action: {
            guard !isProcessing else { return }
            isProcessing = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + reactivationDelay) {
                isProcessing = false
            }
        }) {
            Text(title)
                .font(.system(size: 16, weight: BaseTheme.baseClickFontWeight))
                .foregroundColor(Color(BaseTheme.baseSecondaryTextColor))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .contentShape(Rectangle())
        }
        .disabled(isProcessing)
    }
}
