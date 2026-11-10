import SwiftUI

/// Shown on top of the camera before the scan starts: hold the document in your hand, not on a table.
/// The camera behind is dimmed and does not take taps. The texts come from the caller (any document, any language);
/// an empty message hides its line. The same theme as Android's HoldCardInHandPopup:
///   card      BaseTheme.fieldColor, a thin baseAccentColor border (25 %), a soft shadow
///   title     baseTextColor, message baseTextColor at 75 %
///   drawing   table baseTextColor at 45 %, card baseTextColor, its lines + the arrow baseAccentColor
///   button    BaseClickButton (the theme's click colour and its secondary text colour)
///
/// The drawing is the same as Android's (assets/held-card-*.svg): the card lifts off the table and tips up from its
/// bottom-left corner, the arrow bobs up and brightens. It is drawn here in SwiftUI, so no asset is needed.
public struct HoldCardInHandPopup: View {

    let title: String
    let message: String
    let buttonText: String
    let onContinue: () -> Void

    public init(
        title: String,
        message: String,
        buttonText: String,
        onContinue: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.buttonText = buttonText
        self.onContinue = onContinue
    }

    public var body: some View {
        let text = Color(BaseTheme.baseTextColor)
        let accent = Color(BaseTheme.baseAccentColor)
        let field = Color(BaseTheme.fieldColor)                     // Android: BaseTheme.FieldColor

        ZStack {
            Color.black.opacity(0.45)                                // dims the camera, swallows its taps
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}

            VStack(spacing: 0) {
                HeldCardAnimation(lineColor: text, accent: accent)
                    .frame(width: 200, height: 200 * HeldCardArt.H / HeldCardArt.W)

                Spacer().frame(height: 22)

                Text(title)
                    .foregroundColor(text)
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !message.isEmpty {
                    Spacer().frame(height: 10)
                    Text(message)
                        .foregroundColor(text.opacity(0.75))
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer().frame(height: 24)

                BaseClickButton(
                    title: buttonText,
                    cornerRadius: 28,
                    verticalPadding: 14,
                    enabled: true,
                    action: onContinue
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(field)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 10)
            .padding(.horizontal, 28)
        }
        .transition(.opacity)
    }
}

// MARK: - The drawing (the same 220 x 100 canvas and motion as Android's layers)

enum HeldCardArt {
    static let W: CGFloat = 220
    static let H: CGFloat = 100
    static let pivot = UnitPoint(x: 70 / 220, y: 86 / 100)          // the card's bottom-left corner
    static let lift: CGFloat = 10                                   // how far the card rises (art units)
    static let tiltDeg: Double = -16                                // and tips (the right end comes up)
    static let arrowFrom: CGFloat = 4, arrowTo: CGFloat = -6        // the arrow bobs
    static let halfCycle: Double = 0.9                              // seconds one way; the loop goes up and back
}

/// The card lifts off the table and tips up; the arrow bobs and brightens. Loops.
struct HeldCardAnimation: View {
    let lineColor: Color
    let accent: Color

    @State private var lifted = false

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / HeldCardArt.W                  // art units -> points
            let stroke = StrokeStyle(lineWidth: 4 * k, lineCap: .round, lineJoin: .round)

            ZStack {
                // the table
                TableLine()
                    .stroke(lineColor.opacity(0.45), style: StrokeStyle(lineWidth: 3 * k, lineCap: .round))

                // the card and its lines: rotate about the bottom-left corner, then lift
                ZStack {
                    CardOutline().stroke(lineColor, style: stroke)
                    CardLines().stroke(accent, style: stroke)
                }
                .rotationEffect(.degrees(lifted ? HeldCardArt.tiltDeg : 0), anchor: HeldCardArt.pivot)
                .offset(y: (lifted ? -HeldCardArt.lift : 0) * k)

                // the arrow
                UpArrow()
                    .stroke(accent, style: stroke)
                    .offset(y: (lifted ? HeldCardArt.arrowTo : HeldCardArt.arrowFrom) * k)
                    .opacity(lifted ? 1 : 0.55)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: HeldCardArt.halfCycle).repeatForever(autoreverses: true)) {
                lifted = true
            }
        }
    }
}

/// The shapes, in the art's 220 x 100 units, scaled to the frame.
private struct TableLine: Shape {
    func path(in r: CGRect) -> Path {
        let k = r.width / HeldCardArt.W
        var p = Path()
        p.move(to: CGPoint(x: 30 * k, y: 88 * k))
        p.addLine(to: CGPoint(x: 190 * k, y: 88 * k))
        return p
    }
}

private struct CardOutline: Shape {
    func path(in r: CGRect) -> Path {
        let k = r.width / HeldCardArt.W
        return Path(roundedRect: CGRect(x: 70 * k, y: 50 * k, width: 58 * k, height: 36 * k),
                    cornerRadius: 6 * k)
    }
}

private struct CardLines: Shape {
    func path(in r: CGRect) -> Path {
        let k = r.width / HeldCardArt.W
        var p = Path()
        p.move(to: CGPoint(x: 80 * k, y: 61 * k)); p.addLine(to: CGPoint(x: 104 * k, y: 61 * k))
        p.move(to: CGPoint(x: 80 * k, y: 71 * k)); p.addLine(to: CGPoint(x: 96 * k, y: 71 * k))
        return p
    }
}

private struct UpArrow: Shape {
    func path(in r: CGRect) -> Path {
        let k = r.width / HeldCardArt.W
        var p = Path()
        p.move(to: CGPoint(x: 152 * k, y: 80 * k)); p.addLine(to: CGPoint(x: 152 * k, y: 24 * k))
        p.move(to: CGPoint(x: 141 * k, y: 35 * k)); p.addLine(to: CGPoint(x: 152 * k, y: 24 * k))
        p.addLine(to: CGPoint(x: 163 * k, y: 35 * k))
        return p
    }
}
