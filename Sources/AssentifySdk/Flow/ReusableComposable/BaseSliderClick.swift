import SwiftUI

public struct BaseSliderClick: View {

    @Environment(\.layoutDirection)
    private var appLayoutDirection

    public let onNext: () -> Void
    public let label: String
    public let icon: String
    public let isActive: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var trackWidth: CGFloat = 0
    @State private var isCompleting = false

    private let sliderHeight: CGFloat = 54
    private let knobSize: CGFloat = 53
    private let knobPadding: CGFloat = 0

    private let completionThreshold: CGFloat = 0.60
    private let predictedThreshold: CGFloat = 0.75
    private let completionDuration: Double = 0.22

    private var isRTL: Bool {
        appLayoutDirection == .rightToLeft
    }

    private var knobRadius: CGFloat {
        knobSize / 2
    }

    private var maximumOffset: CGFloat {
        max(
            0,
            trackWidth
                - knobSize
                - (knobPadding * 2)
        )
    }

    private var knobCenterX: CGFloat {
        if isRTL {
            return trackWidth
                - knobPadding
                - knobRadius
                - dragOffset
        } else {
            return knobPadding
                + knobRadius
                + dragOffset
        }
    }

    public init(
        onNext: @escaping () -> Void,
        label: String,
        icon: String,
        isActive: Bool = true
    ) {
        self.onNext = onNext
        self.label = label
        self.icon = icon
        self.isActive = isActive
    }

