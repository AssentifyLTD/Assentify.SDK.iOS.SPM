
import SwiftUI
import UIKit

struct StepCard: View {
    let step: LocalStepModel
    let selectedColor: Color
    let unselectedColor: Color
    let onClick: () -> Void

    private var backgroundColor: Color { step.isDone ? selectedColor : unselectedColor }
    private var circleColor: Color { step.isDone ? .white : selectedColor }
    private var iconColor: Color { step.isDone ? selectedColor : .white }
    private var textColor: Color {
        step.isDone ? Color(BaseTheme.baseSecondaryTextColor) : Color(BaseTheme.baseTextColor)
    }

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 12) {

                // icon circle
                ZStack {
                    Circle().fill(circleColor)
                    SVGAssetIcon(
                        name: step.iconAssetPath,
                        size: CGSize(width: 24, height: 24),
                        tintColor: UIColor(iconColor)
                    )
                    .frame(width: 24, height: 24)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(textColor)

                    Text(step.description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(textColor)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 25)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 5)
            .padding(.top, 5)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
}
