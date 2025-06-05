import Foundation
import AVFoundation
import MediaPlayer

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
    var previewPlayer: AVAudioPlayer?
        private(set) var previewingCategoryIndex: Int? = nil

    // MARK: - Now Playing Info
    var currentPresetName: String? = nil
    private var activePlayerCount: Int { // 실제 재생 중인 (볼륨 > 0) 플레이어 수
        return players.filter { $0.isPlaying && $0.volume > 0 }.count
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
    
    /// 현재 재생 중인지
    var isPlaying: Bool {
        return players.contains { $0.isPlaying }
    }
    
    private init() {
        setupSelectedVersions()
        configureAudioSession()
        loadPlayers()
        setupRemoteTransportControls()
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
    
    /// 특정 버전 미리듣기 (무한 반복)
    func previewVersion(categoryIndex: Int, versionIndex: Int, fromTime: TimeInterval = 0) {
        guard let category = getCategory(at: categoryIndex) else { 
            print("⚠️ 미리듣기 오류: 유효하지 않은 카테고리 인덱스 \(categoryIndex)")
            return
        }
        guard versionIndex >= 0, versionIndex < category.files.count else { 
            print("⚠️ 미리듣기 오류: 카테고리 \(category.name)에 유효하지 않은 버전 인덱스 \(versionIndex)")
            return
        }
        
        let fileName = category.files[versionIndex]
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("⚠️ 미리듣기 파일을 찾을 수 없습니다: \(fileName)")
            return
        }
        
        // 기존 미리듣기가 있다면 중지
        if previewPlayer != nil {
            stopPreview()
        }
        
        do {
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            previewPlayer?.numberOfLoops = -1 // 무한 반복 설정
            previewPlayer?.volume = 0.6      // 미리듣기 볼륨
            previewPlayer?.currentTime = fromTime // 재생 시작 시간 설정
            previewPlayer?.prepareToPlay()
            previewPlayer?.play()
            previewingCategoryIndex = categoryIndex // 현재 미리듣기 중인 카테고리 인덱스 저장
            
            print("🔊 미리듣기 시작 (무한 반복): \(fileName) at \(fromTime)s")
        } catch {
            print("⚠️ 미리듣기 플레이어 생성 실패: \(error.localizedDescription) - 파일: \(fileName)")
            previewPlayer = nil // 실패 시 nil로 확실히 설정
            previewingCategoryIndex = nil
        }
    }

    func seekPreview(to time: TimeInterval) {
        guard let player = previewPlayer else {
            print("⚠️ 미리듣기 탐색 오류: 플레이어가 존재하지 않습니다.")
            return
        }
        // 재생 시간이 음원 길이를 넘지 않도록 보정
        let newTime = max(0, min(time, player.duration))
        player.currentTime = newTime
        // print("🔊 미리듣기 탐색: \(newTime)s (요청: \(time)s)") // 디버깅용
    }

    func stopPreview() {
        if let player = previewPlayer, player.isPlaying {
            player.stop()
            print("🔇 미리듣기 중지")
        }
        previewPlayer = nil
        previewingCategoryIndex = nil
    }

    func getPreviewDuration() -> TimeInterval {
        return previewPlayer?.duration ?? 0
    }
    
    func getPreviewCurrentTime() -> TimeInterval {
        return previewPlayer?.currentTime ?? 0
    }
    
    // MARK: - 전체 제어 (기존 API 유지)
    
    /// 모든 트랙 일괄 재생 (볼륨이 0 이상인 것만)
    func playAll() {
        var playedSomething = false
        for (_, player) in players.enumerated() {
            if player.volume > 0 && !player.isPlaying {
                player.play() // player.play()는 개별 play(at:)를 호출하지 않으므로 직접적인 nowPlayingInfo 업데이트 안됨
                playedSomething = true
            }
        }
        print("🔊 SoundManager: playAll() 호출됨")
        if playedSomething {
            updateNowPlayingPlaybackStatus() // 전체 재생 상태 업데이트
        }
    }
    
    /// 모든 트랙 일괄 일시정지
    func pauseAll() {
        var pausedSomething = false
        for player in players {
            if player.isPlaying {
                player.pause()
                pausedSomething = true
            }
        }
        print("🔇 SoundManager: pauseAll() 호출됨")
        if pausedSomething {
            updateNowPlayingPlaybackStatus() // 전체 정지 상태 업데이트
        }
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
            updateNowPlayingPlaybackStatus() // NowPlayingInfo 업데이트
        }
    }
    
    func pause(at index: Int) {
        guard index >= 0, index < players.count else { return }
        let player = players[index]
        if player.isPlaying {
            player.pause()
            print("사운드 \(index) 일시정지")
            updateNowPlayingPlaybackStatus() // NowPlayingInfo 업데이트
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

    // MARK: - 재생 상태 변경에 따른 NowPlayingInfo 업데이트

    /// 특정 카테고리의 볼륨을 설정하고 NowPlayingInfo를 업데이트합니다.
    func setVolume(for categoryIndex: Int, volume: Float) {
        guard categoryIndex >= 0, categoryIndex < players.count else { return }
        
        let newVolume = max(0, min(1, volume)) // 0.0 ~ 1.0
        players[categoryIndex].volume = newVolume
        
        if newVolume > 0 && !players[categoryIndex].isPlaying {
            players[categoryIndex].play()
        } else if newVolume == 0 && players[categoryIndex].isPlaying {
            // 볼륨이 0이 되면 실질적으로 멈춘 것으로 간주 (선택적: 완전히 stop() 할 수도 있음)
            // players[categoryIndex].pause() // 또는 stop()
        }
        updateNowPlayingPlaybackStatus() // 재생 상태 변경 시 항상 호출
    }

    /// 모든 플레이어를 정지시키고 NowPlayingInfo를 업데이트합니다.
    func stopAllPlayers() {
        for player in players {
            player.stop()
            player.currentTime = 0 // 필요시 처음으로 되감기
        }
        currentPresetName = nil // 프리셋 이름 초기화
        updateNowPlayingPlaybackStatus()
        print("⏹️ 모든 사운드 중지")
    }
    
    /// 현재 활성화된 사운드들을 재생 (볼륨이 0보다 큰 경우)
    func playActiveSounds() {
        var playedSomething = false
        for player in players where player.volume > 0 {
            if !player.isPlaying {
                player.play()
                playedSomething = true
            }
        }
        if playedSomething {
            updateNowPlayingPlaybackStatus()
        }
    }
    
    /// 모든 활성 사운드를 일시정지
    func pauseActiveSounds() {
        var pausedSomething = false
        for player in players where player.isPlaying && player.volume > 0 {
            player.pause()
            pausedSomething = true
        }
        if pausedSomething {
            updateNowPlayingPlaybackStatus()
        }
    }

    // MARK: - MPNowPlayingInfoCenter 및 MPRemoteCommandCenter 설정

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // 재생 명령
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.playActiveSounds()
            return .success
        }

        // 일시정지 명령
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.pauseActiveSounds()
            return .success
        }
        
        // 재생/일시정지 토글 명령
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            if self.activePlayerCount > 0 {
                self.pauseActiveSounds()
            } else {
                self.playActiveSounds() 
            }
            return .success
        }
        
        // 재생 위치 변경 명령
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            
            if let firstActivePlayer = self.players.first(where: { $0.isPlaying && $0.volume > 0 }) {
                firstActivePlayer.currentTime = event.positionTime
                self.updateNowPlayingPlaybackStatus() // 시간 변경 후 즉시 NowPlayingInfo 업데이트
            }
            return .success
        }
        
        // 사용하지 않는 명령 비활성화
        commandCenter.stopCommand.isEnabled = false // 또는 필요시 구현
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
        commandCenter.changeRepeatModeCommand.isEnabled = false
        commandCenter.changeShuffleModeCommand.isEnabled = false
        // 필요한 경우 더 많은 특정 명령 비활성화
        
        // 앱이 오디오 포커스를 가질 때만 컨트롤이 활성화되도록 하는 것이 좋을 수 있으나,
        // 현재는 항상 활성화된 상태로 둡니다.
    }

    /// NowPlayingInfo를 현재 재생 상태에 따라 업데이트합니다.
    /// 이 함수는 외부(예: ViewController)에서도 호출될 수 있도록 public으로 변경
    public func updateNowPlayingInfo(presetName: String?,isPlayingOverride: Bool? = nil) {
        self.currentPresetName = presetName // 외부에서 설정한 프리셋 이름 저장
        updateNowPlayingPlaybackStatus(isPlayingOverride: isPlayingOverride)
    }
    
    /// 내부 재생 상태 변화에 따라 NowPlayingInfo 업데이트
    private func updateNowPlayingPlaybackStatus(isPlayingOverride: Bool? = nil) {
        print("🔵 [NowPlayingInfo DEBUG] updateNowPlayingPlaybackStatus 시작. isPlayingOverride: \(String(describing: isPlayingOverride)), currentPresetName: \(currentPresetName ?? "nil")")
        var nowPlayingInfo = [String: Any]()
        let actuallyPlaying = activePlayerCount > 0
        let isEffectivelyPlaying = isPlayingOverride ?? actuallyPlaying
        
        print("🔵 [NowPlayingInfo DEBUG] actuallyPlaying: \\(actuallyPlaying), isEffectivelyPlaying: \\(isEffectivelyPlaying), activePlayerCount: \\(activePlayerCount)")

        if let presetName = self.currentPresetName, !presetName.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyTitle] = presetName
            print("🔵 [NowPlayingInfo DEBUG] Title 설정: \\(presetName)")
        } else if isEffectivelyPlaying {
            nowPlayingInfo[MPMediaItemPropertyTitle] = "EmoZleep 사운드" // 앱 이름 변경 반영
            print("🔵 [NowPlayingInfo DEBUG] Title 기본값 설정: EmoZleep 사운드")
        } else {
            // 재생 중이 아니고 프리셋 이름도 없으면 정보센터 클리어
            DispatchQueue.main.async {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                print("🔵 [NowPlayingInfo DEBUG] nowPlayingInfo를 nil로 설정 (메인 스레드). 조건: !isEffectivelyPlaying AND currentPresetName is empty or nil.")
            }
            // iOS 8+ 정보 사라짐 문제 해결 시도 부분도 여기서는 실행될 필요 없음
            return
        }

        nowPlayingInfo[MPMediaItemPropertyArtist] = "EmoZleep" // 앱 이름 변경 반영
        print("🔵 [NowPlayingInfo DEBUG] Artist 설정: EmoZleep")
        
        // 앨범 아트
        var artworkSet = false
        if let artworkImage = UIImage(named: "NowPlayingArtwork") {
            let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            artworkSet = true
            print("🖼️ [NowPlayingInfo DEBUG] NowPlayingArtwork 로드 성공. Artwork 객체: \\(artwork)")
        } else {
            print("🔴 [NowPlayingInfo DEBUG] NowPlayingArtwork 로드 실패.")
        }
        
        // 재생 상태 및 시간
        let playbackRate = isEffectivelyPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        print("🔵 [NowPlayingInfo DEBUG] PlaybackRate 설정: \\(playbackRate)")

        if isEffectivelyPlaying,
           let firstActivePlayer = players.first(where: { $0.isPlaying && $0.volume > 0 }) {
            print("🔵 [NowPlayingInfo DEBUG] firstActivePlayer 정보: duration=\\(firstActivePlayer.duration), currentTime=\\(firstActivePlayer.currentTime), isPlaying=\\(firstActivePlayer.isPlaying), volume=\\(firstActivePlayer.volume)")
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = firstActivePlayer.duration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = firstActivePlayer.currentTime
            print("🔵 [NowPlayingInfo DEBUG] PlaybackDuration 설정: \\(firstActivePlayer.duration)")
            print("🔵 [NowPlayingInfo DEBUG] ElapsedPlaybackTime 설정: \\(firstActivePlayer.currentTime)")
        } else {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
            print("🔵 [NowPlayingInfo DEBUG] PlaybackDuration 및 ElapsedPlaybackTime을 0으로 설정 (활성 플레이어 없음 또는 재생 중 아님). isEffectivelyPlaying: \\(isEffectivelyPlaying)")
        }
        
        print("🔵 [NowPlayingInfo DEBUG] 최종 nowPlayingInfo 딕셔셔너리 (설정 전):")
        for (key, value) in nowPlayingInfo {
            print("  - Key: \\(key), Value: \\(value), Type: \\(type(of: value))")
        }

        DispatchQueue.main.async {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            
            // MPNowPlayingInfoCenter.default().nowPlayingInfo 값을 안전하게 문자열로 변환
            let currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
            let infoDescription: String
            if let unwrappedInfo = currentInfo {
                infoDescription = String(describing: unwrappedInfo)
            } else {
                infoDescription = "nil (정보 없음)"
            }
            // print 문 수정: 문자열 보간 대신 쉼표로 인자 구분
            print("✅ [NowPlayingInfo] 정보 설정 완료 (메인 스레드에서). 설정된 값:", infoDescription)
            
            // iOS 8+ 정보 사라짐 문제 해결 시도 (0.2초 후 재설정)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // 현재 상태를 다시 가져와서 설정 (nowPlayingInfo 변수는 클로저 캡처 시점의 값일 수 있음)
                var currentInfoToResend = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                // 만약 nil로 설정된 상태라면, 이전에 유효했던 값을 다시 보내는 것은 의미가 없으므로,
                // 또는 현재 재생 상태에 따라 다시 빌드해야 할 수도 있음.
                // 여기서는 간단히 현재 infoCenter의 값을 다시 설정 시도.
                // 또는, 이 시점에서 self.updateNowPlayingPlaybackStatus()를 다시 호출하는 것을 고려할 수도 있으나 무한 루프 위험.
                // 지금은 단순히 현재 설정된 값을 다시 설정하는 것으로 유지.
                // 만약 nil로 설정된 후라면, 이 재설정은 의미가 없을 수 있음.
                if !currentInfoToResend.isEmpty { // nil이 아닌 경우에만 재설정
                   MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfoToResend
                   // print 문 수정: 문자열 보간 대신 쉼표로 인자 구분, 딕셔너리는 String(describing:) 사용
                   print("🔵 [NowPlayingInfo DEBUG] 정보 재설정 (0.2초 후, 메인 스레드). 재설정 값:", String(describing: currentInfoToResend))
                } else {
                   print("🔵 [NowPlayingInfo DEBUG] 정보 재설정 건너뜀 (0.2초 후, 현재 infoCenter가 nil임).")
                }
            }
        }
    }

    /// 특정 카테고리가 현재 '실질적으로' 재생 중인지 (볼륨 > 0)
    func isPlaying(for categoryIndex: Int) -> Bool {
        guard categoryIndex >= 0, categoryIndex < players.count else { return false }
        return players[categoryIndex].isPlaying && players[categoryIndex].volume > 0
    }
}