    public var body: some View {
        ZStack {
            trackBackground
            progressFill
            labelView
            arrowView
            knobView
        }
        .frame(height: sliderHeight)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        updateTrackWidth(
                            geometry.size.width
                        )
                    }
                    .onChange(of: geometry.size.width) { newWidth in
                        updateTrackWidth(newWidth)
                    }
            }
        }
        .highPriorityGesture(dragGesture)
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .onChange(of: appLayoutDirection) { _ in
            resetSlider(animated: false)
        }
        .onChange(of: isActive) { active in
            if !active {
                resetSlider(animated: true)
            }
        }
    }

    // MARK: - Track

    private var trackBackground: some View {
        Capsule()
            .fill(
                Color(BaseTheme.fieldColor)
                    .opacity(isActive ? 1 : 0.4)
            )
    }

    // MARK: - Progress Fill

    private var progressFill: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width

            if isRTL {
                rtlProgressFill(
                    totalWidth: totalWidth
                )
            } else {
                ltrProgressFill(
                    totalWidth: totalWidth
                )
            }
        }
        .opacity(isActive ? 1 : 0.4)
        .allowsHitTesting(false)
    }

    private func ltrProgressFill(
        totalWidth: CGFloat
    ) -> some View {

        let circleCenterX = min(
            max(
                knobCenterX,
                knobRadius
            ),
            totalWidth - knobRadius
        )

        let fillWidth = min(
            totalWidth,
            circleCenterX + knobRadius
        )

        return ZStack(alignment: .leading) {

            themedRectangle
                .frame(
                    width: fillWidth,
                    height: knobSize
                )
                .position(
                    x: fillWidth / 2,
                    y: sliderHeight / 2
                )

            themedCircle
                .frame(
                    width: knobSize,
                    height: knobSize
                )
                .position(
                    x: circleCenterX,
                    y: sliderHeight / 2
                )
        }
        .frame(
            width: totalWidth,
            height: sliderHeight,
            alignment: .leading
        )
    }

    private func rtlProgressFill(
        totalWidth: CGFloat
    ) -> some View {

        let circleCenterX = min(
            max(
                knobCenterX,
                knobRadius
            ),
            totalWidth - knobRadius
        )

        let fillStartX = max(
            0,
            circleCenterX - knobRadius
        )

        let fillWidth = max(
            0,
            totalWidth - fillStartX
        )

        return ZStack(alignment: .leading) {

            themedRectangle
                .frame(
                    width: fillWidth,
                    height: knobSize
                )
                .position(
                    x: fillStartX + (fillWidth / 2),
                    y: sliderHeight / 2
                )

            themedCircle
                .frame(
                    width: knobSize,
                    height: knobSize
                )
                .position(
                    x: circleCenterX,
                    y: sliderHeight / 2
                )
        }
        .frame(
            width: totalWidth,
            height: sliderHeight,
            alignment: .leading
        )
    }

    // MARK: - Theme Views

    private var themedRectangle: some View {
        Rectangle()
            .fill(Color.clear)
            .background {
                clickBackground
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: knobRadius
                )
            )
    }

    private var themedCircle: some View {
        Circle()
            .fill(Color.clear)
            .background {
                clickBackground
            }
            .clipShape(Circle())
    }

    @ViewBuilder
    private var clickBackground: some View {
        if let background = BaseTheme.baseClickColor {
            background.toSwiftUIBackground()
        } else {
            Color.clear
        }
    }

    // MARK: - Label

    private var labelView: some View {
        Text(label)
            .font(
                .system(
                    size: 18,
                    weight: .bold
                )
            )
            .foregroundStyle(
                Color(BaseTheme.baseTextColor)
                    .opacity(isActive ? 1 : 0.4)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(
                .horizontal,
                knobSize + 28
            )
            .allowsHitTesting(false)
    }

    // MARK: - Arrows

    private var arrowView: some View {
        GeometryReader { geometry in
            Image(
                systemName: isRTL
                    ? "chevron.left.2"
                    : "chevron.right.2"
            )
            .resizable()
            .scaledToFit()
            .frame(
                width: 15,
                height: 15
            )
            .foregroundStyle(
                Color(BaseTheme.baseTextColor)
                    .opacity(isActive ? 0.5 : 0.2)
            )
            .position(
                x: isRTL
                    ? 22
                    : geometry.size.width - 22,
                y: geometry.size.height / 2
            )
        }
        .allowsHitTesting(false)
    }

    // MARK: - Knob

    private var knobView: some View {
        ZStack {
            themedCircle
                .opacity(isActive ? 1 : 0.4)

            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(
                    width: 19,
                    height: 19
                )
                .foregroundStyle(
                    Color(BaseTheme.fieldColor)
                        .opacity(isActive ? 1 : 0.4)
                )
        }
        .frame(
            width: knobSize,
            height: knobSize
        )
        .position(
            x: knobCenterX,
            y: sliderHeight / 2
        )
        .contentShape(Circle())
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(
            minimumDistance: 1,
            coordinateSpace: .local
        )
        .onChanged { value in
            guard isActive else {
                return
            }

            guard !isCompleting else {
                return
            }

            guard maximumOffset > 0 else {
                return
            }

            let translation = isRTL
                ? -value.translation.width
                : value.translation.width

            dragOffset = clampOffset(
                translation
            )
        }
        .onEnded { value in
            guard isActive else {
                return
            }

            guard !isCompleting else {
                return
            }

            guard maximumOffset > 0 else {
                resetSlider(animated: true)
                return
            }

            let currentTranslation = isRTL
                ? -value.translation.width
                : value.translation.width

            let predictedTranslation = isRTL
                ? -value.predictedEndTranslation.width
                : value.predictedEndTranslation.width

            let currentProgress =
                clampOffset(currentTranslation)
                / maximumOffset

            let predictedProgress =
                clampOffset(predictedTranslation)
                / maximumOffset

            let shouldComplete =
                currentProgress >= completionThreshold ||
                predictedProgress >= predictedThreshold

            if shouldComplete {
                completeSlider()
            } else {
                resetSlider(animated: true)
            }
        }
    }

    // MARK: - Complete

    private func completeSlider() {
        guard !isCompleting else {
            return
        }

        isCompleting = true

        withAnimation(
            .easeOut(
                duration: completionDuration
            )
        ) {
            dragOffset = maximumOffset
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + completionDuration
        ) {
            onNext()
            resetSlider(animated: false)
        }
    }

    // MARK: - Reset

    private func resetSlider(
        animated: Bool
    ) {
        isCompleting = false

        if animated {
            withAnimation(
                .spring(
                    response: 0.38,
                    dampingFraction: 0.78
                )
            ) {
                dragOffset = 0
            }
        } else {
            dragOffset = 0
        }
    }

    // MARK: - Helpers

    private func updateTrackWidth(
        _ newWidth: CGFloat
    ) {
        guard abs(trackWidth - newWidth) > 0.5 else {
            return
        }

        trackWidth = newWidth

        dragOffset = min(
            dragOffset,
            maximumOffset
        )
    }

    private func clampOffset(
        _ value: CGFloat
    ) -> CGFloat {
        min(
            max(value, 0),
            maximumOffset
        )
    }
}
