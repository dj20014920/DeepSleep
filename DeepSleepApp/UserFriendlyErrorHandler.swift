import UIKit
import Foundation

/// 사용자 친화적인 에러 처리 및 피드백 시스템
final class UserFriendlyErrorHandler {
    static let shared = UserFriendlyErrorHandler()
    
    private init() {}
    
    // MARK: - 사용자 친화적 에러 메시지
    
    /// 에러를 사용자가 이해하기 쉬운 메시지로 변환
    func getUserFriendlyMessage(for error: Error) -> String {
        // AIServiceError 우선 처리
        if let ai = error as? AIServiceError {
            switch ai {
            case .serverError(let code):
                if code == 401 || code == 403 {
                    return "프록시 인증이 필요해요. 🔐\n개발 환경이라면 PROXY_BASE_URL/CLIENT_PROXY_HMAC_SECRET를 확인하고, 문제가 지속되면 잠시 후 다시 시도해주세요."
                } else {
                    return "일시적인 서버 오류가 발생했어요. 🔧\n잠시 후 다시 시도해주세요. (코드 \(code))"
                }
            case .usageLimitExceeded(let msg):
                return msg
            case .quotaExceeded:
                return "모델 할당량을 초과했어요. 내일 다시 이용해주세요."
            case .unauthorized:
                return "인증이 만료되었거나 키가 유효하지 않아요. 설정을 확인해주세요."
            default:
                break
            }
        }
        
        // 일부 런타임/동시성 경로에서 Swift Error → NSError로 브리징될 수 있음
        // 이 경우에도 401/403을 정확히 인식해 사용자에게 안내
        let desc = String(describing: error)
        let lower = (error.localizedDescription + " " + desc).lowercased()
        if lower.contains("401") || lower.contains("403") {
            if lower.contains("server") || lower.contains("서버") || lower.contains("servererror") {
                return "프록시 인증이 필요해요. 🔐\n개발 환경이라면 PROXY_BASE_URL/CLIENT_PROXY_HMAC_SECRET를 확인하고, 문제가 지속되면 잠시 후 다시 시도해주세요."
            }
        }
        
        switch error {
        case let urlError as URLError:
            return handleNetworkError(urlError)
        case let nsError as NSError:
            return handleNSError(nsError)
        default:
            return handleGenericError(error)
        }
    }
    
