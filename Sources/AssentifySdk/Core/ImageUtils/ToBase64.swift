import UIKit
import CoreImage
import MobileCoreServices
import CoreVideo
import Accelerate


func convertPixelToDataImage(pixelBuffer: CVPixelBuffer) -> Data? {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
        return nil
    }
    let uiImage = UIImage(cgImage: cgImage)
    
    guard let pngData = uiImage.pngData() else {
        return nil
    }
    
    guard let imageData = uiImage.jpegData(compressionQuality: 0.6) else {
        return nil
    }
    
    return imageData
}

func base64ToData(_ base64String: String) -> Data? {
    return Data(base64Encoded: base64String, options: .ignoreUnknownCharacters)
}


private let sharedCIContext: CIContext = {
    return CIContext(options: nil)
}()


func convertClipsPixelBufferToData(
    _ pixelBuffer: CVPixelBuffer,
    targetSize: CGSize,
    targetAspect: CGSize,
    jpegQuality: CGFloat = 0.8
) -> Data? {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

    let cropped = crop(ciImage: ciImage, toAspect: targetAspect)
    let resized = lanczosResize(ciImage: cropped, to: targetSize)

    guard let cg = sharedCIContext.createCGImage(resized, from: resized.extent) else {
        return nil
    }

    let ui = UIImage(cgImage: cg)
    return ui.jpegData(compressionQuality: jpegQuality)
}

private func crop(ciImage: CIImage, toAspect aspect: CGSize) -> CIImage {
    let src = ciImage.extent
    let srcW = src.width
    let srcH = src.height
    let srcAR = srcW / srcH
    let tgtAR = aspect.width / aspect.height

    var cropW = srcW
    var cropH = srcH

    if srcAR > tgtAR {
        cropW = srcH * tgtAR
        cropH = srcH
    } else {
        cropW = srcW
        cropH = srcW / tgtAR
    }

    let cropX = src.origin.x + (srcW - cropW) / 2.0
    let cropY = src.origin.y + (srcH - cropH) / 2.0
    let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

    return ciImage.cropped(to: cropRect)
}

private func lanczosResize(ciImage: CIImage, to targetSize: CGSize) -> CIImage {
    let src = ciImage.extent
    let scaleX = targetSize.width / src.width
    let scaleY = targetSize.height / src.height
    let scale = min(scaleX, scaleY)

    let filter = CIFilter(name: "CILanczosScaleTransform")!
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(scale, forKey: kCIInputScaleKey)
    filter.setValue(1.0, forKey: kCIInputAspectRatioKey) // already cropped to aspect
    return filter.outputImage!
}




func saveBase64ImageToGallery(base64String: String) {
    guard let imageData = Data(base64Encoded: base64String) else {
        print("Failed to decode Base64 string to Data")
        return
    }
    
    guard let uiImage = UIImage(data: imageData) else {
        print("Failed to create UIImage from decoded Data")
        return
    }
    
    // Save the image to the photo gallery
    UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
    print("Image saved to gallery")
}



func downscalePixelBuffer(_ pixelBuffer: CVPixelBuffer, scaleFactor: CGFloat) -> CVPixelBuffer? {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let transform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
    let scaledImage = ciImage.transformed(by: transform)
    
    let context = CIContext()
    var scaledPixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(nil,
                        Int(scaledImage.extent.width),
                        Int(scaledImage.extent.height),
                        CVPixelBufferGetPixelFormatType(pixelBuffer),
                        nil,
                        &scaledPixelBuffer)
    
    if let scaledPixelBuffer = scaledPixelBuffer {
        context.render(scaledImage, to: scaledPixelBuffer)
    }
    
    return scaledPixelBuffer
}


func copyPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer)
    
    var copiedBuffer: CVPixelBuffer?
    let attributes: [CFString: Any] = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ]
    
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        pixelFormatType,
        attributes as CFDictionary,
        &copiedBuffer
    )
    
    guard status == kCVReturnSuccess, let newBuffer = copiedBuffer else {
        print("Failed to create pixel buffer copy")
        return nil
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    CVPixelBufferLockBaseAddress(newBuffer, [])
    
    if let sourceBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
       let destinationBaseAddress = CVPixelBufferGetBaseAddress(newBuffer) {
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let destinationBytesPerRow = CVPixelBufferGetBytesPerRow(newBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        for row in 0..<height {
            memcpy(destinationBaseAddress + row * destinationBytesPerRow,
                   sourceBaseAddress + row * sourceBytesPerRow,
                   sourceBytesPerRow)
        }
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    CVPixelBufferUnlockBaseAddress(newBuffer, [])
    
    return newBuffer
}
extension UIImage {

    class func gifImageWithName(_ name: String) -> UIImage? {
           guard let bundleURL = Bundle.module.url(forResource: name, withExtension: "gif") else {
               return nil
           }
           guard let imageData = try? Data(contentsOf: bundleURL) else {
               return nil
           }
           return UIImage.gifImageWithData(imageData)
       }
       
       class func gifImageWithData(_ data: Data) -> UIImage? {
           guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
               return nil
           }
           return UIImage.animatedImageWithSource(source)
       }
       
       class func animatedImageWithSource(_ source: CGImageSource) -> UIImage? {
           let count = CGImageSourceGetCount(source)
           var images = [UIImage]()
           var duration = 0.0
           
           for i in 0..<count {
               guard let image = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                   continue
               }
               guard let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any] else {
                   continue
               }
               guard let gifDictionary = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] else {
                   continue
               }
               guard let gifDelayTime = gifDictionary[kCGImagePropertyGIFDelayTime as String] as? Double else {
                   continue
               }
               duration += gifDelayTime
               images.append(UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .up))
           }
           
           return UIImage.animatedImage(with: images, duration: duration)
       }
}
