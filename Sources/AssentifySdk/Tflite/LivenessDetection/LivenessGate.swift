import Foundation

/// From readings to a verdict (rc17 spec, 02-core-spec). Port of LivenessGate.kt.
///
///  - iridescenceResult ... checks/laminate.md   (core/iridescence.ts:24)
///  - emblemResult ........ checks/emblem.md     (core/emblem.ts:30)
///  - ReflectionAnalyzer .. checks/reflection.md (core/reflection.ts:34)
///  - decide .............. gate-policy.md       (core/gate-policy.ts:44)
///
/// States and reasons are the spec's strings, so they can be compared with the web's results.
public enum LivenessGate {

    public static let CONTINUE = "continue"
    public static let RETRY = "retry"
    public static let SUSPECTED_COPY = "suspected_copy"
    public static let INCONCLUSIVE = "inconclusive"

    // =============================================================================================
    // Laminate (iridescence.ts:24)
    // =============================================================================================

    public final class LaminateResult {
        public var state = "unassessable"          // present | absent | unassessable
        public var strong = false
        public var frames = 0
        public var litFrames = 0
        public var hues = 0
        public var peak: Double? = nil             // nil when there were no frames
        public var peakOr0: Double { peak ?? 0 }
    }

    public static func iridescenceResult(_ frames: [[Double]], _ c: LivenessConfig.Laminate) -> LaminateResult {
        let r = LaminateResult()
        r.frames = frames.count
        if frames.isEmpty { return r }             // unassessable, not strong

        var best = [Double](repeating: 0, count: 12)
        var peak = 0.0
        var lit = 0
        for f in frames {
            var total = 0.0
            for i in 0..<12 {
                total += f[i]
                best[i] = max(best[i], f[i])
            }
            if total >= 0.001 { lit += 1 }
            peak = max(peak, total)
        }
        r.litFrames = lit
        r.hues = best.filter { $0 >= 0.0005 }.count
        r.peak = peak

        let enough = r.frames >= c.minFrames && lit >= c.minLitFrames
        if r.frames < c.minFrames {
            r.state = "unassessable"
        } else if enough && r.hues >= c.minHues && peak >= c.minPeak {
            r.state = "present"
        } else {
            r.state = "absent"
        }
        r.strong = enough && r.hues >= c.strongHues && peak >= c.strongPeak
        return r
    }

    // =============================================================================================
    // Emblem (core/emblem.ts:30): the ID front's cedar under the light and the right-edge tilt
    // =============================================================================================

    public final class EmblemResult {
        public var state = "not_configured"        // present | absent | untested | unassessable | not_configured
        public var lit: Double? = nil
        public var jump: Double? = nil
        public var frames = 0
        public var low: Double? = nil
        public var dark: Bool? = nil
    }

    /// readings: lit frames [now, base]; tilt: the emblem per tilted frame (NaN where the frame does not count), or nil
    /// before the tilt; tested: the right edge came far enough for minTiltFrames frames in a row.
    public static func emblemResult(_ readings: [[Double]], configured: Bool, tilt: [Double]?, tested: Bool,
                                    _ c: LivenessConfig.Emblem) -> EmblemResult {
        let r = EmblemResult()
        if !configured { return r }
        let ok = readings.filter { $0[0].isFinite && $0[1].isFinite }
        r.frames = ok.count
        if ok.count < c.minFrames { r.state = "unassessable"; return r }
        let lit = ok.map { $0[0] }.sorted(by: >)[1]
        let bases = ok.map { $0[1] }.sorted()
        let jump = lit - max(0, bases[bases.count >> 1])
        r.lit = lit
        r.jump = jump
        let jumped = lit >= c.litMin && (jump >= c.jumpMin || lit >= c.strongLit)
        guard let tilt = tilt else { r.state = jumped ? "present" : "absent"; return r }
        let n = c.minTiltFrames
        var low: Double? = nil
        var i = 0
        while i + n <= tilt.count {
            var allFinite = true
            var top = -Double.greatestFiniteMagnitude
            for j in i..<(i + n) {
                if !tilt[j].isFinite { allFinite = false; break }
                top = max(top, tilt[j])
            }
            if allFinite && (low == nil || top < low!) { low = top }
            i += 1
        }
        r.low = low
        let dark = low != nil && low! <= c.darkMax * lit
        r.dark = dark
        r.state = (jumped && dark) ? "present" : (jumped && !tested) ? "untested" : "absent"
        return r
    }

