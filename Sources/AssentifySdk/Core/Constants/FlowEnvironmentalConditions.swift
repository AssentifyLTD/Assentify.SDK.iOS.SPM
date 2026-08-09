import UIKit


public enum BackgroundStyle: Equatable {
    case solid(hex: String)
    case gradient(colorsHex: [String], angleDegrees: CGFloat = 90.0, holdUntil: CGFloat = 0.4)
}

// MARK: - Hex -> UIColor

public extension UIColor {
    static func fromHex(_ hex: String) -> UIColor {
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        let argb: String
        switch clean.count {
        case 6:
            argb = "FF" + clean   // add alpha
        case 8:
            argb = clean
        default:
            fatalError("Invalid hex: \(hex)")
        }

        let value = UInt64(argb, radix: 16) ?? 0
        let a = CGFloat((value >> 24) & 0xFF) / 255.0
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8)  & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Helpers (firstColor, darken)

public extension BackgroundStyle {
    func firstColor() -> UIColor {
        switch self {
        case .solid(let hex):
            return .fromHex(hex)
        case .gradient(let colorsHex, _, _):
            return .fromHex(colorsHex.first ?? "#000000")
        }
    }
}

public extension UIColor {
    func darken(factor: CGFloat = 0.6) -> UIColor {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)

        return UIColor(
            red: max(0, min(1, r * factor)),
            green: max(0, min(1, g * factor)),
            blue: max(0, min(1, b * factor)),
            alpha: a
        )
    }
}

// MARK: - "Brush" equivalent for UIKit: CAGradientLayer
// Compose Brush -> iOS commonly uses CAGradientLayer

public extension BackgroundStyle {
    /// Returns either a solid color or a configured gradient layer.
    /// If you want "holdUntil" behavior, we use locations [0, t, 1] with first color repeated.
    func makeGradientLayer(frame: CGRect) -> (solidColor: UIColor?, gradientLayer: CAGradientLayer?) {
        switch self {
        case .solid(let hex):
            return (UIColor.fromHex(hex), nil)

        case .gradient(let colorsHex, let angleDegrees, let holdUntil):
            let first = UIColor.fromHex(colorsHex.first ?? "#000000").cgColor
            let last  = UIColor.fromHex(colorsHex.last ?? "#000000").cgColor

            let t = max(0, min(1, holdUntil))

            let layer = CAGradientLayer()
            layer.frame = frame
            layer.colors = [first, first, last]
            layer.locations = [0.0, NSNumber(value: Float(t)), 1.0]

            // Handle 90° (vertical) and 0° (horizontal) like your Kotlin
            if angleDegrees == 90 {
                layer.startPoint = CGPoint(x: 0.5, y: 0.0)
                layer.endPoint   = CGPoint(x: 0.5, y: 1.0)
            } else if angleDegrees == 0 {
                layer.startPoint = CGPoint(x: 0.0, y: 0.5)
                layer.endPoint   = CGPoint(x: 1.0, y: 0.5)
            } else {
                // Simple fallback: approximate angle direction
                // 0° = left->right, 90° = top->bottom
                let rad = angleDegrees * .pi / 180
                let dx = cos(rad)
                let dy = sin(rad)
                layer.startPoint = CGPoint(x: 0.5 - dx * 0.5, y: 0.5 - dy * 0.5)
                layer.endPoint   = CGPoint(x: 0.5 + dx * 0.5, y: 0.5 + dy * 0.5)
            }

            return (nil, layer)
        }
    }
}

// MARK: - BackgroundType

public enum BackgroundType: String, Codable {
    case image = "Image"
    case color = "Color"
}

public enum StepperType: String, Codable {
    case normal = "Normal"
    case percentageBased = "PercentageBased"
}

public struct UiLanguage {
      public static let English = "en"
      public static let Arabic = "ar"
}


// MARK: - FlowEnvironmentalConditions

public final class FlowEnvironmentalConditions {
    public var logoUrl: String
    public var svgBackgroundImageUrl: String
    public var textColor: String
    public var secondaryTextColor: String
    public var backgroundCardColor: String
    public var accentColor: String
    public var backgroundColor: BackgroundStyle?
    public var clickColor: BackgroundStyle?
    public var backgroundType: BackgroundType

    
    public var stepperType: StepperType
    public var rangeStart: Int
    public var rangeEnd : Int
    public var stepperTitle:String
    
    public let extractedDataLanguage: String
    public let enableNfc: Bool
    public let enableQr: Bool
    public let showCountDown: Bool
    public let blockLoaderCustomProperties: [String: Any]

    public init(
        backgroundType: BackgroundType,          // required like
        logoUrl: String = "",
        svgBackgroundImageUrl: String = "",
        textColor: String = "",
        secondaryTextColor: String = "",
        backgroundCardColor: String = "",
        accentColor: String = "",
        backgroundColor: BackgroundStyle? = nil,
        clickColor: BackgroundStyle? = nil,
        stepperType: StepperType = StepperType.normal,
        rangeStart: Int = 25,
        rangeEnd: Int = 50,
        stepperTitle: String = "Identification",
        extractedDataLanguage: String = Language.NON,
        enableNfc: Bool = false,
        enableQr: Bool = false,
        showCountDown: Bool = true,
        blockLoaderCustomProperties: [String: Any] = [:]
    ) {
        self.logoUrl = logoUrl
        self.svgBackgroundImageUrl = svgBackgroundImageUrl
        self.textColor = textColor
        self.secondaryTextColor = secondaryTextColor
        self.backgroundCardColor = backgroundCardColor
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.clickColor = clickColor
        self.backgroundType = backgroundType

        self.stepperType = stepperType
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.stepperTitle = stepperTitle
        
        self.extractedDataLanguage = extractedDataLanguage
        self.enableNfc = enableNfc
        self.enableQr = enableQr
        self.showCountDown = showCountDown
        self.blockLoaderCustomProperties = blockLoaderCustomProperties
    }
}
