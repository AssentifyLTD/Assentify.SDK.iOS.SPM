
import TensorFlowLite
import CoreVideo
import UIKit

class CheckLiveness {
    private var interpreter: Interpreter?
    
    init() {
        loadTfliteModel()
    }

    func loadTfliteModel() {
        guard let modelPath = Bundle.module.path(forResource: ConstantsValues.ModelLivenessFileName, ofType: "tflite") else {
            print("Failed to load model file.")
            return
        }
        do {
            interpreter = try Interpreter(modelPath: modelPath)
            try interpreter?.allocateTensors()
        } catch {
            print("Failed to initialize interpreter: \(error)")
        }
    }


    

    func preprocessImage(pixelBuffer: CVPixelBuffer) -> Data? {
        
        var resizePixelBuffer = pixelBuffer.resizedAndHorizontallyFlipped(to: CGSize(width: ConstantsValues.InputFaceModelSize,height: ConstantsValues.InputFaceModelSize))

                CVPixelBufferLockBaseAddress(resizePixelBuffer!, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(resizePixelBuffer!, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(resizePixelBuffer!) else {
            return nil
        }
        let width = CVPixelBufferGetWidth(resizePixelBuffer!)
        let height = CVPixelBufferGetHeight(resizePixelBuffer!)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(resizePixelBuffer!)
        
        let pixelFormat = CVPixelBufferGetPixelFormatType(resizePixelBuffer!)
        var componentsPerPixel = 4
        if pixelFormat == kCVPixelFormatType_32BGRA {
            componentsPerPixel = 4
        } else if pixelFormat == kCVPixelFormatType_32ARGB {
            componentsPerPixel = 4
        } else {
            print("Unsupported pixel format")
            return nil
        }
        
        var float32Data = [Float]()
        float32Data.reserveCapacity(width * height * componentsPerPixel)
        
        for y in 0..<height {
            let rowPointer = baseAddress.advanced(by: y * bytesPerRow)
            for x in 0..<width {
                let pixelPointer = rowPointer.advanced(by: x * componentsPerPixel)
                
                let r = Float(pixelPointer.load(fromByteOffset: 2, as: UInt8.self))
                let g = Float(pixelPointer.load(fromByteOffset: 1, as: UInt8.self))
                let b = Float(pixelPointer.load(fromByteOffset: 0, as: UInt8.self))
                float32Data.append(contentsOf: [r, g, b])
            }
        }
        
        return Data(buffer: UnsafeBufferPointer(start: float32Data, count: float32Data.count))
    }

    
  
    func preprocessAndPredict(pixelBuffer: CVPixelBuffer) -> LivenessType? {
        guard let interpreter = interpreter,
              let imageData = preprocessImage(pixelBuffer:pixelBuffer) else {
            return nil
        }
        
        do {
            let inputTensor = try interpreter.input(at: 0)
            try interpreter.copy(imageData, toInputAt: 0)
            try interpreter.invoke()
            
            let outputTensor = try interpreter.output(at: 0)
            let outputData = outputTensor.data
            let output = outputData.withUnsafeBytes {
                Array(UnsafeBufferPointer<Float>(start: $0.baseAddress!.assumingMemoryBound(to: Float.self), count: outputTensor.shape.dimensions.reduce(1, *)))
            }
            
            return output.first!  > 0.5 ? LivenessType.NOT_LIVE : LivenessType.LIVE
        } catch {
            print("Error during model inference: \(error)")
            return nil
        }
    }
}


