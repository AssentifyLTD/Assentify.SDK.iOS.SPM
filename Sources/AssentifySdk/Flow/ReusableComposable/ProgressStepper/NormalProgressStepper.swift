import SwiftUI
import UIKit
import SVGKit

// MARK: - Theme


// MARK: - Main View

public struct NormalProgressStepper: View {

    private let steps: [LocalStepModel]
    private let theme: StepperTheme = StepperTheme()
    private let bundle: Bundle

    private let nodeSize: CGFloat
    private let ringWidth: CGFloat
    private let gapWidth: CGFloat
    private let dashLength: CGFloat
    private let dashGap: CGFloat
    private let connectorLength: CGFloat
    private let connectorThickness: CGFloat
    private let itemSpacing: CGFloat

    public init(
        steps: [LocalStepModel],
        bundle: Bundle,
        nodeSize: CGFloat = 50,
        ringWidth: CGFloat = 2,
        gapWidth: CGFloat = 3,
        dashLength: CGFloat = 12,
        dashGap: CGFloat = 10,
        connectorLength: CGFloat = 15,
        connectorThickness: CGFloat = 2,
        itemSpacing: CGFloat = 12
    ) {
        self.steps = steps.filter { $0.show }
        self.bundle = bundle
        self.nodeSize = nodeSize
        self.ringWidth = ringWidth
        self.gapWidth = gapWidth
        self.dashLength = dashLength
        self.dashGap = dashGap
        self.connectorLength = connectorLength
        self.connectorThickness = connectorThickness
        self.itemSpacing = itemSpacing
    }

    private var activeIndex: Int {
        guard !steps.isEmpty else { return 0 }
        let idx = steps.firstIndex(where: { !$0.isDone }) ?? (steps.count - 1)
        return max(0, min(idx, steps.count - 1))
    }

    public var body: some View {
        VStack(spacing: 0) {

            GeometryReader { geo in
                let totalWidth =
                    (CGFloat(steps.count) * nodeSize) +
                    (CGFloat(max(0, steps.count - 1)) * connectorLength) +
                    (CGFloat(steps.count + 1) * itemSpacing)

                let isScrollable = totalWidth > geo.size.width
                let vPad = max(2, ringWidth) // ✅ prevent top/bottom clipping

                Group {
                    if isScrollable {
                        ScrollView(.horizontal, showsIndicators: false) {
                            stepperRow
                                .padding(.horizontal, itemSpacing / 2)
                                .padding(.vertical, vPad)
                        }
                        .frame(height: nodeSize + (vPad * 2))
                    } else {
                        stepperRow
                            .padding(.horizontal, itemSpacing / 2)
                            .padding(.vertical, vPad)
                            .frame(height: nodeSize + (vPad * 2))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .frame(height: nodeSize + (max(2, ringWidth) * 2))

            Text(FlowStrings.stepOutOf(current: activeIndex + 1, total: steps.count))
                .font(.system(size: 8, weight: .regular))
                .foregroundColor(theme.upcomingColor)
                .multilineTextAlignment(.center)
                .padding(.top, 5)
                .padding(.horizontal, 25)
                .padding(.bottom, 10)
        }
    }

    private var stepperRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { i in
                StepperRowItem(
                    index: i,
                    steps: steps,
                    activeIndex: activeIndex,
                    theme: theme,
                    bundle: bundle,
                    nodeSize: nodeSize,
                    ringWidth: ringWidth,
                    gapWidth: gapWidth,
                    dashLength: dashLength,
                    dashGap: dashGap,
                    connectorLength: connectorLength,
                    connectorThickness: connectorThickness,
                    itemSpacing: itemSpacing
                )
            }
        }
        .frame(height: nodeSize + (max(2, ringWidth) * 2), alignment: .center)
    }

    private struct StepperRowItem: View {
        let index: Int
        let steps: [LocalStepModel]
        let activeIndex: Int
        let theme: StepperTheme
        let bundle: Bundle

        let nodeSize: CGFloat
        let ringWidth: CGFloat
        let gapWidth: CGFloat
        let dashLength: CGFloat
        let dashGap: CGFloat
        let connectorLength: CGFloat
        let connectorThickness: CGFloat
        let itemSpacing: CGFloat

        private var step: LocalStepModel { steps[index] }

        private var state: StepVisualState {
            if step.isDone { return .done }
            if index == activeIndex { return .active }
            return .upcoming
        }

        private var connectorColor: Color {
            if steps[index].isDone { return theme.doneColor }
            if index == activeIndex { return theme.activeColor }
            return theme.upcomingColor.opacity(0.9)
        }

        var body: some View {
            HStack(spacing: 0) {
                Spacer().frame(width: itemSpacing / 2)

                StepNodeView(
                    iconAssetName: step.iconAssetPath,
                    state: state,
                    nodeSize: nodeSize,
                    ringWidth: ringWidth,
                    gapWidth: gapWidth,
                    theme: theme,
                    bundle: bundle
                )

                Spacer().frame(width: itemSpacing / 2)

                if index < steps.count - 1 {
                    StepConnectorView(
                        length: connectorLength,
                        thickness: connectorThickness,
                        color: connectorColor,
                        dashLength: dashLength,
                        dashGap: dashGap
                    )
                }
            }
            .frame(height: nodeSize + (max(2, ringWidth) * 2), alignment: .center)
        }
    }
}

// MARK: - Node

private struct StepNodeView: View {
    let iconAssetName: String
    let state: StepVisualState
    let nodeSize: CGFloat
    let ringWidth: CGFloat
    let gapWidth: CGFloat
    let theme: StepperTheme
    let bundle: Bundle

    private var ringColor: Color {
        switch state {
        case .upcoming: return theme.upcomingColor
        case .active:   return theme.activeColor
        case .done:     return theme.doneColor
        }
    }

    private var fillColor: Color {
        switch state {
        case .upcoming: return .clear
        case .active:   return theme.activeColor
        case .done:     return theme.doneColor
        }
    }

    private var iconTint: UIColor {
        switch state {
        case .upcoming:
            return UIColor(theme.upcomingColor)
        case .active, .done:
            return .white
        }
    }

    var body: some View {
        ZStack {
            // ✅ Stroke inside bounds (prevents clipping)
            Circle()
                .strokeBorder(ringColor, lineWidth: ringWidth)

            // Inner fill (creates the "gap" between ring and fill)
            if fillColor != .clear {
                Circle()
                    .fill(fillColor)
                    .padding(ringWidth + gapWidth)
            }

            SVGAssetIcon(
                name: iconAssetName,
                size: CGSize(width: nodeSize * 0.5, height: nodeSize * 0.5),
                tintColor: iconTint
            )
            .frame(width: nodeSize * 0.5, height: nodeSize * 0.5)
        }
        .frame(width: nodeSize, height: nodeSize)
    }
}

// MARK: - Connector (Dashed)

private struct StepConnectorView: View {
    let length: CGFloat
    let thickness: CGFloat
    let color: Color
    let dashLength: CGFloat
    let dashGap: CGFloat

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let y = size.height / 2
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: thickness,
                    lineCap: .round,
                    dash: [dashLength, dashGap],
                    dashPhase: 0
                )
            )
        }
        .frame(width: length, height: thickness)
    }
}



// MARK: - Helpers

public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        case 8: (a, r, g, b) = ((int >> 24) & 255, (int >> 16) & 255, (int >> 8) & 255, int & 255)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
