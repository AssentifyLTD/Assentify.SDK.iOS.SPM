
import CoreImage
import TensorFlowLite
import UIKit
import Accelerate

struct Result {
    let inferenceTime: Double
    let inferences: [Inference]
}

struct Inference {
    let confidence: Float
    let className: String
    let rect: CGRect
    let displayColor: UIColor
}

typealias FileInfo = (name: String, extension: String)

enum Yolov5 {
    static let modelInfo: FileInfo = (name: "best-fp16", extension: "tflite")
    static let labelsInfo: FileInfo = (name: "classes", extension: "txt")
}

class ModelDataHandler: NSObject {
    
    let threadCount: Int
    let threadCountLimit = 10
    
    let threshold: Float = 0.5
    
    let batchSize = 1
    let inputChannels = 3
    let inputWidth = 256
    let inputHeight = 256
    
    let imageMean: Float = 0
    let imageStd:  Float = 255
    
    private var labels: [String] = []
    
    private var interpreter: Interpreter
    private var isFront: Bool
    
    private let bgraPixel = (channels: 4, alphaComponent: 3, lastBgrComponent: 2)
    private let rgbPixelChannels = 3
    private let colorStrideValue = 10
    private let colors = [
        UIColor.red,
        UIColor(displayP3Red: 90.0/255.0, green: 200.0/255.0, blue: 250.0/255.0, alpha: 1.0),
        UIColor.green,
        UIColor.orange,
        UIColor.blue,
        UIColor.purple,
        UIColor.magenta,
        UIColor.yellow,
        UIColor.cyan,
        UIColor.brown
    ]
    
    public var customColor =   "#FFC400";

    init?(modelFileInfo: FileInfo, labelsFileInfo: FileInfo, threadCount: Int = 1,isFront:Bool) {
        let modelFilename = modelFileInfo.name
        self.isFront = isFront
        
        guard let modelPath = Bundle.module.path(
            forResource: modelFilename,
            ofType: modelFileInfo.extension
        ) else {
            print("Failed to load the model file with name: \(modelFilename).")
            return nil
        }
        
        self.threadCount = threadCount
        var options = Interpreter.Options()
        options.threadCount = threadCount
        do {
            interpreter = try Interpreter(modelPath: modelPath, options: options)
            try interpreter.allocateTensors()
        } catch let error {
            print("Failed to create the interpreter with error: \(error.localizedDescription)")
            return nil
        }
        
        super.init()
        
        loadLabels(fileInfo: labelsFileInfo)
    }

    func runModel(onFrame pixelBuffer: CVPixelBuffer) -> Result? {
        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(sourcePixelFormat == kCVPixelFormatType_32ARGB ||
               sourcePixelFormat == kCVPixelFormatType_32BGRA ||
               sourcePixelFormat == kCVPixelFormatType_32RGBA)
        
        
        let imageChannels = 4
        assert(imageChannels >= inputChannels)
        
        let scaledSize = CGSize(width: inputWidth, height: inputHeight)
        var scaledPixelBuffer:CVPixelBuffer?;
         scaledPixelBuffer = pixelBuffer.resized(to: scaledSize);
        
      
        
        let interval: TimeInterval
        let outputResult: Tensor

        do {
            let inputTensor = try interpreter.input(at: 0)
            
            guard let rgbData = rgbDataFromBuffer(
                scaledPixelBuffer!,
                byteCount: batchSize * inputWidth * inputHeight * inputChannels,
                isModelQuantized: inputTensor.dataType == .uInt8
            ) else {
                print("Failed to convert the image buffer to RGB data.")
                return nil
            }
            
            try interpreter.copy(rgbData, toInputAt: 0)
            
            let startDate = Date()
            try interpreter.invoke()
            interval = Date().timeIntervalSince(startDate) * 1000
            
            outputResult = try interpreter.output(at: 0)
        } catch let error {
            print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
            return nil
        }
        
        let outputs = ([Float](unsafeData: outputResult.data) ?? []) as [NSNumber]

        let nmsPredictions = PrePostProcessor.outputsToNMSPredictions(outputs: outputs, imageWidth: CGFloat(imageWidth), imageHeight: CGFloat(imageHeight))

        var inference: [Inference] = []
        for prediction in nmsPredictions {
            let pred = Inference(confidence: prediction.score, className: labels[prediction.classIndex], rect: prediction.rect, displayColor: UIColor(hexString: self.customColor))
            inference.append(pred)
        }
        let result = Result(inferenceTime: interval, inferences: inference)

        return result
    }
    
