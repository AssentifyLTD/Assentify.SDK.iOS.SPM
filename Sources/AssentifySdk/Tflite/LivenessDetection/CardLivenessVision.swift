import Foundation
import CoreVideo

/// Pixel maths of the rc17 document-liveness spec for the ID CARDS (civil ID front / back, driving licence, residence
/// permit), pure Swift. Its own copy, separate from the passport's LivenessVision: the same frame / rectify / colour /
/// reflection / quality maths, plus the card checks of LivenessVision.kt (cedar emblem, oriented baseline, cut edge).
///
///  - analysis frame ............... area averaging (OpenCV INTER_AREA), then upright (90° clockwise for the back camera)
///  - rectify + corner roll ........ checks/rectify-colour.md  (makeBaseline, rectify, sRGB -> CIELAB)
///  - laminate colours per frame ... checks/laminate.md        (iridescence: 12 hue sectors)
///  - page response to the light ... checks/reflection.md      (pageResponse: spec / chroma / flare / veilLift)
///  - sharpness and glare .......... checks/quality.md         (Laplacian variance + grey > 249 in the shrunk outline)
///
/// Quads are [Double] of 8, TL, TR, BR, BL, in upright ANA pixels.
public enum CardLivenessVision {

    /// Width of the straightened measuring frame (vision-core.ts:40).
    public static let OPT_W = 480

    /// pageResponse sample layout: [specFrac, chromaFrac, flareFrac, veilLift].
    public static let SPEC = 0
    public static let CHROMA = 1
    public static let FLARE = 2
    public static let VEIL = 3

    /// The baseline choice: which corner is the document's top-left, and the straightened image.
    public struct Baseline {
        public let k: Int
        public let img: [UInt32]
    }

    /// Half-resolution Lab grid with the frame's colour cast (mean a*, b* of the ok cells) removed.
    public final class Grid {
        public let gw: Int, gh: Int
        public var L: [Double], A: [Double], B: [Double]
        public var ok: [Bool]
        init(_ gw: Int, _ gh: Int) {
            self.gw = gw; self.gh = gh
            L = [Double](repeating: 0, count: gw * gh)
            A = L; B = L
            ok = [Bool](repeating: false, count: gw * gh)
        }
    }

    /// The lit flat reference: per cell, the strongest colour already there in its 7x7 neighbourhood.
    public struct IridBase {
        public let gw: Int, gh: Int
        public let own: [Double]
    }

    // =============================================================================================
    // Frames from the camera (wiring/ios.md §3)
    // =============================================================================================

    /// The analysis frame (ANA) from a BGRA camera buffer: area-averaged so its long edge is at most `longEdge`
    /// (never enlarged; sizes rounded like JavaScript), then turned upright when `rotateClockwise` (back camera,
    /// portrait phone, sensor buffers: option B of wiring/ios.md). Same order as Android: shrink, then rotate.
    public static func analysisFrame(_ pb: CVPixelBuffer, longEdge: Int, rotateClockwise: Bool) -> LivenessImage? {
        guard let src = image(from: pb) else { return nil }
        let sw = src.width, sh = src.height
        let longest = max(sw, sh)
        var img = src
        if longest > longEdge {
            let sc = Double(longEdge) / Double(longest)
            img = areaResize(src, Int(jsRound(Double(sw) * sc)), Int(jsRound(Double(sh) * sc)))
        }
        return rotateClockwise ? rotate90CW(img) : img
    }

