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

    @ViewBuilder
    public func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                if BaseTheme.stepperType == .normal || noStepper {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onBack) {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(BaseTheme.baseTextColor))
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                    }
                }
                if BaseTheme.stepperType == .normal || noStepper {
                    ToolbarItem(placement: .principal) {
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
               
            }
    }
}

public extension View {
    @ViewBuilder
    func topBarBackLogo(
        logoUrl: String = BaseTheme.baseLogo,
        noStepper: Bool = false,
        onBack: @escaping () -> Void
    ) -> some View {
        if BaseTheme.stepperType == .normal || noStepper {
            self.modifier(TopBarBackLogoToolbar(logoUrl: logoUrl, onBack: onBack, noStepper: noStepper)) .toolbar(.visible, for: .navigationBar)
        } else {
            self.navigationBarBackButtonHidden(true) .toolbar(.hidden, for: .navigationBar)
        }
    }
}



