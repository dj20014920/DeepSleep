import Foundation
import AVFoundation

/// 사운드 파일 이름과 AVAudioPlayer 인스턴스를 관리하는 매니저
final class SoundManager {
    static let shared = SoundManager()
    /// 앱 번들에 추가해 둘 사운드 파일 이름 (확장자 포함)
    /// 순서가 ViewController.sliderLabels 순서(A~L)와 1:1 매핑됩니다.
    private var soundFileNames = [
        "rain.mp3", "thunder.mp3", "wave.mp3", "bonfire.mp3",
        "steam.mp3", "windowsill_rain.mp3", "forest_bird.mp3", "cold_wind.mp3",
        "summer_night.mp3", "lullaby.mp3", "fan.mp3", "white_noise.mp3"
    ]
    
    var players: [AVAudioPlayer] = []    /// 현재 재생 중인지
    var isPlaying: Bool {
        return players.contains { $0.isPlaying }
    }
    
    private init() {
        configureAudioSession()
        loadPlayers()
    }
    
    /// AVAudioSession 설정 (백그라운드 재생, 믹스 옵션 등)
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            // 인터럽션 관찰
            NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: session)
        } catch {
            print("⚠️ AudioSession 설정 실패:", error)
        }
    }
    
    /// 모든 트랙 일괄 재생 / 일시정지
    func playAll() { players.forEach { if !$0.isPlaying { $0.play() } } }
    func pauseAll() { players.forEach { if $0.isPlaying { $0.pause() } } }
    /// 번들에 있는 파일들을 AVAudioPlayer로 미리 로드합니다.
    private func loadPlayers() {
        for fileName in soundFileNames {
            guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
                print("⚠️ 사운드 파일을 찾을 수 없습니다:", fileName)
                continue
            }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1    // 무한 루프
                player.volume = 0            // 초기 볼륨 0
                player.prepareToPlay()
                players.append(player)
            } catch {
                print("⚠️ AVAudioPlayer 생성 실패:", error)
            }
        }
    }
    //――▶ 개별 제어
        func play(at index: Int) {
            guard index >= 0, index < players.count else { return }
            let p = players[index]
            if !p.isPlaying { p.play() }
        }
        func pause(at index: Int) {
            guard index >= 0, index < players.count else { return }
            let p = players[index]
            if p.isPlaying { p.pause() }
        }
        func isPlaying(at index: Int) -> Bool {
            guard index >= 0, index < players.count else { return false }
            return players[index].isPlaying
        }
    /// 슬라이더나 프리셋에서 설정한 볼륨을 반영합니다. volume 은 0~100 사이.
    func setVolume(at index: Int, volume: Float) {
        guard index >= 0, index < players.count else { return }
        players[index].volume = volume / 100.0
    }
    
    /// 배열 단위로 한 번에 설정
    func setVolumes(_ volumes: [Float]) {
        for (i, v) in volumes.enumerated() {
            setVolume(at: i, volume: v)
        }
    }
    
    /// 완전 중지 (재생 위치 리셋)
    func stopAll() {
        for player in players {
            player.stop()
            player.currentTime = 0
        }
    }
    
    @objc private func handleInterruption(_ notif: Notification) {
            guard let info = notif.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

            switch type {
            case .began:
                // 인터럽션 시작: 일시정지
                pauseAll()
            case .ended:
                // 인터럽션 종료: 옵션에 따라 재생 재시도
                if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
                   AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                    playAll()
                }
            @unknown default: break
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    
    func fadeOutAll(duration: TimeInterval = 3.0) {
            players.forEach { player in
                // AVAudioPlayer가 백그라운드 Audio 모드에서
                // 자동으로 볼륨을 줄여줍니다.
                player.setVolume(0, fadeDuration: duration)
            }
            // 끝나고 완전히 멈추고 싶으면,  duration 후에 호출:
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.pauseAll()
            }
        }
}
