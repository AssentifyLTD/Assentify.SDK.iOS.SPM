import Vision
import CoreVideo
import CoreGraphics
import Foundation

@available(iOS 15.0, *)
struct FrontalFaceResult {
    let face: VNFaceObservation
    let yaw: Double            // degrees, 0 = facing camera
    let pitch: Double          // degrees
    let roll: Double           // degrees
    let noseOffset: CGFloat    // landmark-based yaw proxy, 0 = nose centered between eyes
    let gazeOffset: CGFloat    // -1...1, 0 = pupils centered in the eyes
}

/// Returns a result ONLY when exactly one face is looking straight at the screen.
/// Returns nil for: no face, multiple faces, small/low-confidence face, turned/tilted head,
/// eyes looking sideways, or eyes closed.
@available(iOS 15.0, *)
final class FrontalFaceChecker {

    struct Limits {
        var maxYawDegrees: Double = 5
        var maxRollDegrees: Double = 5
        /// Pitch is measured relative to this value, not 0. Phones sit below eye level,
        /// so a head held perfectly straight reads ~8–10° (your log: 10.5°).
        var pitchCenterDegrees: Double = 9
        var maxPitchDeviation: Double = 5     // accepted pitch = center ± this
        var maxNoseOffset: CGFloat = 0.06     // nose shift along eye line / inter-eye distance
        var maxGazeOffset: CGFloat = 0.20     // pupil shift / half eye width
        /// Consecutive frontal frames required before a result is returned.
        /// Stops a single lucky frame from passing with strict limits.
        var requiredStableFrames: Int = 3
        var minEyeOpenness: CGFloat = 0.15    // eye height / eye width
        var minFaceWidth: CGFloat = 0.20      // fraction of image width
        var minConfidence: Float = 0.5
    }

    let limits: Limits

    /// Set to false to silence logs in production.
    var debugLogging = false

    private let queue = DispatchQueue(label: "com.assentify.frontalface", qos: .userInitiated)

    init(limits: Limits = Limits()) {
        self.limits = limits
    }

    // MARK: - Logging

    private func log(_ message: @autoclosure () -> String) {
        guard debugLogging else { return }
        print("[FrontalFace] \(message())")
    }

    private func f(_ v: Double) -> String { String(format: "%.2f", v) }
    private func f(_ v: CGFloat) -> String { String(format: "%.3f", Double(v)) }

    // MARK: - Async API (camera stream)

    func check(_ pixelBuffer: CVPixelBuffer,
               orientation: CGImagePropertyOrientation = .up,
               completion: @escaping (FrontalFaceResult?) -> Void) {
        queue.async { [weak self] in
            completion(self?.check(pixelBuffer, orientation: orientation))
        }
    }

    // MARK: - Sync API

    private var stableCount = 0

    /// Call when starting a new capture session to clear the frame counter.
    func resetStability() {
        stableCount = 0
    }

    func check(_ pixelBuffer: CVPixelBuffer,
               orientation: CGImagePropertyOrientation = .up) -> FrontalFaceResult? {
        guard let result = evaluate(pixelBuffer, orientation: orientation) else {
            stableCount = 0
            return nil
        }
        stableCount += 1
        guard stableCount >= limits.requiredStableFrames else {
            log("⏳ frontal \(stableCount)/\(limits.requiredStableFrames) — hold still")
            return nil
        }
        return result
    }

    private func evaluate(_ pixelBuffer: CVPixelBuffer,
                          orientation: CGImagePropertyOrientation) -> FrontalFaceResult? {

        let size = imageSize(pixelBuffer, orientation)
        log("---- frame \(Int(size.width))x\(Int(size.height)) orientation=\(orientation.rawValue) ----")

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: orientation,
                                            options: [:])

        // 1. Face detection + continuous head pose (revision 3)
        let rectRequest = VNDetectFaceRectanglesRequest()
        rectRequest.revision = VNDetectFaceRectanglesRequestRevision3

        do {
            try handler.perform([rectRequest])
        } catch {
            log("❌ rectangles request failed: \(error)")
            return nil
        }