    func formatResults(boundingBox: [Float], outputClasses: [Float], outputScores: [Float], outputCount: Int, width: CGFloat, height: CGFloat) -> [Inference]{
        var resultsArray: [Inference] = []
        if (outputCount == 0) {
            return resultsArray
        }
        for i in 0...outputCount - 1 {
            
            let score = outputScores[i]
            
            guard score >= threshold else {
                continue
            }
            
            let outputClassIndex = Int(outputClasses[i])
            let outputClass = labels[outputClassIndex + 1]
            
            var rect: CGRect = CGRect.zero
            
            rect.origin.y = CGFloat(boundingBox[4*i])
            rect.origin.x = CGFloat(boundingBox[4*i+1])
            rect.size.height = CGFloat(boundingBox[4*i+2]) - rect.origin.y
            rect.size.width = CGFloat(boundingBox[4*i+3]) - rect.origin.x
            

            let newRect = rect.applying(CGAffineTransform(scaleX: width, y: height))
            
            let colorToAssign = UIColor(hexString: self.customColor)
            let inference = Inference(confidence: score,
                                      className: outputClass,
                                      rect: newRect,
                                      displayColor: colorToAssign)
            resultsArray.append(inference)
        }
        
        resultsArray.sort { (first, second) -> Bool in
            return first.confidence  > second.confidence
        }
        
        return resultsArray
    }
    
    private func loadLabels(fileInfo: FileInfo) {
        let filename = fileInfo.name
        let fileExtension = fileInfo.extension
        guard let fileURL = Bundle.module.url(forResource: filename, withExtension: fileExtension) else {
            fatalError("Labels file not found in bundle. Please add a labels file with name " +
                       "\(filename).\(fileExtension) and try again.")
        }
        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            labels = contents.components(separatedBy: .newlines)
        } catch {
            fatalError("Labels file named \(filename).\(fileExtension) cannot be read. Please add a " +
                       "valid labels file and try again.")
        }
    }
    

    private func rgbDataFromBuffer(
        _ buffer: CVPixelBuffer,
        byteCount: Int,
        isModelQuantized: Bool
    ) -> Data? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }
        guard let sourceData = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }
        
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let destinationChannelCount = 3
        let destinationBytesPerRow = destinationChannelCount * width
        
        var sourceBuffer = vImage_Buffer(data: sourceData,
                                         height: vImagePixelCount(height),
                                         width: vImagePixelCount(width),
                                         rowBytes: sourceBytesPerRow)
        
        guard let destinationData = malloc(height * destinationBytesPerRow) else {
            print("Error: out of memory")
            return nil
        }
        
        defer {
            free(destinationData)
        }
        
        var destinationBuffer = vImage_Buffer(data: destinationData,
                                              height: vImagePixelCount(height),
                                              width: vImagePixelCount(width),
                                              rowBytes: destinationBytesPerRow)
        
        if (CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA){
            vImageConvert_BGRA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
        } else if (CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32ARGB) {
            vImageConvert_ARGB8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
        }
        
        let byteData = Data(bytes: destinationBuffer.data, count: destinationBuffer.rowBytes * height)
        if isModelQuantized {
            return byteData
        }
        
        let bytes = Array<UInt8>(unsafeData: byteData)!
        var floats = [Float]()
        for i in 0..<bytes.count {
            floats.append((Float(bytes[i]) - imageMean) / imageStd)
        }
        return Data(copyingBufferOf: floats)
    }
    
}


extension Data {

    init<T>(copyingBufferOf array: [T]) {
        self = array.withUnsafeBufferPointer(Data.init)
    }
}

extension Array {

    init?(unsafeData: Data) {
        guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
#if swift(>=5.0)
        self = unsafeData.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
#else
        self = unsafeData.withUnsafeBytes {
            .init(UnsafeBufferPointer<Element>(
                start: $0,
                count: unsafeData.count / MemoryLayout<Element>.stride
            ))
        }
#endif 
    }
}
