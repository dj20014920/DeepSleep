import Foundation

/// 로그 설정 관리자
/// 런타임에 로그 레벨과 카테고리별 로깅을 제어할 수 있습니다
final class LogConfiguration {
    static let shared = LogConfiguration()
    
    private init() {
        setupDefaultConfiguration()
    }
    
    /// 기본 로그 설정
    private func setupDefaultConfiguration() {
        #if DEBUG
        // 개발 빌드에서는 info 레벨 이상만 표시 (debug 로그는 제외)
        UnifiedLogger.shared.setMinimumLogLevel(.info)
        
        // 특정 카테고리 비활성화 (너무 빈번한 로그)
        disabledCategories = [
            .performance,  // 성능 관련 로그 비활성화
            .battery,      // 배터리 관련 로그 비활성화
            .memory        // 메모리 관련 로그 비활성화
        ]
        #else
        // 프로덕션 빌드에서는 warning 이상만 표시
        UnifiedLogger.shared.setMinimumLogLevel(.warning)
        #endif
    }
    
    /// 비활성화된 로그 카테고리
    private var disabledCategories: Set<UnifiedLogger.Category> = []
    
    /// 특정 카테고리 로깅 활성화/비활성화
    func setCategory(_ category: UnifiedLogger.Category, enabled: Bool) {
        if enabled {
            disabledCategories.remove(category)
        } else {
            disabledCategories.insert(category)
        }
    }
    
    /// 카테고리가 활성화되어 있는지 확인
    func isCategoryEnabled(_ category: UnifiedLogger.Category) -> Bool {
        return !disabledCategories.contains(category)
    }
    
    /// 모든 로그 활성화 (디버깅용)
    func enableAllLogs() {
        UnifiedLogger.shared.setMinimumLogLevel(.debug)
        disabledCategories.removeAll()
        UnifiedLogger.shared.info("모든 로그 활성화됨", category: .system)
    }
    
    /// 성능 관련 로그만 활성화
    func enablePerformanceLogs() {
        disabledCategories.remove(.performance)
        disabledCategories.remove(.battery)
        disabledCategories.remove(.memory)
        UnifiedLogger.shared.info("성능 관련 로그 활성화됨", category: .system)
    }
    
    /// 최소 로그만 표시 (중요한 것만)
    func setMinimalLogging() {
        UnifiedLogger.shared.setMinimumLogLevel(.warning)
        disabledCategories = [
            .performance,
            .battery,
            .memory,
            .cache,
            .timer,
            .appLifecycle
        ]
        UnifiedLogger.shared.warning("최소 로깅 모드 활성화됨", category: .system)
    }
    
    /// 현재 로그 설정 상태 출력
    func printCurrentConfiguration() {
        print("=== 현재 로그 설정 ===")
        print("최소 로그 레벨: info") // UnifiedLogger에서 직접 가져올 수 없으므로 하드코딩
        print("비활성화된 카테고리: \(disabledCategories.map { $0.rawValue }.joined(separator: ", "))")
        print("==================")
    }
}

// MARK: - UnifiedLogger 확장
extension UnifiedLogger {
    /// LogConfiguration과 연동하여 카테고리 필터링 적용
    func log(
        _ message: String,
        level: LogLevel,
        category: Category,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // 카테고리가 비활성화되어 있으면 로그하지 않음
        guard LogConfiguration.shared.isCategoryEnabled(category) else { return }
        
        // 기존 로그 메서드 호출
        switch level {
        case .debug:
            debug(message, category: category, file: file, function: function, line: line)
        case .info:
            info(message, category: category, file: file, function: function, line: line)
        case .warning:
            warning(message, category: category, file: file, function: function, line: line)
        case .error:
            error(message, category: category, file: file, function: function, line: line)
        case .critical:
            critical(message, category: category, file: file, function: function, line: line)
        }
    }
}