    // =============================================================================================
    // Reflection (reflection.ts:34)
    // =============================================================================================

    public final class ReflectionResult {
        public var state = "unassessable"          // reflective | matte | emissive | unassessable
        public var usable = 0
        public var litFlare: Double? = nil
        public var litLift: Double? = nil
        public var iridescent = false              // recorded only
    }

    /// Samples are LivenessVision.pageResponse arrays [specFrac, chromaFrac, flareFrac, veilLift].
    public final class ReflectionAnalyzer {
        private let c: LivenessConfig.Reflection
        private var lit: [[Double]] = []
        private var tilt: [[Double]] = []

        public init(_ c: LivenessConfig.Reflection) { self.c = c }

        /// A lit frame of the light step (unlit reference). Whited-out frames are not a reflection.
        public func addLit(_ s: [Double]?) {
            if let s = s, s[LivenessVision.FLARE].isFinite, s[LivenessVision.FLARE] <= c.whiteoutMax { lit.append(s) }
        }

        /// A tilted frame (lit reference): recorded only.
        public func add(_ s: [Double]?) {
            if let s = s, s[LivenessVision.SPEC].isFinite, s[LivenessVision.CHROMA].isFinite { tilt.append(s) }
        }

        public func usable() -> Int { lit.count }

        public func result() -> ReflectionResult {
            let r = ReflectionResult()
            r.usable = lit.count
            r.litFlare = steadyMax(lit.map { $0[LivenessVision.FLARE] })
            let lifts = lit.map { $0[LivenessVision.VEIL] }.filter { $0.isFinite }.sorted()
            r.litLift = lifts.isEmpty ? nil : lifts[lifts.count >> 1]
            if r.usable < c.minLitFrames {
                r.state = "unassessable"
            } else if let lift = r.litLift, lift < c.liftMin {
                r.state = "emissive"
            } else if (r.litFlare ?? 0) >= c.flareMin {
                r.state = "reflective"
            } else {
                r.state = "matte"
            }
            let chromas = tilt.map { $0[LivenessVision.CHROMA] }
            let tiltChroma = chromas.count >= 2 ? steadyMax(chromas) : nil
            r.iridescent = tiltChroma != nil && tiltChroma! >= c.chromaMin
            return r
        }

        /// Second largest, so one stray frame cannot decide (the only one if there is one; nil if none).
        private func steadyMax(_ xs: [Double]) -> Double? {
            switch xs.count {
            case 0: return nil
            case 1: return xs[0]
            default: return xs.sorted()[xs.count - 2]
            }
        }
    }

    // =============================================================================================
    // decide (gate-policy.ts:44)
    // =============================================================================================

    /// nil fields are "not given" (not the same as false), exactly as in the spec.
    public final class GateInput {
        public var cameraOk = true
        public var enginePhase: String? = nil      // done | failed | other
        public var attempt = 0
        public var challenge: String? = nil        // observed | not_observed | unassessable
        public var optical = "not_configured"
        public var opticalPolicy = "shadow"
        public var reflection: String? = nil       // reflective | matte | emissive | unassessable
        public var reflectionPolicy: String? = nil
        public var matteBefore: Bool? = nil
        public var lightAvailable: Bool? = nil
        public var emblem: String? = nil
        public var emblemPolicy: String? = nil
        public var laminate: String? = nil         // present | absent | unassessable | not_configured
        public var laminatePolicy: String? = nil
        public var laminateStrong: Bool? = nil
        public var matteNotEvidence: Bool? = nil
        public var batteryLow: Bool? = nil
        public var emblemRequired: Bool? = nil
        public var laminateRequired: Bool? = nil
        public var cutEdge: String? = nil
        public var cutEdgePolicy: String? = nil
        public var backShown: Bool? = nil
        public var photoOk: Bool? = nil
        public init() {}
    }

    public struct Decision {
        public let verdict: String
        public let reasons: [String]
    }

