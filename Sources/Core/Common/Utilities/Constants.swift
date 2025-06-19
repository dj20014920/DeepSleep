import Foundation

// MARK: - Application Constants

public enum AppConstants {
    // MARK: - Cache Configuration
    public enum Cache {
        public static let keepDays = 14       // 캐시 보관 기간 (14일)
        public static let recentDaysRaw = 3   // "날것"으로 프롬프트에 포함하는 기간 (3일)
        public static let maxPromptTokens = 4000 // 프롬프트 최대 토큰 제한
        public static let maxCacheSizeMB = 500   // 최대 캐시 크기 (MB)
    }
    
    // MARK: - API Configuration
    public enum API {
        public static let requestTimeoutSeconds: TimeInterval = 30.0
        public static let maxRetryAttempts = 3
        public static let baseURL = "https://api.example.com" // Will be replaced with actual URL
    }
    
    // MARK: - UI Configuration
    public enum UI {
        public static let animationDuration: TimeInterval = 0.3
        public static let shortAnimationDuration: TimeInterval = 0.15
        public static let longAnimationDuration: TimeInterval = 0.6
        public static let cornerRadius: CGFloat = 12.0
        public static let smallCornerRadius: CGFloat = 8.0
        public static let largeCornerRadius: CGFloat = 16.0
    }
    
    // MARK: - Audio Configuration
    public enum Audio {
        public static let defaultVolume: Float = 0.8
        public static let fadeInDuration: TimeInterval = 1.0
        public static let fadeOutDuration: TimeInterval = 2.0
        public static let maxSimultaneousLayers = 5
        public static let bufferSize = 1024
    }
    
    // MARK: - AI Configuration
    public enum AI {
        public static let maxResponseLength = 2000
        public static let contextWindowSize = 4096
        public static let temperature: Float = 0.7
        public static let topP: Float = 0.9
        public static let maxTokens = 1000
    }
    
    // MARK: - Storage Configuration
    public enum Storage {
        public static let dataRetentionDays = 30
        public static let maxDatabaseSizeMB = 100
        public static let backupIntervalDays = 7
        public static let compressionEnabled = true
    }
    
    // MARK: - Performance Configuration
    public enum Performance {
        public static let maxConcurrentTasks = 3
        public static let backgroundTaskTimeout: TimeInterval = 30.0
        public static let memoryWarningThresholdMB = 50
        public static let lowPowerModeAdjustments = true
    }
}

// MARK: - Token Estimation Utility

public struct TokenEstimator {
    /// 대략적인 토큰 수 계산 (±4 char ≈ 1 token)
    public static func roughCount(_ text: String) -> Int {
        return max(1, text.count / 4)
    }
    
    /// 더 정확한 토큰 수 계산 (단어, 구두점, 공백 고려)
    public static func estimateTokens(for text: String) -> Int {
        let words = text.split(separator: " ").count
        let punctuation = text.filter { ".,!?;:()[]{}\"'".contains($0) }.count
        let spaces = text.filter { $0.isWhitespace }.count
        
        // 대략적인 계산: 단어 + 구두점/2 + 공백/4
        return max(1, words + punctuation / 2 + spaces / 4)
    }
    
    /// 한국어 텍스트에 특화된 토큰 수 계산
    public static func estimateKoreanTokens(for text: String) -> Int {
        let koreanCharCount = text.filter { $0.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7AF } }.count
        let otherCharCount = text.count - koreanCharCount
        
        // 한국어: 2.5 char ≈ 1 token, 기타: 4 char ≈ 1 token
        return max(1, Int(Double(koreanCharCount) / 2.5) + otherCharCount / 4)
    }
}

// MARK: - File System Utilities

public struct FileSystemConstants {
    public static let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    public static let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    public static let temporaryDirectory = FileManager.default.temporaryDirectory
    
    public static func soundsDirectory() -> URL {
        return documentsDirectory.appendingPathComponent("Sounds")
    }
    
    public static func presetsDirectory() -> URL {
        return documentsDirectory.appendingPathComponent("Presets")
    }
    
    public static func databaseDirectory() -> URL {
        return documentsDirectory.appendingPathComponent("Database")
    }
    
    public static func logsDirectory() -> URL {
        return cachesDirectory.appendingPathComponent("Logs")
    }
}

// MARK: - UserDefaults Keys

public enum UserDefaultsKeys {
    public static let isFirstLaunch = "isFirstLaunch"
    public static let lastCleanupDate = "lastCleanupDate"
    public static let userPreferences = "userPreferences"
    public static let soundSettings = "soundSettings"
    public static let aiSettings = "aiSettings"
    public static let privacySettings = "privacySettings"
    public static let analyticsEnabled = "analyticsEnabled"
    public static let notificationsEnabled = "notificationsEnabled"
    public static let darkModeEnabled = "darkModeEnabled"
    public static let hapticFeedbackEnabled = "hapticFeedbackEnabled"
} 