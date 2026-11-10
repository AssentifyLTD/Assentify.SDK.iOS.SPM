import Foundation
import Vision
import CoreGraphics

/// The PDF417 barcode on the back of the Lebanese ID card (02-core-spec/checks/barcode-qr.md). Port of IdBackBarcode.kt.
///
///  - Images to read it from (capture/barcode-prep.ts): the card straightened from the FULL camera frame, the band that
///    holds the barcode cut out 1712 px wide, plus a sharpened and a thresholded copy; the lower band first (its place),
///    then the upper one (a card held upside down). Six tries in order.
///  - Its content (core/id-back.ts): windows-1256 text, fields split at commas; the card number is the first 12-digit field.
///
/// Recorded only (and the number check against the front): never a liveness verdict. The reading itself is done by
/// Apple Vision (VNDetectBarcodesRequest, PDF417), as Android uses ML Kit.
public enum IdBackBarcode {

    /// The card's shape, width to height (85.6 x 54 mm).
    public static let CARD_ASPECT = 85.6 / 54
    public static let TRY_WIDTH = 1712

    /// A grey image, one value 0..255 per pixel.
    public struct Gray {
        public let width: Int
        public let height: Int
        public let data: [Int]
    }

    /// The ID back's barcode taken apart.
    public struct Content {
        public let text: String              // the whole content, windows-1256 (every byte one character)
        public let fields: [String]          // split at commas, trimmed; fields that are not text are kept in place
        public let number: String?           // the first field of exactly 12 digits (the number on the front), or nil
        /// Only the text fields (Arabic letters, digits, spaces, / . - ( )): what can be shown or compared.
        public func textFields() -> [String] { fields.filter { IdBackBarcode.isTextField($0) } }
    }

    // =============================================================================================
    // Images (barcode-prep.ts)
    // =============================================================================================

    /// toGray: (77 R + 150 G + 29 B) >> 8 of every pixel.
    public static func toGray(_ frame: LivenessImage) -> Gray {
        var px = [Int](repeating: 0, count: frame.pixels.count)
        for i in 0..<px.count {
            let p = frame.pixels[i]
            px[i] = (Int((p >> 16) & 255) * 77 + Int((p >> 8) & 255) * 150 + Int(p & 255) * 29) >> 8
        }
        return Gray(width: frame.width, height: frame.height, data: px)
    }

    /// The six tries: lower band (0.40..1.02) plain, sharpened, thresholded; then upper band (-0.02..0.60) the same.
    public static func tries(_ g: Gray, _ quad: [Double], width: Int = TRY_WIDTH) -> [Gray] {
        var out: [Gray] = []
        for band in [(0.4, 1.02), (-0.02, 0.6)] {
            let b = cardBand(g, quad, width, band.0, band.1)
            out.append(b)
            out.append(sharpen(b, 4))
            out.append(threshold(b, 15, 5.0))
        }
        return out
    }

    /// The band of the card from `from` to `to` of its height (0 = top), straightened and `width` px wide, bilinear;
    /// outside the picture = 255. quad: the card's corners in the picture, top left first, clockwise.
    public static func cardBand(_ g: Gray, _ quad: [Double], _ width: Int, _ from: Double, _ to: Double) -> Gray {
        let hq = CardLivenessVision.unitToQuad(quad)
        let cardH = Double(width) / CARD_ASPECT
        let height = max(1, Int(((to - from) * cardH).rounded()))
        var out = [Int](repeating: 255, count: width * height)
        let w = g.width, hh = g.height
        let d = g.data
        for y in 0..<height {
            let v = from + (Double(y) + 0.5) / cardH
            for x in 0..<width {
                let u = (Double(x) + 0.5) / Double(width)
                let ww = hq[6] * u + hq[7] * v + hq[8]
                let px = (hq[0] * u + hq[1] * v + hq[2]) / ww - 0.5
                let py = (hq[3] * u + hq[4] * v + hq[5]) / ww - 0.5
                let ix = Int(floor(px)), iy = Int(floor(py))
                if ix < 0 || iy < 0 || ix + 1 >= w || iy + 1 >= hh { continue }   // stays 255
                let fx = px - Double(ix), fy = py - Double(iy)
                let i = iy * w + ix
                let top = Double(d[i]) + Double(d[i + 1] - d[i]) * fx
                let bottom = Double(d[i + w]) + Double(d[i + w + 1] - d[i + w]) * fx
                out[y * width + x] = clamp8(top + (bottom - top) * fy)
            }
        }
        return Gray(width: width, height: height, data: out)
    }