    private func handleNetworkError(_ error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "인터넷 연결을 확인해주세요. 📶\n오프라인에서도 기본 기능은 사용 가능합니다."
        case .timedOut:
            return "서버 응답이 지연되고 있어요. ⏰\n잠시 후 다시 시도해주세요."
        case .cannotFindHost, .cannotConnectToHost:
            return "서버에 연결할 수 없어요. 🔌\n네트워크 상태를 확인해주세요."
        case .networkConnectionLost:
            return "네트워크 연결이 끊어졌어요. 📡\n연결을 확인하고 다시 시도해주세요."
        default:
            return "네트워크 오류가 발생했어요. 🌐\n연결 상태를 확인해주세요."
        }
    }
    
    private func handleNSError(_ error: NSError) -> String {
        switch error.domain {
        case NSCocoaErrorDomain:
            return handleCocoaError(error)
        case "CoreDataError":
            return "데이터 저장 중 문제가 발생했어요. 💾\n앱을 다시 시작해보세요."
        default:
            return "일시적인 문제가 발생했어요. 🔄\n잠시 후 다시 시도해주세요."
        }
    }
    
    private func handleCocoaError(_ error: NSError) -> String {
        switch error.code {
        case NSFileReadNoSuchFileError:
            return "필요한 파일을 찾을 수 없어요. 📁\n앱을 다시 설치해보세요."
        case NSFileWriteFileExistsError:
            return "파일이 이미 존재해요. 📄\n다른 이름으로 저장해보세요."
        case NSFileWriteNoPermissionError:
            return "파일 저장 권한이 없어요. 🔒\n설정에서 권한을 확인해주세요."
        default:
            return "파일 처리 중 문제가 발생했어요. 📂\n다시 시도해주세요."
        }
    }
    
    private func handleGenericError(_ error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("memory") {
            return "메모리가 부족해요. 🧠\n다른 앱을 종료하고 다시 시도해주세요."
        } else if errorDescription.contains("permission") || errorDescription.contains("authorization") {
            return "권한이 필요해요. 🔐\n설정에서 권한을 허용해주세요."
        } else if errorDescription.contains("timeout") {
            return "시간이 초과되었어요. ⏱️\n네트워크 상태를 확인하고 다시 시도해주세요."
        } else {
            return "예상치 못한 문제가 발생했어요. 😅\n잠시 후 다시 시도해주세요."
        }
    }
    
    // MARK: - 사용자 피드백 표시
    
    /// 에러를 사용자에게 친화적으로 표시
    func showError(_ error: Error, in viewController: UIViewController, 
                   title: String = "앗, 문제가 생겼어요!", 
                   actionTitle: String = "확인",
                   retryAction: (() -> Void)? = nil) {
        
        let message = getUserFriendlyMessage(for: error)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // 온디바이스 설정 요구 에러인 경우 "친구 선택" 진입 액션 추가 (DRY: 중앙 처리)
        if let aiErr = error as? AIServiceError, case .requiresOnDeviceSetup = aiErr {
            let friendAction = UIAlertAction(title: "친구 선택", style: .default) { _ in
                // 이미 선택 화면이면 중복 진입 방지
                if viewController is AIModelSelectionViewController { return }
                let selectorVC = AIModelSelectionViewController()
                // 네비게이션 스택이 있으면 push, 없으면 모달
                if let nav = viewController.navigationController {
                    nav.pushViewController(selectorVC, animated: true)
                } else {
                    let nav = UINavigationController(rootViewController: selectorVC)
                    nav.modalPresentationStyle = .automatic
                    viewController.present(nav, animated: true)
                }
            }
            alert.addAction(friendAction)
        }
        
        // 기본 확인 버튼
        alert.addAction(UIAlertAction(title: actionTitle, style: .default))
        
        // 재시도 버튼 (옵션)
        if let retryAction = retryAction {
            alert.addAction(UIAlertAction(title: "다시 시도", style: .default) { _ in
                retryAction()
            })
        }
        
        // 도움말 버튼 (심각한 에러의 경우)
        if isSerious(error) {
            alert.addAction(UIAlertAction(title: "도움말", style: .default) { _ in
                self.showHelpForError(error, in: viewController)
            })
        }
        
        DispatchQueue.main.async {
            viewController.present(alert, animated: true)
        }
        
        // 에러 로깅
        UnifiedLogger.shared.error("사용자 에러 표시: \(error.localizedDescription)")
    }
    
    /// 성공 메시지 표시
    func showSuccess(_ message: String, in viewController: UIViewController) {
        let alert = UIAlertController(title: "성공! 🎉", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "좋아요!", style: .default))
        
        DispatchQueue.main.async {
            viewController.present(alert, animated: true)
        }
    }
    
    /// 정보 메시지 표시
    func showInfo(_ message: String, in viewController: UIViewController, title: String = "알림") {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        
        DispatchQueue.main.async {
            viewController.present(alert, animated: true)
        }
    }
    
    // MARK: - 도움말 시스템
    
    private func isSerious(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        return errorDescription.contains("memory") || 
               errorDescription.contains("permission") ||
               errorDescription.contains("file") ||
               (error as NSError).domain == NSCocoaErrorDomain
    }
    
    private func showHelpForError(_ error: Error, in viewController: UIViewController) {
        let helpMessage = getHelpMessage(for: error)
        let helpAlert = UIAlertController(title: "도움말 💡", message: helpMessage, preferredStyle: .alert)
        helpAlert.addAction(UIAlertAction(title: "이해했어요", style: .default))
        
        DispatchQueue.main.async {
            viewController.present(helpAlert, animated: true)
        }
    }
    
    private func getHelpMessage(for error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("memory") {
            return """
            메모리 부족 해결 방법:
            
            1. 다른 앱들을 종료해주세요
            2. 기기를 재시작해보세요
            3. 저장 공간을 확보해주세요
            4. 앱을 최신 버전으로 업데이트해주세요
            
            그래도 문제가 지속되면 고객센터로 문의해주세요.
            """
        } else if errorDescription.contains("permission") {
            return """
            권한 설정 방법:
            
            1. 설정 앱을 열어주세요
            2. 리플릿(Leaflet) 앱을 찾아주세요
            3. 필요한 권한들을 허용해주세요
            4. 앱을 다시 시작해주세요
            
            권한은 앱의 핵심 기능을 위해 필요합니다.
            """
        } else {
            return """
            일반적인 문제 해결 방법:
            
            1. 앱을 완전히 종료하고 다시 시작해주세요
            2. 인터넷 연결을 확인해주세요
            3. 기기를 재시작해보세요
            4. 앱을 최신 버전으로 업데이트해주세요
            
            문제가 계속되면 고객센터로 연락해주세요.
            """
        }
    }
}

// MARK: - UIViewController Extension
extension UIViewController {
    /// 편리한 에러 표시 메서드
    func showFriendlyError(_ error: Error, retryAction: (() -> Void)? = nil) {
        UserFriendlyErrorHandler.shared.showError(error, in: self, retryAction: retryAction)
    }
    
    /// 편리한 성공 메시지 표시 메서드
    func showSuccess(_ message: String) {
        UserFriendlyErrorHandler.shared.showSuccess(message, in: self)
    }
    
    /// 편리한 정보 메시지 표시 메서드
    func showInfo(_ message: String, title: String = "알림") {
        UserFriendlyErrorHandler.shared.showInfo(message, in: self, title: title)
    }
}
