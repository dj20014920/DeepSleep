import Foundation
import AVFoundation

/// 11개 카테고리 + 다중 버전을 지원하는 사운드 매니저
final class SoundManager {
    static let shared = SoundManager()
    
    // MARK: - 새로운 11개 카테고리 정의
    struct SoundCategory {
        let emoji: String
        let name: String
        let files: [String]  // 여러 버전 지원
        let defaultIndex: Int  // 기본 선택 버전
        
        init(emoji: String, name: String, files: [String], defaultIndex: Int = 0) {
            self.emoji = emoji
            self.name = name
            self.files = files
            self.defaultIndex = min(defaultIndex, files.count - 1)
        }
    }
    
    /// 11개 사운드 카테고리 (이모지 + 다중 버전)
    private let soundCategories: [SoundCategory] = [
        SoundCategory(emoji: "🐱", name: "고양이", files: ["고양이.mp3"]),
        SoundCategory(emoji: "💨", name: "바람", files: ["바람.mp3"]),
        SoundCategory(emoji: "🌙", name: "밤", files: ["밤.mp3"]),
        SoundCategory(emoji: "🔥", name: "불", files: ["불1.mp3"]),
        SoundCategory(emoji: "🌧️", name: "비", files: ["비.mp3", "비-창문.mp3"]),
        SoundCategory(emoji: "🏞️", name: "시냇물", files: ["시냇물.mp3"]),
        SoundCategory(emoji: "✏️", name: "연필", files: ["연필.mp3"]),
        SoundCategory(emoji: "🌌", name: "우주", files: ["우주.mp3"]),
        SoundCategory(emoji: "🌀", name: "쿨링팬", files: ["쿨링팬.mp3"]),
        SoundCategory(emoji: "⌨️", name: "키보드", files: ["키보드1.mp3", "키보드2.mp3"]),
        SoundCategory(emoji: "🌊", name: "파도", files: ["파도.mp3"])
    ]
    
    // MARK: - 현재 선택된 버전 추적
    private var selectedVersions: [Int] = []  // 각 카테고리별 선택된 버전 인덱스
    
    // MARK: - AVAudioPlayer 관리
    var players: [AVAudioPlayer] = []
    private var previewPlayer: AVAudioPlayer?  // 미리듣기용 플레이어
    
    /// 현재 재생 중인지
    var isPlaying: Bool {
        return players.contains { $0.isPlaying }
    }
    
    private init() {
        setupSelectedVersions()
        configureAudioSession()
        loadPlayers()
    }
    
