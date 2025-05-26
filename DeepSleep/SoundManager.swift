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
    
    var players: [AVAudioPlayer] = []
    
    /// 현재 재생 중인지
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
                object: session
            )
        } catch {
            print("⚠️ AudioSession 설정 실패:", error)
        }
    }
    
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
    
    // MARK: - 전체 제어
    
    /// 모든 트랙 일괄 재생 (볼륨이 0 이상인 것만)
    func playAll() {
        for (index, player) in players.enumerated() {
            // 볼륨이 0보다 큰 플레이어만 재생
            if player.volume > 0 && !player.isPlaying {
                player.play()
            }
        }
        print("전체 재생 시작")
    }
    
    /// 모든 트랙 일괄 일시정지
    func pauseAll() {
        for player in players {
            if player.isPlaying {
                player.pause()
            }
        }
        print("전체 재생 일시정지")
    }
    
    /// 완전 중지 (재생 위치 리셋)
    func stopAll() {
        for player in players {
            player.stop()
            player.currentTime = 0
        }
    }
    
    // MARK: - 개별 제어
    
    func play(at index: Int) {
        guard index >= 0, index < players.count else { return }
        let player = players[index]
        if !player.isPlaying && player.volume > 0 {
            player.play()
            print("사운드 \(index) 재생 시작")
        }
    }
    
    func pause(at index: Int) {
        guard index >= 0, index < players.count else { return }
        let player = players[index]
        if player.isPlaying {
            player.pause()
            print("사운드 \(index) 일시정지")
        }
    }
    
    func isPlaying(at index: Int) -> Bool {
        guard index >= 0, index < players.count else { return false }
        return players[index].isPlaying
    }
    
    // MARK: - 볼륨 제어
    
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
        print("볼륨 설정 완료: \(volumes)")
    }
    
    /// 프리셋 적용 (볼륨 설정 + 재생 시작)
    func applyPreset(volumes: [Float]) {
        // 1. 먼저 볼륨 설정
        setVolumes(volumes)
        
        // 2. 볼륨이 0 이상인 사운드만 재생 시작
        for (index, volume) in volumes.enumerated() {
            if index < players.count && volume > 0 {
                play(at: index)
            } else if index < players.count && volume == 0 {
                pause(at: index)
            }
        }
        
        print("프리셋 적용 완료: \(volumes)")
    }
    
    // MARK: - 페이드아웃
    
    /// 모든 사운드를 부드럽게 페이드아웃
    /// - Parameter duration: 페이드아웃 지속 시간 (기본값: 30초)
    func fadeOutAll(duration: TimeInterval = 30.0) {
        print("페이드아웃 시작: \(duration)초 동안")
        
        players.forEach { player in
            // AVAudioPlayer의 내장 페이드아웃 기능 사용
            player.setVolume(0, fadeDuration: duration)
        }
        
        // 페이드아웃 완료 후 완전히 정지
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.pauseAll()
            print("페이드아웃 완료 - 모든 사운드 정지")
        }
    }
    
    // MARK: - 인터럽션 처리
    
    @objc private func handleInterruption(_ notif: Notification) {
        guard let info = notif.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // 인터럽션 시작: 일시정지
            pauseAll()
            print("오디오 인터럽션 시작 - 일시정지")
        case .ended:
            // 인터럽션 종료: 옵션에 따라 재생 재시도
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                playAll()
                print("오디오 인터럽션 종료 - 재생 재시작")
            }
        @unknown default:
            break
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 사운드 이름 매핑 (ChatViewController에서 사용)
extension SoundManager {
    /// 사운드 이름을 인덱스로 변환
    func getSoundIndex(for soundName: String) -> Int? {
        let soundMapping: [String: Int] = [
            "Rain": 0, "Thunder": 1, "Ocean": 2, "Fire": 3,
            "Steam": 4, "WindowRain": 5, "Forest": 6, "Wind": 7,
            "Night": 8, "Lullaby": 9, "Fan": 10, "WhiteNoise": 11
        ]
        return soundMapping[soundName]
    }
    
    /// ChatViewController에서 사용할 표준 사운드 이름들
    static let standardSoundNames = [
        "Rain", "Thunder", "Ocean", "Fire", "Steam", "WindowRain",
        "Forest", "Wind", "Night", "Lullaby", "Fan", "WhiteNoise"
    ]
}
