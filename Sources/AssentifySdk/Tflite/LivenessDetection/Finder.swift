import Foundation
import TensorFlowLite

/// Which of the model's 4 heads to read. Pick the one for the document you are capturing.
public enum DocHead: Int {
    case card = 0            // ID cards, licences, any card
    case passportPage = 1    // passport photo page
    case passportSpread = 2  // whole open passport (optional assist)
    case a4 = 3              // A4 sheets
}

public struct FinderResult {
    /// true if a document was found (at least 3 sure corners).
    public let found: Bool
    /// Final outline TL, TR, BR, BL as [x0,y0, ..., x3,y3] in image pixels, or nil if no document.
    public let corners: [Double]?
    /// Decoded position of every corner, even unsure ones.
    public let rawCorners: [Double]
    /// Peak score (0..1) of each corner TL, TR, BR, BL. A corner is sure when >= 0.5.
    public let peaks: [Float]
    /// Index (0..3) of a corner that was filled in from the other three, or nil.
    public let inferredCorner: Int?
}

/// Runs the finder2 model (finder2_fp32.tflite) on an upright analysis frame. Port of Finder.kt.
///
///     let finder = try Finder(modelName: "finder_fp32")        // once per capture screen
///     let r = try finder.detect(anaFrame, head: .passportPage)
///
/// The model file must be in the SDK's resources (Swift Package: Bundle.module; declare it with .copy in Package.swift).
/// In an SDK, Bundle.main is the HOST app, so it is only the last fallback.
/// Not thread-safe: use it from the one analysis queue only.
public final class Finder {

    public enum FinderError: Error {
        case modelNotFound(String)
        case badModelShape(String)
    }

    public static let IN = 160      // input is 160 x 160 x 3 (RGB 0..1, NHWC)
    public static let GRID = 40     // output grid is 40 x 40
    public static let CH = 48       // 4 heads x 12 maps
    public static let SURE: Float = 0.5

    private let interpreter: Interpreter

    /// Raw output of the last run: 40 x 40 x 48, NHWC. maps[(y*40 + x)*48 + ch].
    public private(set) var maps = [Float](repeating: 0, count: GRID * GRID * CH)

    public init(modelName: String = "finder_fp32", threads: Int = 2) throws {
        guard let path = Finder.modelPath(modelName) else { throw FinderError.modelNotFound(modelName + ".tflite") }
        var options = Interpreter.Options()
        options.threadCount = threads
        interpreter = try Interpreter(modelPath: path, options: options)
        try interpreter.allocateTensors()
        let inShape = try interpreter.input(at: 0).shape.dimensions
        let outShape = try interpreter.output(at: 0).shape.dimensions
        guard inShape == [1, Finder.IN, Finder.IN, 3], outShape == [1, Finder.GRID, Finder.GRID, Finder.CH] else {
            throw FinderError.badModelShape("input \(inShape), output \(outShape)")
        }
    }

    /// The model in the SDK: Bundle.module (Swift Package), the framework's bundle, then the host app's.
    /// Matches the name ignoring case (an iPhone's file system is case-sensitive); if it is not found, prints the
    /// .tflite files that ARE in the SDK's bundles, so the log shows the real name.
    public static func modelPath(_ name: String) -> String? {
        if let u = LivenessConfig.resourceURL(name, "tflite") { return u.path }

        var bundles: [Bundle] = []
        #if SWIFT_PACKAGE
        bundles.append(Bundle.module)
        #endif
        let sdk = Bundle(for: Finder.self)
        bundles.append(sdk)
        for url in sdk.urls(forResourcesWithExtension: "bundle", subdirectory: nil) ?? [] {   // CocoaPods resource bundles
            if let b = Bundle(url: url) { bundles.append(b) }
        }
        bundles.append(Bundle.main)

        var seen: [String] = []
        for b in bundles {
            for url in b.urls(forResourcesWithExtension: "tflite", subdirectory: nil) ?? [] {
                seen.append(url.lastPathComponent)
                if url.deletingPathExtension().lastPathComponent.lowercased() == name.lowercased() { return url.path }
            }
        }
        print("Finder: \(name).tflite not found. .tflite files in the SDK bundles: "
              + (seen.isEmpty ? "none" : seen.joined(separator: ", ")))
        return nil
    }

    /// Runs the model and decodes one head. Corners are in the image's pixel coordinates.
    public func detect(_ image: LivenessImage, head: DocHead) throws -> FinderResult {
        try run(image)
        return Finder.decode(maps, head: head, width: image.width, height: image.height)
    }

    /// Runs the model only: the whole image squashed to 160 x 160 by area averaging, RGB 0..1, NHWC.
    @discardableResult
    public func run(_ image: LivenessImage) throws -> [Float] {
        let small = LivenessVision.areaResize(image, Finder.IN, Finder.IN)
        var input = [Float](repeating: 0, count: Finder.IN * Finder.IN * 3)
        for i in 0..<(Finder.IN * Finder.IN) {
            let p = small.pixels[i]
            input[3 * i] = Float((p >> 16) & 255) / 255
            input[3 * i + 1] = Float((p >> 8) & 255) / 255
            input[3 * i + 2] = Float(p & 255) / 255
        }
        let data = input.withUnsafeBufferPointer { Data(buffer: $0) }
        try interpreter.copy(data, toInputAt: 0)
        try interpreter.invoke()
        let out = try interpreter.output(at: 0)
        maps = out.data.withUnsafeBytes { Array($0.bindMemory(to: Float32.self)) }
        return maps
    }

    /// Decodes the NHWC maps for one head into corners in a width x height frame.
    public static func decode(_ maps: [Float], head: DocHead, width: Int, height: Int) -> FinderResult {
        let base = head.rawValue * 12
        var pts: [Double] = []
        var peaks: [Float] = []
        for c in 0..<4 {
            let ch = base + c
            var at = 0                                      // argmax over the 1600 cells (first maximum wins)
            var best = maps[ch]
            for cell in 1..<(GRID * GRID) {
                let v = maps[cell * CH + ch]
                if v > best { best = v; at = cell }
            }
            let gx = at % GRID, gy = at / GRID
            let ox = maps[at * CH + base + 4 + 2 * c]
            let oy = maps[at * CH + base + 5 + 2 * c]
            let x = (Float(gx) + 0.5 + (ox - 0.5) * 2) / Float(GRID) * Float(width)
            let y = (Float(gy) + 0.5 + (oy - 0.5) * 2) / Float(GRID) * Float(height)
            pts.append(Double(x)); pts.append(Double(y))
            peaks.append(best)
        }
        let unsure = (0..<4).filter { peaks[$0] < SURE }
        switch unsure.count {
        case 0:
            return FinderResult(found: true, corners: pts, rawCorners: pts, peaks: peaks, inferredCorner: nil)
        case 1:
            // One corner hidden (e.g. a thumb): use the parallelogram's 4th corner.
            let i = unsure[0]
            let a = (i + 3) % 4, b = (i + 1) % 4, o = (i + 2) % 4
            var fixed = pts
            fixed[2 * i] = pts[2 * a] + pts[2 * b] - pts[2 * o]
            fixed[2 * i + 1] = pts[2 * a + 1] + pts[2 * b + 1] - pts[2 * o + 1]
            return FinderResult(found: true, corners: fixed, rawCorners: pts, peaks: peaks, inferredCorner: i)
        default:
            return FinderResult(found: false, corners: nil, rawCorners: pts, peaks: peaks, inferredCorner: nil)
        }
    }
}
