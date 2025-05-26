import UIKit
import MediaPlayer

// MARK: - 재생 제어 관련 Extension
extension ViewController {
    
    // MARK: - 재생 제어
    @objc func toggleTrack(_ sender: UIButton) {
        let index = sender.tag
        
        if SoundManager.shared.isPlaying(at: index) {
            SoundManager.shared.pause(at: index)
        } else {
            SoundManager.shared.play(at: index)
        }
        
        updatePlayButtonStates()
    }

    @objc func playAllTapped() {
        SoundManager.shared.playAll()
        updatePlayButtonStates()
        provideMediumHapticFeedback()
    }

    @objc func pauseAllTapped() {
        SoundManager.shared.pauseAll()
        updatePlayButtonStates()
        provideMediumHapticFeedback()
    }
    
    // MARK: - 실시간 재생 상태 모니터링
    func startPlaybackStateMonitoring() {
        stopPlaybackStateMonitoring()
        playbackMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePlayButtonStates()
            }
        }
    }
    
    func stopPlaybackStateMonitoring() {
        playbackMonitorTimer?.invalidate()
        playbackMonitorTimer = nil
    }
    
    func updatePlayButtonStates() {
        for (index, button) in playButtons.enumerated() {
            let isPlaying = SoundManager.shared.isPlaying(at: index)
            let imageName = isPlaying ? "pause.fill" : "play.fill"
            button.setImage(UIImage(systemName: imageName), for: .normal)
        }
    }
    
    // MARK: - Remote Commands (제어 센터)
    func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { _ in SoundManager.shared.playAll(); return .success }
        center.pauseCommand.addTarget { _ in SoundManager.shared.pauseAll(); return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            
            if SoundManager.shared.isPlaying {
                SoundManager.shared.pauseAll()
            } else {
                SoundManager.shared.playAll()
            }
            
            self.updatePlayButtonStates()
            return .success
        }
    }
}