    /// The whole camera buffer as an RGB image (BGRA, padded rows handled).
    public static func image(from pb: CVPixelBuffer) -> LivenessImage? {
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return nil }
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
        let rowBytes = CVPixelBufferGetBytesPerRow(pb)
        let p = base.assumingMemoryBound(to: UInt8.self)
        var out = [UInt32](repeating: 0, count: w * h)
        out.withUnsafeMutableBufferPointer { o in
            for y in 0..<h {
                let row = p + y * rowBytes
                for x in 0..<w {
                    let b = UInt32(row[4 * x]), g = UInt32(row[4 * x + 1]), r = UInt32(row[4 * x + 2])
                    o[y * w + x] = (r << 16) | (g << 8) | b
                }
            }
        }
        return LivenessImage(width: w, height: h, pixels: out)
    }

    /// A quarter turn clockwise: pixel (x, y) goes to (h-1-y, x).
    public static func rotate90CW(_ s: LivenessImage) -> LivenessImage {
        let w = s.width, h = s.height
        var out = [UInt32](repeating: 0, count: w * h)
        s.pixels.withUnsafeBufferPointer { src in
            out.withUnsafeMutableBufferPointer { o in
                for y in 0..<h {
                    for x in 0..<w {
                        o[x * h + (h - 1 - y)] = src[y * w + x]
                    }
                }
            }
        }
        return LivenessImage(width: h, height: w, pixels: out)
    }

    /// Shrinks src to dw x dh by area averaging (each output pixel = the mean of the source area it covers).
    public static func areaResize(_ src: LivenessImage, _ dw: Int, _ dh: Int) -> LivenessImage {
        let sw = src.width, sh = src.height
        if dw >= sw && dh >= sh { return src }
        let sx = Double(sw) / Double(dw)
        let sy = Double(sh) / Double(dh)

        // horizontal weights: for each output column, the source columns it covers and how much of each
        var colStart = [Int](repeating: 0, count: dw)
        var colW = [[Float]](repeating: [], count: dw)
        for x in 0..<dw {
            let x0 = Double(x) * sx, x1 = Double(x + 1) * sx
            let a = Int(floor(x0)), b = min(sw, Int(ceil(x1)))
            colStart[x] = a
            colW[x] = (0..<(b - a)).map { k in
                let c = Double(a + k)
                return Float((min(x1, c + 1) - max(x0, c)) / sx)
            }
        }

        var hr = [Float](repeating: 0, count: dw * 3)        // one source row, resampled horizontally
        var acc = [Float](repeating: 0, count: dw * 3)
        var out = [UInt32](repeating: 0, count: dw * dh)
        var cached = -1
        src.pixels.withUnsafeBufferPointer { px in
            for y in 0..<dh {
                for i in 0..<acc.count { acc[i] = 0 }
                let y0 = Double(y) * sy, y1 = Double(y + 1) * sy
                var r = Int(floor(y0))
                let rEnd = min(sh, Int(ceil(y1)))
                while r < rEnd {
                    let wy = Float((min(y1, Double(r) + 1) - max(y0, Double(r))) / sy)
                    if wy > 0 {
                        if r != cached {                       // a source row is shared by at most two output rows
                            let row = r * sw
                            for x in 0..<dw {
                                let ws = colW[x]
                                let a = colStart[x]
                                var rr: Float = 0, gg: Float = 0, bb: Float = 0
                                for k in 0..<ws.count {
                                    let p = px[row + a + k]
                                    let w = ws[k]
                                    rr += Float((p >> 16) & 255) * w
                                    gg += Float((p >> 8) & 255) * w
                                    bb += Float(p & 255) * w
                                }
                                hr[3 * x] = rr; hr[3 * x + 1] = gg; hr[3 * x + 2] = bb
                            }
                            cached = r
                        }
                        for i in 0..<acc.count { acc[i] += wy * hr[i] }
                    }
                    r += 1
                }
                for x in 0..<dw {
                    out[y * dw + x] = (to8(acc[3 * x]) << 16) | (to8(acc[3 * x + 1]) << 8) | to8(acc[3 * x + 2])
                }
            }
        }
        return LivenessImage(width: dw, height: dh, pixels: out)
    }

    // =============================================================================================
    // Rectify (checks/rectify-colour.md)
    // =============================================================================================

    public static func rectHeight(_ aspect: Double) -> Int { Int((Double(OPT_W) / aspect).rounded()) }

    /// Corners rolled so corner k becomes the document's top-left: [q_k, q_k+1, q_k+2, q_k+3].
    public static func roll(_ q: [Double], _ k: Int) -> [Double] {
        var r = [Double](repeating: 0, count: 8)
        for i in 0..<4 {
            let s = (i + k) % 4
            r[2 * i] = q[2 * s]
            r[2 * i + 1] = q[2 * s + 1]
        }
        return r
    }

    /// Perspective warp of the quad to W x H (bilinear, border replicate), then the OpenCV 5x5 Gaussian
    /// ([1 4 6 4 1] / 16, border reflect-101). Returns packed 0xRRGGBB pixels.
    public static func rectify(_ frame: LivenessImage, _ quad: [Double], _ W: Int, _ H: Int) -> [UInt32]? {
        let rect: [Double] = [0, 0, Double(W), 0, Double(W), Double(H), 0, Double(H)]
        guard let hm = homography(rect, quad) else { return nil }   // destination pixel -> frame pixel

        let fw = frame.width, fh = frame.height
        let minX = min(min(quad[0], quad[2]), min(quad[4], quad[6]))
        let maxX = max(max(quad[0], quad[2]), max(quad[4], quad[6]))
        let minY = min(min(quad[1], quad[3]), min(quad[5], quad[7]))
        let maxY = max(max(quad[1], quad[3]), max(quad[5], quad[7]))
        guard minX.isFinite, maxX.isFinite, minY.isFinite, maxY.isFinite else { return nil }
        let x0 = clamp(toInt(floor(minX)) - 1, 0, fw - 1)
        let y0 = clamp(toInt(floor(minY)) - 1, 0, fh - 1)
        let x1 = clamp(toInt(ceil(maxX)) + 1, x0, fw - 1)
        let y1 = clamp(toInt(ceil(maxY)) + 1, y0, fh - 1)
        let rw = x1 - x0 + 1, rh = y1 - y0 + 1

        let n = W * H
        var r = [Float](repeating: 0, count: n)
        var g = r, b = r
        frame.pixels.withUnsafeBufferPointer { px in
            for v in 0..<H {
                for u in 0..<W {
                    let d = hm[6] * Double(u) + hm[7] * Double(v) + hm[8]
                    let sx = (hm[0] * Double(u) + hm[1] * Double(v) + hm[2]) / d - Double(x0)
                    let sy = (hm[3] * Double(u) + hm[4] * Double(v) + hm[5]) / d - Double(y0)
                    let fx0 = floor(sx), fy0 = floor(sy)
                    let ix = toInt(fx0), iy = toInt(fy0)                // saturating, like Kotlin's toInt()
                    let fx = Float(sx - fx0), fy = Float(sy - fy0)
                    let xa = clamp(ix, 0, rw - 1) + x0, xb = clamp(ix + 1, 0, rw - 1) + x0   // border replicate
                    let ya = clamp(iy, 0, rh - 1) + y0, yb = clamp(iy + 1, 0, rh - 1) + y0
                    let p00 = px[ya * fw + xa], p10 = px[ya * fw + xb]
                    let p01 = px[yb * fw + xa], p11 = px[yb * fw + xb]
                    let i = v * W + u
                    r[i] = bilinear(red(p00), red(p10), red(p01), red(p11), fx, fy)
                    g[i] = bilinear(green(p00), green(p10), green(p01), green(p11), fx, fy)
                    b[i] = bilinear(blue(p00), blue(p10), blue(p01), blue(p11), fx, fy)
                }
            }
        }
        blur5(&r, W, H)
        blur5(&g, W, H)
        blur5(&b, W, H)
        var out = [UInt32](repeating: 0, count: n)
        for i in 0..<n { out[i] = (to8(r[i]) << 16) | (to8(g[i]) << 8) | to8(b[i]) }
        return out
    }

    /// makeBaseline for a profile without orient / staticHue (passports, licence): candidates = corners whose next edge
    /// is a long edge; score = bandSD(0.8..0.96) - bandSD(0.04..0.2), red channel; the highest wins (first wins ties).
    public static func makeBaseline(_ frame: LivenessImage, _ quad: [Double], _ H: Int) -> Baseline? {
        var ks: [Int] = []
        for k in 0..<4 {
            let k1 = (k + 1) % 4, k2 = (k + 2) % 4
            let e1 = hypot(quad[2 * k1] - quad[2 * k], quad[2 * k1 + 1] - quad[2 * k + 1])
            let e2 = hypot(quad[2 * k2] - quad[2 * k1], quad[2 * k2 + 1] - quad[2 * k1 + 1])
            if e1 >= e2 { ks.append(k) }
        }
        if ks.isEmpty { ks.append(0) }
        var best: Baseline? = nil
        var bestScore = -Double.greatestFiniteMagnitude
        for k in ks {
            guard let img = rectify(frame, roll(quad, k), OPT_W, H) else { continue }
            let score = bandSD(img, OPT_W, H, 0.8, 0.96) - bandSD(img, OPT_W, H, 0.04, 0.2)
            if score > bestScore {
                bestScore = score
                best = Baseline(k: k, img: img)
            }
        }
        return best
    }

    /// Population SD of the RED channel over the full width, rows round(y0*H) for max(1, round((y1-y0)*H)).
    public static func bandSD(_ img: [UInt32], _ W: Int, _ H: Int, _ y0: Double, _ y1: Double) -> Double {
        let r0 = Int(jsRound(y0 * Double(H)))
        let rows = max(1, Int(jsRound((y1 - y0) * Double(H))))
        let r1 = min(H, r0 + rows)
        var sum = 0.0, sq = 0.0
        var n = 0
        if r0 < r1 {
            for y in r0..<r1 {
                for x in 0..<W {
                    let v = Double(red(img[y * W + x]))
                    sum += v; sq += v * v; n += 1
                }
            }
        }
        if n == 0 { return 0 }
        let mean = sum / Double(n)
        return sqrt(max(0, sq / Double(n) - mean * mean))
    }

    // =============================================================================================
    // CIELAB (checks/rectify-colour.md)
    // =============================================================================================

    private static let LIN: [Double] = (0..<256).map { v in
        let c = Double(v) / 255
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16.0 / 116.0 }

    /// sRGB (D65) -> (L*, a*, b*).
    public static func lab(_ rgb: UInt32) -> (Double, Double, Double) {
        let r = LIN[Int(red(rgb))], g = LIN[Int(green(rgb))], b = LIN[Int(blue(rgb))]
        let x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047
        let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
        let z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883
        let fx = f(x), fy = f(y), fz = f(z)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }

    // =============================================================================================
    // Laminate colours (checks/laminate.md, vision-core.ts:1187)
    // =============================================================================================

    public static func chromaGrid(_ img: [UInt32], _ W: Int, _ H: Int) -> Grid {
        let gr = Grid(W >> 1, H >> 1)
        var sumA = 0.0, sumB = 0.0
        var okN = 0
        for y in 0..<gr.gh {
            for x in 0..<gr.gw {
                let p = img[(2 * y) * W + 2 * x]
                let j = y * gr.gw + x
                let (l, a, b) = lab(p)
                gr.L[j] = l; gr.A[j] = a; gr.B[j] = b
                gr.ok[j] = min(min(red(p), green(p)), blue(p)) < 235
                if gr.ok[j] { sumA += a; sumB += b; okN += 1 }
            }
        }
        if okN > 0 {                                        // remove the frame's colour cast
            let ma = sumA / Double(okN), mb = sumB / Double(okN)
            for j in 0..<gr.A.count { gr.A[j] -= ma; gr.B[j] -= mb }
        }
        return gr
    }

    public static func iridBase(_ litImg: [UInt32], _ W: Int, _ H: Int) -> IridBase {
        let g = chromaGrid(litImg, W, H)
        let chroma = (0..<(g.gw * g.gh)).map { hypot(g.A[$0], g.B[$0]) }
        var own = [Double](repeating: 0, count: g.gw * g.gh)
        for y in 0..<g.gh {
            for x in 0..<g.gw {
                var m = 0.0
                for dy in -3...3 {
                    let yy = y + dy
                    if yy < 0 || yy >= g.gh { continue }
                    for dx in -3...3 {
                        let xx = x + dx
                        if xx < 0 || xx >= g.gw { continue }
                        m = max(m, chroma[yy * g.gw + xx])
                    }
                }
                own[y * g.gw + x] = m
            }
        }
        return IridBase(gw: g.gw, gh: g.gh, own: own)
    }

    /// 12 hue-sector shares of NEW saturated colour on the page (nil when no usable cell).
    public static func iridescence(_ base: IridBase?, _ cur: Grid?) -> [Double]? {
        guard let base = base, let cur = cur, base.gw == cur.gw, base.gh == cur.gh else { return nil }
        let gw = cur.gw, gh = cur.gh
        let bx = Int(jsRound(0.04 * Double(gw))), by = Int(jsRound(0.04 * Double(gh)))
        var count = [Double](repeating: 0, count: 12)
        var usable = 0
        if by < gh - by && bx < gw - bx {
            for y in by..<(gh - by) {
                for x in bx..<(gw - bx) {
                    let j = y * gw + x
                    if !cur.ok[j] { continue }
                    usable += 1
                    let a = cur.A[j], b = cur.B[j]
                    if cur.L[j] < 55 || hypot(a, b) - base.own[j] <= 12 { continue }   // not bright / no new colour
                    let deg = atan2(b, a) * 180 / Double.pi
                    if deg > -15 && deg < 75 { continue }                           // skin and warm paper tones
                    let sector = Int(floor((deg + 360).truncatingRemainder(dividingBy: 360) / 30))
                    count[min(11, sector)] += 1
                }
            }
        }
        if usable == 0 { return nil }
        for i in 0..<12 { count[i] /= Double(usable) }
        return count
    }

    // =============================================================================================
    // Page response to the light (checks/reflection.md, vision-core.ts:1280)
    // =============================================================================================

    public static func pageResponse(_ B: [UInt32], _ C: [UInt32], _ W: Int, _ H: Int) -> [Double]? {
        let cell = 8, edge = 2
        let cols = W / cell - 2 * edge, rows = H / cell - 2 * edge
        if cols <= 0 || rows <= 0 { return nil }
        let n = cols * rows

        // mean RGB per cell (every 2nd pixel in x and y), baseline and now
        var bR = [Double](repeating: 0, count: n), bG = bR, bB = bR, cR = bR, cG = bR, cB = bR
        for j in 0..<n {
            let ox = (j % cols + edge) * cell, oy = (j / cols + edge) * cell
            var sbr = 0.0, sbg = 0.0, sbb = 0.0, scr = 0.0, scg = 0.0, scb = 0.0
            var k = 0
            for dy in stride(from: 0, to: cell, by: 2) {
                for dx in stride(from: 0, to: cell, by: 2) {
                    let i = (oy + dy) * W + ox + dx
                    let pb = B[i], pc = C[i]
                    sbr += Double(red(pb)); sbg += Double(green(pb)); sbb += Double(blue(pb))
                    scr += Double(red(pc)); scg += Double(green(pc)); scb += Double(blue(pc))
                    k += 1
                }
            }
            let kd = Double(k)
            bR[j] = sbr / kd; bG[j] = sbg / kd; bB[j] = sbb / kd
            cR[j] = scr / kd; cG[j] = scg / kd; cB[j] = scb / kd
        }

        // per-channel gain: median of c/b over cells with b > 25 and c < 250
        let gain = [channelGain(bR, cR), channelGain(bG, cG), channelGain(bB, cB)]

        // log-ratio of brightness, then a lighting plane over the calm cells
        var lrs: [(Double, Double, Double)] = []          // (lr, x, y)
        for j in 0..<n {
            let lb = (bR[j] + bG[j] + bB[j]) / 3, lc = (cR[j] + cG[j] + cB[j]) / 3
            let clip = min(min(cR[j], cG[j]), cB[j]) >= 250
            if lb > 25 && lc > 5 && !clip {
                lrs.append((log(lc / lb), Double(j % cols) / Double(cols), Double(j / cols) / Double(rows)))
            }
        }
        var m0 = 0.0
        if !lrs.isEmpty {
            let v = lrs.map { $0.0 }.sorted()
            m0 = v[v.count >> 1]
        }
        var p0 = m0, p1 = 0.0, p2 = 0.0
        var calm = 0
        var s11 = 0.0, s1x = 0.0, s1y = 0.0, sxx = 0.0, sxy = 0.0, syy = 0.0
        var t1 = 0.0, tx = 0.0, ty = 0.0
        for e in lrs {
            if abs(e.0 - m0) >= 0.2 { continue }
            let x = e.1 - 0.5, y = e.2 - 0.5, l = e.0
            calm += 1
            s11 += 1; s1x += x; s1y += y; sxx += x * x; sxy += x * y; syy += y * y
            t1 += l; tx += l * x; ty += l * y
        }
        if calm >= 50 {
            let det = det3(s11, s1x, s1y, s1x, sxx, sxy, s1y, sxy, syy)
            if abs(det) > 1e-9 {
                p0 = det3(t1, s1x, s1y, tx, sxx, sxy, ty, sxy, syy) / det
                p1 = det3(s11, t1, s1y, s1x, tx, sxy, s1y, ty, syy) / det
                p2 = det3(s11, s1x, t1, s1x, sxx, tx, s1y, sxy, ty) / det
            }
        }

        // specular / colour-shifted cells, and the brightness pairs for the veil lift
        var spec = 0, chroma = 0
        var pairs: [(Double, Double)] = []
        for j in 0..<n {
            let lb = (bR[j] + bG[j] + bB[j]) / 3, lc = (cR[j] + cG[j] + cB[j]) / 3
            let clip = min(min(cR[j], cG[j]), cB[j]) >= 250
            let x = Double(j % cols) / Double(cols), y = Double(j / cols) / Double(rows)
            let expected = lb * exp(p0 + p1 * (x - 0.5) + p2 * (y - 0.5))
            let gbR = bR[j] * gain[0], gbG = bG[j] * gain[1], gbB = bB[j] * gain[2]
            let sc = cR[j] + cG[j] + cB[j], sg = gbR + gbG + gbB
            let shift = (sc == 0 || sg == 0) ? 0 : hypot(cR[j] / sc - gbR / sg, cG[j] / sc - gbG / sg)
            let isSpec: Bool = clip ? (expected < 240) : (shift <= 0.05 && lc > 1.18 * expected + 10)
            if isSpec {
                spec += 1
            } else if !clip && shift > 0.05 && lb > 40 && lc > 40 {
                chroma += 1
            }
            if lb < 236 && lc < 236 && lb > 4 { pairs.append((gamma(lb), gamma(lc))) }
        }

        // flare: pixels inside the 16 px ring that white out under the light but were not white before
        var flare = 0, total = 0
        let ring = cell * edge
        for yy in stride(from: ring, to: H - ring, by: 2) {
            for xx in stride(from: ring, to: W - ring, by: 2) {
                let i = yy * W + xx
                let pc = C[i], pb = B[i]
                let minC = min(min(red(pc), green(pc)), blue(pc))
                let minB = min(min(Double(red(pb)) * gain[0], Double(green(pb)) * gain[1]), Double(blue(pb)) * gain[2])
                total += 1
                if minC >= 242 && minB < 236 { flare += 1 }
            }
        }

        // veil lift: how much more the dark third brightened than the bright third (added light)
        var veil = 1.0
        if pairs.count >= 200 {
            // stable sort by the base brightness (Kotlin sortBy is stable: equal keys keep their order)
            let order = pairs.indices.sorted { pairs[$0].0 < pairs[$1].0 || (pairs[$0].0 == pairs[$1].0 && $0 < $1) }
            let sorted = order.map { pairs[$0] }
            let third = Int(floor(0.3 * Double(sorted.count)))
            if third > 0 {
                let dark = partRatio(Array(sorted[0..<third]))
                let bright = partRatio(Array(sorted[(sorted.count - third)..<sorted.count]))
                veil = dark / max(bright, 0.001)
            }
        }

        return [Double(spec) / Double(n), Double(chroma) / Double(n), total == 0 ? 0 : Double(flare) / Double(total), veil]
    }

    private static func channelGain(_ b: [Double], _ c: [Double]) -> Double {
        var v: [Double] = []
        for j in 0..<b.count where b[j] > 25 && c[j] < 250 { v.append(c[j] / b[j]) }
        if v.isEmpty { return 1 }
        v.sort()
        return v[v.count >> 1]
    }

    private static func partRatio(_ part: [(Double, Double)]) -> Double {
        let b = part.map { $0.0 }.sorted(), c = part.map { $0.1 }.sorted()
        return c[c.count >> 1] / max(b[b.count >> 1], 0.001)
    }

    private static func gamma(_ v: Double) -> Double { 255 * pow(v / 255, 2.2) }

    private static func det3(_ a: Double, _ b: Double, _ c: Double,
                             _ d: Double, _ e: Double, _ f: Double,
                             _ g: Double, _ h: Double, _ i: Double) -> Double {
        a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    }

    // =============================================================================================
    // Quality (checks/quality.md, vision-core.ts:1016)
    // =============================================================================================

    /// (sharpness = Laplacian variance (population), glareFrac = grey > 249) inside the outline shrunk by 4%.
    public static func quality(_ frame: LivenessImage, _ quad: [Double]) -> (Double, Double) {
        let cx = (quad[0] + quad[2] + quad[4] + quad[6]) / 4
        let cy = (quad[1] + quad[3] + quad[5] + quad[7]) / 4
        var m = [Double](repeating: 0, count: 8)
        for i in 0..<4 {
            m[2 * i] = jsRound(cx + (quad[2 * i] - cx) * 0.96)
            m[2 * i + 1] = jsRound(cy + (quad[2 * i + 1] - cy) * 0.96)
        }
        let fw = frame.width, fh = frame.height
        guard m.allSatisfy({ $0.isFinite }) else { return (0, 0) }
        let x0 = clamp(toInt(floor(min(min(m[0], m[2]), min(m[4], m[6])))), 0, fw - 1)
        let x1 = clamp(toInt(ceil(max(max(m[0], m[2]), max(m[4], m[6])))), x0, fw - 1)
        let y0 = clamp(toInt(floor(min(min(m[1], m[3]), min(m[5], m[7])))), 0, fh - 1)
        let y1 = clamp(toInt(ceil(max(max(m[1], m[3]), max(m[5], m[7])))), y0, fh - 1)

        func grey(_ x: Int, _ y: Int) -> Int {                 // OpenCV RGBA2GRAY fixed point
            let p = frame.pixels[y * fw + x]
            return (Int(red(p)) * 4899 + Int(green(p)) * 9617 + Int(blue(p)) * 1868 + 8192) >> 14
        }
        var sum = 0.0, sq = 0.0
        var area = 0, bright = 0
        for y in y0...y1 {
            for x in x0...x1 {
                if !insideConvex(m, Double(x), Double(y)) { continue }
                let g = grey(x, y)
                let lap = Double(grey(x, reflect(y - 1, fh)) + grey(x, reflect(y + 1, fh))
                                 + grey(reflect(x - 1, fw), y) + grey(reflect(x + 1, fw), y)) - 4.0 * Double(g)
                sum += lap; sq += lap * lap
                area += 1
                if g > 249 { bright += 1 }
            }
        }
        if area == 0 { return (0, 0) }
        let mean = sum / Double(area)
        return (sq / Double(area) - mean * mean, Double(bright) / Double(area))
    }

    /// Point (pixel centre) inside or on the edge of a convex quad.
    private static func insideConvex(_ q: [Double], _ x: Double, _ y: Double) -> Bool {
        var pos = false, neg = false
        for i in 0..<4 {
            let j = (i + 1) % 4
            let c = (q[2 * j] - q[2 * i]) * (y - q[2 * i + 1]) - (q[2 * j + 1] - q[2 * i + 1]) * (x - q[2 * i])
            if c > 0 { pos = true } else if c < 0 { neg = true }
            if pos && neg { return false }
        }
        return true
    }

    // =============================================================================================
    // Helpers
    // =============================================================================================

    /// 3x3 homography (9 numbers) mapping the 4 'from' points onto the 4 'to' points.
    public static func homography(_ from: [Double], _ to: [Double]) -> [Double]? {
        var a = [[Double]](repeating: [Double](repeating: 0, count: 9), count: 8)
        for i in 0..<4 {
            let x = from[2 * i], y = from[2 * i + 1], tx = to[2 * i], ty = to[2 * i + 1]
            a[2 * i] = [x, y, 1, 0, 0, 0, -tx * x, -tx * y, tx]
            a[2 * i + 1] = [0, 0, 0, x, y, 1, -ty * x, -ty * y, ty]
        }
        for col in 0..<8 {                                  // Gauss-Jordan, partial pivoting
            var piv = col
            for r in (col + 1)..<8 where abs(a[r][col]) > abs(a[piv][col]) { piv = r }
            if abs(a[piv][col]) < 1e-12 { return nil }
            a.swapAt(col, piv)
            for r in 0..<8 where r != col {
                let f = a[r][col] / a[col][col]
                for k in col..<9 { a[r][k] -= f * a[col][k] }
            }
        }
        var h = [Double](repeating: 0, count: 9)
        for i in 0..<8 { h[i] = a[i][8] / a[i][i] }
        h[8] = 1
        return h
    }

    private static func bilinear(_ p00: UInt32, _ p10: UInt32, _ p01: UInt32, _ p11: UInt32, _ fx: Float, _ fy: Float) -> Float {
        let top = Float(p00) + (Float(p10) - Float(p00)) * fx
        let bot = Float(p01) + (Float(p11) - Float(p01)) * fx
        return top + (bot - top) * fy
    }

    /// Separable [1 4 6 4 1]/16 blur, border reflect-101 (OpenCV GaussianBlur 5x5 with sigma 0).
    private static func blur5(_ ch: inout [Float], _ W: Int, _ H: Int) {
        let k0: Float = 6.0 / 16, k1: Float = 4.0 / 16, k2: Float = 1.0 / 16
        var tmp = [Float](repeating: 0, count: ch.count)
        for y in 0..<H {
            let row = y * W
            for x in 0..<W {
                tmp[row + x] = k0 * ch[row + x]
                    + k1 * (ch[row + reflect(x - 1, W)] + ch[row + reflect(x + 1, W)])
                    + k2 * (ch[row + reflect(x - 2, W)] + ch[row + reflect(x + 2, W)])
            }
        }
        for y in 0..<H {
            for x in 0..<W {
                ch[y * W + x] = k0 * tmp[y * W + x]
                    + k1 * (tmp[reflect(y - 1, H) * W + x] + tmp[reflect(y + 1, H) * W + x])
                    + k2 * (tmp[reflect(y - 2, H) * W + x] + tmp[reflect(y + 2, H) * W + x])
            }
        }
    }

    private static func reflect(_ index: Int, _ n: Int) -> Int {
        if n == 1 { return 0 }
        var i = index
        while i < 0 || i >= n {
            if i < 0 { i = -i }
            if i >= n { i = 2 * n - 2 - i }
        }
        return i
    }

    @inline(__always) static func red(_ p: UInt32) -> UInt32 { (p >> 16) & 255 }
    @inline(__always) static func green(_ p: UInt32) -> UInt32 { (p >> 8) & 255 }
    @inline(__always) static func blue(_ p: UInt32) -> UInt32 { p & 255 }

    /// Math.round to 0..255 (half up; the values are never negative after clamping).
    @inline(__always) private static func to8(_ v: Float) -> UInt32 {
        UInt32(max(0, min(255, Int((v + 0.5).rounded(.down)))))
    }

    @inline(__always) static func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { max(lo, min(hi, v)) }

    /// Double -> Int that never traps: NaN -> 0, out of range -> saturated (as Kotlin's Double.toInt()).
    @inline(__always) static func toInt(_ d: Double) -> Int {
        if d.isNaN { return 0 }
        if d >= 9.0e15 { return 9_000_000_000_000_000 }
        if d <= -9.0e15 { return -9_000_000_000_000_000 }
        return Int(d)
    }

    // =============================================================================================
    // Cards (03-documents/civil-id, checks/emblem.md, checks/overlay-cut-edge.md, rectify-colour.md)
    // =============================================================================================


    /// A profile rectangle in RECT pixels (vision-core.ts:1048 px): round, at least 1 px. Returns [x, y, w, h].
    public static func px(_ r: [Double], _ h: Int) -> [Int] {
        [Int(jsRound(r[0] * Double(OPT_W))), Int(jsRound(r[1] * Double(h))),
         max(1, Int(jsRound(r[2] * Double(OPT_W)))), max(1, Int(jsRound(r[3] * Double(h))))]
    }

    /// CIELAB b* of one sRGB pixel (vision-core.ts:128 labB).
    public static func labB(_ r: Int, _ g: Int, _ b: Int) -> Double {
        let rr = cardLIN[r], gg = cardLIN[g], bb = cardLIN[b]
        return 200 * (cardF(0.2126729 * rr + 0.7151522 * gg + 0.072175 * bb)
                      - cardF((0.0193339 * rr + 0.119192 * gg + 0.9503041 * bb) / 1.08883))
    }

    /// The cedar emblem (vision-core.ts:1242): how much yellower (b*) the cell is than the plain ring around it, now and
    /// in the reference, at 9 small offsets; the offset where the emblem stands out most NOW is used, with the reference
    /// read at that same place. Returns [now, base] or nil. cell / inner / outer are fractions [x, y, w, h] of the card.
    public static func emblemReading(_ B: [UInt32], _ C: [UInt32], _ W: Int, _ H: Int,
                              _ cellR: [Double], _ innerR: [Double], _ outerR: [Double]) -> [Double]? {
        let cell = px(cellR, H), inner = px(innerR, H), outer = px(outerR, H)
        func inside(_ r: [Int], _ x: Int, _ y: Int) -> Bool { x >= r[0] && x < r[0] + r[2] && y >= r[1] && y < r[1] + r[3] }
        func read(_ img: [UInt32], _ dx: Int, _ dy: Int) -> Double? {
            var sc = 0.0, sr = 0.0
            var nc = 0, nr = 0
            var y = outer[1]
            while y < outer[1] + outer[3] {
                var x = outer[0]
                while x < outer[0] + outer[2] {
                    let inCell = inside(cell, x, y)
                    if inCell || !inside(inner, x, y) {             // the rest of the mark: neither sample
                        let px = x + dx, py = y + dy
                        if px >= 0 && py >= 0 && px < W && py < H {
                            let p = img[py * W + px]
                            let r = Int(red(p)), g = Int(green(p)), b = Int(blue(p))
                            if !(r >= 235 && g >= 235 && b >= 235) {
                                let v = labB(r, g, b)
                                if inCell { sc += v; nc += 1 } else { sr += v; nr += 1 }
                            }
                        }
                    }
                    x += 2
                }
                y += 2
            }
            return nc >= 20 && nr >= 20 ? sc / Double(nc) - sr / Double(nr) : nil
        }
        var best: [Double]? = nil
        for dy in [-7, 0, 7] {
            for dx in [-9, 0, 9] {
                guard let now = read(C, dx, dy) else { continue }
                if let b = best, now <= b[0] { continue }
                if let base = read(B, dx, dy) { best = [now, base] }
            }
        }
        return best
    }

    /// OpenCV 8-bit HSV of one pixel: (H 0..180, S 0..255).
    private static func hsv(_ p: UInt32) -> (Int, Int) {
        let r = Int(red(p)), g = Int(green(p)), b = Int(blue(p))
        let v = max(r, g, b), mn = min(r, g, b), d = v - mn
        let s = v == 0 ? 0 : Int(jsRound(255.0 * Double(d) / Double(v)))
        var h: Double
        if d == 0 { h = 0 }
        else if v == r { h = 60.0 * Double(g - b) / Double(d) }
        else if v == g { h = 120.0 + 60.0 * Double(b - r) / Double(d) }
        else { h = 240.0 + 60.0 * Double(r - g) / Double(d) }
        if h < 0 { h += 360 }
        return (Int(jsRound(h / 2)), s)
    }

    /// rectify-colour.md hueShare: every 2nd pixel of the rect with hue in [lo, hi] and saturation >= minSat.
    private static func hueShare(_ img: [UInt32], _ W: Int, _ r: [Int], _ lo: Double, _ hi: Double, _ minSat: Double) -> Double {
        var n = 0
        var y = r[1]
        while y < r[1] + r[3] {
            var x = r[0]
            while x < r[0] + r[2] {
                if x >= 0 && x < W && y >= 0 && y * W + x < img.count {
                    let hs = hsv(img[y * W + x])
                    if Double(hs.0) >= lo && Double(hs.0) <= hi && Double(hs.1) >= minSat { n += 1 }
                }
                x += 2
            }
            y += 2
        }
        let cells = ((r[3] + 1) / 2) * ((r[2] + 1) / 2)
        return cells == 0 ? 0 : Double(n) / Double(cells)
    }

    /// rectify-colour.md staticFeature frac: share of the feature ROI with the resting hue (every pixel).
    private static func staticFrac(_ img: [UInt32], _ W: Int, _ r: [Int], _ lo: Double, _ hi: Double, _ minSat: Double) -> Double {
        var n = 0, all = 0
        for y in r[1]..<(r[1] + r[3]) {
            for x in r[0]..<(r[0] + r[2]) {
                if x < 0 || x >= W || y < 0 || y * W + x >= img.count { continue }
                all += 1
                let hs = hsv(img[y * W + x])
                if Double(hs.0) >= lo && Double(hs.0) <= hi && Double(hs.1) >= minSat { n += 1 }
            }
        }
        return all == 0 ? 0 : Double(n) / Double(all)
    }

    /// makeBaseline for a profile WITH an orientation mark (the ID front, vision-core.ts:1074): of the corners whose next
    /// edge is long, the one whose straightened card shows the mark's hue in orient.roi (+ 0.01 x the resting cedar share).
    /// orient = [x, y, w, h, hueLo, hueHi, minSat]; feature = the same or nil.
    public static func makeBaselineOriented(_ frame: LivenessImage, _ quad: [Double], _ H: Int,
                                     _ orient: [Double], _ feature: [Double]?) -> Baseline? {
        var ks: [Int] = []
        for k in 0..<4 {
            let k1 = (k + 1) % 4, k2 = (k + 2) % 4
            let e1 = hypot(quad[2 * k1] - quad[2 * k], quad[2 * k1 + 1] - quad[2 * k + 1])
            let e2 = hypot(quad[2 * k2] - quad[2 * k1], quad[2 * k2 + 1] - quad[2 * k1 + 1])
            if e1 >= e2 { ks.append(k) }
        }
        if ks.isEmpty { ks.append(0) }
        var best: Baseline? = nil
        var bestScore = -Double.greatestFiniteMagnitude
        for k in ks {
            guard let img = rectify(frame, roll(quad, k), OPT_W, H) else { continue }
            let o = px(Array(orient[0..<4]), H)
            var score = hueShare(img, OPT_W, o, orient[4], orient[5], orient[6])
            if let f = feature {
                let fr = px(Array(f[0..<4]), H)
                score += 0.01 * staticFrac(img, OPT_W, fr, f[4], f[5], f[6])
            }
            if score > bestScore {
                bestScore = score
                best = Baseline(k: k, img: img)
            }
        }
        return best
    }

    /// The overlay cut edge is measured on the card straightened to CUT_W x CUT_H from the FULL camera frame.
    public static let CUT_W = 856
    public static let CUT_H = 540

    /// cut-edge.ts cutEdgeOf: the score of the straightest near-vertical line to the right of the emblem (an overlaid
    /// print's cut edge). frame = the FULL upright camera frame; quad = the card there, top left first, clockwise.
    public static func cutEdgeOf(_ frame: LivenessImage, _ quad: [Double]) -> Double {
        let fw = frame.width, fh = frame.height
        let minX = min(min(quad[0], quad[2]), min(quad[4], quad[6])), maxX = max(max(quad[0], quad[2]), max(quad[4], quad[6]))
        let minY = min(min(quad[1], quad[3]), min(quad[5], quad[7])), maxY = max(max(quad[1], quad[3]), max(quad[5], quad[7]))
        let mx = 0.08 * (maxX - minX), my = 0.08 * (maxY - minY)
        let x0 = clamp(Int(floor(minX - mx)), 0, fw - 1), y0 = clamp(Int(floor(minY - my)), 0, fh - 1)
        let x1 = clamp(Int(ceil(maxX + mx)), x0, fw - 1), y1 = clamp(Int(ceil(maxY + my)), y0, fh - 1)
        let bw = x1 - x0 + 1, bh = y1 - y0 + 1
        var grey = [Int](repeating: 0, count: bw * bh)
        for y in 0..<bh {
            for x in 0..<bw {
                let p = frame.pixels[(y0 + y) * fw + x0 + x]
                grey[y * bw + x] = (Int(red(p)) * 77 + Int(green(p)) * 150 + Int(blue(p)) * 29) >> 8
            }
        }
        // cardBand: unit square -> quad homography, bilinear, outside = 255, clamped and rounded half to even
        let hq = unitToQuad(quad)
        var card = [Double](repeating: 0, count: CUT_W * CUT_H)
        for y in 0..<CUT_H {
            let v = (Double(y) + 0.5) / Double(CUT_H)
            for x in 0..<CUT_W {
                let u = (Double(x) + 0.5) / Double(CUT_W)
                let w = hq[6] * u + hq[7] * v + hq[8]
                let sx = (hq[0] * u + hq[1] * v + hq[2]) / w - 0.5 - Double(x0)
                let sy = (hq[3] * u + hq[4] * v + hq[5]) / w - 0.5 - Double(y0)
                let ix = Int(floor(sx)), iy = Int(floor(sy))
                let o = y * CUT_W + x
                if ix < 0 || iy < 0 || ix + 1 >= bw || iy + 1 >= bh { card[o] = 255; continue }
                let fx = sx - Double(ix), fy = sy - Double(iy)
                let i = iy * bw + ix
                let top = Double(grey[i]) + Double(grey[i + 1] - grey[i]) * fx
                let bottom = Double(grey[i + bw]) + Double(grey[i + bw + 1] - grey[i + bw]) * fx
                card[o] = min(255, max(0, top + (bottom - top) * fy)).rounded(.toNearestOrEven)
            }
        }
        return cutEdgeScore(card, CUT_W, CUT_H)
    }

    /// cut-edge.ts cutEdgeScore on a straightened grey card w x h.
    public static func cutEdgeScore(_ card: [Double], _ w: Int, _ h: Int) -> Double {
        var tmp = [Double](repeating: 0, count: w * h)
        var b = [Double](repeating: 0, count: w * h)
        for y in 0..<h {                                            // blur3: [1 2 1]/4, edges replicated
            for x in 0..<w {
                let i = y * w + x
                let l = x > 0 ? card[i - 1] : card[i], r = x < w - 1 ? card[i + 1] : card[i]
                tmp[i] = (l + 2 * card[i] + r) / 4
            }
        }
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let u = y > 0 ? tmp[i - w] : tmp[i], d = y < h - 1 ? tmp[i + w] : tmp[i]
                b[i] = (u + 2 * tmp[i] + d) / 4
            }
        }
        var gx = [Double](repeating: 0, count: w * h)               // |Sobel x|, interior only
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let i = y * w + x
                gx[i] = abs((b[i - w + 1] - b[i - w - 1]) + 2 * (b[i + 1] - b[i - 1]) + (b[i + w + 1] - b[i + w - 1]))
            }
        }
        let leftW = Int(floor(0.45 * Double(w)))
        var left: [Double] = []
        left.reserveCapacity(h * leftW)
        for y in 0..<h { for x in 0..<leftW { left.append(gx[y * w + x]) } }
        let base = percentile(&left, 0.5) + 1
        let y0 = Int(floor(0.04 * Double(h))), y1 = Int(floor(0.30 * Double(h)))
        let n = y1 - y0
        var best = 0.0
        for x0 in Int(floor(0.12 * Double(w)))..<Int(floor(0.34 * Double(w))) {
            for s in [-0.06, -0.03, 0.0, 0.03, 0.06] {
                var col = [Double](repeating: 0, count: n)
                for k in 0..<n {
                    let yy = y0 + k
                    let xx = min(w - 2, max(1, Int(jsRound(Double(x0) + s * Double(k)))))
                    let i = yy * w + xx
                    col[k] = max(gx[i], max(gx[i - 1], gx[i + 1]))
                }
                best = max(best, percentile(&col, 0.2))
            }
        }
        return best / base
    }

    /// Sorted ascending, linear interpolation between floor(k) and ceil(k), k = (n - 1) p. Sorts its argument.
    private static func percentile(_ v: inout [Double], _ p: Double) -> Double {
        v.sort()
        let k = Double(v.count - 1) * p
        let lo = Int(floor(k)), hi = Int(ceil(k))
        return v[lo] + (v[hi] - v[lo]) * (k - Double(lo))
    }

    /// barcode-prep.ts unitToQuad: (u, v) in the unit square -> the quad (TL, TR, BR, BL).
    public static func unitToQuad(_ q: [Double]) -> [Double] {
        let x0 = q[0], y0 = q[1], x1 = q[2], y1 = q[3], x2 = q[4], y2 = q[5], x3 = q[6], y3 = q[7]
        let dx1 = x1 - x2, dx2 = x3 - x2, dy1 = y1 - y2, dy2 = y3 - y2
        let sx = x0 - x1 + x2 - x3, sy = y0 - y1 + y2 - y3
        let den = dx1 * dy2 - dx2 * dy1
        let g = den == 0 ? 0 : (sx * dy2 - dx2 * sy) / den
        let h = den == 0 ? 0 : (dx1 * sy - sx * dy1) / den
        return [x1 - x0 + g * x1, x3 - x0 + h * x3, x0, y1 - y0 + g * y1, y3 - y0 + h * y3, y0, g, h, 1]
    }

    /// The full camera buffer upright (sensor buffers are landscape, the phone is held in portrait).
    public static func fullUprightFrame(_ pb: CVPixelBuffer) -> LivenessImage? {
        guard let img = image(from: pb) else { return nil }
        return img.width > img.height ? rotate90CW(img) : img
    }
}

private let cardLIN: [Double] = (0..<256).map { v in
    let c = Double(v) / 255
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
}

private func cardF(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16.0 / 116.0 }
