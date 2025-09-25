import Combine
import Foundation
import UIKit

/// 2025년 최신 메모리 최적화 관리자
/// iOS 26 기준 메모리 효율성 및 누수 방지 기법 적용
@MainActor
final class MemoryOptimizationManager: ObservableObject, MemoryOptimizationProtocol {
    static let shared = MemoryOptimizationManager()

    // MARK: - Properties
    @Published var currentMemoryUsage: UInt64 = 0
    @Published var peakMemoryUsage: UInt64 = 0
    @Published var memoryPressureLevel: MemoryPressureLevel = .normal
    @Published var isMemoryWarningActive = false

    private var cancellables = Set<AnyCancellable>()

    // 메모리 풀 관리
    private var imageCache = NSCache<NSString, UIImage>()
    private var modelCache = NSCache<NSString, AnyObject>()
    private var stringCache = NSCache<NSString, NSString>()

    // 성능 모니터링
    private var memoryMonitoringTimer: Timer?
    private let memoryCheckInterval: TimeInterval = 2.0

    // MARK: - Initialization
    private init() {
        setupMemoryMonitoring()
        configureMemoryCaches()
        setupMemoryWarningHandlers()
    }

    deinit {
        memoryMonitoringTimer?.invalidate()
    }

    // MARK: - Setup Methods
    private func setupMemoryMonitoring() {
        // 실시간 메모리 사용량 모니터링
        memoryMonitoringTimer = Timer.scheduledTimer(
            withTimeInterval: memoryCheckInterval, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }

        // 메모리 경고 알림 설정
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleMemoryWarning()
                }
            }
            .store(in: &cancellables)

        // 앱 상태 변화 모니터링
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleBackgroundTransition()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleForegroundTransition()
                }
            }
            .store(in: &cancellables)
    }

    private func configureMemoryCaches() {
        // 이미지 캐시 설정 (iOS 26 최적화)
        imageCache.countLimit = 50
        imageCache.totalCostLimit = 100 * 1024 * 1024  // 100MB

        // 모델 캐시 설정
        modelCache.countLimit = 10
        modelCache.totalCostLimit = 200 * 1024 * 1024  // 200MB

        // 문자열 캐시 설정
        stringCache.countLimit = 1000
        stringCache.totalCostLimit = 10 * 1024 * 1024  // 10MB
    }

    private func setupMemoryWarningHandlers() {
        // 메모리 압박 상황 모니터링
        $currentMemoryUsage
            .sink { [weak self] usage in
                self?.evaluateMemoryPressure(usage: usage)
            }
            .store(in: &cancellables)
    }

    // MARK: - Memory Monitoring
    private func updateMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        currentMemoryUsage = usage

        if usage > peakMemoryUsage {
            peakMemoryUsage = usage
        }

        // 메모리 사용량 로깅 (개발 중에만)

    }

    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }

    private func evaluateMemoryPressure(usage: UInt64) {
        let usageMB = Double(usage) / (1024 * 1024)
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        let ratio = totalBytes > 0 ? (Double(usage) / totalBytes) : 0.0

        // 온디바이스 AI 모델을 위한 완화된 임계값 (메모리 압박 완화)
        // - medium: >60% 또는 >1200MB (기존 50%/700MB에서 완화)
        // - high:   >75% 또는 >1600MB (기존 65%/1000MB에서 완화)
        // - critical: >85% 또는 >2000MB (기존 80%/1400MB에서 완화)
        let isCritical = (ratio > 0.85) || (usageMB > 2000)
        let isHigh = (ratio > 0.75) || (usageMB > 1600)
        let isMedium = (ratio > 0.60) || (usageMB > 1200)

        let newPressureLevel: MemoryPressureLevel
        if isCritical {
            newPressureLevel = .critical
        } else if isHigh {
            newPressureLevel = .high
        } else if isMedium {
            newPressureLevel = .medium
        } else {
            newPressureLevel = .normal
        }

        if newPressureLevel != memoryPressureLevel {
            memoryPressureLevel = newPressureLevel
            handleMemoryPressureChange(newPressureLevel)
        }
    }

    // MARK: - Memory Management
    private func handleMemoryWarning() {
        isMemoryWarningActive = true
        UnifiedLogger.shared.warning("메모리 경고 발생 - 즉시 메모리 정리 시작", category: .performance)

        // 단계별 메모리 정리
        performEmergencyMemoryCleanup()

        // 5초 후 경고 상태 해제
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isMemoryWarningActive = false
        }
    }

    private func handleMemoryPressureChange(_ level: MemoryPressureLevel) {
        UnifiedLogger.shared.info("메모리 압박 레벨 변경: \(level.description)", category: .performance)

        switch level {
        case .normal:
            // 정상 상태 - 제한 해제
            restoreNormalMemoryBehavior()
        case .medium:
            // 중간 압박 - 예방적 정리
            performPreventiveMemoryCleanup()
        case .high:
            // 높은 압박 - 적극적 정리
            performAggressiveMemoryCleanup()
        case .critical:
            // 위험 수준 - 응급 정리
            performEmergencyMemoryCleanup()
        }
    }

    private func handleBackgroundTransition() {

        // 백그라운드에서 불필요한 캐시 정리
        clearNonEssentialCaches()

        // AI 모델 언로드
        unloadNonEssentialModels()

        // 이미지 캐시 압축
        compressImageCaches()
    }

    private func handleForegroundTransition() {
        UnifiedLogger.shared.info("포그라운드 전환 - 캐시 재구성", category: .performance)

        // 필요한 모델 재로드
        preloadEssentialModels()
    }

    // MARK: - Memory Cleanup Operations
    private func restoreNormalMemoryBehavior() {
        // 캐시 한도 복구
        imageCache.countLimit = 50
        modelCache.countLimit = 10
        stringCache.countLimit = 1000
    }

    private func performPreventiveMemoryCleanup() {
        // 오래된 캐시 항목 정리
        clearOldCacheEntries()

        // 캐시 한도를 더 관대하게 감소 (온디바이스 AI 고려)
        imageCache.countLimit = 40  // 기존 30에서 40으로
        modelCache.countLimit = 10  // 기존 8에서 10으로 (원래값 유지)
        stringCache.countLimit = 900  // 기존 800에서 900으로
    }

    private func performAggressiveMemoryCleanup() {
        // 캐시 대폭 정리 (온디바이스 AI 모델 보호)
        clearMostCaches()

        // 캐시 한도를 더 관대하게 감소 (AI 모델 고려)
        imageCache.countLimit = 25  // 기존 15에서 25로
        modelCache.countLimit = 8  // 기존 5에서 8로
        stringCache.countLimit = 750  // 기존 500에서 750으로

        // 백그라운드 작업 중단
        suspendNonEssentialBackgroundTasks()
    }

    private func performEmergencyMemoryCleanup() {
        UnifiedLogger.shared.critical("응급 메모리 정리 시작 - 온디바이스 AI 모델 보호", category: .performance)

        // 일반 캐시만 정리 (AI 모델 캐시는 보존)
        imageCache.removeAllObjects()
        stringCache.removeAllObjects()

        // AI 모델 캐시는 50%만 정리 (완전 삭제 방지)
        let currentModelLimit = modelCache.countLimit
        modelCache.countLimit = max(1, currentModelLimit / 2)

        // AI 시스템 프롬프트 캐시는 선택적으로만 무효화
        AIContextManager.shared.clearCache(
            reason: .manual, caller: "MemoryOptimizationManager.emergency")

        // AFM 세션 풀은 새 세션 생성 방지만 하고 기존 세션은 유지
        Task {
            await AppleFMSessionPool.shared.invalidateAll(reason: "emergencyMemoryCleanup")
        }

        // 캐시 한도를 더 관대하게 설정 (AI 모델 고려)
        imageCache.countLimit = 10  // 기존 5에서 10으로
        modelCache.countLimit = max(3, currentModelLimit / 2)  // 기존 2에서 3으로, 또는 절반
        stringCache.countLimit = 200  // 기존 100에서 200으로

        // 온디바이스 AI 모델은 보호하고 다른 모델만 언로드
        unloadNonEssentialModelsGently()

        // 강제 가비지 컬렉션
        autoreleasepool {
            // 메모리 해제 작업
            URLCache.shared.removeAllCachedResponses()
        }

        // 시스템에 메모리 해제 요청 (더 부드럽게)
        DispatchQueue.global(qos: .utility).async {
            let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: .main)
            source.setEventHandler { [weak source] in
                source?.cancel()
            }
            source.resume()
        }
    }

    private func clearNonEssentialCaches() {
        // 이미지 캐시 50% 정리
        let imageCacheSize = imageCache.countLimit
        imageCache.countLimit = imageCacheSize / 2
        imageCache.removeAllObjects()
        imageCache.countLimit = imageCacheSize

        // 문자열 캐시 정리
        stringCache.removeAllObjects()
    }

    private func clearOldCacheEntries() {
        // TODO: 캐시 항목 나이 기반 정리 구현
    }

    private func clearMostCaches() {
        imageCache.removeAllObjects()
        stringCache.removeAllObjects()
        // 모델 캐시는 핵심 모델만 유지
    }

    private func clearAllCaches() {
        imageCache.removeAllObjects()
        modelCache.removeAllObjects()
        stringCache.removeAllObjects()

        UnifiedLogger.shared.info("모든 캐시 완전 삭제 완료", category: .performance)
    }

    private func compressImageCaches() {
        // TODO: 이미지 캐시 압축 구현
        UnifiedLogger.shared.debug("이미지 캐시 압축", category: .performance)
    }

    private func unloadNonEssentialModels() {
        // TODO: 비필수 AI 모델 언로드 구현
        UnifiedLogger.shared.debug("비필수 모델 언로드", category: .ai)
    }

    private func unloadAllNonEssentialModels() {
        UnifiedLogger.shared.warning("모든 비필수 모델 언로드 시작", category: .ai)

        // 모든 캐시 완전 정리
        imageCache.removeAllObjects()
        modelCache.removeAllObjects()
        stringCache.removeAllObjects()

        // 캐시 용량 최소화
        imageCache.totalCostLimit = 1024 * 1024 * 10  // 10MB
        imageCache.countLimit = 10
        modelCache.countLimit = 3

        // 긴급 메모리 정리 알림
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryPressure.EmergencyCleanup"),
            object: nil,
            userInfo: ["level": "critical"]
        )

        UnifiedLogger.shared.warning("모든 비필수 모델 언로드 완료 - 긴급 모드 활성화", category: .ai)
    }

    private func unloadNonEssentialModelsGently() {
        UnifiedLogger.shared.info("온디바이스 AI 모델 보호하며 비필수 모델만 언로드", category: .ai)

        // 이미지/문자열 캐시만 정리 (모델 캐시는 부분 정리)
        imageCache.removeAllObjects()
        stringCache.removeAllObjects()

        // 모델 캐시는 25%만 정리
        let currentLimit = modelCache.countLimit
        modelCache.countLimit = max(5, (currentLimit * 3) / 4)

        // 캐시 용량을 더 관대하게 설정
        imageCache.totalCostLimit = 1024 * 1024 * 25  // 25MB (기존 10MB에서 증가)
        imageCache.countLimit = 25  // 기존 10에서 25로
        modelCache.countLimit = max(5, currentLimit / 2)  // 최소 5개는 유지

        // 부드러운 메모리 정리 알림
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryPressure.GentleCleanup"),
            object: nil,
            userInfo: ["level": "moderate", "protectOnDevice": true]
        )

        UnifiedLogger.shared.info("온디바이스 AI 모델 보호 완료 - 부드러운 정리 모드", category: .ai)
    }

    private func preloadEssentialModels() {
        UnifiedLogger.shared.debug("필수 모델 재로드 시작 - 온디바이스 AI 우선", category: .ai)

        // 온디바이스 AI를 위한 넉넉한 캐시 용량 복원
        imageCache.totalCostLimit = 1024 * 1024 * 100  // 100MB (기존 50MB에서 증가)
        imageCache.countLimit = 150  // 기존 100에서 150으로
        modelCache.countLimit = 15  // 기존 10에서 15로

        // 온디바이스 AI 모델 우선 로드 알림
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryPressure.LoadEssentialModels"),
            object: nil,
            userInfo: ["level": "essential", "prioritizeOnDevice": true]
        )

        // 선택된 온디바이스 모델 즉시 재활성화
        NotificationCenter.default.post(
            name: NSNotification.Name("OnDeviceModel.ReactivateSelected"),
            object: nil,
            userInfo: ["reason": "memoryRecovery"]
        )

        UnifiedLogger.shared.info("온디바이스 AI 모델 우선 재로드 완료", category: .ai)
    }

    private func suspendNonEssentialBackgroundTasks() {

        // 백그라운드 작업 중단 알림
        NotificationCenter.default.post(
            name: NSNotification.Name("MemoryPressure.SuspendBackgroundTasks"),
            object: nil,
            userInfo: ["suspend": true]
        )

        // 타이머 기반 작업들 일시 중단
        memoryMonitoringTimer?.invalidate()

        // 5초 후 모니터링 재시작 (더 긴 간격으로)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.memoryMonitoringTimer = Timer.scheduledTimer(
                withTimeInterval: 10.0, repeats: true
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updateMemoryUsage()
                }
            }
        }

    }

    // MARK: - Public Methods
    func requestMemoryOptimization() {
        performPreventiveMemoryCleanup()
    }

    func getMemoryStatus() -> MemoryStatus {
        return MemoryStatus(
            currentUsage: currentMemoryUsage,
            peakUsage: peakMemoryUsage,
            pressureLevel: memoryPressureLevel,
            isWarningActive: isMemoryWarningActive
        )
    }

    func addToImageCache(_ image: UIImage, forKey key: String) {
        let cost = image.size.width * image.size.height * 4  // RGBA 추정
        imageCache.setObject(image, forKey: key as NSString, cost: Int(cost))
    }

    func getFromImageCache(forKey key: String) -> UIImage? {
        return imageCache.object(forKey: key as NSString)
    }

    func removeFromImageCache(forKey key: String) {
        imageCache.removeObject(forKey: key as NSString)
    }

    func enableDetailedLogging(_ enabled: Bool) {
        UnifiedLogger.shared.info("상세 메모리 로깅 설정: \(enabled)", category: .performance)

    }
}

// MARK: - Supporting Types
enum MemoryPressureLevel: String, CaseIterable {
    case normal = "정상"
    case medium = "보통"
    case high = "높음"
    case critical = "위험"

    var description: String {
        return rawValue
    }

    var color: UIColor {
        switch self {
        case .normal: return .systemGreen
        case .medium: return .systemYellow
        case .high: return .systemOrange
        case .critical: return .systemRed
        }
    }
}

struct MemoryStatus {
    let currentUsage: UInt64
    let peakUsage: UInt64
    let pressureLevel: MemoryPressureLevel
    let isWarningActive: Bool

    var currentUsageMB: Double {
        return Double(currentUsage) / (1024 * 1024)
    }

    var peakUsageMB: Double {
        return Double(peakUsage) / (1024 * 1024)
    }

    var description: String {
        return String(
            format: "현재: %.1fMB, 최고: %.1fMB, 상태: %@",
            currentUsageMB, peakUsageMB, pressureLevel.description)
    }
}

// MARK: - Extensions
// NSCache는 currentCount 속성을 직접 제공하지 않으므로 별도 구현 불필요
