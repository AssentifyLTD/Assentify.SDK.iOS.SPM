import SwiftUI

public enum SubmitDataTypes {
    public static let onSend     = "onSend"
    public static let onError    = "onError"
    public static let none       = "none"
}

// MARK: - SubmitStepScreen (SwiftUI - single view like your other screens)
public struct SubmitStepScreen: View ,SubmitDataDelegate {
    public func onSubmitError(message: String) {
        DispatchQueue.main.async {
            submitDataTypes = SubmitDataTypes.onError
        }
    }
    
    public func onSubmitSuccess() {
        
        DispatchQueue.main.async {
            HasSubmittedObject.shared.set(true)
            flowController.endFlow(flowData:flowController.getFlowCompletedList())

        }

    }
    

    public let flowController: FlowController

    @State private var submitDataTypes: String = SubmitDataTypes.none

    @State private var resetTick: Int = 0

    public init(flowController: FlowController) {
        self.flowController = flowController
    }

    public var body: some View {

        BaseBackgroundContainer {
            VStack(spacing: 0) {
                // Middle + Bottom
                VStack(spacing: 0) {

                    // =========================
                    // MIDDLE (takes remaining space)
                    // =========================
                    ZStack {
                        switch submitDataTypes {

                        case SubmitDataTypes.none , SubmitDataTypes.onSend:
                            MiddleContent(
                                title: FlowStrings.readyToSubmit,
                                message: FlowStrings.swipeToConfirm,
                                messageColor: Color(BaseTheme.baseTextColor)
                            )
                            
                        case SubmitDataTypes.onError:
                            MiddleContent(
                                title: nil,
                                message: FlowStrings.submitError,
                                messageColor: Color(BaseTheme.baseRedColor)
                            )

                       
                        default:
                            MiddleContent(
                                title: FlowStrings.readyToSubmit,
                                message: FlowStrings.swipeToConfirm,
                                messageColor: Color(BaseTheme.baseTextColor)
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)

                    // =========================
                    // BOTTOM (fixed)
                    // =========================
                    if shouldShowSwipe {
                        SwipeToSubmit(
                            text: swipeText,
                            height: 75,
                            corner: 35,
                            resetKey: resetTick,
                        ) {
                            onSubmit()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 30)
                    }
                    if(submitDataTypes == SubmitDataTypes.onSend){
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color(BaseTheme.baseTextColor)))
                           .scaleEffect(1.6) .padding(.vertical, 30)
                    }
                }
            }.topBarBackLogo(logoUrl :BaseTheme.baseLogo,noStepper: true,) {
                onBack()
            }
        } .modifier(InterceptSystemBack(action: onBack))
        .onAppear {
            // Start submit when screen appears (like Activity onCreate)

            var wrapUp: SubmitRequestModel? = nil
            let initSteps = ConfigModelObject.shared.get()!.stepDefinitions

            for item in initSteps {
                if item.stepDefinition == StepsNames.wrapUp {

                    var values: [String: String] = [:]

                    for property in item.outputProperties {
                        if property.key.contains(WrapUpKeys.timeEnded) {
                            values[property.key] = getTimeUTC()
                        }
                    }

                    wrapUp = SubmitRequestModel(
                        stepId: item.stepId,
                        stepDefinition: StepsNames.wrapUp,
                        extractedInformation: values
                    )
                    
                    flowController.trackProgress(
                        currentStep : LocalStepModel(
                            name : "",
                            description : "",
                            iconAssetPath : "",
                            isDone : false,
                            stepDefinition : item,
                            submitRequestModel : wrapUp
                        ),
                        inputData: wrapUp?.extractedInformation,
                        response: "Completed",
                        status: "Completed"
                    )

                    break
                }
            }
            
            
            
        }
        .onChange(of: submitDataTypes) { newValue in
            if newValue == SubmitDataTypes.onError {
                resetTick += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if submitDataTypes == SubmitDataTypes.onError {
                        submitDataTypes = SubmitDataTypes.none
                    }
                }
            }
        }
    }


    // MARK: - Derived
    private var shouldShowSwipe: Bool {
        if submitDataTypes == SubmitDataTypes.onSend { return false }
        if submitDataTypes == SubmitDataTypes.onError { return false }
        return true
    }

    private var swipeText: String {
         FlowStrings.swipeToSubmit
    }

    // MARK: - Actions
    private func onBack() {
        flowController.backClick()
        
    }

    private func onSubmit() {
            startSubmit()
            submitDataTypes = SubmitDataTypes.onSend
    }

    private func startSubmit() {
        AssentifySdkObject.shared.get()!.startSubmitData(
            submitDataDelegate: self,
            submitRequestModel: flowController.getSubmitList(),

        )
    }
}

