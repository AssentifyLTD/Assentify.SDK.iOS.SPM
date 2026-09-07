import SwiftUI

public struct BaseClickButton: View {
    
    public let title: String
    public let cornerRadius: CGFloat
    public let verticalPadding: CGFloat
    public let enabled: Bool
    public let action: () -> Void
    
    public init(
        title: String = "Next",
        cornerRadius: CGFloat = 28,
        verticalPadding: CGFloat = 15,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.cornerRadius = cornerRadius
        self.verticalPadding = verticalPadding
        self.enabled = enabled
        self.action = action
    }
    
    public var body: some View {
        Button(action: {
            if enabled {
                action()
            }
        }) {
            Text(title)
                .font(.system(size: 16, weight: BaseTheme.baseClickFontWeight)) // ← uses param
                .foregroundColor(
                    enabled
                    ? Color(BaseTheme.baseSecondaryTextColor)
                    : Color(BaseTheme.baseTextColor).opacity(0.6)
                )
                .padding(.vertical, verticalPadding)
                .frame(maxWidth: .infinity)
        }
        .background(
            Group {
                if enabled,
                   let click = BaseTheme.baseClickColor {
                    click.toSwiftUIBackground()
                } else {
                    Color(BaseTheme.fieldColor)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .opacity(enabled ? 1.0 : 0.85)
        .disabled(!enabled)
    }
}
