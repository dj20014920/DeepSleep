import AVFoundation
import Foundation
import MediaPlayer

/// 오디오 재생 모드
enum AudioPlaybackMode: Int, CaseIterable {
    case exclusive = 0  // 독점 재생 (다른 음악 정지, Now Playing 표시됨)
    case mixWithOthers = 1  // 다른 음악과 혼합 재생 (Now Playing 표시 안됨)

    var displayName: String {
        switch self {
        case .exclusive:
            return "집중 모드"
        case .mixWithOthers:
            return "혼합 모드"
        }
    }

    var description: String {
        switch self {
        case .exclusive:
            return "다른 음악을 정지하고 수면 사운드만 재생합니다.\n제어 센터와 잠금 화면에 표시됩니다."
        case .mixWithOthers:
            return "다른 음악과 함께 백그라운드로 재생합니다.\n음악을 들으면서 수면 사운드도 함께 들을 수 있습니다."
        }
    }
}

/// 🆕 사운드 카탈로그 데이터 모델
struct SoundCatalog: Codable {
    let id: String
    let baseName: String
    let categoryIndex: Int
    let versions: [SoundVersion]

    enum CodingKeys: String, CodingKey {
        case id
        case baseName = "base_name"
        case categoryIndex = "category_index"
        case versions
    }
}

struct SoundVersion: Codable {
    let version: String
    let fileName: String
    let displayName: String
    let emoji: String
    let description: String
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case version
        case fileName = "file_name"
        case displayName = "display_name"
        case emoji
        case description
        case isDefault = "is_default"
    }
}

/// 🆕 확장 가능한 사운드 매니저 - JSON 기반 동적 로딩
final class SoundManager {
    static let shared = SoundManager()

    // MARK: - 오디오 모드 설정
    private var currentAudioMode: AudioPlaybackMode = .exclusive
    private let audioModeKey = "AudioPlaybackMode"

    // MARK: - 🆕 동적 사운드 카탈로그
    private var soundCatalog: [SoundCatalog] = []
    private var selectedVersions: [Int] = []  // 각 카테고리별 선택된 버전 인덱스

    // MARK: - 🆕 레거시 호환성을 위한 SoundCategory 구조체
    struct SoundCategory {
        let emoji: String
        let name: String
        let files: [String]
        let defaultIndex: Int

        init(emoji: String, name: String, files: [String], defaultIndex: Int = 0) {
            self.emoji = emoji
            self.name = name
            self.files = files
            self.defaultIndex = min(defaultIndex, files.count - 1)
        }
    }

    // MARK: - AVAudioPlayer 관리
    var players: [AVAudioPlayer] = []
    private var isApplyingPreset = false
    var previewPlayer: AVAudioPlayer?
    private(set) var previewingCategoryIndex: Int?

    /// 현재 재생 중인지
    var isPlaying: Bool {
        return players.contains { $0.isPlaying }
    }

    // MARK: - Now Playing Info
    var currentPresetName: String?
    private var activePlayerCount: Int {
        return players.filter { $0.isPlaying && $0.volume > 0 }.count
    }

    // MARK: - Scene 상태 추적
    private var isSceneActive: Bool = true
    var isGloballyPaused: Bool = false

    private init() {
        loadSavedAudioMode()
        loadSoundCatalog()
        setupSelectedVersions()
        configureAudioSession()
        loadPlayers()
        setupRemoteTransportControls()
    }

    // MARK: - 🆕 사운드 카탈로그 로딩 (Deprecated JSON Path)
    private func loadSoundCatalog() {
        // ✅ 사유:
        // 기존 sound_catalog.json 기반 로딩은 SoundCatalogManager(동적/확장 관리)로 대체됨.
        // - 중복 경고(파일 없음) 스팸 제거
        // - 불필요한 파일 I/O 제거 (KISS / DRY)
        // - YAGNI: JSON 미사용 시 굳이 실패 로그 남기지 않음
        //
        // 정책:
        // 1) 현재 메모리 soundCatalog가 비어있으면 하드코딩 폴백만 1회 로드
        // 2) 향후 SoundCatalogManager와 직접 연동 시 여기서 manager를 통해 로드하도록 전환
        if soundCatalog.isEmpty {
            loadFallbackCatalog()
        }
        // 더 이상 JSON 존재 여부를 강제로 확인하거나 경고 로그를 남기지 않는다.
        return
    }

    /// 🆕 사운드 카탈로그 검증
    private func validateSoundCatalog() {
        for catalog in soundCatalog {
            for version in catalog.versions {
                guard Bundle.main.url(forResource: version.fileName, withExtension: nil) != nil
                else {
                    UnifiedLogger.shared.warning("음원 파일 누락: \(version.fileName)")
                    continue
                }
            }
        }
    }

    /// 🆕 폴백 카탈로그 (기존 하드코딩 방식)
    private func loadFallbackCatalog() {
        // 기존 하드코딩된 데이터를 SoundCatalog 형태로 변환
        let fallbackData = [
            ("cat", "고양이", "🐱", ["고양이.mp3"]),
            ("wind", "바람", "🌪", ["바람.mp3", "바람2.mp3"]),
            ("footsteps", "발걸음-눈", "👣", ["발걸음-눈.mp3", "발걸음-눈2.mp3"]),
            ("night", "밤", "🌙", ["밤.mp3", "밤2.mp3"]),
            ("fire", "불", "🔥", ["불1.mp3"]),
            ("rain", "비", "🌧", ["비.mp3", "비-창문.mp3"]),
            ("birds", "새", "🐦", ["새.mp3", "새-비.mp3"]),
            ("stream", "시냇물", "🏞", ["시냇물.mp3"]),
            ("pencil", "연필", "✏️", ["연필.mp3"]),
            ("space", "우주", "🌌", ["우주.mp3"]),
            ("fan", "쿨링팬", "❄️", ["쿨링팬.mp3"]),
            ("keyboard", "키보드", "⌨️", ["키보드1.mp3", "키보드2.mp3"]),
            ("waves", "파도", "🌊", ["파도.mp3", "파도2.mp3"]),
        ]

        soundCatalog = fallbackData.enumerated().map { index, data in
            let versions = data.3.enumerated().map { versionIndex, fileName in
                SoundVersion(
                    version: versionIndex == 0 ? "1.0" : "2.0",
                    fileName: fileName,
                    displayName: "\(data.2) \(data.1)"
                        + (versionIndex > 0 ? " v\(versionIndex + 1)" : ""),
                    emoji: data.2,
                    description: "\(data.1) 소리",
                    isDefault: versionIndex == (data.3.count > 1 ? 1 : 0)
                )
            }

            return SoundCatalog(
                id: data.0,
                baseName: data.1,
                categoryIndex: index,
                versions: versions
            )
        }

        // 폴백 사운드 카탈로그 로드 완료
    }