    public static func decide(_ i: GateInput, maxAttempts: Int) -> Decision {
        var reasons: [String] = []
        func stop(_ verdict: String, _ r: String) -> Decision { Decision(verdict: verdict, reasons: reasons + [r]) }
        func retryOrGiveUp(_ r: String) -> Decision { stop(i.attempt + 1 >= maxAttempts ? INCONCLUSIVE : RETRY, r) }

        // 1
        if !i.cameraOk { return Decision(verdict: INCONCLUSIVE, reasons: ["camera_unavailable"]) }
        // 2
        if i.backShown == false { return retryOrGiveUp("back_barcode_not_seen") }
        // 3
        if i.enginePhase == "failed" { return Decision(verdict: INCONCLUSIVE, reasons: ["challenge_not_completed"]) }
        // 4
        if i.enginePhase != "done" || i.challenge != "observed" { return retryOrGiveUp("challenge_incomplete") }
        // 5
        if i.photoOk == false { return retryOrGiveUp("photo_failed") }
        // 6
        if i.emblemRequired == true && i.emblemPolicy == "enforce" {
            if i.emblem == nil || i.emblem == "not_configured" { return retryOrGiveUp("emblem_missing") }
            if i.emblem == "unassessable" { return retryOrGiveUp("emblem_unassessable") }
        }
        // 7
        if i.laminateRequired == true && i.laminatePolicy == "enforce" {
            if i.laminate == nil || i.laminate == "not_configured" { return retryOrGiveUp("laminate_missing") }
            if i.laminate == "unassessable" { return retryOrGiveUp("laminate_unassessable") }
        }
        // 8
        if i.emblem == "untested" && i.emblemPolicy == "enforce" { return retryOrGiveUp("emblem_untested") }
        // 9
        if i.optical == "inconsistent_response" {
            if i.opticalPolicy == "enforce" { return stop(SUSPECTED_COPY, "optical_inconsistent") }
            reasons.append("optical_inconsistent_shadow")
        }
        // 10
        if i.opticalPolicy == "enforce" && i.optical == "unassessable" { return retryOrGiveUp("optical_unassessable") }
        // 11
        let matte = i.reflection == "matte"
        let emissive = i.reflection == "emissive"
        let emblemPresent = i.emblem == "present"
        if matte && (emblemPresent || (i.laminate == "present" && i.laminateStrong != false)) {
            reasons.append("reflection_matte_excused")
        } else if emissive && emblemPresent {
            reasons.append("no_response_to_light_excused")
        } else if matte || emissive {
            let what = matte ? "reflection_matte" : "no_response_to_light"
            if emissive && i.batteryLow == true { return stop(INCONCLUSIVE, "battery_low") }
            if i.reflectionPolicy == "enforce" {
                if emissive { return retryOrGiveUp("no_response_to_light") }
                if i.matteNotEvidence == true { return retryOrGiveUp("reflection_matte_unproven") }
                if i.matteBefore != true { return stop(RETRY, what + "_first") }
                return stop(SUSPECTED_COPY, what)
            }
            reasons.append(what + "_shadow")
        }
        // 12
        if i.reflectionPolicy == "enforce" && i.reflection == "unassessable" {
            if i.lightAvailable == false { return stop(INCONCLUSIVE, "no_camera_light") }
            return retryOrGiveUp("reflection_unassessable")
        }
        // 13
        if i.emblem == "absent" {
            if i.emblemPolicy == "enforce" {
                return i.matteBefore != true ? stop(RETRY, "emblem_absent_first") : stop(SUSPECTED_COPY, "emblem_absent")
            }
            reasons.append("emblem_absent_shadow")
        }
        // 14
        if i.laminate == "absent" {
            if i.laminatePolicy == "enforce" {
                return i.matteBefore != true ? stop(RETRY, "laminate_absent_first") : stop(SUSPECTED_COPY, "laminate_absent")
            }
            reasons.append("laminate_absent_shadow")
        }
        // 15
        if i.cutEdge == "cut" {
            if i.cutEdgePolicy == "enforce" {
                return i.matteBefore != true ? stop(RETRY, "overlay_cut_first") : stop(SUSPECTED_COPY, "overlay_cut")
            }
            reasons.append("overlay_cut_shadow")
        }
        // end
        reasons.append("capture_completed")
        if i.batteryLow == true { reasons.append("battery_low_noted") }
        return Decision(verdict: CONTINUE, reasons: reasons)
    }
}
