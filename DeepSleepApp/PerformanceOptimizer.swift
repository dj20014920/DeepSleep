import UIKit
import Foundation

/// 앱 성능 최적화 및 사용자 경험 개선 유틸리티
final class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()
    
    private init() {}
    
    // MARK: - 디바운싱 최적화
    
    private var debounceTimers: [String: Timer] = [:]
    
    /// 디바운싱을 통한 과도한 호출 방지
    func debounce(identifier: String, delay: TimeInterval, action: @escaping () -> Void) {
        // 기존 타이머 무효화
        debounceTimers[identifier]?.invalidate()
        
        // 새 타이머 설정
        debounceTimers[identifier] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            action()
            self?.debounceTimers.removeValue(forKey: identifier)
        }
    }
    
    // MARK: - 배치 처리 최적화
    
    private var batchOperations: [String: [() -> Void]] = [:]
    private var batchTimers: [String: Timer] = [:]
    
    /// 여러 작업을 배치로 처리하여 성능 최적화
    func batchOperation(identifier: String, delay: TimeInterval = 0.1, operation: @escaping () -> Void) {
        // 배치에 작업 추가
        if batchOperations[identifier] == nil {
            batchOperations[identifier] = []
        }
        batchOperations[identifier]?.append(operation)
        
        // 기존 타이머 무효화
        batchTimers[identifier]?.invalidate()
        
        // 새 타이머 설정
        batchTimers[identifier] = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.executeBatch(identifier: identifier)
        }
    }
    
    private func executeBatch(identifier: String) {
        guard let operations = batchOperations[identifier] else { return }
        
        DispatchQueue.main.async {
            operations.forEach { $0() }
        }
        
        // 정리
        batchOperations.removeValue(forKey: identifier)
        batchTimers.removeValue(forKey: identifier)
        
        DebugManager.shared.logPerformance("배치 작업 실행 완료: \(identifier), 작업 수: \(operations.count)")
    }
    
    // MARK: - 메모리 효율적인 이미지 처리
    
    /// 메모리 효율적인 이미지 리사이징
    func resizeImageEfficiently(_ image: UIImage, to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    /// 이미지 압축 (메모리 절약)
    func compressImage(_ image: UIImage, quality: CGFloat = 0.8) -> Data? {
        return image.jpegData(compressionQuality: quality)
    }
    
    // MARK: - 스마트 캐싱
    
    private var smartCache: [String: (data: Any, timestamp: Date, accessCount: Int)] = [:]
    private let maxCacheSize = 50
    private let cacheExpiryTime: TimeInterval = 300 // 5분
    
    /// 스마트 캐싱 (사용 빈도와 시간 기반)
    func cacheData<T>(_ data: T, forKey key: String) {
        cleanExpiredCache()
        
        if smartCache.count >= maxCacheSize {
            removeOldestCacheItem()
        }
        
        smartCache[key] = (data: data, timestamp: Date(), accessCount: 0)
        DebugManager.shared.logPerformance("데이터 캐시됨: \(key)")
    }
    
    /// 캐시된 데이터 가져오기
    func getCachedData<T>(forKey key: String, type: T.Type) -> T? {
        guard var cacheItem = smartCache[key] else { return nil }
        
        // 만료 확인
        if Date().timeIntervalSince(cacheItem.timestamp) > cacheExpiryTime {
            smartCache.removeValue(forKey: key)
            return nil
        }
        
        // 접근 횟수 증가
        cacheItem.accessCount += 1
        smartCache[key] = cacheItem
        
        return cacheItem.data as? T
    }
    
    /// 캐시에서 데이터 제거
    func removeFromCache(key: String) {
        smartCache.removeValue(forKey: key)
        DebugManager.shared.logPerformance("캐시에서 제거됨: \(key)")
    }
    
    private func cleanExpiredCache() {
        let now = Date()
        smartCache = smartCache.filter { _, value in
            now.timeIntervalSince(value.timestamp) <= cacheExpiryTime
        }
    }
    
    private func removeOldestCacheItem() {
        // 가장 적게 사용되고 오래된 항목 제거
        let sortedItems = smartCache.sorted { first, second in
            if first.value.accessCount == second.value.accessCount {
                return first.value.timestamp < second.value.timestamp
            }
            return first.value.accessCount < second.value.accessCount
        }
        
        if let oldestKey = sortedItems.first?.key {
            smartCache.removeValue(forKey: oldestKey)
        }
    }
    
    // MARK: - 사용자 경험 개선
    
    /// 부드러운 애니메이션 헬퍼
    func smoothAnimation(duration: TimeInterval = 0.3, 
                        delay: TimeInterval = 0,
                        options: UIView.AnimationOptions = [.curveEaseInOut],
                        animations: @escaping () -> Void,
                        completion: ((Bool) -> Void)? = nil) {
        UIView.animate(
            withDuration: duration,
            delay: delay,
            options: options,
            animations: animations,
            completion: completion
        )
    }
    
    /// 스프링 애니메이션 헬퍼
    func springAnimation(duration: TimeInterval = 0.6,
                        damping: CGFloat = 0.7,
                        velocity: CGFloat = 0.5,
                        animations: @escaping () -> Void,
                        completion: ((Bool) -> Void)? = nil) {
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: damping,
            initialSpringVelocity: velocity,
            options: [.curveEaseInOut],
            animations: animations,
            completion: completion
        )
    }
    
    /// 햅틱 피드백 최적화
    func optimizedHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        // 배터리 절약을 위한 햅틱 제한
        guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
        
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // MARK: - 성능 모니터링
    
    private var performanceMetrics: [String: Date] = [:]
    
    /// 성능 측정 시작
    func startPerformanceMeasurement(_ identifier: String) {
        performanceMetrics[identifier] = Date()
    }
    
    /// 성능 측정 종료 및 로깅
    func endPerformanceMeasurement(_ identifier: String) {
        guard let startTime = performanceMetrics[identifier] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        performanceMetrics.removeValue(forKey: identifier)
        
        DebugManager.shared.logPerformance("성능 측정 [\(identifier)]: \(String(format: "%.3f", duration))초")
        
        // 성능 경고 (1초 이상 소요 시)
        if duration > 1.0 {
            DebugManager.shared.warning("성능 경고 [\(identifier)]: \(String(format: "%.3f", duration))초 소요")
        }
    }
    
    // MARK: - 정리
    
    /// 리소스 정리
    func cleanup() {
        debounceTimers.values.forEach { $0.invalidate() }
        debounceTimers.removeAll()
        
        batchTimers.values.forEach { $0.invalidate() }
        batchTimers.removeAll()
        batchOperations.removeAll()
        
        smartCache.removeAll()
        performanceMetrics.removeAll()
        
        DebugManager.shared.logPerformance("PerformanceOptimizer 정리 완료")
    }
}

// MARK: - UIView Extension for Performance
extension UIView {
    /// 성능 최적화된 코너 라운딩
    func optimizedCornerRadius(_ radius: CGFloat) {
        layer.cornerRadius = radius
        layer.masksToBounds = true
        
        // 성능 최적화를 위한 래스터화 (정적인 뷰에만 사용)
        if !isUserInteractionEnabled {
            layer.shouldRasterize = true
            layer.rasterizationScale = UIScreen.main.scale
        }
    }
    
    /// 성능 최적화된 그림자
    func optimizedShadow(color: UIColor = .black, 
                        opacity: Float = 0.1, 
                        offset: CGSize = CGSize(width: 0, height: 2), 
                        radius: CGFloat = 4) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offset
        layer.shadowRadius = radius
        
        // 성능 최적화를 위한 그림자 경로 설정
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
    }
}