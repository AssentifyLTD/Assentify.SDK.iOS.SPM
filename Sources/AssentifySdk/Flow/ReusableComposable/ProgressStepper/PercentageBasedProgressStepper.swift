import SwiftUI

// MARK: - PercentageBasedProgressStepper
//
// Swift port of the Android Compose `PercentageBasedProgressStepper`.
//
// Key concepts (mirrored from Android):
//  • rangeStart / rangeEnd  – the visible percentage window (e.g. 0…100).
//  • nodeCount              – how many circle nodes to show (≥ 2).
//  • Each node sits at an evenly-spaced % position inside [rangeStart, rangeEnd].
//  • doneCount steps → currentPct → determines which nodes are Done/Active/Upcoming.
//  • The active node shows a left-to-right partial fill (fillFraction).
//  • A caret + title label is pinned below the active node.
//  • Back button on the left, currentPct% badge on the right.
//
// Usage reference: NormalProgressStepper (Swift) for structure, theming & helpers.

public struct PercentageBasedProgressStepper: View {

    @Environment(\.layoutDirection) private var layoutDirection

    // ── Inputs ────────────────────────────────────────────────────────────────
    private let steps: [LocalStepModel]       // filtered to show == true by caller
    private let theme: StepperPercentageTheme
    private let bundle: Bundle
    private let onBack: () -> Void

    // ── Layout knobs (match Android defaults) ─────────────────────────────────
    private let nodeSize: CGFloat
    private let connectorLength: CGFloat
    private let connectorThickness: CGFloat

    // ── Range / node config (from BaseTheme on Android; passed directly here) ─
    private let rangeStart: Double   // e.g. 0
    private let rangeEnd: Double     // e.g. 100
    private let nodeCount: Int       // e.g. 4  (≥ 2)
    private let stepperTitle: String // label shown under active node

    public init(
        steps: [LocalStepModel],
        bundle: Bundle,
        theme: StepperPercentageTheme = StepperPercentageTheme(),
        onBack: @escaping () -> Void,
        nodeSize: CGFloat     = 57,
        connectorLength: CGFloat   = 40,
        connectorThickness: CGFloat = 3,
        nodeCount: Int        = 3,
    ) {
        self.steps            = steps.filter { $0.show }
        self.bundle           = bundle
        self.theme            = theme
        self.onBack           = onBack
        self.nodeSize         = nodeSize
        self.connectorLength  = connectorLength
        self.connectorThickness = connectorThickness
        self.rangeStart       = Double(BaseTheme.rangeStart)
        self.rangeEnd         = Double(BaseTheme.rangeEnd)
        self.nodeCount        = max(nodeCount, 2)
        self.stepperTitle     = BaseTheme.stepperTitle
    }

    // ── Derived state (mirrors Android range math) ────────────────────────────

    private var doneCount: Int {
        steps.filter { $0.isDone }.count
    }

    private var rangeWidth: Double {
        max(0, rangeEnd - rangeStart)
    }

    private var pctPerStep: Double {
        steps.isEmpty ? 0 : rangeWidth / Double(steps.count)
    }

    /// The current progress percentage (what Android calls `currentPct`).
    private var currentPct: Double {
        rangeStart + Double(doneCount) * pctPerStep
    }

    /// Evenly-spaced percentage positions for each node.
    private var nodePcts: [Double] {
        (0 ..< nodeCount).map { i in
            rangeStart + (Double(i) / Double(nodeCount - 1)) * rangeWidth
        }
    }

    // ── Node model ────────────────────────────────────────────────────────────

    private struct NodeInfo: Identifiable {
        let id: Int
        let pct: Double
        let state: StepVisualState
        /// 0…1 – how far the active fill reaches across the circle (left→right).
        let fillFraction: Double
    }

