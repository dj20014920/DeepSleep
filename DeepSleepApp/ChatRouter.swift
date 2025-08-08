import UIKit

// MARK: - 🚀 채팅 화면 통합 관리 라우터
enum ChatRouter {
    
    /// 채팅 라우팅 컨텍스트 타입 (ChatMode enum과 구분하기 위해 다른 이름 사용)
    enum RoutingContext {
        case general
        case diaryAnalysis(diary: EmotionDiary)
        case emotionAnalysis(emotion: String)
        case monthlyPattern(data: String)
        case feedbackAnalysis
        case customContext(title: String, initialMessage: String)
    }
    
    /// 통합된 채팅 화면 생성 (컨텍스트 지원)
    static func chatViewController(context: RoutingContext = .general) -> ChatViewController {
        let vc = ChatViewController()
        vc.chatManager = ChatManager.shared
        
        // 컨텍스트에 따른 초기 설정 (ChatMode enum 사용)
        switch context {
        case .general:
            vc.chatContext = .generalConversation
            
        case .diaryAnalysis(let diary):
            vc.chatContext = .emotionDiaryAnalysis
            vc.initialDiaryData = diary
            
        case .emotionAnalysis(let emotion):
            vc.chatContext = .emotionAnalysis
            vc.initialEmotion = emotion
            
        case .monthlyPattern(let data):
            vc.chatContext = .monthlyPatternAnalysis
            vc.initialPatternData = data
            
        case .feedbackAnalysis:
            vc.chatContext = .feedbackAnalysis
            
        case .customContext(let title, let initialMessage):
            // 커스텀 컨텍스트의 경우 title에 따라 적절한 ChatMode enum 매핑
            vc.chatContext = ChatMode.from(title)
            vc.initialSystemMessage = initialMessage
        }
        
        return vc
    }
    
    /// 기존 호환성을 위한 메서드
    static func chatViewController() -> ChatViewController {
        return chatViewController(context: .general)
    }
    
    /// 채팅 화면 모달 프레젠테이션 설정
    static func configurePresentationStyle(_ vc: ChatViewController) {
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .coverVertical
    }
    
    /// 편의 메서드: Navigation Push
    static func pushChatViewController(from sourceVC: UIViewController, animated: Bool = true) {
        let chatVC = chatViewController()
        sourceVC.navigationController?.pushViewController(chatVC, animated: animated)
    }
    
    /// 편의 메서드: Modal Present
    static func presentChatViewController(from sourceVC: UIViewController, animated: Bool = true) {
        let chatVC = chatViewController()
        configurePresentationStyle(chatVC)
        sourceVC.present(chatVC, animated: animated)
    }
}

// MARK: - 🚀 ChatViewController 디버그 헬퍼
extension ChatRouter {
    static func debugInfo() -> String {
        let hasCache = false // 캐시 제거로 인해 항상 false
        let messageCount = ChatManager.shared.messages.count
        
        return """
        🔍 [ChatRouter 디버그 정보]
        • 캐시된 VC: \(hasCache ? "있음" : "없음")
        • 메시지 수: \(messageCount)개
        • ChatManager: \(ChatManager.shared)
        """
    }
} 
