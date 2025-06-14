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
        print("▶️ ViewController: playAllTapped() 호출됨")
        SoundManager.shared.playAll()
        // SoundManager.shared.playAll() 내부의 개별 play()가 nowPlayingInfo를 업데이트하지만,
        // 여기서는 명시적으로 프리셋 이름과 전체 재생 상태를 한 번 더 업데이트합니다.
        print("▶️ ViewController: playAllTapped() - SoundManager.shared.updateNowPlayingInfo 호출 직전")
        SoundManager.shared.updateNowPlayingInfo(presetName: "DeepSleep 믹스", isPlayingOverride: true)
        updatePlayButtonStates()
        provideMediumHapticFeedback()

    }

    @objc func pauseAllTapped() {
        print("⏸️ ViewController: pauseAllTapped() 호출됨")
        SoundManager.shared.pauseAll()
        // SoundManager.shared.pauseAll() 내부의 개별 pause()가 nowPlayingInfo를 업데이트하지만,
        // 여기서는 명시적으로 전체 정지 상태를 한 번 더 업데이트합니다.
        // currentPresetName은 SoundManager가 내부적으로 유지하고 있는 것을 사용합니다.
        print("⏸️ ViewController: pauseAllTapped() - SoundManager.shared.updateNowPlayingInfo 호출 직전")
        SoundManager.shared.updateNowPlayingInfo(presetName: SoundManager.shared.currentPresetName, isPlayingOverride: false)
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
    // 이 함수는 SoundManager에서 처리하므로 삭제합니다.
    /*
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
    */
}
