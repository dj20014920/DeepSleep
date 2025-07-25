import Foundation

/// 감정 분석 채팅 화면의 ViewModel 프로토콜
protocol EmotionAnalysisViewModelProtocol: AnyObject {
    // MARK: - Properties
    
    /// 현재 대화 내역
    var chatHistory: [(isUser: Bool, message: String)] { get }
    
    /// 감정 패턴 데이터
    var emotionPatternData: String { get }
    
    /// 로딩 상태 업데이트 핸들러
    var onLoadingStateChanged: ((Bool) -> Void)? { get set }
    
    /// 새 메시지 추가 핸들러
    var onNewMessageAdded: ((Bool, String) -> Void)? { get set }
    
    /// 에러 발생 핸들러
    var onError: ((Error) -> Void)? { get set }
    
    // MARK: - Methods
    
    /// 초기 감정 분석 수행
    func performInitialAnalysis() async
    
    /// 사용자 메시지 전송
    func sendUserMessage(_ message: String) async
    
    /// 빠른 액션 처리
    func handleQuickAction(title: String, intent: String) async
    
    /// AI 추천 처리
    func handleAIRecommendation() async
    
    /// 로컬 추천 처리
    func handleLocalRecommendation() async
    
    /// 피드백 제출
    func submitFeedback(for recommendationId: String, score: Int, comment: String?) async
}

// MARK: - Error Types
public enum EmotionAnalysisViewModelError: LocalizedError {
    case invalidEmotionData
    case aiServiceUnavailable
    case networkError(Error)
    case recommendationFailed
    case feedbackSubmissionFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidEmotionData:
            return "감정 데이터가 올바르지 않습니다."
        case .aiServiceUnavailable:
            return "AI 서비스를 일시적으로 사용할 수 없습니다."
        case .networkError(let error):
            return "네트워크 오류가 발생했습니다: \(error.localizedDescription)"
        case .recommendationFailed:
            return "추천을 생성하는 중 오류가 발생했습니다."
        case .feedbackSubmissionFailed:
            return "피드백을 제출하는 중 오류가 발생했습니다."
        }
    }
}

// MARK: - Constants
public struct EmotionAnalysisViewModelConstants {
    public static let maxRetryAttempts = 3
    public static let retryDelay: TimeInterval = 1.0
    public static let maxMessageLength = 1000
    public static let maxHistoryItems = 50
}

// MARK: - Helper Types
/// 사운드 컴포넌트 모델
public struct EmotionAnalysisViewModelSoundComponent {
    public let soundId: String
    public let version: Int
    public let volume: Float
    
    public init(soundId: String, version: Int, volume: Float) {
        self.soundId = soundId
        self.version = version
        self.volume = volume
    }
}

 