    // MARK: - 🆕 동적 카테고리 정보 접근

    /// 카테고리 개수 (동적)
    var categoryCount: Int {
        return soundCatalog.count
    }

    /// 🆕 특정 카테고리 정보 (JSON 기반)
    func getSoundCatalog(at index: Int) -> SoundCatalog? {
        guard index >= 0, index < soundCatalog.count else { return nil }
        return soundCatalog[index]
    }

    /// 🆕 레거시 호환성을 위한 SoundCategory 변환
    func getCategory(at index: Int) -> SoundCategory? {
        guard let catalog = getSoundCatalog(at: index) else { return nil }

        let files = catalog.versions.map { $0.fileName }
        let defaultIndex = catalog.versions.firstIndex { $0.isDefault } ?? 0

        return SoundCategory(
            emoji: catalog.versions.first?.emoji ?? "🎵",
            name: catalog.baseName,
            files: files,
            defaultIndex: defaultIndex
        )
    }

    // MARK: - 초기 설정
    private func setupSelectedVersions() {
        selectedVersions = (0..<soundCatalog.count).map { categoryIndex in
            let savedVersion = SettingsManager.shared.getSelectedVersion(for: categoryIndex)
            guard let catalog = getSoundCatalog(at: categoryIndex) else { return 0 }

            // 저장된 버전이 유효한지 확인
            if savedVersion < catalog.versions.count {
                return savedVersion
            } else {
                // 기본 버전 찾기
                let defaultIndex = catalog.versions.firstIndex { $0.isDefault } ?? 0
                SettingsManager.shared.updateSelectedVersion(for: categoryIndex, to: defaultIndex)
                return defaultIndex
            }
        }

        UnifiedLogger.shared.debug("저장된 버전 정보 복원 완료: \(selectedVersions)", category: .audio)
    }

    /// AVAudioSession 설정
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            let options: AVAudioSession.CategoryOptions
            switch currentAudioMode {
            case .exclusive:
                options = []
                UnifiedLogger.shared.debug("AudioSession: 독점 재생 모드 설정", category: .audio)
            case .mixWithOthers:
                options = [.mixWithOthers]
                UnifiedLogger.shared.debug("AudioSession: 혼합 재생 모드 설정", category: .audio)
            }

            try session.setCategory(.playback, mode: .default, options: options)
            try session.setActive(true)

            print("✅ [AudioSession] 오디오 세션 설정 완료")

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

    /// 🆕 동적 플레이어 로딩
    private func loadPlayers() {
        players.removeAll()

        for (categoryIndex, catalog) in soundCatalog.enumerated() {
            let versionIndex = selectedVersions[categoryIndex]
            guard versionIndex < catalog.versions.count else {
                print("⚠️ 유효하지 않은 버전 인덱스: \(versionIndex) for \(catalog.baseName)")
                continue
            }

            let version = catalog.versions[versionIndex]
            guard let url = Bundle.main.url(forResource: version.fileName, withExtension: nil)
            else {
                print("⚠️ 사운드 파일을 찾을 수 없습니다: \(version.fileName)")
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.numberOfLoops = -1
                player.volume = 0
                player.prepareToPlay()
                players.append(player)
            } catch {
                print("⚠️ AVAudioPlayer 생성 실패: \(error)")
            }
        }

        print("✅ \(players.count)개 사운드 로드 완료")
    }

    /// 카테고리의 이모지 + 이름
    func getCategoryDisplay(at index: Int) -> String {
        guard let catalog = getSoundCatalog(at: index) else { return "Unknown" }
        let currentVersion = getCurrentVersion(at: index)
        return "\(currentVersion.emoji) \(catalog.baseName)"
    }

    /// 현재 선택된 버전 정보
    func getCurrentVersion(at categoryIndex: Int) -> SoundVersion {
        guard let catalog = getSoundCatalog(at: categoryIndex) else {
            return SoundVersion(
                version: "1.0", fileName: "unknown.mp3", displayName: "Unknown", emoji: "❓",
                description: "Unknown sound", isDefault: true)
        }
        let versionIndex = selectedVersions[categoryIndex]
        guard versionIndex < catalog.versions.count else {
            return catalog.versions.first
                ?? SoundVersion(
                    version: "1.0", fileName: "unknown.mp3", displayName: "Unknown", emoji: "❓",
                    description: "Unknown sound", isDefault: true)
        }
        return catalog.versions[versionIndex]
    }

    /// 현재 선택된 버전 정보 (문자열)
    func getCurrentVersionInfo(at categoryIndex: Int) -> String? {
        guard let catalog = getSoundCatalog(at: categoryIndex) else { return nil }
        let versionIndex = selectedVersions[categoryIndex]

        if catalog.versions.count > 1 {
            let version = getCurrentVersion(at: categoryIndex)
            return "\(version.fileName) (\(versionIndex + 1)/\(catalog.versions.count))"
        } else {
            return getCurrentVersion(at: categoryIndex).fileName
        }
    }

    // MARK: - 🆕 오디오 모드 관리

    /// 오디오 재생 모드 변경
    public func setAudioPlaybackMode(_ mode: AudioPlaybackMode) {
        if currentAudioMode != mode {
            currentAudioMode = mode
            saveAudioMode()
            print("🔄 [AudioSession] 오디오 모드 변경: \(mode.displayName)")
            configureAudioSession()

            if activePlayerCount > 0 {
                updateNowPlayingPlaybackStatus()
            }
        }
    }

    /// 현재 오디오 모드 조회
    public var audioPlaybackMode: AudioPlaybackMode {
        return currentAudioMode
    }

    // MARK: - 심리 음향학 기반 프리셋 적용

