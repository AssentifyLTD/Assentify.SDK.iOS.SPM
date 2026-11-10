import Foundation

/// For an OPEN passport shown with BOTH pages (lb_passport "spread"). Port of SpreadFix.kt.
///
/// finder2's bottom corners sit on the photo page, but a top corner sometimes lands on the TOP OF THE UPPER PAGE instead
/// of the fold. Expected photo-page height = bottom edge / pageAspect. For each side (TL-BL, TR-BR):
///   0.70 .. 1.35 x expected -> keep the top corner (on the fold)
///   1.60 .. 2.50 x expected -> the top corner is on the upper page: move it to the side's midpoint (the fold)
///   anything else           -> nil (cannot tell where the photo page is this frame)
public enum SpreadFix {

    public static func photoPage(_ q: [Double], pageAspect: Double) -> [Double]? {
        func d(_ a: Int, _ b: Int) -> Double { hypot(q[2 * a] - q[2 * b], q[2 * a + 1] - q[2 * b + 1]) }
        let bottom = d(3, 2)
        if bottom < 1.0 { return nil }
        let expected = bottom / pageAspect
        var out = q
        for (top, bot) in [(0, 3), (1, 2)] {               // left side TL-BL, right side TR-BR
            let r = d(top, bot) / expected
            if r >= 0.70 && r <= 1.35 {
                continue                                    // top corner on the fold: keep
            } else if r >= 1.60 && r <= 2.50 {              // top corner on the upper page: halve the side
                out[2 * top] = (q[2 * top] + q[2 * bot]) / 2
                out[2 * top + 1] = (q[2 * top + 1] + q[2 * bot + 1]) / 2
            } else {
                return nil
            }
        }
        return out
    }

    /// true = the page above the photo page fits in the picture (REF upperPageCut with spread.cutMax).
    public static func upperPageInView(_ page: [Double], w: Double, h: Double, cutMax: Double = 0.05) -> Bool {
        !Geometry.upperPageCut(page, w: w, h: h, slack: cutMax)
    }
}
