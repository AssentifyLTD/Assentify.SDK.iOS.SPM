import Foundation

/// INTERIM stabiliser for raw finder2 corners. Port of OutlineStabilizer.kt.
///
///  1. SANITY   an outline far from the document's proportions is rejected.
///  2. AGREE    the first outline, and any JUMP away from the current one, must be seen on 2 frames in a row that agree
///              (every corner within `near` x frame diagonal) before it is accepted; a single odd frame is ignored.
///  3. INFERRED a completed hidden corner gives a parallelogram (lr = tb = 0): passed on for position, but
///              poseReliable = false (not for the flat hold or the tilt).
public final class OutlineStabilizer {

    public struct Result {
        public let quad: [Double]?          // the outline to use this frame, or nil (no document this frame)
        public let poseReliable: Bool       // false: do not use for "hold flat" / tilt
        public let status: String           // accepted, moved, held-jump, pending, rejected-shape, none
    }

    private let docAspect: Double
    private let near: Double
    private let aspectMin: Double
    private let aspectMax: Double
    private let maxHeldFrames: Int

    private var accepted: [Double]?
    private var candidate: [Double]?
    private var held = 0

    public init(docAspect: Double, near: Double = 0.03, aspectMin: Double = 0.6, aspectMax: Double = 1.6,
                maxHeldFrames: Int = 3) {
        self.docAspect = docAspect
        self.near = near
        self.aspectMin = aspectMin
        self.aspectMax = aspectMax
        self.maxHeldFrames = maxHeldFrames
    }

    public func reset() { accepted = nil; candidate = nil; held = 0 }

    public func update(_ q: [Double]?, w: Double, h: Double, inferred: Bool) -> Result {
        guard let q = q else {
            candidate = nil; held = 0; accepted = nil
            return Result(quad: nil, poseReliable: false, status: "none")
        }
        let a = Geometry.poseOf(q).aspect
        if !a.isFinite || a < aspectMin * docAspect || a > aspectMax * docAspect {
            return keepOrDrop("rejected-shape")
        }
        let tol = near * hypot(w, h)

        guard let cur = accepted else {                     // first sight: needs two looks that agree
            let c = candidate
            candidate = q
            if let c = c, agree(c, q, tol) {
                accepted = q; candidate = nil; held = 0
                return Result(quad: q, poseReliable: !inferred, status: "accepted")
            }
            return Result(quad: nil, poseReliable: false, status: "pending")
        }

        if agree(cur, q, tol) {                             // small move: follow it
            accepted = q; candidate = nil; held = 0
            return Result(quad: q, poseReliable: !inferred, status: "accepted")
        }
        // a jump: switch only if the new place is confirmed by the next frame
        if let c = candidate, agree(c, q, tol) {
            accepted = q; candidate = nil; held = 0
            return Result(quad: q, poseReliable: !inferred, status: "moved")
        }
        candidate = q
        return keepOrDrop("held-jump")
    }

    private func keepOrDrop(_ status: String) -> Result {
        if let cur = accepted, held < maxHeldFrames {
            held += 1
            return Result(quad: cur, poseReliable: false, status: status)   // keep showing it, not for pose decisions
        }
        accepted = nil; held = 0
        return Result(quad: nil, poseReliable: false, status: status)
    }

    private func agree(_ p: [Double], _ q: [Double], _ tol: Double) -> Bool {
        for i in 0..<4 where hypot(p[2 * i] - q[2 * i], p[2 * i + 1] - q[2 * i + 1]) > tol { return false }
        return true
    }
}
