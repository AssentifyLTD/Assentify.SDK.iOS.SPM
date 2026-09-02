import Vision
import CoreVideo
import Foundation

/// OCR + MRZ parsing for images already in memory as a `CVPixelBuffer` — e.g. the
/// image buffer from a `CMSampleBuffer` delivered by `AVCaptureVideoDataOutput`.
///
/// Two differences from the Android `MrzBitmapScanner` this mirrors:
///  1. Vision's `VNImageRequestHandler` takes an `orientation` flag directly, so
///     there's no need to physically rotate the buffer first the way the Android
///     code rotates the `Bitmap` before OCR.
///  2. Vision has no persistent recognizer object to create/close between scans
///     (unlike ML Kit's `TextRecognizer`), so this is a stateless enum of static
///     functions rather than a class with a lifecycle.
public enum MrzPixelBufferScanner {

    public enum ScanError: Error {
        case visionFailure(Error)
    }

    /// Runs OCR + MRZ parsing on `pixelBuffer` and reports the outcome on `completion`.
    /// `completion` fires on a background queue — dispatch to main yourself if you touch UI.
    /// Check `allValid()`/`bacReady()`/`failSummary()` on the result before trusting it.
    ///
    /// - Parameter orientation: the orientation that makes the MRZ text upright in the
    ///   buffer. For a back-camera capture on a portrait-locked phone held normally,
    ///   `.right` is the usual value; pass whatever corresponds to your capture setup
    ///   (this is the equivalent of the Android `rotationDegrees` parameter, expressed
    ///   the way Vision wants it instead of as a rotation to apply beforehand).
    public static func scan(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up,
        completion: @escaping (Swift.Result<MrzResult?, Error>) -> Void
    ) {
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(ScanError.visionFailure(error)))
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.success(nil))
                return
            }
            let text = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            completion(.success(Mrz.bestCandidate(rawText: text)))
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(ScanError.visionFailure(error)))
            }
        }
    }

    /// async/await version of `scan(pixelBuffer:orientation:completion:)`.
    public static func scan(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) async throws -> MrzResult? {
        try await withCheckedThrowingContinuation { continuation in
            scan(pixelBuffer: pixelBuffer, orientation: orientation) { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Blocking version. Call from a background thread only (never the main thread) —
    /// mirrors the synchronous per-frame pattern `MainActivity#analyze` uses on Android.
    /// Returns nil when OCR found no MRZ-shaped lines.
    public static func scanBlocking(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .up
    ) throws -> MrzResult? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw ScanError.visionFailure(error)
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else { return nil }
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        return Mrz.bestCandidate(rawText: text)
    }
}

/*
Usage from an AVCaptureVideoDataOutputSampleBufferDelegate:

func captureOutput(_ output: AVCaptureOutput,
                    didOutput sampleBuffer: CMSampleBuffer,
                    from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    MrzPixelBufferScanner.scan(pixelBuffer: pixelBuffer, orientation: .right) { result in
        switch result {
        case .success(let mrz?):
            if mrz.isComplete() {
                let props = mrz.toOutputProperties()
                let (mrzInfo, kseed, kenc, kmac) = Mrz.bacKeys(mrz)
                // hand off to your BAC/NFC step
            }
        case .success(nil):
            break // no MRZ-shaped lines in this frame yet
        case .failure(let error):
            print("OCR failed: \(error)")
        }
    }
}
*/
