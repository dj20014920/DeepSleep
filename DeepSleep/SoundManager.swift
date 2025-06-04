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
    var previewPlayer: AVAudioPlayer?
    private(set) var previewingCategoryIndex: Int? = nil

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
        print("👍 [SoundManager] init() 호출됨.")
        setupSelectedVersions()
        configureAudioSession()
        loadPlayers()
    }
    
    // MARK: - 초기 설정
    private func setupSelectedVersions() {
        selectedVersions = soundCategories.map { $0.defaultIndex }
        print("👍 [SoundManager] 기본 버전 설정 완료: \(selectedVersions)")
    }
    
    /// AVAudioSession 설정 (백그라운드 재생, 믹스 옵션 등)
    private func configureAudioSession() {
        print("👍 [SoundManager] configureAudioSession() 호출됨.")
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            print("  ✅ [SoundManager] AVAudioSession Category 설정 완료: .playback, .mixWithOthers")
            try session.setActive(true)
            print("  ✅ [SoundManager] AVAudioSession Active 설정 완료.")
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInterruption),
                name: AVAudioSession.interruptionNotification,
                object: session
            )
            print("  ✅ [SoundManager] AVAudioSession Interruption Observer 등록 완료.")
        } catch {
            print("⚠️ [SoundManager] AVAudioSession 설정 실패: \(error.localizedDescription)")
        }
    }
    
    /// 선택된 버전의 파일들을 AVAudioPlayer로 로드
    private func loadPlayers() {
        print("👍 [SoundManager] loadPlayers() 호출됨.")
        
        // 디버깅 정보 출력
        print("📁 [DEBUG] Bundle path: \(Bundle.main.bundlePath)")
        if let resourcePath = Bundle.main.resourcePath {
            print("📁 [DEBUG] Resource path: \(resourcePath)")
            do {
                let allFiles = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                print("📁 [DEBUG] All files in bundle: \(allFiles.prefix(10))") // 처음 10개만 출력
                
                let soundPath = resourcePath + "/Sound"
                if FileManager.default.fileExists(atPath: soundPath) {
                    let soundFiles = try FileManager.default.contentsOfDirectory(atPath: soundPath)
                    print("📁 [DEBUG] Files in Sound directory: \(soundFiles)")
                } else {
                    print("⚠️ [DEBUG] Sound directory does not exist at: \(soundPath)")
                }
            } catch {
                print("⚠️ [DEBUG] Error listing files: \(error)")
            }
        }
        
        players.removeAll()
        
        for (categoryIndex, category) in soundCategories.enumerated() {
            let versionIndex = selectedVersions[categoryIndex]
            let fileName = category.files[versionIndex]
            
            print("  🔄 [SoundManager] Loading player for category \(categoryIndex) ('\(category.name)') - Version: \(versionIndex), File: '\(fileName)'")
            
            let fileNameWithoutExtension = String(fileName.dropLast(4)) // .mp3 제거
            
            var url: URL?
            
            // 번들 루트에서 파일 찾기 (Sound 폴더 없음)
            if let foundURL = Bundle.main.url(forResource: fileNameWithoutExtension, withExtension: "mp3") {
                url = foundURL
                print("    ✅ [SoundManager] 파일 발견 (루트 - 확장자분리): \(foundURL.path)")
            } else if let foundURL = Bundle.main.url(forResource: fileName, withExtension: nil) {
                url = foundURL
                print("    ✅ [SoundManager] 파일 발견 (루트 - 전체파일명): \(foundURL.path)")
            } else {
                print("    ❌ [SoundManager] 사운드 파일을 찾을 수 없습니다: '\(fileName)'")
                print("    🔍 [SoundManager] 시도한 방법들:")
                print("      - forResource: '\(fileNameWithoutExtension)', withExtension: 'mp3' (번들 루트)")
                print("      - forResource: '\(fileName)', withExtension: nil (번들 루트)")
                continue
            }
            
            guard let finalURL = url else { continue }
            
            do {
                let player = try AVAudioPlayer(contentsOf: finalURL)
                player.numberOfLoops = -1    // 무한 루프
                player.volume = 0            // 초기 볼륨 0
                print("    👍 [SoundManager] AVAudioPlayer 인스턴스 생성 성공 for '\(fileName)'. Duration: \(player.duration)")
                if player.prepareToPlay() {
                    print("    ✅ [SoundManager] player.prepareToPlay() 성공 for '\(fileName)'.")
                } else {
                    print("    ⚠️ [SoundManager] player.prepareToPlay() 실패 for '\(fileName)'.")
                }
                players.append(player)
            } catch {
                print("    ⚠️ [SoundManager] AVAudioPlayer 생성 실패 for '\(fileName)': \(error.localizedDescription)")
            }
        }
        print("✅ [SoundManager] \(players.count)개 사운드 로드 완료.")
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
        guard categoryIndex >= 0, categoryIndex < soundCategories.count else {
            print("⚠️ [SoundManager] selectVersion: 유효하지 않은 카테고리 인덱스 \(categoryIndex)")
            return
        }
        let category = soundCategories[categoryIndex]
        guard versionIndex >= 0, versionIndex < category.files.count else {
            print("⚠️ [SoundManager] selectVersion: 카테고리 '\(category.name)'에 유효하지 않은 버전 인덱스 \(versionIndex)")
            return
        }
        
        print("🔄 [SoundManager] selectVersion 호출됨 - Category: \(categoryIndex) ('\(category.name)'), NewVersionIndex: \(versionIndex)")
        
        let wasPlaying = isPlaying(at: categoryIndex)
        let currentVolume = players.count > categoryIndex ? players[categoryIndex].volume : 0
        
        if categoryIndex < players.count {
            print("  ➡️ [SoundManager] 기존 플레이어 정지 (index: \(categoryIndex))")
            players[categoryIndex].stop()
        }
        
        selectedVersions[categoryIndex] = versionIndex
        print("  ✅ [SoundManager] selectedVersions 업데이트됨: \(selectedVersions)")
        
        reloadPlayer(at: categoryIndex)
        
        if categoryIndex < players.count {
            players[categoryIndex].volume = currentVolume
            print("  👍 [SoundManager] 볼륨 복원 (index: \(categoryIndex), volume: \(currentVolume))")
            if wasPlaying && currentVolume > 0 {
                print("  ▶️ [SoundManager] 이전 재생 상태 복원 시도 (index: \(categoryIndex))")
                play(at: categoryIndex) // play 함수 내부에서 재생 조건 다시 확인
            }
        }
        print("✅ [SoundManager] 카테고리 \(categoryIndex) ('\(category.name)') 버전 변경 완료 to \(versionIndex).")
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
        guard categoryIndex >= 0, categoryIndex < soundCategories.count else {
            print("⚠️ [SoundManager] reloadPlayer: 유효하지 않은 카테고리 인덱스 \(categoryIndex)")
            return
        }
        
        let category = soundCategories[categoryIndex]
        let versionIndex = selectedVersions[categoryIndex]
        let fileName = category.files[versionIndex]
        
        print("  🔄 [SoundManager] reloadPlayer for category \(categoryIndex) ('\(category.name)') - Version: \(versionIndex), File: '\(fileName)'")

        let fileNameWithoutExtension = String(fileName.dropLast(4)) // .mp3 제거
        
        var url: URL?
        
        // 번들 루트에서 파일 찾기 (loadPlayers와 동일한 로직)
        if let foundURL = Bundle.main.url(forResource: fileNameWithoutExtension, withExtension: "mp3") {
            url = foundURL
            print("      ✅ [SoundManager] reloadPlayer: 파일 발견 (루트 - 확장자분리): \(foundURL.path)")
        } else if let foundURL = Bundle.main.url(forResource: fileName, withExtension: nil) {
            url = foundURL
            print("      ✅ [SoundManager] reloadPlayer: 파일 발견 (루트 - 전체파일명): \(foundURL.path)")
        } else {
            print("      ❌ [SoundManager] reloadPlayer: 사운드 파일을 찾을 수 없습니다: '\(fileName)'")
            return
        }
        
        guard let finalURL = url else { return }
        
        do {
            let player = try AVAudioPlayer(contentsOf: finalURL)
            player.numberOfLoops = -1
            player.volume = 0 // 재로드 시 볼륨은 0으로 초기화 (selectVersion에서 복원)
            print("      👍 [SoundManager] reloadPlayer: AVAudioPlayer 인스턴스 생성 성공 for '\(fileName)'. Duration: \(player.duration)")
            if player.prepareToPlay() {
                print("      ✅ [SoundManager] reloadPlayer: player.prepareToPlay() 성공 for '\(fileName)'.")
            } else {
                print("      ⚠️ [SoundManager] reloadPlayer: player.prepareToPlay() 실패 for '\(fileName)'.")
            }
            
            if categoryIndex < players.count {
                players[categoryIndex] = player
            } else {
                while players.count <= categoryIndex { // 배열이 작으면 확장
                    players.append(player) // 임시 플레이스홀더 추가 후 교체해야 할 수도 있음
                }
                players[categoryIndex] = player
            }
            print("      ✅ [SoundManager] reloadPlayer: Player 교체/추가 완료 (index: \(categoryIndex))")
        } catch {
            print("    ⚠️ [SoundManager] reloadPlayer: AVAudioPlayer 생성 실패 for '\(fileName)': \(error.localizedDescription)")
        }
    }
    
    // MARK: - 미리듣기 기능
    
    /// 특정 버전 미리듣기 (무한 반복)
    func previewVersion(categoryIndex: Int, versionIndex: Int, fromTime: TimeInterval = 0) {
        guard let category = getCategory(at: categoryIndex) else {
            print("⚠️ [SoundManager] previewVersion: 유효하지 않은 카테고리 인덱스 \(categoryIndex)")
            return
        }
        guard versionIndex >= 0, versionIndex < category.files.count else {
            print("⚠️ [SoundManager] previewVersion: 카테고리 '\(category.name)'에 유효하지 않은 버전 인덱스 \(versionIndex)")
            return
        }
        
        let fileName = category.files[versionIndex]
        print("🔊 [SoundManager] previewVersion 호출됨 - Category: \(category.name), File: '\(fileName)', StartTime: \(fromTime)s")

        let fileNameWithoutExtension = String(fileName.dropLast(4)) // .mp3 제거
        
        var url: URL?
        
        // 번들 루트에서 파일 찾기
        if let foundURL = Bundle.main.url(forResource: fileNameWithoutExtension, withExtension: "mp3") {
            url = foundURL
        } else if let foundURL = Bundle.main.url(forResource: fileName, withExtension: nil) {
            url = foundURL
        } else {
            print("  ⚠️ [SoundManager] previewVersion: 미리듣기 파일을 찾을 수 없습니다: '\(fileName)'")
            return
        }
        
        guard let finalURL = url else { return }
        print("    ✅ [SoundManager] previewVersion: 파일 URL 확인됨: \(finalURL.path)")
        
        // 기존 미리듣기가 있다면 중지
        if previewPlayer != nil {
            stopPreview()
        }
        
        do {
            previewPlayer = try AVAudioPlayer(contentsOf: finalURL)
            previewPlayer?.numberOfLoops = -1 // 무한 반복 설정
            previewPlayer?.volume = 0.6      // 미리듣기 볼륨
            previewPlayer?.currentTime = fromTime // 재생 시작 시간 설정
            print("    👍 [SoundManager] previewVersion: AVAudioPlayer 인스턴스 생성 성공. Duration: \(previewPlayer?.duration ?? 0)")
            if previewPlayer?.prepareToPlay() == true {
                 print("    ✅ [SoundManager] previewVersion: player.prepareToPlay() 성공.")
            } else {
                 print("    ⚠️ [SoundManager] previewVersion: player.prepareToPlay() 실패.")
            }
            if previewPlayer?.play() == true {
                print("    ▶️ [SoundManager] previewVersion: 미리듣기 재생 시작 성공.")
            } else {
                print("    ❌ [SoundManager] previewVersion: 미리듣기 재생 시작 실패.")
            }
            previewingCategoryIndex = categoryIndex // 현재 미리듣기 중인 카테고리 인덱스 저장
        } catch {
            print("  ⚠️ [SoundManager] previewVersion: 미리듣기 플레이어 생성 실패: \(error.localizedDescription) - 파일: '\(fileName)'")
            previewPlayer = nil // 실패 시 nil로 확실히 설정
            previewingCategoryIndex = nil
        }
    }

    func seekPreview(to time: TimeInterval) {
        guard let player = previewPlayer else {
            print("⚠️ [SoundManager] seekPreview: 플레이어가 존재하지 않습니다.")
            return
        }
        // 재생 시간이 음원 길이를 넘지 않도록 보정
        let newTime = max(0, min(time, player.duration))
        player.currentTime = newTime
        print("🔊 [SoundManager] 미리듣기 탐색: \(newTime)s (요청: \(time)s), Duration: \(player.duration)s")
    }

    func stopPreview() {
        if let player = previewPlayer, player.isPlaying {
            player.stop()
            print("🔇 [SoundManager] 미리듣기 중지됨.")
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
    
    // MARK: - 전체 제어
    
    /// 모든 트랙 일괄 재생 (볼륨이 0 이상인 것만)
    func playAll() {
        print("▶️ [SoundManager] playAll() 호출됨.")
        var playedCount = 0
        for (index, player) in players.enumerated() {
            if player.volume > 0 && !player.isPlaying {
                print("  ▶️ [SoundManager] Playing sound for index \(index) ('\(getCategoryDisplay(at: index))') at volume \(player.volume)")
                if player.play() {
                    playedCount += 1
                } else {
                    print("    ❌ [SoundManager] playAll: Failed to play sound for index \(index)")
                }
            }
        }
        print("  ✅ [SoundManager] playAll: \(playedCount)개 사운드 재생 시작됨.")
    }
    
    /// 모든 트랙 일괄 일시정지
    func pauseAll() {
        print("⏸️ [SoundManager] pauseAll() 호출됨.")
        var pausedCount = 0
        for player in players {
            if player.isPlaying {
                player.pause()
                pausedCount += 1
            }
        }
        print("  ✅ [SoundManager] pauseAll: \(pausedCount)개 사운드 일시정지됨.")
    }
    
    /// 완전 중지 (재생 위치 리셋)
    func stopAll() {
        print("⏹️ [SoundManager] stopAll() 호출됨.")
        var stoppedCount = 0
        for player in players {
            if player.isPlaying {
                player.stop()
                stoppedCount += 1
            }
            player.currentTime = 0
        }
        print("  ✅ [SoundManager] stopAll: \(stoppedCount)개 사운드 중지 및 초기화됨.")
        stopPreview()  // 미리듣기도 정지
    }
    
    // MARK: - 개별 제어
    
    func play(at index: Int) {
        guard index >= 0, index < players.count else {
            print("🚫 [SoundManager] Play Error: Invalid index \(index). Player count: \(players.count)")
            return
        }
        let player = players[index]
        let categoryInfo = getCategoryDisplay(at: index)
        let currentVersionInfo = getCurrentVersionInfo(at: index) ?? "N/A"
        
        print("▶️ [SoundManager] play(at: \(index)) 호출됨 - Category: '\(categoryInfo)', Version: '\(currentVersionInfo)'")
        print("  Player Info - URL: \(player.url?.lastPathComponent ?? "N/A"), Volume: \(player.volume), IsPlaying: \(player.isPlaying), Duration: \(player.duration), CurrentTime: \(player.currentTime)")

        if !player.isPlaying {
            if player.volume > 0 {
                if player.play() {
                    print("  ✅ [SoundManager] 사운드 \(index) ('\(categoryInfo)') 재생 시작 성공.")
                } else {
                    print("  ❌ [SoundManager] 사운드 \(index) ('\(categoryInfo)') 재생 시작 실패.")
                }
            } else {
                print("  ℹ️ [SoundManager] 사운드 \(index) ('\(categoryInfo)') 볼륨이 0이므로 재생하지 않음.")
            }
        } else {
            print("  ℹ️ [SoundManager] 사운드 \(index) ('\(categoryInfo)') 이미 재생 중.")
        }
    }
    
    func pause(at index: Int) {
        guard index >= 0, index < players.count else {
             print("🚫 [SoundManager] Pause Error: Invalid index \(index). Player count: \(players.count)")
            return
        }
        let player = players[index]
        let categoryInfo = getCategoryDisplay(at: index)
        print("⏸️ [SoundManager] pause(at: \(index)) 호출됨 - Category: '\(categoryInfo)'")
        if player.isPlaying {
            player.pause()
            print("  ✅ [SoundManager] 사운드 \(index) ('\(categoryInfo)') 일시정지됨.")
        } else {
            print("  ℹ️ [SoundManager] 사운드 \(index) ('\(categoryInfo)') 이미 일시정지 상태임.")
        }
    }
    
    func isPlaying(at index: Int) -> Bool {
        guard index >= 0, index < players.count else { return false }
        return players[index].isPlaying
    }
    
    // MARK: - 볼륨 제어
    
    /// 슬라이더나 프리셋에서 설정한 볼륨을 반영합니다. volume 은 0~100 사이.
    func setVolume(at index: Int, volume: Float) {
        guard index >= 0, index < players.count else {
            print("🚫 [SoundManager] SetVolume Error: Invalid index \(index). Player count: \(players.count)")
            return
        }
        let categoryInfo = getCategoryDisplay(at: index)
        // SoundManager 내부에서는 볼륨을 0.0 ~ 1.0으로 관리
        let internalVolume = max(0.0, min(1.0, volume / 100.0))
        
        print("🔊 [SoundManager] setVolume(at: \(index), volume: \(volume) (internal: \(internalVolume))) 호출됨 - Category: '\(categoryInfo)'")
        players[index].volume = internalVolume
        print("  ✅ [SoundManager] 사운드 \(index) ('\(categoryInfo)') 볼륨 설정됨: \(players[index].volume) (요청된 외부 값: \(volume))")
    }
    
    /// 배열 단위로 한 번에 설정
    func setVolumes(_ volumes: [Float]) {
        print("🔊 [SoundManager] setVolumes(\(volumes)) 호출됨.")
        for (i, v) in volumes.enumerated() {
            setVolume(at: i, volume: v) // 내부에서 0~1 스케일로 변환됨
        }
        print("  ✅ [SoundManager] 전체 볼륨 설정 완료.")
    }
    
    /// 프리셋 적용
    func applyPreset(volumes: [Float]) {
        print("🎶 [SoundManager] applyPreset(volumes: \(volumes)) 호출됨.")
        // 1. 먼저 볼륨 설정
        setVolumes(volumes) // 각 setVolume 호출 시 로그 출력됨
        
        // 2. 볼륨이 0 이상인 사운드만 재생 시작 (또는 이미 재생 중이면 그대로 둠)
        print("  🔄 [SoundManager] applyPreset: 각 사운드 재생 상태 확인 및 조정 시작...")
        for (index, volume) in volumes.enumerated() {
            if index < players.count {
                let player = players[index]
                let categoryInfo = getCategoryDisplay(at: index)
                if volume > 0 {
                    if !player.isPlaying { // 볼륨이 있고, 재생 중이 아니면 재생
                        print("    ▶️ [SoundManager] applyPreset: 사운드 \(index) ('\(categoryInfo)') 재생 시작 (볼륨: \(volume))")
                        play(at: index) // play 함수 내부에서 상세 로그 출력
                    } else {
                         print("    ℹ️ [SoundManager] applyPreset: 사운드 \(index) ('\(categoryInfo)') 이미 재생 중 (볼륨: \(volume))")
                    }
                } else { // 볼륨이 0이면 일시정지
                    print("    ⏸️ [SoundManager] applyPreset: 사운드 \(index) ('\(categoryInfo)') 볼륨 0이므로 일시정지")
                    pause(at: index) // pause 함수 내부에서 상세 로그 출력
                }
            }
        }
        print("  ✅ [SoundManager] 프리셋 적용 및 재생 상태 조정 완료.")
    }
    
    // MARK: - 프리셋 호환성
    
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
    
    // MARK: - 인터럽션 처리
    
    @objc private func handleInterruption(_ notif: Notification) {
        guard let info = notif.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            print("⚠️ [SoundManager] handleInterruption: 알림 정보 파싱 실패.")
            return
        }

        switch type {
        case .began:
            print("🔔 [SoundManager] 오디오 인터럽션 시작 - 일시정지 시도.")
            pauseAll() // 내부에서 로그 출력
            stopPreview() // 내부에서 로그 출력
        case .ended:
            print("🔔 [SoundManager] 오디오 인터럽션 종료.")
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt,
               AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                print("  ➡️ [SoundManager] 재생 재시작 옵션 확인됨. playAll() 호출.")
                playAll() // 내부에서 로그 출력
            } else {
                print("  ℹ️ [SoundManager] 재생 재시작 옵션 없음.")
            }
        @unknown default:
            print("🔔 [SoundManager] 알 수 없는 오디오 인터럽션 타입.")
            break
        }
    }
    
    deinit {
        print("🗑️ [SoundManager] deinit 호출됨.")
        NotificationCenter.default.removeObserver(self)
        stopAll() // 모든 사운드 정리
    }
}
