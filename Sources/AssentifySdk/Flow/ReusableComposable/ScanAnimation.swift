import SwiftUI
import UIKit

public struct ScanAnimation: View {

    private let cardWidth: CGFloat = 140
    private var cardHeight: CGFloat { cardWidth * (99.0 / 163.0) }

    // ✅ Make bar a bit wider than card
    private var barWidth: CGFloat  { cardWidth * 1.15 } // 15% wider
    private var barHeight: CGFloat {
           (barWidth * (35.0 / 199.0)) * 0.75   
       }

    private let extraTravel: CGFloat = 16
    private let iconName: String

    @State private var animate = false

    public init(iconName: String?) {
        self.iconName = iconName ?? "ic_scan_id"
    }

    public var body: some View {
        ZStack {
            // Card
            SVGAssetIcon(
                name: iconName,
                size: CGSize(width: cardWidth, height: cardHeight),
                tintColor: BaseTheme.baseAccentColor
            ).padding(.horizontal,15)

            // Bar (wider)
            SVGAssetIcon(
                name: "ic_bar",
                size: CGSize(width: barWidth, height: barHeight),
                tintColor: BaseTheme.baseAccentColor
            )
            .offset(y: animate ? travelDown : travelUp)
            .onAppear { animate = true }
            .animation(
                .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                value: animate
            )
        }
    }

    private var travelUp: CGFloat {
        -(cardHeight / 2 - barHeight / 2) - extraTravel
    }

    private var travelDown: CGFloat {
        (cardHeight / 2 - barHeight / 2) + extraTravel
    }
}


public struct FaceScanAnimation: View {

    private let cardWidth: CGFloat = 140

    // ✅ Let the face icon scale naturally — don't force a calculated height
    private var barWidth: CGFloat  { cardWidth * 1.15 }
    private var barHeight: CGFloat { (barWidth * (35.0 / 199.0)) * 0.75 }

    private let extraTravel: CGFloat = 16
    private let iconName: String

    @State private var animate = false

    public init(iconName: String?) {
        self.iconName = iconName ?? "ic_scan_id"
    }

    public var body: some View {
        ZStack {
            // Card — only set width, let height be natural
            SVGAssetIcon(
                name: iconName,
                size: CGSize(width: cardWidth, height: cardWidth), // square container, SVG picks its own height
                tintColor: BaseTheme.baseAccentColor
            )
            .scaledToFit() // ← respects the SVG's natural proportions
            .padding(.horizontal, 15)

            // Bar (wider)
            SVGAssetIcon(
                name: "ic_bar",
                size: CGSize(width: barWidth, height: barHeight),
                tintColor: BaseTheme.baseAccentColor
            )
            .offset(y: animate ? travelDown : travelUp)
            .onAppear { animate = true }
            .animation(
                .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                value: animate
            )
        }
    }

    private var cardHeight: CGFloat { cardWidth } // square for travel calculation

    private var travelUp: CGFloat {
        -(cardHeight / 2 - barHeight / 2) - extraTravel
    }

    private var travelDown: CGFloat {
        (cardHeight / 2 - barHeight / 2) + extraTravel
    }
}
