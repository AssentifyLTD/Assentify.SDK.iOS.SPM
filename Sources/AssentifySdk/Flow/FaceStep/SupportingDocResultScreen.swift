import SwiftUI

/// Result of the supporting document: face compare + identity match.
/// Kotlin: SupportingDocResultScreen.
struct SupportingDocResultScreen: View {

    let selfieImage: String
    let supportingDocImage: String
    let faceResult: CompareFacesResponse?
    let identityResult: IdentityMatchResponse?
    let onNext: (_ isSkip: Bool) -> Void
    let onRetry: () -> Void
    let onBack: () -> Void

    @State private var steps: [LocalStepModel] = LocalStepsObject.shared.get()
    private let passThreshold: Int
    private let allowSkip: Bool

    init(
        settings: FaceStepSettings,
        selfieImage: String,
        supportingDocImage: String,
        faceResult: CompareFacesResponse?,
        identityResult: IdentityMatchResponse?,
        onNext: @escaping (_ isSkip: Bool) -> Void,
        onRetry: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self.selfieImage = selfieImage
        self.supportingDocImage = supportingDocImage
        self.faceResult = faceResult
        self.identityResult = identityResult
        self.onNext = onNext
        self.onRetry = onRetry
        self.onBack = onBack

        // Never read getCurrentStep() here: this view is re-created on every redraw,
        // and after makeCurrentStepDone() the current step is the next one.
        self.passThreshold = settings.passThreshold
        self.allowSkip = settings.supportingDocumentAllowSkip
    }

    // MARK: - Derived data (same logic as Kotlin)

    private var match: Int { faceResult?.matchScore ?? 0 }
    private var isFaceMatched: Bool { match >= passThreshold }
    private var isSamePerson: Bool { identityResult?.samePerson == true }
    private var isPassed: Bool { isFaceMatched && isSamePerson }

    private var title: String {
        isPassed ? FlowStrings.verificationSuccessful : FlowStrings.verificationUnsuccessful
    }

    private var subTitle: String {
        isPassed ? FlowStrings.verificationSuccessSubtitle : FlowStrings.verificationFailSubtitle
    }

    private var borderColor: Color {
        isPassed ? Color(BaseTheme.baseGreenColor) : Color(BaseTheme.baseRedColor)
    }

    /// The message under the progress circle, one per status.
    private var statusMessage: String {
        switch (isFaceMatched, isSamePerson) {
        case (true, true):   return FlowStrings.supportingDocPassedMsg
        case (false, true):  return FlowStrings.supportingDocFaceNoMatchMsg
        case (true, false):  return FlowStrings.supportingDocIdentityMismatchMsg
        case (false, false): return FlowStrings.supportingDocBothFailedMsg
        }
    }

    // MARK: - Body

    var body: some View {
        let text = Color(BaseTheme.baseTextColor)

        BaseBackgroundContainer {
            VStack(spacing: 0) {

                ProgressStepperView(steps: steps, bundle: .main, onBack: { onBack() })
                    .padding(.top, BaseTheme.stepperType == .normal ? 100 : 60)

                // TOP + MIDDLE (scrollable)
                ScrollView {
                    VStack(spacing: 0) {

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

                        Spacer().frame(height: 32)

                        HStack(spacing: 10) {
                            documentImage(selfieImage)
                            documentImage(supportingDocImage)
                        }
                        .frame(maxWidth: .infinity)

                        Spacer().frame(height: 25)

                        MatchProgressView(
                            percentage: match,
                            progressColor: borderColor,
                            size: 100,
                            strokeWidth: 4
                        )
                        .frame(maxWidth: .infinity, alignment: .center)

                        Spacer().frame(height: 16)

                        Text(statusMessage)
                            .foregroundColor(text)
                            .font(.system(size: 13, weight: .medium))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 25)

                        Spacer().frame(height: 24)
                    }
                }

                // BOTTOM ACTIONS (always visible)
                VStack(spacing: 8) {
                    actions
                }
                .padding(.top, 12)
                .padding(.horizontal, 25)
                .padding(.bottom, 20)
            }
            .padding(.top, 24)
        }.onAppear { self.steps = LocalStepsObject.shared.get() }
        .ignoresSafeArea()
    }

    private func documentImage(_ url: String) -> some View {
        SecureImage(imageUrl: url)
            .aspectRatio(contentMode: .fit)
            .frame(width: 120, height: 140)
            .background(Color.black.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    @ViewBuilder
    private var actions: some View {
        if isPassed {
            // 1) Score >= threshold AND same person
            SupportingResultButton(title: FlowStrings.next, color: Color(BaseTheme.baseGreenColor)) {
                onNext(false)
            }
        } else {
            // 2) Score below threshold OR not the same person
            SupportingResultButton(title: FlowStrings.retry, color: Color(BaseTheme.baseRedColor), action: onRetry)

            // 3) Same failure, but skipping is allowed
            if allowSkip {
                SupportingResultButton(title: FlowStrings.skip, color: Color(BaseTheme.baseAccentColor)) {
                    onNext(true)
                }
            }
        }
    }
}

// MARK: - Filled button (Compose ResultButton)

private struct SupportingResultButton: View {

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
