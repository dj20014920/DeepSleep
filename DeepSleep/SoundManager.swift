import Foundation
import AVFoundation

/// 사운드 파일 이름과 AVAudioPlayer 인스턴스를 관리하는 매니저
final class SoundManager {
    static let shared = SoundManager()
    /// 앱 번들에 추가해 둘 사운드 파일 이름 (확장자 포함)
    /// 순서가 ViewController.sliderLabels 순서(A~L)와 1:1 매핑됩니다.
    private let soundFileNames = [
        "rain.mp3", "thunder.mp3", "wave.mp3", "bonfire.mp3",
        "steam.mp3", "windowsill_rain.mp3", "forest_bird.mp3", "cold_wind.mp3",
        "summer_night.mp3", "lullaby.mp3", "fan.mp3", "white_noise.mp3"
    ]
    
    private var players: [AVAudioPlayer] = []
    
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
}
