import Foundation
import TensorFlowLite

/// Which document is in front of the camera: the 25-class model (MobileNetV3-Small), `classification.tflite` in the SDK's
/// resources (the same model as Android's model_A_all25_dynamic.tflite). Port of DocumentClassifier.kt.
///
///  - input  [1, 256, 256, 3] float32 RGB, values 0..255 (the model rescales itself: x / 127.5 - 1; do NOT normalise)
///  - output [1, 25] softmax, classes in alphabetical folder order (LABELS below)
///
/// The whole UPRIGHT camera frame is squashed to 256 x 256 (bilinear), as image_dataset_from_directory does when training.
/// Not thread-safe: use one instance from the analysis queue only.
public final class DocumentClassifier {

    public enum ClassifierError: Error {
        case modelNotFound(String)
        case badModelShape(String)
    }

    public struct Result: CustomStringConvertible {
        public let label: String            // e.g. "lebanese-civil-id-front"
        public let index: Int
        public let confidence: Float        // softmax probability of the label, 0..1
        public let scores: [Float]          // all 25 probabilities, in LABELS order
        public var description: String { String(format: "%@ (%.2f)", label, confidence) }
    }

    public static let MODEL_FILE = "classification"     // classification.tflite
    public static let SIZE = 256

    /// The model's classes, in output order (alphabetical folder order of the training set).
    public static let LABELS: [String] = [
        "Car-Registration-New-Front",
        "Car-Registration-New-Rear",
        "Car-Registration-Old-Front",
        "Car-Registration-Old-Rear",
        "Old-Lawyer-Card",
        "lebanese-army-card",
        "lebanese-army-services",
        "lebanese-civil-extract",
        "lebanese-civil-extract-old",
        "lebanese-civil-id-back",
        "lebanese-civil-id-front",
        "lebanese-driving-license",
        "lebanese-form-2",
        "lebanese-gdgs-card",
        "lebanese-isf-card",
        "lebanese-lawyer-card",
        "lebanese-passport",
        "lebanese-resident-permit-back",
        "lebanese-resident-permit-front",
        "lebanese-temporary-resident-permit-back",
        "lebanese-temporary-resident-permit-front",
        "palestinian-id-back",
        "palestinian-id-front",
        "syrian-civil-id-back",
        "syrian-civil-id-front",
    ]

    /// Model class -> profile kind in rectifier_config_file.json. Classes with no profile in the config are absent:
    /// for them kindFor() returns nil and the local liveness check is skipped.
    public static let LABEL_TO_KIND: [String: String] = [
        "lebanese-passport": "lb_passport",
        "lebanese-civil-id-front": "lb_civil_id",
        "lebanese-civil-id-back": "lb_civil_id_back",
        "lebanese-driving-license": "lb_driving_licence",
        "lebanese-civil-extract": "lb_civil_extract",
        "lebanese-civil-extract-old": "lb_civil_extract",
        "lebanese-resident-permit-front": "lb_residence_permit",
    ]

    /// The config kind for a model class, or nil when the config has no profile for it.
    public static func kindFor(_ label: String) -> String? { LABEL_TO_KIND[label] }

    private let interpreter: Interpreter

    public init(modelName: String = DocumentClassifier.MODEL_FILE, threads: Int = 2) throws {
        guard let url = LivenessConfig.resourceURL(modelName, "tflite") else {
            throw ClassifierError.modelNotFound(modelName + ".tflite")
        }
        var options = Interpreter.Options()
        options.threadCount = threads
        interpreter = try Interpreter(modelPath: url.path, options: options)
        try interpreter.allocateTensors()
        let inShape = try interpreter.input(at: 0).shape.dimensions
        let outShape = try interpreter.output(at: 0).shape.dimensions
        let S = DocumentClassifier.SIZE
        guard inShape == [1, S, S, 3], outShape == [1, DocumentClassifier.LABELS.count] else {
            throw ClassifierError.badModelShape("input \(inShape), output \(outShape)")
        }
    }

    /// Classifies an UPRIGHT frame (the same orientation the person sees).
    public func classify(_ frame: LivenessImage) throws -> Result {
        let S = DocumentClassifier.SIZE
        let small = (frame.width == S && frame.height == S) ? frame : DocumentClassifier.bilinear(frame, S, S)
        var input = [Float](repeating: 0, count: S * S * 3)
        for i in 0..<(S * S) {                                      // raw RGB 0..255: the model rescales itself
            let p = small.pixels[i]
            input[3 * i] = Float((p >> 16) & 255)
            input[3 * i + 1] = Float((p >> 8) & 255)
            input[3 * i + 2] = Float(p & 255)
        }
        let data = input.withUnsafeBufferPointer { Data(buffer: $0) }
        try interpreter.copy(data, toInputAt: 0)
        try interpreter.invoke()
        let out = try interpreter.output(at: 0)
        let scores: [Float] = out.data.withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
        var best = 0
        for i in 1..<scores.count where scores[i] > scores[best] { best = i }
        return Result(label: DocumentClassifier.LABELS[best], index: best, confidence: scores[best], scores: scores)
    }

    /// Bilinear resize (pixel centres aligned), as Android's Bitmap.createScaledBitmap(…, filter = true).
    static func bilinear(_ src: LivenessImage, _ dw: Int, _ dh: Int) -> LivenessImage {
        let sw = src.width, sh = src.height
        var out = [UInt32](repeating: 0, count: dw * dh)
        let sx = Double(sw) / Double(dw), sy = Double(sh) / Double(dh)
        for y in 0..<dh {
            let fy = max(0, min(Double(sh - 1), (Double(y) + 0.5) * sy - 0.5))
            let y0 = Int(fy), y1 = min(y0 + 1, sh - 1), wy = fy - Double(y0)
            for x in 0..<dw {
                let fx = max(0, min(Double(sw - 1), (Double(x) + 0.5) * sx - 0.5))
                let x0 = Int(fx), x1 = min(x0 + 1, sw - 1), wx = fx - Double(x0)
                let p00 = src.pixels[y0 * sw + x0], p01 = src.pixels[y0 * sw + x1]
                let p10 = src.pixels[y1 * sw + x0], p11 = src.pixels[y1 * sw + x1]
                var px: UInt32 = 0xFF00_0000
                for shift in [16, 8, 0] {
                    let a = Double((p00 >> UInt32(shift)) & 255), b = Double((p01 >> UInt32(shift)) & 255)
                    let c = Double((p10 >> UInt32(shift)) & 255), d = Double((p11 >> UInt32(shift)) & 255)
                    let top = a + (b - a) * wx, bot = c + (d - c) * wx
                    let v = UInt32(max(0, min(255, (top + (bot - top) * wy).rounded())))
                    px |= v << UInt32(shift)
                }
                out[y * dw + x] = px
            }
        }
        return LivenessImage(width: dw, height: dh, pixels: out)
    }
}
