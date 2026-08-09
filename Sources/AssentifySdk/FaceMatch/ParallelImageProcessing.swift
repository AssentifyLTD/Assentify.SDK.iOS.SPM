import Foundation
import CoreVideo

class ParallelImageProcessing {
    private var clips: [Data] = []
    private var pixelBufferLiveImage: [CVPixelBuffer] = []
    private let queue = DispatchQueue.global(qos: .userInitiated)
    private let dispatchGroup = DispatchGroup()
    
   
    func setPixelBuffers(_ buffers: [CVPixelBuffer]) {
        self.pixelBufferLiveImage = buffers
    }
    
    
    func convertBuffers(completion: @escaping () -> Void) {
        clips.removeAll()

        for i in 0..<pixelBufferLiveImage.count {
            dispatchGroup.enter()
            queue.async {
                if let base64String = convertClipsPixelBufferToData(self.pixelBufferLiveImage[i],
                           targetSize: CGSize(width: 360, height: 640),
                           targetAspect: CGSize(width: 9, height: 16),
                            jpegQuality: 0.8
                ) {
                    DispatchQueue.main.async {
                        self.clips.append(base64String)
                        self.dispatchGroup.leave()
                    }
                } else {
                    self.dispatchGroup.leave()
                }
            }
        }

        dispatchGroup.notify(queue: DispatchQueue.main) {
            completion()
        }
    }
    
    func getClips() -> [Data] {
        return clips
    }
    
   
}
