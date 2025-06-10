import UIKit

// MARK: - 🚀 채팅 화면 통합 관리 라우터
enum ChatRouter {
    private static var cachedVC: ChatViewController?
    
    /// 싱글턴 ChatViewController 반환 (상태 보존)
    static func chatViewController() -> ChatViewController {
        if let vc = cachedVC {
            print("✅ [ChatRouter] 기존 채팅 화면 재사용")
            return vc
        }
        
        // 새 ChatViewController 생성 (ChatManager.shared 주입)
        let vc = ChatViewController()
        vc.chatManager = ChatManager.shared
        cachedVC = vc
        
        print("🆕 [ChatRouter] 새 채팅 화면 생성 및 캐시")
        return vc
    }
    
    /// 캐시된 ChatViewController 해제 (메모리 정리용)
    static func releaseCachedViewController() {
        cachedVC = nil
        print("🗑️ [ChatRouter] 캐시된 채팅 화면 해제")
    }
    
    /// 현재 캐시된 VC가 있는지 확인
    static var hasCachedViewController: Bool {
        return cachedVC != nil
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
        let hasCache = hasCachedViewController
        let messageCount = ChatManager.shared.messages.count
        
        return """
        🔍 [ChatRouter 디버그 정보]
        • 캐시된 VC: \(hasCache ? "있음" : "없음")
        • 메시지 수: \(messageCount)개
        • ChatManager: \(ChatManager.shared)
        """
    }
} 