    /// 심리 음향학 전문가 추천을 바탕으로 프리셋 적용
    func applyExpertPreset(recommendation: [String: Any]) {
        guard let sounds = recommendation["sounds"] as? [String: Int] else {
            print("⚠️ 잘못된 추천 데이터 형식")
            return
        }

        // 모든 사운드를 먼저 0으로 설정
        resetAllVolumes()

        // 추천된 사운드들을 해당 볼륨으로 설정
        for (soundName, volume) in sounds {
            if let categoryIndex = findCategoryIndex(for: soundName) {
                setVolume(for: categoryIndex, volume: Float(volume))
                print("🎵 [\(soundName)] 볼륨 설정: \(volume)")
            } else {
                print("⚠️ 사운드를 찾을 수 없음: \(soundName)")
            }
        }

        // 프리셋 이름 설정 (Now Playing용)
        if let category = recommendation["category"] as? String {
            currentPresetName = "\(category) 전문가 추천"
        }

        // 호환성 체크 결과 출력
        if let compatibility = recommendation["compatibility"] as? [String: Any],
            let score = compatibility["score"] as? Int
        {
            print("🔍 프리셋 호환성 점수: \(score)/100")

            if let warnings = compatibility["warnings"] as? [String], !warnings.isEmpty {
                for warning in warnings {
                    print("⚠️ \(warning)")
                }
            }
        }

        print("✅ 전문가 추천 프리셋 적용 완료")
    }

    /// 🆕 사운드 이름으로 카테고리 인덱스 찾기 (동적)
    private func findCategoryIndex(for soundName: String) -> Int? {
        return soundCatalog.firstIndex { catalog in
            // 기본 이름으로 먼저 비교
            if catalog.baseName == soundName {
                return true
            }

            // 파일명에서 확장자를 제거한 이름과 비교
            return catalog.versions.contains { version in
                let fileName = version.fileName.replacingOccurrences(of: ".mp3", with: "")
                return fileName == soundName
            }
        }
    }

    /// 모든 볼륨을 0으로 리셋
    private func resetAllVolumes() {
        for i in 0..<players.count {
            setVolume(for: i, volume: 0)
        }
    }

    // MARK: - 감정 기반 즉석 추천

    /// 현재 감정 상태에 맞는 즉석 추천 생성 및 적용
    func applyEmotionalPreset(emotion: String, completion: @escaping (String) -> Void) {
        // 하이브리드 추천 생성 (온디바이스 + 외부 AI)
        generateHybridRecommendation(
            emotion: emotion, situation: "", existingPresets: [],
            completion: { [weak self] preset in
                DispatchQueue.main.async {
                    if let preset = preset {
                        self?.applyExpertPreset(recommendation: [
                            "volumes": preset.volumes, "category": preset.name,
                        ])
                    }
                    completion("")
                }
            })
    }

    // MARK: - 전문가 프리셋 카탈로그 접근

    /// 미리 정의된 전문가 프리셋 목록 가져오기
    func getExpertPresetCategories() -> [String] {
        return Array(SoundPresetCatalog.expertPresets.keys).sorted()
    }

    /// 특정 전문가 프리셋 적용
    func applyNamedExpertPreset(_ presetName: String) {
        guard let preset = SoundPresetCatalog.expertPresets[presetName] else {
            print("⚠️ 프리셋을 찾을 수 없음: \(presetName)")
            return
        }

        applyExpertPreset(recommendation: preset)
        print("🎨 전문가 프리셋 '\(presetName)' 적용됨")
    }

    // MARK: - 상황별 자동 추천

    /// 시간대와 날씨에 맞는 자동 추천
    func getContextualRecommendation() -> [String: Any] {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = getTimeOfDay(from: currentHour)

        // 기본 감정을 시간대에 맞게 설정
        let baseEmotion = getDefaultEmotionForTime(timeOfDay: timeOfDay)

        if let preset = generateLocalPresetRecommendation(
            emotion: baseEmotion, situation: timeOfDay)
        {
            return ["volumes": preset.volumes, "category": preset.name]
        } else {
            return ["volumes": Array(repeating: 0.3, count: 13), "category": "기본"]
        }
    }

    private func getTimeOfDay(from hour: Int) -> String {
        switch hour {
        case 5..<7: return "새벽"
        case 7..<10: return "아침"
        case 10..<12: return "오전"
        case 12..<14: return "점심"
        case 14..<18: return "오후"
        case 18..<21: return "저녁"
        case 21..<24: return "밤"
        default: return "자정"
        }
    }

    private func getDefaultEmotionForTime(timeOfDay: String) -> String {
        switch timeOfDay {
        case "새벽", "자정": return "불면"
        case "아침": return "활력"
        case "오전", "점심": return "집중"
        case "오후": return "집중"
        case "저녁": return "피로"
        case "밤": return "평온"
        default: return "평온"
        }
    }

    // MARK: - 버전 선택 관리

