
import UIKit
import AVFoundation
import CoreImage

extension CVPixelBuffer {
    var brightness: Double {
        let width = CVPixelBufferGetWidth(self)
            let height = CVPixelBufferGetHeight(self)
            
            CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags.readOnly)
            defer { CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags.readOnly) }
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(self) else {
                return 0.0
            }
            
           _ = CVPixelBufferGetBytesPerRow(self)
            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
            
            var totalBrightness: Double = 0.0
            for y in 0..<height {
                for x in 0..<width {
                    let pixelInfo: Int = ((width * y) + x) * 4 // Assuming 4 bytes per pixel (RGBA)
                    
                    let r = Double(buffer[pixelInfo])
                    let g = Double(buffer[pixelInfo + 1])
                    let b = Double(buffer[pixelInfo + 2])
                    
                    // Calculate luminance
                    let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                    totalBrightness += luminance
                }
            }
            
            let numPixels = width * height
            return totalBrightness / Double(numPixels)
    }
}





func cropPixelBuffer(_ pixelBuffer: CVPixelBuffer, toRect rect: CGRect) -> CVPixelBuffer? {
    let outputWidth = Int(rect.width)
    let outputHeight = Int(rect.height)
    
    var croppedPixelBuffer: CVPixelBuffer?
    
    let attributes = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ] as CFDictionary
    
    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     outputWidth,
                                     outputHeight,
                                     kCVPixelFormatType_32BGRA,
                                     attributes,
                                     &croppedPixelBuffer)
    
    guard status == kCVReturnSuccess, let cropped = croppedPixelBuffer else {
        return nil
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    CVPixelBufferLockBaseAddress(cropped, [])
    
    let pixelBufferWidth = CVPixelBufferGetWidth(pixelBuffer)
    let pixelBufferHeight = CVPixelBufferGetHeight(pixelBuffer)
    
    guard let srcBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
          let destBaseAddress = CVPixelBufferGetBaseAddress(cropped) else {
              return nil
    }
    
    let srcBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let destBytesPerRow = CVPixelBufferGetBytesPerRow(cropped)
    
    let startY = Int(rect.origin.y)
    let startX = Int(rect.origin.x)
    
    for row in 0..<outputHeight {
        let srcStart = (startY + row) * srcBytesPerRow + startX * 4
        let destStart = row * destBytesPerRow
        
        memcpy(destBaseAddress.advanced(by: destStart),
               srcBaseAddress.advanced(by: srcStart),
               outputWidth * 4)
    }
    
    CVPixelBufferUnlockBaseAddress(cropped, [])
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    
    return cropped
}



