import AVFoundation

class AssetsAudioPlayer {
    private var audioPlayer: AVAudioPlayer?
    
    func playAudio(fileName: String, fileExtension: String? = nil) {
        stopAudio()
        
        guard let path = Bundle.module.path(forResource: fileName, ofType: fileExtension) else {
            print("Audio file not found.")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
           
            audioPlayer?.delegate = AudioPlayerDelegate { [weak self] in
                self?.releaseAudioPlayer()
            }
            
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }
    
    func stopAudio() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        releaseAudioPlayer()
    }
    
    private func releaseAudioPlayer() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    func isPlaying() -> Bool {
        return audioPlayer?.isPlaying ?? false
    }
}


private class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion()
    }
}
