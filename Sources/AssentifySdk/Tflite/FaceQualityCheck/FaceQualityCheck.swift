import UIKit
import Vision
import CoreMedia

class FaceQualityCheck {

    private var isProcessingQuality = false
    private var isProcessingWink = false
    private let processingQueue = DispatchQueue(label: "com.assentify.facequality", qos: .userInitiated)

    // MARK: - Public API

    func checkQualityAction(pixelBuffer: CVPixelBuffer, completion: @escaping (FaceEvents) -> Void) {
        guard !isProcessingQuality else { return }
        isProcessingQuality = true

        // Pose (roll/pitch/yaw) comes from VNDetectFaceRectanglesRequest with
        // revision 3 explicitly set — this is the request type Apple's own
        // samples use to get real pitch values. VNDetectFaceLandmarksRequest
        // alone does not reliably populate pitch.
        let poseRequest = VNDetectFaceRectanglesRequest()
        if #available(iOS 15.0, *) {
            poseRequest.revision = VNDetectFaceRectanglesRequestRevision3
        }

        // Landmarks (eye/nose/mouth presence) still comes from the landmarks request.
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        if #available(iOS 15.0, *) {
            landmarksRequest.revision = VNDetectFaceLandmarksRequestRevision3
        }

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

            do {
                try handler.perform([poseRequest, landmarksRequest])
            } catch {
                self.isProcessingQuality = false
                completion(.NO_DETECT)
                return
            }

            self.isProcessingQuality = false

            guard let poseFace = (poseRequest.results as? [VNFaceObservation])?.first,
                  let landmarksFace = (landmarksRequest.results as? [VNFaceObservation])?.first else {
                completion(.NO_DETECT)
                return
            }

            guard let landmarks = landmarksFace.landmarks,
                  landmarks.leftEye != nil,
                  landmarks.rightEye != nil,
                  (landmarks.nose != nil || landmarks.noseCrest != nil),
                  landmarks.outerLips != nil else {
                completion(.NO_DETECT)
                return
            }

            let rollDeg = (poseFace.roll?.doubleValue ?? 0) * 180 / .pi
            let yawDeg = (poseFace.yaw?.doubleValue ?? 0) * 180 / .pi
            let pitchDeg: Double = {
                if #available(iOS 15.0, *) {
                    return (poseFace.pitch?.doubleValue ?? 0) * 180 / .pi
                }
                return 0
            }()

            var faceEvent: FaceEvents = .GOOD

            /** Roll Check **/
            if rollDeg > ConstantsValues.FaceCheckQualityThresholdPositive {
                faceEvent = .ROLL_LEFT
            } else if rollDeg < ConstantsValues.FaceCheckQualityThresholdNegative {
                faceEvent = .ROLL_RIGHT
            }

            /** Pitch Check **/
            if pitchDeg > ConstantsValues.FaceCheckQualityThresholdNPositivePitch {
                faceEvent = .PITCH_DOWN
            } else if pitchDeg < ConstantsValues.FaceCheckQualityThresholdNegativePitch {
                faceEvent = .PITCH_UP
            }

            /** Yaw Check **/
            if yawDeg > ConstantsValues.FaceCheckQualityThresholdPositive {
                faceEvent = .YAW_RIGHT
            } else if yawDeg < ConstantsValues.FaceCheckQualityThresholdNegative {
                faceEvent = .YAW_LEFT
            }

            completion(faceEvent)
        }
    }
   

   

    // MARK: - Tunables (retuned for easier/faster wink & blink detection) 
    private let closedRatioFraction: CGFloat = 0.65   // was 0.55 — RAISED so eye counts "closed" sooner
    private let minRelativeGap: CGFloat = 0.015        // was 0.025 — LOWERED so smaller L/R gap counts as a wink
    private let winkOverrideGap: CGFloat = 0.03        // gap needed to call it a WINK even if both eyes crossed "closed"
                                                        // (protects against sympathetic droop in the other eye)
    private let baselineWindowSize = 30                // frames used for rolling "open eye" baseline
    private let minBaselineSamples = 6                 // was 10 — LOWERED so detector is "ready" sooner
    private let probablyOpenFloor: CGFloat = 0.11      // frames below this on either eye are excluded from baseline calibration

    // MARK: - State
    private var leftEARHistory: [CGFloat] = []
    private var rightEARHistory: [CGFloat] = []

    // Exposed for debugging/tuning
    private(set) var leftBaseline: CGFloat = 0
    private(set) var rightBaseline: CGFloat = 0

    func checkQualityWinkAndBLINK(pixelBuffer: CVPixelBuffer, completion: @escaping (FaceEvents) -> Void) {
        guard !isProcessingWink else { return }
        isProcessingWink = true

        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            defer { self?.isProcessingWink = false }
            guard let self = self else { return }

            guard error == nil,
                  let results = request.results as? [VNFaceObservation],
                  !results.isEmpty else {
                completion(.NO_DETECT)
                return
            }

            for face in results {
                guard let landmarks = face.landmarks,
                      let leftEye = landmarks.leftEye,
                      let rightEye = landmarks.rightEye else {
                    continue
                }

                let leftEAR = Self.eyeAspectRatio(for: leftEye)
                let rightEAR = Self.eyeAspectRatio(for: rightEye)

                self.updateBaselinesIfOpen(leftEAR: leftEAR, rightEAR: rightEAR)

                // Bug fix: continue to the next face instead of bailing the whole request.
                guard self.leftEARHistory.count >= self.minBaselineSamples,
                      self.rightEARHistory.count >= self.minBaselineSamples else {
                    continue
                }

                let leftThreshold = self.leftBaseline * closedRatioFraction
                let rightThreshold = self.rightBaseline * closedRatioFraction

                let leftClosed = leftEAR < leftThreshold
                let rightClosed = rightEAR < rightThreshold
                let gap = abs(leftEAR - rightEAR)

                // IMPORTANT: check for a large L/R gap FIRST. A real wink can make BOTH eyes
                // dip under threshold (sympathetic droop in the "other" eye is normal), but a
                // real wink still has a much bigger gap than a real blink. Checking gap first
                // stops those sloppy winks from being misclassified as BLINK.
                if (leftClosed || rightClosed) && gap > winkOverrideGap {
                    if rightEAR < leftEAR {
                        completion(.WINK_RIGHT)
                    } else {
                        completion(.WINK_LEFT)
                    }
                    return
                } else if leftClosed && rightClosed {
                    completion(.BLINK)
                    return
                } else if rightClosed && !leftClosed && gap > minRelativeGap {
                    completion(.WINK_RIGHT)
                    return
                } else if leftClosed && !rightClosed && gap > minRelativeGap {
                    completion(.WINK_LEFT)
                    return
                }
            }

            completion(.NO_DETECT)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            isProcessingWink = false
            completion(.NO_DETECT)
        }
    }

    // MARK: - Baseline calibration

    /// Only rolls a frame into the baseline history if both eyes look reasonably open,
    /// so we're not calibrating "open eye" baseline off a held wink or blink.
    private func updateBaselinesIfOpen(leftEAR: CGFloat, rightEAR: CGFloat) {
        guard leftEAR > probablyOpenFloor && rightEAR > probablyOpenFloor else { return }

        leftEARHistory.append(leftEAR)
        rightEARHistory.append(rightEAR)

        if leftEARHistory.count > baselineWindowSize {
            leftEARHistory.removeFirst()
        }
        if rightEARHistory.count > baselineWindowSize {
            rightEARHistory.removeFirst()
        }

        leftBaseline = leftEARHistory.reduce(0, +) / CGFloat(leftEARHistory.count)
        rightBaseline = rightEARHistory.reduce(0, +) / CGFloat(rightEARHistory.count)
    }

    /// Call this if the user moves to a very different distance/angle from camera
    /// and you want to force recalibration rather than blending with stale history.
    func resetBaselines() {
        leftEARHistory.removeAll()
        rightEARHistory.removeAll()
        leftBaseline = 0
        rightBaseline = 0
    }

    // MARK: - EAR calculation

    private static func eyeAspectRatio(for eye: VNFaceLandmarkRegion2D) -> CGFloat {
        let points = eye.normalizedPoints
        guard points.count >= 6 else { return 1.0 }

        guard let minXIndex = points.indices.min(by: { points[$0].x < points[$1].x }),
              let maxXIndex = points.indices.min(by: { points[$0].x > points[$1].x }) else {
            return 1.0
        }
        let minXPoint = points[minXIndex]
        let maxXPoint = points[maxXIndex]

        let dx = maxXPoint.x - minXPoint.x
        let dy = maxXPoint.y - minXPoint.y
        let lineLength = hypot(dx, dy)
        guard lineLength > 0 else { return 1.0 }

        // Corner points are excluded from the height average — they sit ~on the
        // corner-to-corner line by definition, so including them compresses the
        // open-vs-closed contrast and hurts detection.
        let heights: [CGFloat] = points.indices.compactMap { i in
            guard i != minXIndex, i != maxXIndex else { return nil }
            let p = points[i]
            return abs(dx * (minXPoint.y - p.y) - (minXPoint.x - p.x) * dy) / lineLength
        }
        guard !heights.isEmpty else { return 1.0 }

        let avgHeight = (heights.reduce(0, +) / CGFloat(heights.count)) * 2
        let width = lineLength

        return avgHeight / width
    }
}
