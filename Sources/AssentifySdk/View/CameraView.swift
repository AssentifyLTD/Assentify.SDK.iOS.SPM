import AVFoundation
import UIKit

class CameraSetup: NSObject {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    weak var delegate: CameraSetupDelegate?

    func setupCamera(on view: UIView) {
        captureSession = AVCaptureSession()

        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(input)
        } catch {
            print(error.localizedDescription)
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [ String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]
        captureSession.addOutput(output)
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        if let mainWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            let screenSize = mainWindow.bounds.size
            let previewSize = CGSize(width: screenSize.width, height: screenSize.height)
            

            previewLayer.frame = CGRect(x: 0, y: 0, width: previewSize.width, height: previewSize.height)
            
        }
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            captureSession.startRunning()
    }

}

extension CameraSetup: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

      
         // Converts the CMSampleBuffer to a CVPixelBuffer.
        let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)

         guard let imagePixelBuffer = pixelBuffer else {
           return
         }
   
        // Delegates the pixel buffer to the ViewController.
        delegate?.didCaptureCVPixelBuffer(imagePixelBuffer)
       }
    
    
}