// MARK: - Middle Content (Phone icon + logo + texts)
fileprivate struct MiddleContent: View {

    let title: String?
    let message: String
    let messageColor: Color

    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                
                SVGAssetIcon(
                    name: "ic_phone",
                    size: CGSize(width: 350, height: 330),
                    tintColor:BaseTheme.baseAccentColor
                )
                .frame(width: 350, height: 330)
                SecureImage(imageUrl: BaseTheme.baseLogo)
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .padding(.top, 40)
            }
            .padding(.bottom, 24)

            if let title {
                Text(title)
                    .foregroundColor(Color(BaseTheme.baseTextColor))
                    .font(.system(size: title == "THANK YOU" ? 38 : 30, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
            }

            Text(message)
                .foregroundColor(messageColor)
                .font(.system(size: 15, weight: .regular))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
    }
}


import SwiftUI

public struct SwipeToSubmit: View {

    @Environment(\.layoutDirection) private var appLayoutDirection

    public var text: String
    public var height: CGFloat
    public var corner: CGFloat
    public var resetKey: AnyHashable?
    public var onComplete: () -> Void

    @State private var dragProgress: CGFloat = 0
    @State private var knobTextWidth: CGFloat = 0
    @State private var isCompleting = false

    private var isRTL: Bool {
        appLayoutDirection == .rightToLeft
    }

    private let horizontalPadding: CGFloat = 8
    private let innerPadding: CGFloat = 6

    // The user only needs to swipe halfway.
    private let completionThreshold: CGFloat = 0.50

    public init(
        text: String = FlowStrings.swipeToSubmit,
        height: CGFloat = 75,
        corner: CGFloat = 35,
        resetKey: AnyHashable? = nil,
        onComplete: @escaping () -> Void
    ) {
        self.text = text
        self.height = height
        self.corner = corner
        self.resetKey = resetKey
        self.onComplete = onComplete
    }

    public var body: some View {
        GeometryReader { geometry in
            sliderContent(
                containerWidth: geometry.size.width,
                containerHeight: geometry.size.height
            )
        }
        .frame(height: height)
        .padding(.horizontal, horizontalPadding)
        .onChange(of: resetKey) { _ in
            resetSlider(animated: true)
        }
        .onChange(of: appLayoutDirection) { _ in
            resetSlider(animated: false)
        }
    }

    @ViewBuilder
    private func sliderContent(
        containerWidth: CGFloat,
        containerHeight: CGFloat
    ) -> some View {

        let knobHeight = max(
            0,
            height - 14
        )

        let minimumKnobWidth = max(
            0,
            (height - 12) * 2.2
        )

        let availableKnobWidth = max(
            0,
            containerWidth - ((innerPadding + horizontalPadding) * 2)
        )

        let knobWidth = min(
            availableKnobWidth,
            max(
                minimumKnobWidth,
                knobTextWidth + 32
            )
        )

        let leftPosition = innerPadding

        let rightPosition = max(
            leftPosition,
            containerWidth - innerPadding - knobWidth
        )

        let travelDistance = max(
            0,
            rightPosition - leftPosition
        )

        /*
         English:
         progress 0 = left
         progress 1 = right

         Arabic:
         progress 0 = right
         progress 1 = left
         */
        let knobLeadingX = isRTL
            ? rightPosition - (dragProgress * travelDistance)
            : leftPosition + (dragProgress * travelDistance)

        ZStack {
            arrowView

            knobView(
                width: knobWidth,
                height: knobHeight
            )
            .position(
                x: knobLeadingX + (knobWidth / 2),
                y: containerHeight / 2
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: corner
                )
            )
            .highPriorityGesture(
                dragGesture(
                    travelDistance: travelDistance
                )
            )
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(
            BaseTheme.baseClickColor?
                .toSwiftUIBackground()
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: corner
            )
        )

