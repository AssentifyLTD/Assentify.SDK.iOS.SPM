import SwiftUI

public struct TopBarBackLogoToolbar: ViewModifier {

    let onBack: () -> Void
    let logoUrl: String
    let noStepper: Bool

    public init(
        logoUrl: String = BaseTheme.baseLogo,
        onBack: @escaping () -> Void,
        noStepper: Bool = false
    ) {
        self.logoUrl = logoUrl
        self.onBack = onBack
        self.noStepper = noStepper
    }

    /// Whether the back button + logo bar should be shown for this screen.
    private var showsBar: Bool {
        BaseTheme.stepperType == .normal || noStepper
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    toolbarContent
                }
                .toolbar(showsBar ? .visible : .hidden, for: .navigationBar)
        } else {
            content
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    toolbarContent
                }
                .navigationBarHidden(!showsBar)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if showsBar {
                backButton
            }
        }
        ToolbarItem(placement: .principal) {
            if showsBar {
                logoImage
            }
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(BaseTheme.baseTextColor))
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
    }

    private var logoImage: some View {
        AsyncImage(url: URL(string: logoUrl)) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFit()
            default:
                Color.clear
            }
        }
        .frame(height: 28)
    }
}

public extension View {
    func topBarBackLogo(
        logoUrl: String = BaseTheme.baseLogo,
        noStepper: Bool = false,
        onBack: @escaping () -> Void
    ) -> some View {
        self.modifier(
            TopBarBackLogoToolbar(logoUrl: logoUrl, onBack: onBack, noStepper: noStepper)
        )
    }
}
