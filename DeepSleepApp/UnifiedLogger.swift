import Foundation
import os.log

/// 🚀 **통합 로깅 시스템**
/// ConsoleLogger, RemoteLogger, DebugManager를 하나로 통합한 최적화된 로거
/// 2025년 배터리 효율성 최적화 및 메모리 누수 방지 적용
public final class UnifiedLogger {
    
    // MARK: - 싱글톤
    public static let shared = UnifiedLogger()
    private init() {
        setupLogger()
    }
    
    // MARK: - 로그 레벨
    public enum LogLevel: Int, CaseIterable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
        
        var prefix: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARN"
            case .error: return "ERROR"
            case .critical: return "CRITICAL"
            }
        }
    }
    
    // MARK: - 로그 카테고리
    public enum Category: String, CaseIterable {
        case api = "🚀 API"
        case ui = "🎨 UI"
        case ai = "🧠 AI"
        case network = "🌐 Network"
        case memory = "💾 Memory"
        case audio = "🎵 Audio"
        case system = "⚙️ System"
        case cache = "🗄️ Cache"
        case emotion = "😊 Emotion"
        case chat = "💬 Chat"
        case scene = "📱 Scene"
        case timer = "⏰ Timer"
        case preset = "🎛️ Preset"
        case todo = "📝 Todo"
        case diary = "📔 Diary"
        case feedback = "📊 Feedback"
        case security = "🔐 Security"
        case performance = "⚡ Performance"
        case battery = "🔋 Battery"
        case storage = "💽 Storage"
        case appLifecycle = "🔄 AppLifecycle"
        case coreData = "🗃️ CoreData"
        
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
    private lazy var osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "DeepSleep", category: "unified")
    
    // MARK: - 로그 버퍼 (원격 로깅용)
    private var logBuffer: [LogEntry] = []
    private let maxBufferSize = 100
    private let logQueue = DispatchQueue(label: "unified.logger.queue", qos: .utility)
    
    private struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let category: Category
        let message: String
        let file: String
        let function: String
        let line: Int
    }
    
    // MARK: - 로거 설정
    private func setupLogger() {
        #if DEBUG
        isLoggingEnabled = true
        minimumLogLevel = .warning  // 디버그 모드에서도 경고 이상만 출력
        shouldLogToFile = true
        #else
        isLoggingEnabled = true
        minimumLogLevel = .error    // 릴리즈 모드에서는 에러만 출력
        shouldLogToFile = false
        #endif
        
        setupLogFile()
        // UnifiedLogger 초기화 완료
    }
    
    private func setupLogFile() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        logFileURL = documentsPath.appendingPathComponent("deepsleep_unified.log")
        
        #if DEBUG
        if let logPath = logFileURL?.path {
            debug("📄 로그 파일 위치: \(logPath)", category: .system)
        }
        #endif
    }
    
    // MARK: - 핵심 로깅 메서드
    private func log(
        _ message: String,
        level: LogLevel,
        category: Category,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isLoggingEnabled && level.rawValue >= minimumLogLevel.rawValue else { return }
        
        // 배터리 효율성을 위해 백그라운드 큐에서 처리
        logQueue.async { [weak self] in
            self?.performLogging(message, level: level, category: category, file: file, function: function, line: line)
        }
    }
    
    private func performLogging(
        _ message: String,
        level: LogLevel,
        category: Category,
        file: String,
        function: String,
        line: Int
    ) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = Date()
        let timestampString = DateFormatter.unifiedTimestamp.string(from: timestamp)
        
        let logMessage = "\(timestampString) \(level.emoji) \(category.prefix) \(fileName):\(line) \(function) - \(message)"
        
        // 콘솔 출력
        print(logMessage)
        
        // OS 로그
        if #available(iOS 12.0, *) {
            let osLogType: OSLogType
            switch level {
            case .debug: osLogType = .debug
            case .info: osLogType = .info
            case .warning: osLogType = .default
            case .error, .critical: osLogType = .error
            }
            os_log("%{public}@", log: osLog, type: osLogType, logMessage)
        }
        
        // 파일 로깅 (디버그 빌드만)
        if shouldLogToFile {
            writeToFile(logMessage)
        }
        
        // 로그 버퍼에 추가 (원격 로깅용)
        addToBuffer(timestamp: timestamp, level: level, category: category, message: message, file: fileName, function: function, line: line)
    }
    
    private func writeToFile(_ message: String) {
        guard let logFileURL = logFileURL else { return }
        
        do {
            let logData = (message + "\n").data(using: .utf8) ?? Data()
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(logData)
                fileHandle.closeFile()
            } else {
                try logData.write(to: logFileURL)
            }
        } catch {
            print("❌ [UnifiedLogger] 파일 쓰기 실패: \(error)")
        }
    }
    
    private func addToBuffer(timestamp: Date, level: LogLevel, category: Category, message: String, file: String, function: String, line: Int) {
        let entry = LogEntry(timestamp: timestamp, level: level, category: category, message: message, file: file, function: function, line: line)
        
        logBuffer.append(entry)
        
        // 버퍼 크기 제한
        if logBuffer.count > maxBufferSize {
            logBuffer.removeFirst(logBuffer.count - maxBufferSize)
        }
    }
    
    // MARK: - 공개 로깅 메서드
    
    /// 디버그 로그
    public func debug(_ message: String, category: Category = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// 정보 로그
    public func info(_ message: String, category: Category = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// 경고 로그
    public func warning(_ message: String, category: Category = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// 에러 로그
    public func error(_ message: String, category: Category = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// 치명적 에러 로그
    public func critical(_ message: String, category: Category = .system, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - 편의 메서드 (기존 로거들과의 호환성)
    
    /// API 시작 로그
    public func logAPIStart(_ apiName: String, file: String = #file, function: String = #function, line: Int = #line) {
        info("🚀 \(apiName) API 호출 시작", category: .api, file: file, function: function, line: line)
    }
    
    /// API 성공 로그
    public func logAPISuccess(_ apiName: String, responseTime: TimeInterval, file: String = #file, function: String = #function, line: Int = #line) {
        let timeString = String(format: "%.0fms", responseTime * 1000)
        info("✅ \(apiName) API 성공 (\(timeString))", category: .api, file: file, function: function, line: line)
    }
    
    /// API 실패 로그
    public func logAPIFailure(_ apiName: String, error: String, file: String = #file, function: String = #function, line: Int = #line) {
        self.error("❌ \(apiName) API 실패: \(error)", category: .api, file: file, function: function, line: line)
    }
    
    /// UI 이벤트 로그
    public func logUI(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .ui, file: file, function: function, line: line)
    }
    
    /// Todo 관련 로그
    public func logTodo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .todo, file: file, function: function, line: line)
    }
    
    /// 사용자 액션 로그
    public func logUserAction(action: String, details: [String: Any] = [:], file: String = #file, function: String = #function, line: Int = #line) {
        let detailsString = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
        info("👤 사용자 액션: \(action) - \(detailsString)", category: .ui, file: file, function: function, line: line)
    }
    
    /// AI 요청 로그
    public func logAIRequest(prompt: String, response: String?, error: Error?, file: String = #file, function: String = #function, line: Int = #line) {
        if let error = error {
            self.error("🧠 AI 요청 실패: \(error.localizedDescription)", category: .ai, file: file, function: function, line: line)
        } else {
            info("🧠 AI 요청 성공 - Prompt: \(prompt.prefix(100))...", category: .ai, file: file, function: function, line: line)
        }
    }
    
    /// 보안 사고 로그
    public func logSecurityIncident(issues: [Any], context: String, timestamp: Date, file: String = #file, function: String = #function, line: Int = #line) {
        let issueDescriptions = issues.map { String(describing: $0) }.joined(separator: ", ")
        critical("🔐 보안 사고 감지: \(context) - 이슈: \(issueDescriptions)", category: .security, file: file, function: function, line: line)
    }
    
    // MARK: - 성능 모니터링
    
    /// 성능 메트릭 로그 (값 포함)
    public func logPerformance(_ metric: String, value: Double, unit: String = "", file: String = #file, function: String = #function, line: Int = #line) {
        info("⚡ \(metric): \(value)\(unit)", category: .performance, file: file, function: function, line: line)
    }
    
    /// 성능 메트릭 로그 (메시지만)
    public func logPerformance(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info("⚡ \(message)", category: .performance, file: file, function: function, line: line)
    }
    
    /// 메모리 사용량 로그
    public func logMemoryUsage(_ usage: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug("💾 메모리 사용량: \(usage)", category: .memory, file: file, function: function, line: line)
    }
    
    /// 배터리 상태 로그
    public func logBatteryState(_ state: String, file: String = #file, function: String = #function, line: Int = #line) {
        info("🔋 배터리 상태: \(state)", category: .battery, file: file, function: function, line: line)
    }
    
    // MARK: - 설정 메서드
    
    /// 로그 레벨 설정
    func setMinimumLogLevel(_ level: LogLevel) {
        minimumLogLevel = level
        info("📊 최소 로그 레벨 변경: \(level.prefix)", category: .system)
    }
    
    /// 로깅 활성화/비활성화
    func setLoggingEnabled(_ enabled: Bool) {
        isLoggingEnabled = enabled
        if enabled {
            info("✅ 로깅 시스템 활성화", category: .system)
        }
    }
    
    // MARK: - 정리 메서드
    
    /// 로그 버퍼 정리
    func clearLogBuffer() {
        logQueue.async { [weak self] in
            self?.logBuffer.removeAll()
        }
    }
    
    /// 로그 파일 내용 반환 (디버깅용)
    func getLogFileContents() -> String? {
        guard let logFileURL = logFileURL else { return nil }
        return try? String(contentsOf: logFileURL)
    }
}

// MARK: - DateFormatter 확장
extension DateFormatter {
    static let unifiedTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - 레거시 호환성을 위한 전역 함수들
/// ConsoleLogger 마이그레이션을 위한 호환성 함수
@available(*, deprecated, message: "Use UnifiedLogger.shared.info() instead")
func legacyConsoleLog(_ message: String, category: String = "System") {
    let logCategory: UnifiedLogger.Category
    switch category.lowercased() {
    case "api": logCategory = .api
    case "ui": logCategory = .ui
    case "network": logCategory = .network
    default: logCategory = .system
    }
    UnifiedLogger.shared.info(message, category: logCategory)
}

/// DebugManager 마이그레이션을 위한 호환성 함수
@available(*, deprecated, message: "Use UnifiedLogger.shared.debug() instead")
func legacyDebugLog(_ message: String, category: String = "System") {
    let logCategory: UnifiedLogger.Category
    switch category.lowercased() {
    case "ui": logCategory = .ui
    case "ai": logCategory = .ai
    case "network": logCategory = .network
    case "memory": logCategory = .memory
    case "audio": logCategory = .audio
    case "emotion": logCategory = .emotion
    case "chat": logCategory = .chat
    case "todo": logCategory = .todo
    case "diary": logCategory = .diary
    default: logCategory = .system
    }
    UnifiedLogger.shared.debug(message, category: logCategory)
}