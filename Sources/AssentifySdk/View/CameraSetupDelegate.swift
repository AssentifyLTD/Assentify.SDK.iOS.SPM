import UIKit
import CoreMedia
protocol CameraSetupDelegate: AnyObject {
    func didCaptureCVPixelBuffer(_ pixelBuffer: CVPixelBuffer)
    
}
