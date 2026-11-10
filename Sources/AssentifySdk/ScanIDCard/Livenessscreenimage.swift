import UIKit
import CoreImage

/// The image the liveness screen shows when the LOCAL liveness fails (suspected copy / inconclusive / stalled):
/// the document as the camera saw it, upright (sensor frames are landscape, the phone is held in portrait) and at most
/// MAX_SIDE px on the long side, so keeping it on screen costs little memory.
enum LivenessScreenImage {

    static let MAX_SIDE: CGFloat = 1080
    private static let context = CIContext(options: nil)

    /// From the flat photo (JPEG data) if there is one, else from the camera frame. nil when there is neither.
    static func make(photo: Data?, frame: CVPixelBuffer?) -> UIImage? {
        if let data = photo, let img = UIImage(data: data), let up = upright(img) { return fit(up) }
        if let pb = frame { return fromFrame(pb) }
        return nil
    }

    /// A camera frame (the buffer is read now: call it on the camera thread, before the camera reuses it).
    static func fromFrame(_ pb: CVPixelBuffer) -> UIImage? {
        var ci = CIImage(cvPixelBuffer: pb)
        if CVPixelBufferGetWidth(pb) > CVPixelBufferGetHeight(pb) { ci = ci.oriented(.right) }   // landscape sensor
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return nil }
        return fit(UIImage(cgImage: cg))
    }

    /// A photo taken from a landscape sensor frame is turned to portrait (the scan is held in portrait).
    private static func upright(_ img: UIImage) -> UIImage? {
        guard let cg = img.cgImage else { return img }
        if img.imageOrientation == .up && cg.width > cg.height {
            return UIImage(cgImage: cg, scale: img.scale, orientation: .right)
        }
        return img
    }

    /// Long side at most MAX_SIDE (drawn, so the orientation is baked in).
    private static func fit(_ img: UIImage) -> UIImage {
        let w = img.size.width, h = img.size.height
        let longSide = max(w, h)
        let scale = longSide > MAX_SIDE ? MAX_SIDE / longSide : 1
        let size = CGSize(width: (w * scale).rounded(), height: (h * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
