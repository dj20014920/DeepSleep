import Foundation
import UIKit

/// 배터리 최적화 매니저
/// CPU 사용량 최소화, 메모리 관리, 백그라운드 최적화를 담당
class BatteryOptimizationManager {
    static let shared = BatteryOptimizationManager()
    
    // MARK: - Properties
    
    private var isLowPowerModeEnabled: Bool = false
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var memoryWarningObserver: NSObjectProtocol?
    private var lowPowerModeObserver: NSObjectProtocol?
    
    /// 배터리 최적화 설정
    struct OptimizationSettings {
        var maxConcurrentPlayers: Int = 11  // 기본값
        var audioQuality: AudioQuality = .standard
        var backgroundUpdateInterval: TimeInterval = 0.1
        var enableMemoryOptimization: Bool = true
        var enableCPUOptimization: Bool = true
    }
    
    enum AudioQuality: Int, CaseIterable {
        case low = 0
        case standard = 1
        case high = 2
        
        var displayName: String {
            switch self {
            case .low: return "저품질 (배터리 절약)"
            case .standard: return "표준 품질"
            case .high: return "고품질"
            }
        }
        
        var sampleRate: Double {
            switch self {
            case .low: return 22050.0
            case .standard: return 44100.0
            case .high: return 48000.0
            }
        }
        
        var bitRate: Int {
            switch self {
            case .low: return 96000
            case .standard: return 128000
            case .high: return 256000
            }
        }
    }
    
    private var settings = OptimizationSettings()
    private let settingsKey = "BatteryOptimizationSettings"
    
    // MARK: - Initialization
    
    private init() {
        loadSettings()
        setupObservers()
        updateOptimizationForPowerMode()
    }
    
    deinit {
        removeObservers()
        endBackgroundTask()
    }
    
    // MARK: - Public Methods
    
    /// 배터리 최적화 시작
    func startOptimization() {
        updateOptimizationForPowerMode()
        
        if settings.enableMemoryOptimization {
            scheduleMemoryCleanup()
        }
        
        if settings.enableCPUOptimization {
            optimizeCPUUsage()
        }
    }
    
    /// 배터리 최적화 중지
    func stopOptimization() {
        endBackgroundTask()
    }
    
    /// 현재 설정 반환
    func getCurrentSettings() -> OptimizationSettings {
        return settings
    }
    
    /// 설정 업데이트
    func updateSettings(_ newSettings: OptimizationSettings) {
        settings = newSettings
        saveSettings()
        updateOptimizationForPowerMode()
    }
    
    /// 메모리 정리
    func cleanupMemory() {
        // 메모리 캐시 정리
        URLCache.shared.removeAllCachedResponses()
        
        // 이미지 캐시 정리 (필요시)
        // ImageCache.shared.clearMemoryCache()
        
        // 강제 가비지 컬렉션 요청
        DispatchQueue.global(qos: .utility).async {
            autoreleasepool {
                // 불필요한 객체들이 해제되도록 유도
            }
        }
        
        print("🔋 메모리 정리 완료")
    }
    
    /// CPU 사용량 최적화
    func optimizeCPUUsage() {
        // 타이머 간격 조정
        let interval = isLowPowerModeEnabled ? 0.2 : settings.backgroundUpdateInterval
        
        // SoundManager에 최적화 설정 전달
        NotificationCenter.default.post(
            name: NSNotification.Name("BatteryOptimizationUpdate"),
            object: nil,
            userInfo: [
                "isLowPowerMode": isLowPowerModeEnabled,
                "updateInterval": interval,
                "maxPlayers": settings.maxConcurrentPlayers,
                "audioQuality": settings.audioQuality.rawValue
            ]
        )
    }
    
    /// 백그라운드 작업 시작
    func beginBackgroundTask() {
        endBackgroundTask()
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "DeepSleepAudio") { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    /// 백그라운드 작업 종료
    func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // 저전력 모드 감지
        lowPowerModeObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateOptimizationForPowerMode()
        }
        
        // 메모리 경고 감지
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        
        // 앱 생명주기 관찰
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func removeObservers() {
        if let observer = lowPowerModeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateOptimizationForPowerMode() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if isLowPowerModeEnabled {
            // 저전력 모드일 때 최적화 설정
            settings.maxConcurrentPlayers = min(settings.maxConcurrentPlayers, 6)
            settings.audioQuality = .low
            settings.backgroundUpdateInterval = 0.2
            
            print("🔋 저전력 모드 감지됨 - 배터리 최적화 활성화")
        } else {
            // 일반 모드 복원
            loadSettings()
            print("🔋 일반 모드 - 표준 설정 복원")
        }
        
        optimizeCPUUsage()
    }
    
    private func handleMemoryWarning() {
        print("⚠️ 메모리 경고 수신됨 - 즉시 정리 시작")
        cleanupMemory()
        
        // 추가 메모리 절약 조치
        if !isLowPowerModeEnabled {
            settings.maxConcurrentPlayers = max(settings.maxConcurrentPlayers - 2, 4)
            optimizeCPUUsage()
        }
    }
    
    private func scheduleMemoryCleanup() {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.cleanupMemory()
            
            // 30초마다 메모리 정리 반복
            if self?.settings.enableMemoryOptimization == true {
                self?.scheduleMemoryCleanup()
            }
        }
    }
    
    @objc private func appDidEnterBackground() {
        beginBackgroundTask()
        
        // 백그라운드에서 더욱 적극적인 최적화
        let backgroundSettings = settings
        settings.maxConcurrentPlayers = min(backgroundSettings.maxConcurrentPlayers, 4)
        settings.backgroundUpdateInterval = 0.5
        optimizeCPUUsage()
    }
    
    @objc private func appWillEnterForeground() {
        endBackgroundTask()
        
        // 포그라운드 복원 시 원래 설정 복원
        loadSettings()
        optimizeCPUUsage()
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(OptimizationSettings.self, from: data) {
            settings = decoded
        }
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
}

// MARK: - OptimizationSettings Codable 확장

extension BatteryOptimizationManager.OptimizationSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case maxConcurrentPlayers
        case audioQuality
        case backgroundUpdateInterval
        case enableMemoryOptimization
        case enableCPUOptimization
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxConcurrentPlayers = try container.decode(Int.self, forKey: .maxConcurrentPlayers)
        let qualityRaw = try container.decode(Int.self, forKey: .audioQuality)
        audioQuality = BatteryOptimizationManager.AudioQuality(rawValue: qualityRaw) ?? .standard
        backgroundUpdateInterval = try container.decode(TimeInterval.self, forKey: .backgroundUpdateInterval)
        enableMemoryOptimization = try container.decode(Bool.self, forKey: .enableMemoryOptimization)
        enableCPUOptimization = try container.decode(Bool.self, forKey: .enableCPUOptimization)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(maxConcurrentPlayers, forKey: .maxConcurrentPlayers)
        try container.encode(audioQuality.rawValue, forKey: .audioQuality)
        try container.encode(backgroundUpdateInterval, forKey: .backgroundUpdateInterval)
        try container.encode(enableMemoryOptimization, forKey: .enableMemoryOptimization)
        try container.encode(enableCPUOptimization, forKey: .enableCPUOptimization)
    }
} 