        // Prevent SwiftUI from mirroring the slider again.
        .environment(
            \.layoutDirection,
            .leftToRight
        )
    }

    private var arrowView: some View {
        GeometryReader { geometry in
            Image(
                systemName: isRTL
                    ? "chevron.left.2"
                    : "chevron.right.2"
            )
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(
                Color(UIColor.fromHex("#f3f4f6"))
            )
            .position(
                x: isRTL
                    ? 28                          // Arabic -> arrows on LEFT
                    : geometry.size.width - 28,   // English -> arrows on RIGHT
                y: geometry.size.height / 2
            )
        }
        .allowsHitTesting(false)
    }

    private func knobView(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        RoundedRectangle(
            cornerRadius: corner
        )
        .fill(
            Color(
                UIColor.fromHex("#f3f4f6")
            )
        )
        .shadow(
            color: Color.black.opacity(0.18),
            radius: 4,
            x: 0,
            y: 2
        )
        .frame(
            width: width,
            height: height
        )
        .overlay {
            Text(text)
                .foregroundColor(
                    Color(
                        BaseTheme.baseAccentColor
                    )
                )
                .font(
                    .system(
                        size: 15,
                        weight: .bold
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(
                    horizontal: true,
                    vertical: false
                )
                .background {
                    WidthReader(
                        width: $knobTextWidth
                    )
                    .hidden()
                }
                .padding(.horizontal, 16)
        }
    }

    private func dragGesture(
        travelDistance: CGFloat
    ) -> some Gesture {
        DragGesture(
            minimumDistance: 1,
            coordinateSpace: .local
        )
        .onChanged { value in
            guard !isCompleting else {
                return
            }

            guard travelDistance > 0 else {
                return
            }

            /*
             English:
             right movement is positive.

             Arabic:
             left movement is converted to positive.
             */
            let directionalTranslation = isRTL
                ? -value.translation.width
                : value.translation.width

            dragProgress = clamp(
                directionalTranslation / travelDistance
            )
        }
        .onEnded { value in
            guard !isCompleting else {
                return
            }

            guard travelDistance > 0 else {
                resetSlider(animated: true)
                return
            }

            let currentTranslation = isRTL
                ? -value.translation.width
                : value.translation.width

            let predictedTranslation = isRTL
                ? -value.predictedEndTranslation.width
                : value.predictedEndTranslation.width

            let currentProgress = clamp(
                currentTranslation / travelDistance
            )

            let predictedProgress = clamp(
                predictedTranslation / travelDistance
            )

            let shouldComplete =
                currentProgress >= completionThreshold ||
                predictedProgress >= 0.65

            if shouldComplete {
                completeSlider()
            } else {
                returnSliderToStart()
            }
        }
    }

    private func completeSlider() {
        guard !isCompleting else {
            return
        }

        isCompleting = true

        withAnimation(
            .easeOut(duration: 0.22)
        ) {
            dragProgress = 1
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.22
        ) {
            onComplete()
        }
    }

    private func returnSliderToStart() {
        withAnimation(
            .spring(
                response: 0.35,
                dampingFraction: 0.78
            )
        ) {
            dragProgress = 0
        }
    }

    private func resetSlider(
        animated: Bool
    ) {
        isCompleting = false

        if animated {
            withAnimation(
                .easeOut(duration: 0.20)
            ) {
                dragProgress = 0
            }
        } else {
            dragProgress = 0
        }
    }

    private func clamp(
        _ value: CGFloat
    ) -> CGFloat {
        min(
            max(value, 0),
            1
        )
    }
}

fileprivate struct WidthReader: View {

    @Binding var width: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    updateWidth(
                        geometry.size.width
                    )
                }
                .onChange(
                    of: geometry.size.width
                ) { newWidth in
                    updateWidth(newWidth)
                }
        }
    }

    private func updateWidth(
        _ newWidth: CGFloat
    ) {
        guard abs(width - newWidth) > 0.5 else {
            return
        }

        DispatchQueue.main.async {
            width = newWidth
        }
    }
}