    // MARK: - 초기 설정
    private func setupSelectedVersions() {
        selectedVersions = soundCategories.map { $0.defaultIndex }
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
    
    /// 선택된 버전의 파일들을 AVAudioPlayer로 로드
    private func loadPlayers() {
        players.removeAll()
        
        for (categoryIndex, category) in soundCategories.enumerated() {
            let versionIndex = selectedVersions[categoryIndex]
            let fileName = category.files[versionIndex]
            
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
        
        print("✅ \(players.count)개 사운드 로드 완료")
    }
    
    // MARK: - 카테고리 정보 접근
    
    /// 카테고리 개수
    var categoryCount: Int {
        return soundCategories.count
    }
    
    /// 특정 카테고리 정보
    func getCategory(at index: Int) -> SoundCategory? {
        guard index >= 0, index < soundCategories.count else { return nil }
        return soundCategories[index]
    }
    
    /// 카테고리의 이모지 + 이름
    func getCategoryDisplay(at index: Int) -> String {
        guard let category = getCategory(at: index) else { return "Unknown" }
        return "\(category.emoji) \(category.name)"
    }
    
    /// 현재 선택된 버전 정보
    func getCurrentVersionInfo(at categoryIndex: Int) -> String? {
        guard let category = getCategory(at: categoryIndex) else { return nil }
        let versionIndex = selectedVersions[categoryIndex]
        
        if category.files.count > 1 {
            return "\(category.files[versionIndex]) (\(versionIndex + 1)/\(category.files.count))"
        } else {
            return category.files[versionIndex]
        }
    }
    
    // MARK: - 버전 선택 관리
    
    /// 특정 카테고리의 버전 변경
    func selectVersion(categoryIndex: Int, versionIndex: Int) {
        guard categoryIndex >= 0, categoryIndex < soundCategories.count else { return }
        guard versionIndex >= 0, versionIndex < soundCategories[categoryIndex].files.count else { return }
        
        let wasPlaying = isPlaying(at: categoryIndex)
        let currentVolume = players.count > categoryIndex ? players[categoryIndex].volume : 0
        
        // 기존 플레이어 정지
        if categoryIndex < players.count {
            players[categoryIndex].stop()
        }
        
        // 버전 변경
        selectedVersions[categoryIndex] = versionIndex
        
        // 해당 카테고리만 다시 로드
        reloadPlayer(at: categoryIndex)
        
        // 이전 상태 복원
        if categoryIndex < players.count {
            players[categoryIndex].volume = currentVolume
            if wasPlaying && currentVolume > 0 {
                players[categoryIndex].play()
            }
        }
        
        print("🔄 카테고리 \(categoryIndex) 버전 변경: \(versionIndex)")
    }
    
    /// 다음 버전으로 변경
    func selectNextVersion(categoryIndex: Int) {
        guard let category = getCategory(at: categoryIndex) else { return }
        let currentVersion = selectedVersions[categoryIndex]
        let nextVersion = (currentVersion + 1) % category.files.count
        selectVersion(categoryIndex: categoryIndex, versionIndex: nextVersion)
    }
    
    /// 특정 카테고리의 플레이어만 다시 로드
    private func reloadPlayer(at categoryIndex: Int) {
        guard categoryIndex >= 0, categoryIndex < soundCategories.count else { return }
        
        let category = soundCategories[categoryIndex]
        let versionIndex = selectedVersions[categoryIndex]
        let fileName = category.files[versionIndex]
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("⚠️ 사운드 파일을 찾을 수 없습니다:", fileName)
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            
            // 기존 플레이어 배열에서 교체
            if categoryIndex < players.count {
                players[categoryIndex] = player
            } else {
                // 배열 크기 확장이 필요한 경우
                while players.count <= categoryIndex {
                    players.append(player)
                }
            }
        } catch {
            print("⚠️ AVAudioPlayer 생성 실패:", error)
        }
    }
    
    // MARK: - 미리듣기 기능
    
    /// 특정 버전 미리듣기 (3초간)
    func previewVersion(categoryIndex: Int, versionIndex: Int) {
        guard let category = getCategory(at: categoryIndex) else { return }
        guard versionIndex >= 0, versionIndex < category.files.count else { return }
        
        let fileName = category.files[versionIndex]
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("⚠️ 미리듣기 파일을 찾을 수 없습니다:", fileName)
            return
        }
        
        do {
            // 기존 미리듣기 정지
            previewPlayer?.stop()
            
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.volume = 0.3  // 미리듣기는 조금 작게
            previewPlayer?.play()
            
            // 3초 후 자동 정지
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.previewPlayer?.stop()
                self.previewPlayer = nil
            }
            
            print("🔊 미리듣기: \(fileName)")
        } catch {
            print("⚠️ 미리듣기 플레이어 생성 실패:", error)
        }
    }
    
    /// 미리듣기 정지
    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
    }
    
    // MARK: - 전체 제어 (기존 API 유지)
    
    /// 모든 트랙 일괄 재생 (볼륨이 0 이상인 것만)
    func playAll() {
        for (index, player) in players.enumerated() {
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
        stopPreview()  // 미리듣기도 정지
    }
    
    // MARK: - 개별 제어 (기존 API 유지)
    
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
    
    // MARK: - 볼륨 제어 (기존 API 유지)
    
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
    
    // MARK: - 확장된 프리셋 적용 (버전 정보 포함)
    
    /// 버전 정보를 포함한 프리셋 적용
    func applyPresetWithVersions(volumes: [Float], versions: [Int]? = nil) {
        // 1. 버전 정보가 있으면 먼저 적용
        if let versions = versions {
            for (categoryIndex, versionIndex) in versions.enumerated() {
                if categoryIndex < soundCategories.count {
                    selectVersion(categoryIndex: categoryIndex, versionIndex: versionIndex)
                }
            }
        }
        
        // 2. 볼륨 적용
        applyPreset(volumes: volumes)
    }
    
    // MARK: - 페이드아웃 (기존 API 유지)
    
    /// 모든 사운드를 부드럽게 페이드아웃
    func fadeOutAll(duration: TimeInterval = 30.0) {
        print("페이드아웃 시작: \(duration)초 동안")
        
        players.forEach { player in
            player.setVolume(0, fadeDuration: duration)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.pauseAll()
            print("페이드아웃 완료 - 모든 사운드 정지")
        }
    }
    
    // MARK: - 프리셋 호환성 (기존 API)
    
    /// 현재 선택된 버전들 반환
    func getCurrentVersions() -> [Int] {
        return selectedVersions
    }
    
    /// 카테고리명으로 인덱스 찾기 (ChatViewController 호환성)
    func getSoundIndex(for soundName: String) -> Int? {
        // 기존 매핑 유지 (임시)
        let legacyMapping: [String: Int] = [
            "Rain": 4,      // 🌧️ 비
            "Thunder": 4,   // 🌧️ 비 (천둥 소리가 없으므로 비로 매핑)
            "Ocean": 10,    // 🌊 파도
            "Fire": 3,      // 🔥 불
            "Steam": 5,     // 🏞️ 시냇물 (비슷한 소리)
            "WindowRain": 4, // 🌧️ 비
            "Forest": 0,    // 🐱 고양이 (자연 소리로 매핑)
            "Wind": 1,      // 💨 바람
            "Night": 2,     // 🌙 밤
            "Lullaby": 7,   // 🌌 우주 (잔잔한 소리)
            "Fan": 8,       // 🌀 쿨링팬
            "WhiteNoise": 9 // ⌨️ 키보드 (화이트노이즈 대체)
        ]
        
        // 새로운 이모지/이름 매핑
        if let index = soundCategories.firstIndex(where: { $0.name == soundName }) {
            return index
        }
        
        return legacyMapping[soundName]
    }
    
    /// ChatViewController에서 사용할 표준 사운드 이름들 (업데이트됨)
    static let standardSoundNames = [
        "고양이", "바람", "밤", "불", "비", "시냇물",
        "연필", "우주", "쿨링팬", "키보드", "파도"
    ]
    
    // MARK: - 인터럽션 처리 (기존 유지)
    
    @objc private func handleInterruption(_ notif: Notification) {
        guard let info = notif.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pauseAll()
            stopPreview()
            print("오디오 인터럽션 시작 - 일시정지")
        case .ended:
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
        stopPreview()
    }
}
