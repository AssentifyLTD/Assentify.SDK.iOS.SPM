
import Foundation
import CoreVideo

let ZoomLimit = 30;
let FaceZoomLimit = 10;

func calculatePercentageChangeWidth(rect: CGRect, pixelBuffer: CVPixelBuffer) -> ZoomType {
    var fw = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
    var fh = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

    if fh > fw { swap(&fw, &fh) }

    let aspectRatio = fw / fh

    let rectWidthPx: CGFloat = (rect.width <= 1.0) ? rect.width * fw : rect.width

    let sending16by9: ClosedRange<CGFloat> = 500...800
    let zoomIn16by9: CGFloat = 500
    let zoomOut16by9: CGFloat = 800

    let sending4by3: ClosedRange<CGFloat> = 160...260
    let zoomIn4by3: CGFloat = 160
    let zoomOut4by3: CGFloat = 260

    if abs(aspectRatio - (16.0/9.0)) < 0.1 {
        if sending16by9.contains(rectWidthPx) { return .SENDING }
        if rectWidthPx < zoomIn16by9 { return .ZOOM_IN }
        if rectWidthPx > zoomOut16by9 { return .ZOOM_OUT }
    } else if abs(aspectRatio - (4.0/3.0)) < 0.1 {
        if sending4by3.contains(rectWidthPx) { return .SENDING }
        if rectWidthPx < zoomIn4by3 { return .ZOOM_IN }
        if rectWidthPx > zoomOut4by3 { return .ZOOM_OUT }
    }

    return .NO_DETECT
}