    /// 🆕 특정 카테고리의 버전 변경 (동적)
    func selectVersion(categoryIndex: Int, versionIndex: Int) {
        guard let catalog = getSoundCatalog(at: categoryIndex) else { return }
        guard versionIndex >= 0, versionIndex < catalog.versions.count else { return }

        let wasPlaying = isPlaying(at: categoryIndex)
        let currentVolume = players.count > categoryIndex ? players[categoryIndex].volume : 0

        // 기존 플레이어 정지
        if categoryIndex < players.count {
            players[categoryIndex].stop()
        }

        // 버전 변경
        selectedVersions[categoryIndex] = versionIndex
        SettingsManager.shared.updateSelectedVersion(for: categoryIndex, to: versionIndex)

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

    /// 🆕 다음 버전으로 변경 (동적)
    func selectNextVersion(categoryIndex: Int) {
        guard let catalog = getSoundCatalog(at: categoryIndex) else { return }
        let currentVersion = selectedVersions[categoryIndex]
        let nextVersion = (currentVersion + 1) % catalog.versions.count
        selectVersion(categoryIndex: categoryIndex, versionIndex: nextVersion)
    }

    /// 🆕 특정 카테고리의 플레이어만 다시 로드 (동적)
    private func reloadPlayer(at categoryIndex: Int) {
        guard let catalog = getSoundCatalog(at: categoryIndex) else { return }

        let versionIndex = selectedVersions[categoryIndex]
        guard versionIndex < catalog.versions.count else { return }
        let version = catalog.versions[versionIndex]
        let fileName = version.fileName

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

    /// 🆕 특정 버전 미리듣기 (동적)
    func previewVersion(categoryIndex: Int, versionIndex: Int, fromTime: TimeInterval = 0) {
        guard let catalog = getSoundCatalog(at: categoryIndex) else {
            print("⚠️ 미리듣기 오류: 유효하지 않은 카테고리 인덱스 \(categoryIndex)")
            return
        }
        guard versionIndex >= 0, versionIndex < catalog.versions.count else {
            print("⚠️ 미리듣기 오류: 카테고리 \(catalog.baseName)에 유효하지 않은 버전 인덱스 \(versionIndex)")
            return
        }

        let version = catalog.versions[versionIndex]
        let fileName = version.fileName
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
            previewPlayer?.numberOfLoops = -1  // 무한 반복 설정
            previewPlayer?.volume = 0.6  // 미리듣기 볼륨
            previewPlayer?.currentTime = fromTime  // 재생 시작 시간 설정
            previewPlayer?.prepareToPlay()
            previewPlayer?.play()
            previewingCategoryIndex = categoryIndex  // 현재 미리듣기 중인 카테고리 인덱스 저장

            print("🔊 미리듣기 시작 (무한 반복): \(fileName) at \(fromTime)s")
        } catch {
            print("⚠️ 미리듣기 플레이어 생성 실패: \(error.localizedDescription) - 파일: \(fileName)")
            previewPlayer = nil  // 실패 시 nil로 확실히 설정
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

    /// 모든 트랙 일괄 재생 (볼륨이 0 이상인 것만) - 피드백 시스템 통합
    func playAll(presetName: String? = nil, contextEmotion: String? = nil) {
        print("🔊 SoundManager: playAll() 호출됨")
        print("  - 총 플레이어 수: \(players.count)")

        // 🆕 전체 멈춤 플래그 해제
        isGloballyPaused = false

        // 🆕 사용자가 명시적으로 재생한 것으로 기록 (수동 멈춤 해제)
        UserDefaults.standard.set(false, forKey: "wasManuallyPaused")

        print("  - isGloballyPaused = false로 설정, 수동 멈춤 해제됨")

        var playedSomething = false
        var currentVolumes: [Float] = []

        for (index, player) in players.enumerated() {
            let volumePercent = player.volume * 100.0
            currentVolumes.append(volumePercent)

            print("  - 플레이어 \(index): volume=\(player.volume), isPlaying=\(player.isPlaying)")

            if player.volume > 0 && !player.isPlaying {
                player.play()
                playedSomething = true
                print("    ✅ 플레이어 \(index) 재생 시작됨")
            } else if player.volume > 0 && player.isPlaying {
                print("    ℹ️ 플레이어 \(index) 이미 재생 중")
            } else if player.volume == 0 {
                print("    ⏭️ 플레이어 \(index) 볼륨 0으로 건너뜀")
            }
        }

        print("  - playedSomething: \(playedSomething)")
        print("  - activePlayerCount (after): \(activePlayerCount)")

        // Phase 2: 피드백 세션 시작 (AI 추천이 적용된 경우)
        if let preset = presetName, let emotion = contextEmotion, playedSomething {
            startFeedbackSession(
                presetName: preset,
                volumes: currentVolumes,
                versions: selectedVersions,
                emotion: emotion
            )
        }

        if playedSomething {
            updateNowPlayingPlaybackStatus()  // 전체 재생 상태 업데이트
            print("  - NowPlayingInfo 업데이트 완료")
        }
    }

    // MARK: - Phase 2: 피드백 시스템 통합

    /// 피드백 세션 시작 (SessionManager 통합)
    private func startFeedbackSession(
        presetName: String, volumes: [Float], versions: [Int], emotion: String
    ) {
        Task { @MainActor in
            let recommendation = EnhancedRecommendationResponse(
                presetName: presetName,
                volumes: volumes,
                versions: versions,
                reason: "SessionManager 통합 피드백 세션"
            )

            SessionManager.shared.startSession(
                presetName: presetName,
                recommendation: recommendation,
                contextEmotion: emotion
            )

            print("🎯 [SessionManager] 피드백 세션 시작: \(presetName)")
        }
    }

    /// 현재 세션 볼륨 업데이트 (SessionManager 통합)
    private func updateCurrentSessionVolumes() {
        let currentVolumes = players.map { $0.volume * 100.0 }

        Task { @MainActor in
            SessionManager.shared.updateCurrentSessionVolumes(currentVolumes)
        }
    }

    /// 피드백 세션 종료 (SessionManager 통합)
    private func endCurrentFeedbackSession(
        finalVolumes: [Float], wasSaved: Bool, satisfaction: Int = 0
    ) {
        Task { @MainActor in
            let duration = SessionManager.shared.currentSessionDuration

            SessionManager.shared.endCurrentSession(
                finalVolumes: finalVolumes,
                listeningDuration: duration,
                wasSaved: wasSaved,
                satisfaction: satisfaction
            )

            print("🏁 [SessionManager] 피드백 세션 종료: 청취시간 \(String(format: "%.1f", duration))초")

            // 🎯 자연스러운 피드백 요청 (조건부)
            checkAndRequestFeedback(duration: duration, wasSaved: wasSaved)
        }
    }

    /// 🎯 피드백 요청 조건 체크 및 실행
    private func checkAndRequestFeedback(duration: TimeInterval, wasSaved: Bool) {
        // 조건 1: 30초 이상 청취했고 저장하지 않은 경우 (자연스러운 경험 후)
        // 조건 2: 2분 이상 청취한 경우 (충분한 경험)
        // 조건 3: 랜덤하게 10% 확률 (강제성 방지)

        let shouldRequestFeedback =
            (duration >= 30.0 && !wasSaved && duration < 120.0) || (duration >= 120.0)
            || (duration >= 30.0 && Double.random(in: 0...1) < 0.1)

        if shouldRequestFeedback {
            // 현재 세션의 프리셋 이름과 추천 타입 가져오기
            Task { @MainActor in
                self.requestUserFeedback()
            }
        }
    }

    /// 🎯 사용자 피드백 요청 UI 표시
    @MainActor private func requestUserFeedback() {
        // 현재 메인 뷰컨트롤러 찾기
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }),
            let rootViewController = keyWindow.rootViewController
        else {
            print("⚠️ [FeedbackRequest] 메인 뷰컨트롤러를 찾을 수 없음")
            return
        }

        // 현재 프리셋 이름 (기본값)
        let currentPresetName = getCurrentPresetName() ?? "현재 프리셋"

        // 추천 타입 결정 (최근 추천 기록 기반)
        let recommendationType = determineRecommendationType()

        // 피드백 UI 표시
        FeedbackPromptViewController.present(
            from: rootViewController,
            presetName: currentPresetName,
            recommendationType: recommendationType
        ) { satisfaction in
            // 피드백 받은 후 처리
            self.setUserSatisfaction(satisfaction)
            print("✅ [FeedbackRequest] 사용자 피드백 수신: \(satisfaction)")
        }
    }

    /// 현재 프리셋 이름 가져오기 (SessionManager 통합)
    @MainActor private func getCurrentPresetName() -> String? {
        return SessionManager.shared.getCurrentSessionPresetName()
    }

    /// 추천 타입 결정 (SessionManager 통합)
    @MainActor private func determineRecommendationType()
        -> FeedbackPromptViewController.RecommendationType
    {
        let recentFeedback = SessionManager.shared.getRecentFeedback(
            limit: AppConfig.Pagination.recentFeedbackForRecommendationLimit)

        // PresetFeedback에 recommendationSource가 없으므로 기본값 사용
        // 추후 모델 업데이트 시 개선 예정
        if recentFeedback.count > 3 {
            return .comprehensive
        } else if recentFeedback.count > 1 {
            return .ai
        } else {
            return .local
        }
    }

    /// 사용자가 프리셋을 저장할 때 호출 (만족도 높음으로 기록)
    func onPresetSaved() {
        let currentVolumes = players.map { $0.volume * 100.0 }
        endCurrentFeedbackSession(
            finalVolumes: currentVolumes,
            wasSaved: true,
            satisfaction: 2  // 좋아요
        )
    }

    /// 사용자가 명시적으로 만족도를 표시할 때 호출
    func setUserSatisfaction(_ satisfaction: Int) {
        #if canImport(FeedbackManager)
            if #available(iOS 17.0, *) {
                Task { @MainActor in
                    FeedbackManager.shared.setExplicitFeedback(satisfaction: satisfaction)
                }
            }
        #endif
    }