    private var nodes: [NodeInfo] {
        let firstUpcoming = nodePcts.firstIndex(where: { $0 > currentPct }) ?? nodeCount

        return nodePcts.enumerated().map { (i, pct) in
            let state: StepVisualState
            if i < firstUpcoming        { state = .done }
            else if i == firstUpcoming  { state = .active }
            else                         { state = .upcoming }

            let fillFraction: Double
            if state == .active {
                let slotStart = i == 0 ? rangeStart : nodePcts[i - 1]
                let slotWidth = pct - slotStart
                fillFraction = slotWidth > 0
                    ? min(max((currentPct - slotStart) / slotWidth, 0), 1)
                    : 0
            } else {
                fillFraction = 0
            }

            return NodeInfo(id: i, pct: pct, state: state, fillFraction: fillFraction)
        }
    }

    /// Index of the active node (-1 if none).
    private var activeNodeIndex: Int {
        nodes.firstIndex(where: { $0.state == .active }) ?? -1
    }

    // ── Body ──────────────────────────────────────────────────────────────────

    public var body: some View {
        VStack(alignment: .center, spacing: 0) {
            topRow
            caretAndTitle
        }
    }

    // ── Top row: [back] [nodes…] [pct%] ───────────────────────────────────────

    private let sideWidth: CGFloat = 52

    private var topRow: some View {
        HStack(spacing: 0) {

            // Back button
            backButton
                .frame(width: sideWidth)

            // Nodes + connecto rs (reads its own width for caret alignment)
            GeometryReader { geo in
                nodesRow(availableWidth: geo.size.width)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(height: nodeSize)

            // Percentage badge
            pctBadge
                .frame(width: sideWidth)
        }.padding(.horizontal , 8)
    }

    // ── Back button ───────────────────────────────────────────────────────────

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(BaseTheme.baseTextColor))
                .frame(width: 45, height: 45)
                .background(theme.upcomingColor.opacity(0.8))
                .clipShape(Circle())
        }
    }

    // ── Percentage badge ──────────────────────────────────────────────────────

    private var pctBadge: some View {
        Text("\(Int(currentPct))%")
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(theme.activeColor)
    }

    // ── Nodes row ─────────────────────────────────────────────────────────────

    private func nodesRow(availableWidth: CGFloat) -> some View {
        // Total content width; if it overflows → ScrollView (mirrors Android behaviour)
        let totalNodes      = CGFloat(nodes.count)
        let totalConnectors = CGFloat(max(0, nodes.count - 1))
        let contentWidth    = totalNodes * nodeSize + totalConnectors * connectorLength

        return Group {
            if contentWidth > availableWidth {
                ScrollView(.horizontal, showsIndicators: false) {
                    nodeHStack
                }
            } else {
                nodeHStack
            }
        }
    }

    private var nodeHStack: some View {
        HStack(spacing: 0) {
            ForEach(nodes) { node in
                PBStepNode(
                    number:        node.id + 1,
                    state:         node.state,
                    fillFraction:  node.fillFraction,
                    size:          nodeSize,
                    isRTL:         layoutDirection == .rightToLeft,
                    activeColor:   theme.activeColor,
                    doneColor:     theme.doneColor,
                    upcomingColor: theme.upcomingColor
                )

                if node.id < nodes.count - 1 {
                    PBStepConnector(
                        length:    connectorLength,
                        thickness: connectorThickness,
                        done:      nodes[node.id].state == .done,
                        activeColor:   theme.activeColor,
                        upcomingColor: theme.upcomingColor
                    )
                }
            }
        }
        .frame(height: nodeSize, alignment: .center)
    }

    // ── Caret + title ─────────────────────────────────────────────────────────
    //
    // Android aligns the caret under the active node's centre using an
    // `offset(x:)`. We do the same with a GeometryReader measuring the full
    // row width and computing the active node's centre offset from the
    // row's own centre.

    @State private var activeNodeCenterX: CGFloat = 0
    @State private var rowWidth: CGFloat = 0

    private var caretAndTitle: some View {
        Group {
            if activeNodeIndex != -1 {
                VStack(spacing: 6) {
                    Spacer().frame(height: 5)
                    PBCaret(color: theme.activeColor)
                    Text(stepperTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.upcomingColor)
                        .multilineTextAlignment(.center)
                }
                // Measure where the active node centre is so we can offset the caret
                .overlay(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                rowWidth = geo.size.width
                            }
                    }
                )
                .offset(x: caretOffset)
            }
        }
    }

    /// Pixel offset of active node centre from the row's centre.
    private var caretOffset: CGFloat {
        guard rowWidth > 0, activeNodeIndex != -1 else { return 0 }

        // Width of one "slot": node + connector (except last node has no connector)
        let slotWidth = nodeSize + connectorLength
        let activeCenterX = CGFloat(activeNodeIndex) * slotWidth + nodeSize / 2

        // Total content width (without side panels – mirrors Android's inner Box)
        let totalNodes      = CGFloat(nodes.count)
        let totalConnectors = CGFloat(max(0, nodes.count - 1))
        let contentWidth    = totalNodes * nodeSize + totalConnectors * connectorLength

        let rowCenterX = contentWidth / 2
        return activeCenterX - rowCenterX
    }
}

