

import UIKit
import AVFoundation


class PreviewView: UIView {

  var previewLayer: AVCaptureVideoPreviewLayer {
    guard let layer = layer as? AVCaptureVideoPreviewLayer else {
      fatalError("Layer expected is of type VideoPreviewLayer")
    }
    return layer
  }

  var session: AVCaptureSession? {
    get {
      return previewLayer.session
    }
    set {
      previewLayer.session = newValue
    }
  }

  override class var layerClass: AnyClass {
    return AVCaptureVideoPreviewLayer.self
  }
    
  override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
  }
    
  func stopSession() {
     guard let session = previewLayer.session else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
      }
    }
}
