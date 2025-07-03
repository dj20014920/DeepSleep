import Foundation
import os.log

// MARK: - Debug Manager
/// 앱 전체의 디버그 로깅을 통합 관리하는 시스템
/// 프로덕션 빌드에서는 자동으로 비활성화됩니다.
class DebugManager {
    static let shared = DebugManager()
    
    private init() {}
    
    // MARK: - Configuration
    private let isDebugEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    // MARK: - Log Categories
    enum Category: String, CaseIterable {
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
        case error = "❌ Error"
        case success = "✅ Success"
        case warning = "⚠️ Warning"
        case info = "ℹ️ Info"
    }
    
    enum Level: Int, CaseIterable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
    
    // MARK: - Current Log Level (디버그 빌드에서만 활성화)
    private var currentLogLevel: Level = .debug
    
    // MARK: - Core Logging Method
    private func log(_ message: String, category: Category, level: Level, file: String = #file, function: String = #function, line: Int = #line) {
        guard isDebugEnabled && level.rawValue >= currentLogLevel.rawValue else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.debugTimestamp.string(from: Date())
        
        let logMessage = "\(timestamp) \(level.emoji) [\(category.rawValue)] \(fileName):\(line) \(function) - \(message)"
        
        // 콘솔 출력
        print(logMessage)
        
        // 향후 확장: 파일 로깅, 원격 로깅 등
        // logToFile(logMessage)
        // logToRemoteService(logMessage, level: level)
    }
    
    // MARK: - Public Logging Methods
    
    /// 일반 디버그 로그
    func debug(_ message: String, category: Category = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .debug, file: file, function: function, line: line)
    }
    
    /// 정보성 로그
    func info(_ message: String, category: Category = .info, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .info, file: file, function: function, line: line)
    }
    
    /// 경고 로그
    func warning(_ message: String, category: Category = .warning, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .warning, file: file, function: function, line: line)
    }
    
    /// 에러 로그
    func error(_ message: String, category: Category = .error, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .error, file: file, function: function, line: line)
    }
    
    // MARK: - Category-Specific Convenience Methods
    
    func logUI(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .ui, file: file, function: function, line: line)
    }
    
    func logAI(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .ai, file: file, function: function, line: line)
    }
    
    func logNetwork(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .network, file: file, function: function, line: line)
    }
    
    func logMemory(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .memory, file: file, function: function, line: line)
    }
    
    func logAudio(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .audio, file: file, function: function, line: line)
    }
    
    func logSystem(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .system, file: file, function: function, line: line)
    }
    
    func logCache(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .cache, file: file, function: function, line: line)
    }
    
    func logEmotion(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .emotion, file: file, function: function, line: line)
    }
    
    func logChat(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .chat, file: file, function: function, line: line)
    }
    
    func logScene(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .scene, file: file, function: function, line: line)
    }
    
    func logTimer(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .timer, file: file, function: function, line: line)
    }
    
    func logPreset(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .preset, file: file, function: function, line: line)
    }
    
    func logTodo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .todo, file: file, function: function, line: line)
    }
    
    func logDiary(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .diary, file: file, function: function, line: line)
    }
    
    func logFeedback(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .feedback, file: file, function: function, line: line)
    }
    
    func logSecurity(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .security, file: file, function: function, line: line)
    }
    
    func logPerformance(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, category: .performance, file: file, function: function, line: line)
    }
    
    // MARK: - Log Level Control
    func setLogLevel(_ level: Level) {
        currentLogLevel = level
    }
    
    // MARK: - Utility Methods
    func printAvailableCategories() {
        guard isDebugEnabled else { return }
        print("📋 Available Debug Categories:")
        Category.allCases.forEach { category in
            print("  - \(category.rawValue)")
        }
    }
    
    func printCurrentConfiguration() {
        guard isDebugEnabled else { return }
        print("🔧 Debug Manager Configuration:")
        print("  - Debug Enabled: \(isDebugEnabled)")
        print("  - Current Log Level: \(currentLogLevel.emoji) \(currentLogLevel)")
    }
}

// MARK: - Global Convenience Functions
/// 기존 print 문을 쉽게 대체할 수 있는 글로벌 함수들

func debugLog(_ message: String, category: DebugManager.Category = .info) {
    DebugManager.shared.debug(message, category: category)
}

func infoLog(_ message: String, category: DebugManager.Category = .info) {
    DebugManager.shared.info(message, category: category)
}

func warningLog(_ message: String, category: DebugManager.Category = .warning) {
    DebugManager.shared.warning(message, category: category)
}

func errorLog(_ message: String, category: DebugManager.Category = .error) {
    DebugManager.shared.error(message, category: category)
}

// MARK: - DateFormatter Extension
private extension DateFormatter {
    static let debugTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Migration Helper
/// 기존 print 문을 새로운 시스템으로 마이그레이션하기 위한 헬퍼
struct DebugMigrationHelper {
    
    /// 기존 print 문 패턴을 분석하여 적절한 카테고리 제안
    static func suggestCategory(for message: String) -> DebugManager.Category {
        let lowercased = message.lowercased()
        
        if lowercased.contains("ui") || lowercased.contains("view") || lowercased.contains("button") {
            return .ui
        } else if lowercased.contains("ai") || lowercased.contains("llm") || lowercased.contains("claude") {
            return .ai
        } else if lowercased.contains("network") || lowercased.contains("api") || lowercased.contains("request") {
            return .network
        } else if lowercased.contains("memory") || lowercased.contains("cache") {
            return .memory
        } else if lowercased.contains("audio") || lowercased.contains("sound") || lowercased.contains("preset") {
            return .audio
        } else if lowercased.contains("emotion") || lowercased.contains("감정") {
            return .emotion
        } else if lowercased.contains("chat") || lowercased.contains("message") || lowercased.contains("대화") {
            return .chat
        } else if lowercased.contains("scene") || lowercased.contains("delegate") {
            return .scene
        } else if lowercased.contains("timer") || lowercased.contains("타이머") {
            return .timer
        } else if lowercased.contains("todo") || lowercased.contains("할 일") {
            return .todo
        } else if lowercased.contains("diary") || lowercased.contains("일기") {
            return .diary
        } else if lowercased.contains("feedback") || lowercased.contains("피드백") {
            return .feedback
        } else if lowercased.contains("error") || lowercased.contains("fail") || lowercased.contains("오류") {
            return .error
        } else if lowercased.contains("success") || lowercased.contains("완료") || lowercased.contains("성공") {
            return .success
        } else if lowercased.contains("warning") || lowercased.contains("경고") {
            return .warning
        } else {
            return .info
        }
    }
} 