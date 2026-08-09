//
//  BlurChecker.swift
//  AssentifySdk
//
//  Created by TariQ on 26/02/2024.
//

import CoreImage
import CoreVideo
import Accelerate

import CoreVideo

func calculateImageBlur( pixelBuffer: CVPixelBuffer) -> Double? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let data = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)

    var sum: Double = 0
    var sumSquared: Double = 0

    for row in 0..<height {
        for column in 0..<width {
            let offset = row * rowBytes + column * MemoryLayout<UInt8>.size
            let pixelAddress = data.advanced(by: offset)
            let pixelValue = pixelAddress.assumingMemoryBound(to: UInt8.self).pointee
            sum += Double(pixelValue)
            sumSquared += Double(pixelValue) * Double(pixelValue)
        }
    }

    let mean = sum / Double(width * height)
    let variance = sumSquared / Double(width * height) - mean * mean


    return variance
}

