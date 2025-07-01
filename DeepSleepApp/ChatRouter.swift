import UIKit

// MARK: - 🚀 채팅 화면 통합 관리 라우터
enum ChatRouter {
    // 캐시 제거: 항상 새 인스턴스 반환
    static func chatViewController() -> ChatViewController {
        let vc = ChatViewController()
        vc.chatManager = ChatManager.shared
        return vc
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
