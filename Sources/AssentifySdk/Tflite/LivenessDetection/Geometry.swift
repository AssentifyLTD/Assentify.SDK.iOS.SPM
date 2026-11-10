import Foundation

/// STEP 1: Geometry. Port of Geometry.kt (itself a port of 08-reference-source/core/geometry.ts).
///
/// A quad is [Double] of 8 = [x0,y0, x1,y1, x2,y2, x3,y3], corners TL, TR, BR, BL, in UPRIGHT frame pixels,
/// origin top-left, x right, y down.
public struct Pose {
    public let lr: Double       // ln(left/right):  > 0 left edge nearer the camera
    public let tb: Double       // ln(top/bottom):  > 0 top edge nearer the camera
    public let area: Double     // px²
    public let cx: Double, cy: Double
    public let angle: Double    // in-plane rotation, radians
    public let aspect: Double   // (top+bottom)/(left+right)
}

/// JavaScript Math.round (half toward +∞).
@inline(__always) func jsRound(_ x: Double) -> Double { let f = floor(x); return x - f >= 0.5 ? f + 1 : f }

/// JavaScript (V8) Math.hypot: Kahan-compensated, scaled by the max.
func jsHypot(_ a: Double, _ b: Double) -> Double {
    if a.isInfinite || b.isInfinite { return .infinity }
    if a.isNaN || b.isNaN { return .nan }
    let x = abs(a), y = abs(b)
    let m = max(x, y)
    if m == 0 { return 0 }
    var sum = 0.0, comp = 0.0
    for v in [x, y] {
        let n = v / m
        let summand = n * n - comp
        let prelim = sum + summand
        comp = (prelim - sum) - summand
        sum = prelim
    }
    return sqrt(sum) * m
}

public enum Geometry {
    private static let TL = 0, TR = 1, BR = 2, BL = 3

    private static func dist(_ q: [Double], _ a: Int, _ b: Int) -> Double {
        jsHypot(q[2 * a] - q[2 * b], q[2 * a + 1] - q[2 * b + 1])
    }

    /// cross(o, a, b) = (a.x-o.x)(b.y-o.y) - (a.y-o.y)(b.x-o.x)
    private static func cross(_ q: [Double], _ o: Int, _ a: Int, _ b: Int) -> Double {
        (q[2 * a] - q[2 * o]) * (q[2 * b + 1] - q[2 * o + 1]) - (q[2 * a + 1] - q[2 * o + 1]) * (q[2 * b] - q[2 * o])
    }

    /// The pose of the document from its 4 corners (relative proxies, not calibrated angles).
    public static func poseOf(_ q: [Double]) -> Pose {
        let left = dist(q, TL, BL), right = dist(q, TR, BR)
        let top = dist(q, TL, TR), bottom = dist(q, BL, BR)
        return Pose(
            lr: log(left / right),
            tb: log(top / bottom),
            area: abs(cross(q, TL, TR, BR) + cross(q, TL, BR, BL)) / 2,
            cx: (q[0] + q[2] + q[4] + q[6]) / 4,
            cy: (q[1] + q[3] + q[5] + q[7]) / 4,
            angle: atan2(q[3] - q[1], q[2] - q[0]),
            aspect: (top + bottom) / (left + right)
        )
    }

    /// Can this outline be the document at all? Finite, inside the picture (margin; `outside` x width allowed during
    /// the tilt), convex and not self-crossing, area >= minQuadAreaFrac x w x h.
    public static func isValidQuad(_ q: [Double], w: Double, h: Double, frameMarginPx: Double, minQuadAreaFrac: Double,
                                   outside: Double = 0) -> Bool {
        let m = frameMarginPx - outside * w
        for i in 0..<4 {
            let x = q[2 * i], y = q[2 * i + 1]
            if !x.isFinite || !y.isFinite { return false }
            if x < m || y < m || x > w - m || y > h - m { return false }
        }
        let turns = (0..<4).map { cross(q, $0, ($0 + 1) % 4, ($0 + 2) % 4) }
        if !(turns.allSatisfy { $0 > 0 } || turns.allSatisfy { $0 < 0 }) { return false }
        return poseOf(q).area >= minQuadAreaFrac * w * h
    }

    /// Only DRAW the outline before the steps when flat and with the document's proportions.
    public static func looksRight(_ q: [Double], docAspect: Double, frontalMax: Double, shapeTol: Double) -> Bool {
        let p = poseOf(q)
        return abs(p.lr) <= frontalMax && abs(p.tb) <= frontalMax && abs(p.aspect / docAspect - 1) <= shapeTol
    }

    /// Lebanese passport only (profile.spread): is the page ABOVE the photo page out of the picture?
    public static func upperPageCut(_ q: [Double], w: Double, h: Double, slack: Double) -> Bool {
        let m = slack * (dist(q, TL, BL) + dist(q, TR, BR)) / 2
        func out(_ x: Double, _ y: Double) -> Bool { x < -m || y < -m || x > w + m || y > h + m }
        return out(2 * q[0] - q[6], 2 * q[1] - q[7]) || out(2 * q[2] - q[4], 2 * q[3] - q[5])
    }

    /// Is (x, y) inside the quad? Used by the civil extract.
    public static func insideQuad(_ x: Double, _ y: Double, _ q: [Double]) -> Bool {
        var sign = 0.0
        for i in 0..<4 {
            let j = (i + 1) % 4
            let c = (q[2 * j] - q[2 * i]) * (y - q[2 * i + 1]) - (q[2 * j + 1] - q[2 * i + 1]) * (x - q[2 * i])
            if c == 0 { continue }
            let s: Double = c > 0 ? 1 : -1
            if sign != 0 && s != sign { return false }
            sign = s
        }
        return true
    }
}