    /// 모든 트랙 일괄 일시정지 (피드백 세션 종료)
    func pauseAll() {
        var pausedSomething = false
        var currentVolumes: [Float] = []

        // 🆕 전체 멈춤 플래그 설정
        isGloballyPaused = true

        // 🆕 사용자가 명시적으로 멈춘 것으로 기록
        UserDefaults.standard.set(true, forKey: "wasManuallyPaused")

        for player in players {
            currentVolumes.append(player.volume * 100.0)
            if player.isPlaying {
                player.pause()
                pausedSomething = true
            }
        }

        print("🔇 SoundManager: pauseAll() 호출됨 - isGloballyPaused = true, 수동 조작 기록됨")

        // Phase 2: 피드백 세션 종료
        if pausedSomething {
            endCurrentFeedbackSession(
                finalVolumes: currentVolumes,
                wasSaved: false,
                satisfaction: 0
            )
            updateNowPlayingPlaybackStatus()  // 전체 정지 상태 업데이트
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
        if player.volume > 0 {
            if !player.isPlaying {
                player.play()
                print("사운드 \(index) 재생 시작")
                updateNowPlayingPlaybackStatus()  // NowPlayingInfo 업데이트
            } else {
                print("사운드 \(index) 이미 재생 중 (볼륨: \(player.volume))")
            }
        } else {
            print("사운드 \(index) 볼륨이 0이라 재생하지 않음")
        }
    }

    func pause(at index: Int) {
        guard index >= 0, index < players.count else { return }
        let player = players[index]
        if player.isPlaying {
            player.pause()
            print("사운드 \(index) 일시정지")
            updateNowPlayingPlaybackStatus()  // NowPlayingInfo 업데이트
        }
    }

    func isPlaying(at index: Int) -> Bool {
        guard index >= 0, index < players.count else { return false }
        return players[index].isPlaying
    }

    // MARK: - 볼륨 제어 (기존 API 유지)

    /// 슬라이더나 프리셋에서 설정한 볼륨을 반영합니다. volume 은 0~100 사이. (피드백 실시간 업데이트)
    func setVolume(at index: Int, volume: Float, forUIUpdate: Bool = false) {
        guard index >= 0, index < players.count else { return }

        // 🆕 이전 볼륨 저장 (추적용)
        let oldVolume = players[index].volume * 100.0

        let normalizedVolume = volume / 100.0
        players[index].volume = normalizedVolume

        print(
            "🔊 SoundManager.setVolume(at: \(index), volume: \(volume)) → 정규화된 볼륨: \(normalizedVolume), UI업데이트: \(forUIUpdate), 전체멈춤: \(isGloballyPaused)"
        )

        // 🆕 UI 업데이트 목적이거나 전체 멈춤 상태면 재생하지 않음
        if !forUIUpdate && !isGloballyPaused {
            // 재생 상태 제어
            if normalizedVolume > 0 && !players[index].isPlaying {
                players[index].play()
                print("▶️ 카테고리 \(index) 재생 시작")
            } else if normalizedVolume == 0 && players[index].isPlaying {
                players[index].pause()
                print("⏸️ 카테고리 \(index) 일시정지")
            }

            // 🔄 기존 시스템 활용: 실시간 볼륨 변경 피드백 (이미 모든 추적 포함)
            updateCurrentSessionVolumes()
        } else {
            print("🔇 재생 건너뜀 (UI업데이트: \(forUIUpdate), 전체멈춤: \(isGloballyPaused))")
        }
    }

    /// 배열 단위로 한 번에 설정
    func setVolumes(_ volumes: [Float]) {
        for (i, v) in volumes.enumerated() {
            setVolume(at: i, volume: v)
        }
        print("볼륨 설정 완료: \(volumes)")
    }

    /// 프리셋 적용 (볼륨 설정 + 재생 시작)
    func applyPreset(presetId: String, volumes: [Float], completion: @escaping (Bool) -> Void) {
        guard let preset = SettingsManager.shared.getSoundPresetByStringId(presetId) else {
            completion(false)
            return
        }

        // 프리셋의 볼륨 값을 적용
        for (index, volume) in volumes.enumerated() {
            if index < players.count {
                players[index].volume = volume
            }
        }

        // 프리셋 이름 업데이트
        currentPresetName = preset.name

        // Now Playing 정보 업데이트
        updateNowPlayingInfo(presetName: currentPresetName)

        completion(true)
    }

    func applySounds(soundIds: [String], volumes: [Float], completion: @escaping (Bool) -> Void) {
        // 모든 플레이어의 볼륨을 0으로 설정
        for player in players {
            player.volume = 0
        }

        // 지정된 사운드의 볼륨 설정
        for (index, soundId) in soundIds.enumerated() {
            if let catalogIndex = soundCatalog.firstIndex(where: { $0.id == soundId }),
                catalogIndex < players.count,
                index < volumes.count
            {
                players[catalogIndex].volume = volumes[index]
            }
        }

        // Now Playing 정보 업데이트
        updateNowPlayingInfo(presetName: currentPresetName)

        completion(true)
    }

    // MARK: - 확장된 프리셋 적용 (버전 정보 포함)

    /// 버전 정보를 포함한 프리셋 적용
    func applyPresetWithVersions(volumes: [Float], versions: [Int]? = nil) {
        // 1. 버전 정보가 있으면 먼저 적용
        if let versions = versions {
            for (categoryIndex, versionIndex) in versions.enumerated() {
                if categoryIndex < soundCatalog.count {
                    selectVersion(categoryIndex: categoryIndex, versionIndex: versionIndex)
                }
            }
        }

        // 2. 볼륨 적용
        setVolumes(volumes)
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

    /// 🆕 카테고리명으로 인덱스 찾기 (동적, 레거시 호환성)
    func getSoundIndex(for soundName: String) -> Int? {
        // 1. 직접 매핑 (기본 이름)
        if let index = soundCatalog.firstIndex(where: { $0.baseName == soundName }) {
            return index
        }

        // 2. ID 기반 매핑
        if let index = soundCatalog.firstIndex(where: { $0.id == soundName.lowercased() }) {
            return index
        }

        // 3. 레거시 매핑 (기존 호환성)
        let legacyMapping: [String: String] = [
            "Rain": "rain",
            "Thunder": "rain",  // 천둥 소리가 없으므로 비로 매핑
            "Ocean": "waves",
            "Fire": "fire",
            "Steam": "stream",
            "WindowRain": "rain",
            "Forest": "cat",  // 자연 소리로 매핑
            "Wind": "wind",
            "Night": "night",
            "Lullaby": "space",  // 잔잔한 소리
            "Fan": "fan",
            "WhiteNoise": "keyboard",  // 화이트노이즈 대체
        ]

        if let mappedId = legacyMapping[soundName],
            let index = soundCatalog.firstIndex(where: { $0.id == mappedId })
        {
            return index
        }

        return nil
    }

    /// 🆕 동적 표준 사운드 이름들
    var standardSoundNames: [String] {
        return soundCatalog.map { $0.baseName }
    }

    // MARK: - 인터럽션 처리 (기존 유지)

    @objc private func handleInterruption(_ notif: Notification) {
        guard let info = notif.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            pauseAll()
            stopPreview()
            print("오디오 인터럽션 시작 - 일시정지")
        case .ended:
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
                AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
            {
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
    /// 🆕 ChatViewController+Actions.swift와의 호환성을 위해 파라미터 이름을 index로 통일
    /// 🔧 볼륨 정규화 수정: 0-100 범위를 0.0-1.0으로 정규화
    func setVolume(for index: Int, volume: Float) {
        guard index >= 0, index < players.count else { return }

        // 🔧 0-100 범위 값을 0.0-1.0으로 정규화
        let normalizedVolume = volume / 100.0
        let newVolume = max(0, min(1, normalizedVolume))  // 0.0 ~ 1.0
        players[index].volume = newVolume

        if newVolume > 0 && !players[index].isPlaying {
            players[index].play()
            print("▶️ SoundManager: 카테고리 \(index) 재생 시작 (원본: \(volume) → 정규화: \(newVolume))")
        } else if newVolume == 0 && players[index].isPlaying {
            players[index].pause()
            print("⏸️ SoundManager: 카테고리 \(index) 일시정지 (볼륨 0)")
        }
        updateNowPlayingPlaybackStatus()  // 재생 상태 변경 시 항상 호출
        print("🔊 SoundManager: 카테고리 \(index) 볼륨 설정 → 원본: \(volume) → 정규화: \(newVolume)")
    }

    /// 모든 플레이어를 정지시키고 NowPlayingInfo를 업데이트합니다.
    func stopAllPlayers() {
        for player in players {
            player.stop()
            player.currentTime = 0  // 필요시 처음으로 되감기
        }
        currentPresetName = nil  // 프리셋 이름 초기화
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
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }

            if let firstActivePlayer = self.players.first(where: { $0.isPlaying && $0.volume > 0 })
            {
                firstActivePlayer.currentTime = event.positionTime
                self.updateNowPlayingPlaybackStatus()  // 시간 변경 후 즉시 NowPlayingInfo 업데이트
            }
            return .success
        }

        // 사용하지 않는 명령 비활성화
        commandCenter.stopCommand.isEnabled = false  // 또는 필요시 구현
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
    public func updateNowPlayingInfo(presetName: String?, isPlayingOverride: Bool? = nil) {
        self.currentPresetName = presetName  // 외부에서 설정한 프리셋 이름 저장
        updateNowPlayingPlaybackStatus(isPlayingOverride: isPlayingOverride)
    }

    /// 내부 재생 상태 변화에 따라 NowPlayingInfo 업데이트
    private func updateNowPlayingPlaybackStatus(isPlayingOverride: Bool? = nil) {
        print(
            "🔵 [NowPlayingInfo DEBUG] updateNowPlayingPlaybackStatus 시작. isPlayingOverride: \(String(describing: isPlayingOverride)), currentPresetName: \(currentPresetName ?? "nil")"
        )

        var nowPlayingInfo = [String: Any]()
        let actuallyPlaying = activePlayerCount > 0
        let isEffectivelyPlaying = isPlayingOverride ?? actuallyPlaying

        print(
            "🔵 [NowPlayingInfo DEBUG] actuallyPlaying: \(actuallyPlaying), isEffectivelyPlaying: \(isEffectivelyPlaying), activePlayerCount: \(activePlayerCount)"
        )

        if let presetName = self.currentPresetName, !presetName.isEmpty {
            nowPlayingInfo[MPMediaItemPropertyTitle] = presetName
            print("🔵 [NowPlayingInfo DEBUG] Title 설정: \(presetName)")
        } else if isEffectivelyPlaying {  // 재생 중일 때만 기본 제목 설정
            nowPlayingInfo[MPMediaItemPropertyTitle] = "리플릿 사운드"  // 앱 이름 한국어 표기
            print("🔵 [NowPlayingInfo DEBUG] Title 기본값 설정: 리플릿 사운드")
        } else {
            // 재생 중이 아니고 프리셋 이름도 없으면 정보센터 클리어
            DispatchQueue.main.async {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
                print(
                    "🔵 [NowPlayingInfo DEBUG] nowPlayingInfo를 nil로 설정 (메인 스레드). 조건: !isEffectivelyPlaying AND currentPresetName is empty or nil."
                )
            }
            // iOS 8+ 정보 사라짐 문제 해결 시도 부분도 여기서는 실행될 필요 없음
            return
        }

        nowPlayingInfo[MPMediaItemPropertyArtist] = "리플릿"  // 아티스트 표기 한글
        print("🔵 [NowPlayingInfo DEBUG] Artist 설정: 리플릿")

        // 앨범 아트
        let _ = false
        if let image = UIImage(named: "NowPlayingArtwork") {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            // artworkSet = true
            print("🖼️ [NowPlayingInfo DEBUG] NowPlayingArtwork 로드 성공. Artwork 객체: \(artwork)")
        } else {
            print("🔴 [NowPlayingInfo DEBUG] NowPlayingArtwork 로드 실패.")
        }

        // 재생 상태 및 시간
        let playbackRate = isEffectivelyPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        print("🔵 [NowPlayingInfo DEBUG] PlaybackRate 설정: \(playbackRate)")

        if isEffectivelyPlaying,
            let firstActivePlayer = players.first(where: { $0.isPlaying && $0.volume > 0 })
        {
            print(
                "🔵 [NowPlayingInfo DEBUG] firstActivePlayer 정보: duration=\(firstActivePlayer.duration), currentTime=\(firstActivePlayer.currentTime), isPlaying=\(firstActivePlayer.isPlaying), volume=\(firstActivePlayer.volume)"
            )
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = firstActivePlayer.duration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
                firstActivePlayer.currentTime
            print("🔵 [NowPlayingInfo DEBUG] PlaybackDuration 설정: \(firstActivePlayer.duration)")
            print(
                "🔵 [NowPlayingInfo DEBUG] ElapsedPlaybackTime 설정: \(firstActivePlayer.currentTime)")
        } else {
            // 재생 중이 아니거나 활성 플레이어가 없으면 재생 시간 관련 정보를 0 또는 nil로 설정
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 0
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
            print(
                "🔵 [NowPlayingInfo DEBUG] PlaybackDuration 및 ElapsedPlaybackTime을 0으로 설정 (활성 플레이어 없음 또는 재생 중 아님). isEffectivelyPlaying: \(isEffectivelyPlaying)"
            )
        }

        print("🔵 [NowPlayingInfo DEBUG] 최종 nowPlayingInfo 딕셔셔너리 (설정 전):")
        for (key, value) in nowPlayingInfo {
            // value를 String(describing:)으로 감싸서 모든 타입을 안전하게 출력
            print("  - Key: \(key), Value: \(String(describing: value)), Type: \(type(of: value))")
        }

        // 오디오 세션 상태 확인
        let session = AVAudioSession.sharedInstance()
        print("🔵 [NowPlayingInfo DEBUG] 설정 직전 오디오 세션 상태:")
        print("  - Category: \(session.category)")
        print("  - 실제 재생 중인 플레이어 수: \(players.filter { $0.isPlaying }.count)")
        print("  - 볼륨 > 0인 플레이어 수: \(players.filter { $0.volume > 0 }.count)")

        // 실제로 재생 중인 플레이어가 없으면 NowPlayingInfo 설정하지 않음
        let actualPlayingPlayers = players.filter { $0.isPlaying && $0.volume > 0 }
        if actualPlayingPlayers.isEmpty && isEffectivelyPlaying {
            print(
                "⚠️ [NowPlayingInfo DEBUG] 실제 재생 중인 플레이어가 없음에도 isEffectivelyPlaying=true. NowPlayingInfo 설정 취소"
            )
            return
        }

        // 오디오 세션 재활성화 시도
        do {
            try session.setActive(true)
            print("🔵 [NowPlayingInfo DEBUG] 오디오 세션 활성화 확인 완료")
        } catch {
            print("🔴 [NowPlayingInfo DEBUG] 오디오 세션 활성화 실패: \(error)")
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
            // print 문 수정: 문자열 보간 대신 쉼표로 인자 구분 (컴파일 오류 방지)
            print("✅ [NowPlayingInfo] 정보 설정 완료 (메인 스레드에서). 설정된 값:", infoDescription)

            // iOS 8+ 정보 사라짐 문제 해결 시도 (0.2초 후 재설정)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // 현재 상태를 다시 가져와서 설정 (nowPlayingInfo 변수는 클로저 캡처 시점의 값일 수 있음)
                let currentInfoToResend = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                if !currentInfoToResend.isEmpty {  // nil이 아닌 경우에만 재설정
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfoToResend
                    // print 문 수정: 문자열 보간 대신 쉼표로 인자 구분, 딕셔너리는 String(describing:) 사용 (컴파일 오류 방지)
                    print(
                        "🔵 [NowPlayingInfo DEBUG] 정보 재설정 (0.2초 후, 메인 스레드). 재설정 값:",
                        String(describing: currentInfoToResend))
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

    // MARK: - 설정 저장/불러오기

    /// 저장된 오디오 모드 불러오기
    private func loadSavedAudioMode() {
        let savedModeRawValue = UserDefaults.standard.integer(forKey: audioModeKey)
        if let savedMode = AudioPlaybackMode(rawValue: savedModeRawValue) {
            currentAudioMode = savedMode
            print("📱 [Settings] 저장된 오디오 모드 불러옴: \(savedMode.displayName)")
        } else {
            // 기본값 사용 및 저장
            currentAudioMode = .exclusive
            saveAudioMode()
            print("📱 [Settings] 기본 오디오 모드 설정: \(currentAudioMode.displayName)")
        }
    }

    /// 현재 오디오 모드 저장
    private func saveAudioMode() {
        UserDefaults.standard.set(currentAudioMode.rawValue, forKey: audioModeKey)
        UserDefaults.standard.synchronize()
        print("💾 [Settings] 오디오 모드 저장됨: \(currentAudioMode.displayName)")
    }

    // 🆕 현재 볼륨 값 가져오기 (0.0 ~ 1.0 범위)
    func getVolume(for index: Int) -> Float {
        guard index >= 0, index < players.count else { return 0.0 }
        return players[index].volume
    }

    /// 🆕 Scene 상태 변경 감지 메서드 (AppDelegate에서 호출)
    func handleSceneStateChange(isActive: Bool) {
        print("🔄 [SoundManager] Scene 상태 변경: \(isActive ? "활성" : "비활성")")
        isSceneActive = isActive

        if !isActive {
            // Scene이 비활성화 시에도 백그라운드 재생 유지
            // 자동 일시정지 비활성화되어 백그라운드에서 계속 재생됩니다.
            print("🔇 [SoundManager] Scene 비활성화 시에도 백그라운드 재생 유지")
        }
    }

    /// 🆕 Scene 복귀 시 상태 복원 메서드
    func restorePlaybackStateIfNeeded() {
        guard isSceneActive else { return }

        // 사용자가 명시적으로 멈췄는지 확인 (UserDefaults 활용)
        let wasManuallyPaused = UserDefaults.standard.bool(forKey: "wasManuallyPaused")

        if !wasManuallyPaused {
            // 자동 멈춤이었다면 재생 복원
            isGloballyPaused = false
            print("✅ [SoundManager] Scene 복귀로 인한 재생 상태 복원")
        } else {
            print("⏸️ [SoundManager] 사용자가 명시적으로 멈춰서 복원하지 않음")
        }
    }

    // MARK: - 🧠 AI 추천 시스템 (리팩토링 완료)

    /// 하이브리드 추천 생성 (ChatManager 통합 완료)
    func generateHybridRecommendation(
        emotion: String, situation: String, existingPresets: [SoundPreset],
        completion: @escaping (SoundPreset?) -> Void
    ) {

        let contextPrompt = """
            사용자의 현재 감정은 '\(emotion)'이고, 상황은 '\(situation)'입니다.
            기존에 사용자가 가지고 있는 프리셋 목록은 다음과 같습니다:
            \(existingPresets.map { "- \($0.name)" }.joined(separator: "\n"))

            이 모든 정보를 종합하여, 사용자에게 가장 필요할 것 같은 새로운 사운드 조합을 추천해주세요.

            응답 형식 (JSON):
            {
                "name": "추천 프리셋 이름",
                "description": "프리셋 설명",
                "emotion": "감정 상태",
                "volumes": {
                    "비": 0.6,
                    "백색소음": 0.4,
                    "새소리": 0.2
                }
            }
            """

        Task {
            do {
                // 🤖 SessionManager.sendMessage로 프리셋 추천 호출 (저장 안 함)
                let response = try await SessionManager.shared.sendMessage(
                    content: contextPrompt,
                    model: .gemini,
                    mode: .presetRecommendation,
                    saveMessages: false
                )

                // JSON 파싱하여 SoundPreset 객체 생성
                let preset = try parsePresetFromJSON(response, emotion: emotion)

                await MainActor.run {
                    completion(preset)
                }

            } catch {
                print("❌ [SoundManager] 하이브리드 추천 생성 실패: \(error)")

                await MainActor.run {
                    // AI 실패 시 로컬 추천으로 폴백
                    let fallbackPreset = generateLocalPresetRecommendation(
                        emotion: emotion, situation: situation)
                    completion(fallbackPreset)
                }
            }
        }
    }

    /// AI JSON 응답을 SoundPreset 객체로 파싱
    private func parsePresetFromJSON(_ jsonString: String, emotion: String) throws -> SoundPreset? {
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(
                domain: "SoundManager", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid JSON data"])
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            let name = jsonObject?["name"] as? String ?? "AI 추천 프리셋"
            let description = jsonObject?["description"] as? String ?? "AI가 추천한 개인화된 사운드 조합입니다."
            let presetEmotion = jsonObject?["emotion"] as? String ?? emotion

            // volumes 파싱
            var volumes: [Float] = Array(repeating: 0.0, count: 8)  // 기본 8개 사운드
            if let volumesDict = jsonObject?["volumes"] as? [String: Any] {
                // 사운드 이름을 인덱스로 매핑
                let soundMapping: [String: Int] = [
                    "비": 0, "빗소리": 0, "rain": 0,
                    "백색소음": 1, "white": 1, "noise": 1,
                    "새소리": 2, "birds": 2, "bird": 2,
                    "파도": 3, "wave": 3, "ocean": 3,
                    "바람": 4, "wind": 4,
                    "벌레": 5, "insects": 5, "cricket": 5,
                    "모닥불": 6, "fire": 6, "bonfire": 6,
                    "천둥": 7, "thunder": 7,
                ]

                for (soundName, volumeValue) in volumesDict {
                    if let index = soundMapping[soundName.lowercased()],
                        let volume = volumeValue as? NSNumber
                    {
                        volumes[index] = min(max(volume.floatValue, 0.0), 1.0)  // 0.0~1.0 범위로 제한
                    }
                }
            }

            // 빈 볼륨이면 기본 조합 설정
            if volumes.allSatisfy({ $0 == 0.0 }) {
                volumes = generateDefaultVolumesForEmotion(emotion)
            }

            return SoundPreset(
                name: name,
                volumes: volumes,
                selectedVersions: Array(repeating: 0, count: 8),  // 기본 버전 사용
                emotion: presetEmotion,
                isAIGenerated: true,
                scientificBasis: description
            )

        } catch {
            print("⚠️ [SoundManager] JSON 파싱 실패, 기본 추천으로 대체: \(error)")
            return generateDefaultPresetForEmotion(emotion)
        }
    }

    /// 감정에 따른 기본 볼륨 조합 생성
    private func generateDefaultVolumesForEmotion(_ emotion: String) -> [Float] {
        switch emotion.lowercased() {
        case "스트레스", "불안", "긴장":
            return [0.6, 0.3, 0.0, 0.5, 0.2, 0.0, 0.0, 0.0]  // 비, 백색소음, 파도 중심
        case "슬픔", "우울":
            return [0.7, 0.2, 0.1, 0.4, 0.1, 0.0, 0.0, 0.0]  // 비 중심의 차분한 조합
        case "분노", "화남":
            return [0.5, 0.4, 0.0, 0.6, 0.3, 0.0, 0.0, 0.1]  // 파도와 바람 중심
        case "기쁨", "행복":
            return [0.3, 0.1, 0.6, 0.2, 0.2, 0.1, 0.0, 0.0]  // 새소리 중심의 밝은 조합
        case "피곤", "졸림":
            return [0.4, 0.5, 0.0, 0.3, 0.1, 0.0, 0.0, 0.0]  // 백색소음 중심
        default:  // 평온, 기본
            return [0.5, 0.3, 0.2, 0.3, 0.1, 0.0, 0.0, 0.0]  // 균형 잡힌 조합
        }
    }

    /// 감정에 따른 기본 프리셋 생성
    private func generateDefaultPresetForEmotion(_ emotion: String) -> SoundPreset {
        return SoundPreset(
            name: "\(emotion) 맞춤 프리셋",
            volumes: generateDefaultVolumesForEmotion(emotion),
            selectedVersions: Array(repeating: 0, count: 8),
            emotion: emotion,
            isAIGenerated: true,
            scientificBasis: "감정 상태에 최적화된 기본 사운드 조합입니다."
        )
    }

    /// 로컬 데이터 기반 프리셋 추천 (빠른 추천)
    func generateLocalPresetRecommendation(emotion: String, situation: String) -> SoundPreset? {
        print("🏠 [SoundManager] 로컬 프리셋 추천 실행: \(emotion), \(situation)")
        // AI 실패 시 로컬 추천으로 사용
        return generateDefaultPresetForEmotion(emotion)
    }
}
