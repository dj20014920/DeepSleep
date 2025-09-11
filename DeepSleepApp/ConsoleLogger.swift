import Foundation
import os.log

/// 🖥️ 향상된 콘솔 로깅 시스템
/// API 연결 상태, 성능 지표, 오류 등을 체계적으로 로깅하는 시스템
class ConsoleLogger {
    
    // MARK: - 싱글톤 패턴
    static let shared = ConsoleLogger()
    private init() {
        setupLogging()
    }
    
    // MARK: - 로그 레벨 정의
    enum LogLevel: String, CaseIterable {
        case debug = "🔍 DEBUG"
        case info = "ℹ️  INFO"
        case warning = "⚠️  WARN"
        case error = "❌ ERROR"
        case success = "✅ SUCCESS"
        case api = "🚀 API"
        case performance = "⚡ PERF"
        case security = "🔐 SEC"
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .success: return "✅"
            case .api: return "🚀"
            case .performance: return "⚡"
            case .security: return "🔐"
            }
        }
    }
    
    // MARK: - 로그 카테고리
    enum LogCategory: String {
        case appLifecycle = "AppLifecycle"
        case apiConnection = "APIConnection"
        case security = "Security"
        case performance = "Performance"
        case userInterface = "UI"
        case dataStorage = "DataStorage"
        case networking = "Networking"
        case audio = "Audio"
        case ai = "AI"
        
        var prefix: String {
            return "[\(rawValue)]"
        }
    }
    
    // MARK: - 설정
    private var isLoggingEnabled = true
    private var minimumLogLevel: LogLevel = .debug
    private var shouldLogToFile = false
    private var logFileURL: URL?
    
    // MARK: - OS 로그 (iOS 12+)
    @available(iOS 12.0, *)
    private lazy var osLog = OSLog(subsystem: "com.deepsleep.app", category: "console")
    
    // MARK: - 로깅 설정
    private func setupLogging() {
        // 디버그 빌드에서만 상세 로깅
        #if DEBUG
        isLoggingEnabled = true
        minimumLogLevel = .debug
        #else
        isLoggingEnabled = true
        minimumLogLevel = .info
        #endif
        
        // 로그 파일 설정 (선택적)
        setupLogFile()
        
        // 초기화 로그는 UnifiedLogger로 위임
        UnifiedLogger.shared.info("🖥️ [ConsoleLogger] 로깅 시스템 초기화 완료", category: .system)
    }
    
    private func setupLogFile() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        logFileURL = documentsPath.appendingPathComponent("deepsleep_console.log")
        
        #if DEBUG
        shouldLogToFile = true
        print("📄 [ConsoleLogger] 로그 파일: \(logFileURL?.path ?? "N/A")")
        #endif
    }
    
    // MARK: - 메인 로깅 메서드
    func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .appLifecycle,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isLoggingEnabled else { return }

        // UnifiedLogger로 위임하여 중복 출력 방지 및 일관성 유지
        let ucat: UnifiedLogger.Category = {
            switch category {
            case .appLifecycle: return .appLifecycle
            case .apiConnection: return .api
            case .security: return .security
            case .performance: return .performance
            case .userInterface: return .ui
            case .dataStorage: return .storage
            case .networking: return .network
            case .audio: return .audio
            case .ai: return .ai
            }
        }()
        
        switch level {
        case .debug:
            UnifiedLogger.shared.debug(message, category: ucat, file: file, function: function, line: line)
        case .info, .success, .api, .performance:
            UnifiedLogger.shared.info(message, category: ucat, file: file, function: function, line: line)
        case .warning:
            UnifiedLogger.shared.warning(message, category: ucat, file: file, function: function, line: line)
        case .error, .security:
            UnifiedLogger.shared.error(message, category: ucat, file: file, function: function, line: line)
        }
        
        // 별도의 print / OSLog / 파일로그를 추가로 하지 않음(중복 방지)
    }
    
    // MARK: - 편의 메서드들
    
    func debug(_ message: String, category: LogCategory = .appLifecycle) {
        log(message, level: .debug, category: category)
    }
    
    func info(_ message: String, category: LogCategory = .appLifecycle) {
        log(message, level: .info, category: category)
    }
    
    func warning(_ message: String, category: LogCategory = .appLifecycle) {
        log(message, level: .warning, category: category)
    }
    
    func error(_ message: String, category: LogCategory = .appLifecycle) {
        log(message, level: .error, category: category)
    }
    
    func success(_ message: String, category: LogCategory = .appLifecycle) {
        log(message, level: .success, category: category)
    }
    
    func api(_ message: String) {
        log(message, level: .api, category: .apiConnection)
    }
    
    func performance(_ message: String) {
        log(message, level: .performance, category: .performance)
    }
    
    func security(_ message: String) {
        log(message, level: .security, category: .security)
    }
    
    // MARK: - API 연결 상태 로깅 전용
    
    func logAPIStart(_ apiName: String) {
        let border = String(repeating: "=", count: 40)
        print("\n\(border)")
        api("🚀 \(apiName) API 연결 테스트 시작")
        print("\(border)")
    }
    
    func logAPISuccess(_ apiName: String, responseTime: TimeInterval) {
        let responseTimeMs = String(format: "%.0fms", responseTime * 1000)
        api("✅ \(apiName) 연결 성공 (\(responseTimeMs))")
    }
    
    func logAPIFailure(_ apiName: String, error: String) {
        api("❌ \(apiName) 연결 실패: \(error)")
    }
    
    func logAPIEnd() {
        let border = String(repeating: "=", count: 40)
        print("\(border)")
        api("🏁 API 연결 테스트 완료")
        print("\(border)\n")
    }
    
    // MARK: - 성능 로깅 전용
    
    func logMemoryUsage(_ usage: Double, context: String = "") {
        let formattedUsage = String(format: "%.1f MB", usage)
        let contextSuffix = context.isEmpty ? "" : " (\(context))"
        performance("💾 메모리 사용량: \(formattedUsage)\(contextSuffix)")
    }
    
    func logExecutionTime(_ duration: TimeInterval, operation: String) {
        let formattedTime = String(format: "%.2fms", duration * 1000)
        performance("⏱️ \(operation) 실행 시간: \(formattedTime)")
    }
    
    func logNetworkLatency(_ latency: TimeInterval, endpoint: String) {
        let formattedLatency = String(format: "%.0fms", latency * 1000)
        performance("🌐 \(endpoint) 응답 시간: \(formattedLatency)")
    }
    
    // MARK: - 보안 로깅 전용
    
    func logSecurityEvent(_ event: String, severity: SecuritySeverity = .medium) {
        let severityEmoji = severity.emoji
        security("\(severityEmoji) \(event)")
    }
    
    enum SecuritySeverity {
        case low, medium, high, critical
        
        var emoji: String {
            switch self {
            case .low: return "🟡"
            case .medium: return "🟠"
            case .high: return "🔴"
            case .critical: return "🚨"
            }
        }
    }
    
    // MARK: - 그룹 로깅 (여러 관련 로그를 그룹화)
    
    func logGroup<T>(_ title: String, category: LogCategory = .appLifecycle, operation: () throws -> T) rethrows -> T {
        let border = String(repeating: "-", count: 30)
        print("\n\(border)")
        info("📂 \(title) 시작", category: category)
        print("\(border)")
        
        let startTime = Date()
        
        defer {
            let duration = Date().timeIntervalSince(startTime)
            print("\(border)")
            info("📂 \(title) 완료 (\(String(format: "%.2fms", duration * 1000)))", category: category)
            print("\(border)\n")
        }
        
        return try operation()
    }
    
    func logGroupAsync<T>(_ title: String, category: LogCategory = .appLifecycle, operation: () async throws -> T) async rethrows -> T {
        let border = String(repeating: "-", count: 30)
        print("\n\(border)")
        info("📂 \(title) 시작", category: category)
        print("\(border)")
        
        let startTime = Date()
        
        defer {
            let duration = Date().timeIntervalSince(startTime)
            print("\(border)")
            info("📂 \(title) 완료 (\(String(format: "%.2fms", duration * 1000)))", category: category)
            print("\(border)\n")
        }
        
        return try await operation()
    }
    
    // MARK: - 포맷팅 메서드
    
    private func formatLogMessage(
        message: String,
        level: LogLevel,
        category: LogCategory,
        timestamp: String,
        file: String,
        function: String,
        line: Int
    ) -> String {
        let levelString = level.rawValue
        let categoryString = category.prefix
        
        #if DEBUG
        // 디버그 모드: 상세 정보 포함
        return "\(timestamp) \(levelString) \(categoryString) \(message) [\(file):\(line) \(function)]"
        #else
        // 릴리즈 모드: 간단한 형태
        return "\(timestamp) \(levelString) \(categoryString) \(message)"
        #endif
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
    
    // MARK: - OS 로그 연동
    
    @available(iOS 12.0, *)
    private func logToOSLog(_ message: String, level: LogLevel, category: LogCategory) {
        let osLogType: OSLogType
        
        switch level {
        case .debug:
            osLogType = .debug
        case .info, .success, .api:
            osLogType = .info
        case .warning, .performance:
            osLogType = .default
        case .error, .security:
            osLogType = .error
        }
        
        os_log("%{public}@", log: osLog, type: osLogType, "\(category.prefix) \(message)")
    }
    
    // MARK: - 파일 로그
    
    private func writeToLogFile(_ message: String) {
        guard let logFileURL = logFileURL else { return }
        
        let logEntry = "\(message)\n"
        
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
        
        do {
            let fileHandle = try FileHandle(forWritingTo: logFileURL)
            fileHandle.seekToEndOfFile()
            fileHandle.write(logEntry.data(using: .utf8) ?? Data())
            fileHandle.closeFile()
        } catch {
            print("❌ [ConsoleLogger] 파일 로그 쓰기 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 로그 파일 관리
    
    func getLogFileContent() -> String? {
        guard let logFileURL = logFileURL else { return nil }
        
        do {
            return try String(contentsOf: logFileURL, encoding: .utf8)
        } catch {
            log("로그 파일 읽기 실패: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
    
    func clearLogFile() {
        guard let logFileURL = logFileURL else { return }
        
        do {
            try "".write(to: logFileURL, atomically: true, encoding: .utf8)
            log("로그 파일 정리 완료", level: .info)
        } catch {
            log("로그 파일 정리 실패: \(error.localizedDescription)", level: .error)
        }
    }
    
    // MARK: - 설정 메서드
    
    func setLoggingEnabled(_ enabled: Bool) {
        isLoggingEnabled = enabled
        log("로깅 시스템 \(enabled ? "활성화" : "비활성화")", level: .info)
    }
    
    func setMinimumLogLevel(_ level: LogLevel) {
        minimumLogLevel = level
        info("최소 로그 레벨 설정: \(level.rawValue)")
    }
}

// MARK: - 전역 편의 함수들

/// 빠른 로그 출력을 위한 전역 함수들
func logInfo(_ message: String, category: ConsoleLogger.LogCategory = .appLifecycle) {
    ConsoleLogger.shared.info(message, category: category)
}

func logError(_ message: String, category: ConsoleLogger.LogCategory = .appLifecycle) {
    ConsoleLogger.shared.error(message, category: category)
}

func logAPI(_ message: String) {
    ConsoleLogger.shared.api(message)
}

func logPerformance(_ message: String) {
    ConsoleLogger.shared.performance(message)
}

func logSecurity(_ message: String) {
    ConsoleLogger.shared.security(message)
}