// MARK: - Node View

private struct PBStepNode: View {
    let number: Int
    let state: StepVisualState
    let fillFraction: Double
    let size: CGFloat
    let isRTL: Bool
    let activeColor: Color
    let doneColor: Color
    let upcomingColor: Color

    private var textColor: Color {
        switch state {
        case .done:     return Color(BaseTheme.baseSecondaryTextColor)
        case .active:   return Color(BaseTheme.baseTextColor)
        case .upcoming: return Color(BaseTheme.baseTextColor)
        }
    }

    var body: some View {
        ZStack {
            // Canvas draws the circle fill (mirrors Android `drawNode`)
            Canvas { ctx, sz in
                drawNode(ctx: &ctx, size: sz)
            }
            .frame(width: size, height: size)

            Text("\(number)")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(textColor)
        }
        .frame(width: size, height: size)
    }

    // Mirrors Android's `DrawScope.drawNode`
    private func drawNode(ctx: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)

        switch state {

        case .done:
            // Solid fill with done colour
            ctx.fill(Path(ellipseIn: rect), with: .color(doneColor))

        case .upcoming:
            // Solid upcoming colour (muted)
            ctx.fill(Path(ellipseIn: rect), with: .color(upcomingColor))

        case .active:
            // 1. Background circle in upcoming colour
            ctx.fill(Path(ellipseIn: rect), with: .color(upcomingColor))

            // 2. Partial left-to-right clip of active colour
            //    Android: minFraction = 0.15, effective = 0.15 + fill * 0.85
            let minFraction       = 0.15
            let effectiveFraction = minFraction + fillFraction * (1.0 - minFraction)
            let fillWidth         = size.width * effectiveFraction

            let clipRect = isRTL
                ? CGRect(x: size.width - fillWidth, y: 0, width: fillWidth, height: size.height)
                : CGRect(x: 0, y: 0, width: fillWidth, height: size.height)
            ctx.clip(to: Path(clipRect))
            ctx.fill(Path(ellipseIn: rect), with: .color(activeColor))
        }
    }
}

// MARK: - Connector View

private struct PBStepConnector: View {
    let length: CGFloat
    let thickness: CGFloat
    let done: Bool
    let activeColor: Color
    let upcomingColor: Color

    private var color: Color { done ? activeColor : upcomingColor }

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            let y = size.height / 2
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))

            ctx.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: thickness, lineCap: .round)
            )
        }
        .frame(width: length, height: thickness)
    }
}

// MARK: - Caret

private struct PBCaret: View {
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: 0))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            path.closeSubpath()
            ctx.fill(path, with: .color(color))
        }
        .frame(width: 10, height: 6)
    }
}
