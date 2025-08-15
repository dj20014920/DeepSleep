import Foundation

// MARK: - Session Data Models for Core Data Integration
// All core models moved to SharedModels.swift as Single Source of Truth

// Import all models from SharedModels.swift
// StoredChatMessage, PresetFeedback, BehaviorEvent, BehaviorEventType,
// UnifiedSession, SessionMetadata, LocalAIContext, EmotionHistoryItem,
// BehaviorPattern, TimePreference, ChatSession, ChatSessionMetadata
// are now defined in SharedModels.swift
// MARK: - Migration Support Models

/// 피드백 데이터 래퍼 (마이그레이션용)
public struct PresetFeedbackWrapper: Codable {
    public let feedback: PresetFeedback
    
    public init(feedback: PresetFeedback) {
        self.feedback = feedback
    }
}

/// 사용자 세션 모델 (UserBehaviorAnalytics 마이그레이션용)
public struct UserSession: Codable, Identifiable {
    public let id: UUID
    public let presetName: String
    public let volumes: [Float]
    public let versions: [Int]
    public let emotion: String
    public let startTime: Date
    public let endTime: Date
    public let duration: TimeInterval
    public let completionRate: Float
    public let interactionEvents: [InteractionEvent]
    public let contextData: ContextData
    
    public init(
        id: UUID = UUID(),
        presetName: String,
        volumes: [Float] = [],
        versions: [Int] = [],
        emotion: String,
        startTime: Date,
        endTime: Date,
        duration: TimeInterval,
        completionRate: Float,
        interactionEvents: [InteractionEvent] = [],
        contextData: ContextData = ContextData()
    ) {
        self.id = id
        self.presetName = presetName
        self.volumes = volumes
        self.versions = versions
        self.emotion = emotion
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.completionRate = completionRate
        self.interactionEvents = interactionEvents
        self.contextData = contextData
    }
}

/// 상호작용 이벤트 (마이그레이션용)
public struct InteractionEvent: Codable {
    public let type: String
    public let timestamp: Date
    public let data: [String: String]
    
    public init(type: String, timestamp: Date = Date(), data: [String: String] = [:]) {
        self.type = type
        self.timestamp = timestamp
        self.data = data
    }
}

/// 컨텍스트 데이터 (마이그레이션용)
public struct ContextData: Codable {
    public let deviceInfo: [String: String]
    public let appVersion: String
    public let timestamp: Date
    
    public init(
        deviceInfo: [String: String] = [:],
        appVersion: String = "1.0.0",
        timestamp: Date = Date()
    ) {
        self.deviceInfo = deviceInfo
        self.appVersion = appVersion
        self.timestamp = timestamp
    }
}
// MARK: - Error Handling

/// SessionManager 전용 에러 타입
public enum SessionManagerError: Error, LocalizedError {
    case saveFailure(underlying: Error)
    case fetchFailure(underlying: Error)
    case sessionNotFound(id: String)
    case migrationFailure(underlying: Error)
    case cacheCorruption
    case coreDataUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .saveFailure(let error):
            return "데이터 저장에 실패했습니다: \(error.localizedDescription)"
        case .fetchFailure(let error):
            return "데이터 조회에 실패했습니다: \(error.localizedDescription)"
        case .sessionNotFound(let id):
            return "세션을 찾을 수 없습니다 (ID: \(id))"
        case .migrationFailure(let error):
            return "데이터 마이그레이션에 실패했습니다: \(error.localizedDescription)"
        case .cacheCorruption:
            return "캐시 데이터가 손상되었습니다"
        case .coreDataUnavailable:
            return "데이터베이스에 접근할 수 없습니다"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .saveFailure:
            return "기기를 재시작하거나 저장 공간을 확보해주세요."
        case .fetchFailure:
            return "네트워크 연결을 확인하고 다시 시도해주세요."
        case .sessionNotFound:
            return "새로운 세션을 생성하거나 다른 세션을 선택해주세요."
        case .migrationFailure:
            return "앱을 재설치하거나 고객센터에 문의해주세요."
        case .cacheCorruption:
            return "앱을 재시작해주세요."
        case .coreDataUnavailable:
            return "기기를 재시작하고 다시 시도해주세요."
        }
    }
}