        guard let faces = rectRequest.results, !faces.isEmpty else {
            log("❌ no face detected (if this always happens, try another orientation)")
            return nil
        }
        guard faces.count == 1, let face = faces.first else {
            log("❌ \(faces.count) faces detected, need exactly 1")
            return nil
        }

        log("face box=\(face.boundingBox) confidence=\(face.confidence)")

        guard face.confidence >= limits.minConfidence else {
            log("❌ confidence \(face.confidence) < \(limits.minConfidence)")
            return nil
        }
        guard face.boundingBox.width >= limits.minFaceWidth else {
            log("❌ face too small: width \(f(face.boundingBox.width)) < \(f(limits.minFaceWidth)) — move closer")
            return nil
        }
        guard let yawRad = face.yaw?.doubleValue,
              let pitchRad = face.pitch?.doubleValue,
              let rollRad = face.roll?.doubleValue else {
            log("❌ pose missing: yaw=\(String(describing: face.yaw)) pitch=\(String(describing: face.pitch)) roll=\(String(describing: face.roll))")
            return nil
        }

        let yaw = yawRad * 180 / .pi
        let pitch = pitchRad * 180 / .pi
        let roll = rollRad * 180 / .pi
        log("pose yaw=\(f(yaw))° pitch=\(f(pitch))° roll=\(f(roll))°")

        guard abs(yaw) <= limits.maxYawDegrees else {
            log("❌ yaw \(f(yaw))° exceeds ±\(f(limits.maxYawDegrees))°")
            return nil
        }
        guard abs(pitch - limits.pitchCenterDegrees) <= limits.maxPitchDeviation else {
            log("❌ pitch \(f(pitch))° outside \(f(limits.pitchCenterDegrees - limits.maxPitchDeviation))…\(f(limits.pitchCenterDegrees + limits.maxPitchDeviation))°")
            return nil
        }
        guard abs(roll) <= limits.maxRollDegrees else {
            log("❌ roll \(f(roll))° exceeds ±\(f(limits.maxRollDegrees))° (≈90° means wrong orientation)")
            return nil
        }

        // 2. Landmarks on the SAME face (feed the detected face in)
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        landmarksRequest.revision = VNDetectFaceLandmarksRequestRevision3
        landmarksRequest.inputFaceObservations = [face]

        do {
            try handler.perform([landmarksRequest])
        } catch {
            log("❌ landmarks request failed: \(error)")
            return nil
        }

        guard let lmFace = landmarksRequest.results?.first,
              let lm = lmFace.landmarks else {
            log("❌ no landmarks returned")
            return nil
        }

        log("landmarks: leftEye=\(lm.leftEye != nil) rightEye=\(lm.rightEye != nil) " +
            "leftPupil=\(lm.leftPupil != nil) rightPupil=\(lm.rightPupil != nil) " +
            "nose=\(lm.nose != nil) noseCrest=\(lm.noseCrest != nil)")

        guard let leftEye = lm.leftEye,
              let rightEye = lm.rightEye,
              let leftPupil = lm.leftPupil,
              let rightPupil = lm.rightPupil,
              let nose = lm.nose ?? lm.noseCrest else {
            log("❌ required landmark missing (see line above)")
            return nil
        }

        // Work in pixel coordinates so the image aspect ratio doesn't distort geometry.
        let lEyePts = leftEye.pointsInImage(imageSize: size)
        let rEyePts = rightEye.pointsInImage(imageSize: size)
        let nosePts = nose.pointsInImage(imageSize: size)
        guard let lPupil = leftPupil.pointsInImage(imageSize: size).first,
              let rPupil = rightPupil.pointsInImage(imageSize: size).first,
              !lEyePts.isEmpty, !rEyePts.isEmpty, !nosePts.isEmpty else {
            log("❌ empty landmark point arrays")
            return nil
        }

        let lBox = boundingBox(lEyePts)
        let rBox = boundingBox(rEyePts)
        let lCenter = CGPoint(x: lBox.midX, y: lBox.midY)
        let rCenter = CGPoint(x: rBox.midX, y: rBox.midY)