    /// Sharpened: 1.8 x the picture less 0.8 x its box blur of radius r.
    public static func sharpen(_ g: Gray, _ r: Int) -> Gray {
        let m = boxMean(g, r)
        return Gray(width: g.width, height: g.height, data: (0..<g.data.count).map { clamp8(1.8 * Double(g.data[$0]) - 0.8 * Double(m[$0])) })
    }

    /// Black and white against the local mean: darker than its surroundings by more than c turns black.
    public static func threshold(_ g: Gray, _ r: Int, _ c: Double) -> Gray {
        let m = boxMean(g, r)
        return Gray(width: g.width, height: g.height, data: (0..<g.data.count).map { Double(g.data[$0]) < Double(m[$0]) - c ? 0 : 255 })
    }

    /// The mean of each point's square neighbourhood of radius r (summed-area table), stored as 32-bit floats.
    private static func boxMean(_ g: Gray, _ r: Int) -> [Float] {
        let w = g.width, h = g.height
        var sat = [Double](repeating: 0, count: (w + 1) * (h + 1))
        for y in 0..<h {
            var row = 0.0
            for x in 0..<w {
                row += Double(g.data[y * w + x])
                sat[(y + 1) * (w + 1) + x + 1] = sat[y * (w + 1) + x + 1] + row
            }
        }
        var out = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            let y0 = max(0, y - r), y1 = min(h, y + r + 1)
            for x in 0..<w {
                let x0 = max(0, x - r), x1 = min(w, x + r + 1)
                let s = sat[y1 * (w + 1) + x1] - sat[y0 * (w + 1) + x1] - sat[y1 * (w + 1) + x0] + sat[y0 * (w + 1) + x0]
                out[y * w + x] = Float(s / Double((y1 - y0) * (x1 - x0)))
            }
        }
        return out
    }

    /// Uint8ClampedArray: clamp to 0..255, round half to even, NaN = 0.
    private static func clamp8(_ v: Double) -> Int { v.isNaN ? 0 : Int(min(255, max(0, v)).rounded(.toNearestOrEven)) }

    /// The grey image as a CGImage, for the barcode reader.
    public static func toCGImage(_ g: Gray) -> CGImage? {
        let bytes = g.data.map { UInt8($0) }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: g.width, height: g.height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: g.width,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    // =============================================================================================
    // Reading (Apple Vision, PDF417)
    // =============================================================================================

    /// The raw bytes of the first non-empty PDF417 in the image, or nil. Synchronous: call it off the main thread.
    public static func scanPdf417(_ g: Gray) -> Data? {
        guard let cg = toCGImage(g) else { return nil }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.pdf417]
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do { try handler.perform([request]) } catch { return nil }
        for obs in request.results ?? [] {
            if #available(iOS 17.0, *), let data = obs.payloadData, !data.isEmpty { return data }
            // older iOS: the text as Vision decoded it, one byte per character (Latin-1) -> the original bytes
            if let s = obs.payloadStringValue, !s.isEmpty {
                return s.data(using: .isoLatin1) ?? s.data(using: .utf8)
            }
        }
        return nil
    }

    // =============================================================================================
    // Content (id-back.ts)
    // =============================================================================================

    private static let CP1256 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.windowsArabic.rawValue)))

    /// The barcode's bytes as text (windows-1256).
    public static func decode(_ bytes: Data) -> String {
        String(data: bytes, encoding: CP1256) ?? String(decoding: bytes, as: UTF8.self)
    }

    /// The content taken apart, or nil if it holds no comma-separated fields.
    public static func read(_ text: String) -> Content? {
        let fields = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if fields.count < 2 { return nil }
        let number = fields.first { $0.count == 12 && $0.allSatisfy { $0 >= "0" && $0 <= "9" } }
        return Content(text: text, fields: fields, number: number)
    }

    private static let TEXT_FIELD = try! NSRegularExpression(
        pattern: "^[\\u0621-\\u064A\\u0660-\\u0669\\u067E\\u0686\\u06A9\\u06AF\\u06CC0-9 /.\\-()]*$")

    /// Is this field text (Arabic letters, digits, spaces and the punctuation of dates and names)?
    public static func isTextField(_ field: String) -> Bool {
        TEXT_FIELD.firstMatch(in: field, range: NSRange(field.startIndex..., in: field)) != nil
    }

    /// Bytes as base64, for handing the raw content on.
    public static func toBase64(_ bytes: Data) -> String { bytes.base64EncodedString() }
}