        let dx = rCenter.x - lCenter.x
        let dy = rCenter.y - lCenter.y
        let eyeDistance = hypot(dx, dy)
        guard eyeDistance > 1, abs(dx) > 0 else {
            log("❌ eye distance too small: \(f(eyeDistance))px")
            return nil
        }

        // Unit vector along the eye line (makes the checks below roll-invariant)
        let ux = dx / eyeDistance
        let uy = dy / eyeDistance

        // 3. Landmark roll: angle of the eye line (cross-checks Vision's roll)
        let eyeLineRoll = Double(atan(dy / dx)) * 180 / .pi
        log("eyeLineRoll=\(f(eyeLineRoll))° eyeDistance=\(f(eyeDistance))px")
        guard abs(eyeLineRoll) <= limits.maxRollDegrees else {
            log("❌ eye-line roll \(f(eyeLineRoll))° exceeds ±\(f(limits.maxRollDegrees))°")
            return nil
        }

        // 4. Landmark yaw: nose must sit centered between the eyes
        let mid = CGPoint(x: (lCenter.x + rCenter.x) / 2, y: (lCenter.y + rCenter.y) / 2)
        let noseCenter = centroid(nosePts)
        let noseOffset = ((noseCenter.x - mid.x) * ux + (noseCenter.y - mid.y) * uy) / eyeDistance
        log("noseOffset=\(f(noseOffset)) (limit ±\(f(limits.maxNoseOffset)))")
        guard abs(noseOffset) <= limits.maxNoseOffset else {
            log("❌ nose not centered between eyes")
            return nil
        }

        // 5. Eyes must be open (pupil positions are unreliable on closed eyes)
        let lOpen = lBox.height / max(lBox.width, 1)
        let rOpen = rBox.height / max(rBox.width, 1)
        log("eyeOpenness left=\(f(lOpen)) right=\(f(rOpen)) (min \(f(limits.minEyeOpenness)))")
        guard min(lOpen, rOpen) >= limits.minEyeOpenness else {
            log("❌ eye(s) look closed")
            return nil
        }

        // 6. Gaze: pupils must be near the center of each eye
        func gaze(_ pupil: CGPoint, _ center: CGPoint, _ box: CGRect) -> CGFloat {
            let shift = (pupil.x - center.x) * ux + (pupil.y - center.y) * uy
            return shift / max(box.width / 2, 1)
        }
        let lGaze = gaze(lPupil, lCenter, lBox)
        let rGaze = gaze(rPupil, rCenter, rBox)
        let gazeOffset = (lGaze + rGaze) / 2
        log("gaze left=\(f(lGaze)) right=\(f(rGaze)) avg=\(f(gazeOffset)) (limit ±\(f(limits.maxGazeOffset)))")
        guard abs(gazeOffset) <= limits.maxGazeOffset else {
            log("❌ eyes looking away from the screen")
            return nil
        }

        log("✅ FRONTAL")
        return FrontalFaceResult(face: face,
                                 yaw: yaw,
                                 pitch: pitch,
                                 roll: roll,
                                 noseOffset: noseOffset,
                                 gazeOffset: gazeOffset)
    }

    // MARK: - Helpers

    private func imageSize(_ pb: CVPixelBuffer, _ o: CGImagePropertyOrientation) -> CGSize {
        let w = CGFloat(CVPixelBufferGetWidth(pb))
        let h = CGFloat(CVPixelBufferGetHeight(pb))
        switch o {
        case .left, .leftMirrored, .right, .rightMirrored:
            return CGSize(width: h, height: w)
        default:
            return CGSize(width: w, height: h)
        }
    }

    private func boundingBox(_ pts: [CGPoint]) -> CGRect {
        let xs = pts.map(\.x), ys = pts.map(\.y)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func centroid(_ pts: [CGPoint]) -> CGPoint {
        let n = CGFloat(pts.count)
        return CGPoint(x: pts.map(\.x).reduce(0, +) / n,
                       y: pts.map(\.y).reduce(0, +) / n)
    }
}
