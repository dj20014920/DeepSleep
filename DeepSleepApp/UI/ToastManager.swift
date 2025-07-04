import UIKit

/// 앱 전체에서 사용할 수 있는 Toast 메시지 시스템
class ToastManager {
    static let shared = ToastManager()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 간단한 토스트 메시지 표시
    func showToast(message: String, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async {
            self.presentToast(message: message, duration: duration, style: .default)
        }
    }
    
    /// 성공 토스트 메시지 표시
    func showSuccess(message: String, duration: TimeInterval = 2.5) {
        DispatchQueue.main.async {
            self.presentToast(message: message, duration: duration, style: .success)
        }
    }
    
    /// 에러 토스트 메시지 표시
    func showError(message: String, duration: TimeInterval = 3.5) {
        DispatchQueue.main.async {
            self.presentToast(message: message, duration: duration, style: .error)
        }
    }
    
    /// 경고 토스트 메시지 표시
    func showWarning(message: String, duration: TimeInterval = 3.0) {
        DispatchQueue.main.async {
            self.presentToast(message: message, duration: duration, style: .warning)
        }
    }
    
    // MARK: - Private Methods
    
    private func presentToast(message: String, duration: TimeInterval, style: ToastStyle) {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            DebugManager.shared.warning("Toast 표시 실패: Key Window를 찾을 수 없음")
            return
        }
        
        let toastView = createToastView(message: message, style: style)
        window.addSubview(toastView)
        
        // 초기 위치 설정 (화면 하단 밖)
        toastView.transform = CGAffineTransform(translationX: 0, y: 100)
        toastView.alpha = 0
        
        // 애니메이션으로 등장
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            toastView.transform = .identity
            toastView.alpha = 1.0
        }
        
        // 일정 시간 후 사라짐
        UIView.animate(withDuration: 0.3, delay: duration, options: .curveEaseIn) {
            toastView.transform = CGAffineTransform(translationX: 0, y: 100)
            toastView.alpha = 0
        } completion: { _ in
            toastView.removeFromSuperview()
        }
        
        DebugManager.shared.logUI("Toast 표시: \(message)")
    }
    
    private func createToastView(message: String, style: ToastStyle) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = style.backgroundColor
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.2
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 아이콘 추가
        if let iconName = style.iconName {
            let iconImageView = UIImageView(image: UIImage(systemName: iconName))
            iconImageView.tintColor = style.textColor
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(iconImageView)
            
            NSLayoutConstraint.activate([
                iconImageView.widthAnchor.constraint(equalToConstant: 20),
                iconImageView.heightAnchor.constraint(equalToConstant: 20)
            ])
        }
        
        // 메시지 라벨
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        messageLabel.textColor = style.textColor
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .left
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(messageLabel)
        
        containerView.addSubview(stackView)
        
        // Safe Area 가져오기
        let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        let safeAreaInsets = window?.safeAreaInsets ?? .zero
        
        NSLayoutConstraint.activate([
            // Container constraints
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: window!.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: window!.trailingAnchor, constant: -20),
            containerView.centerXAnchor.constraint(equalTo: window!.centerXAnchor),
            containerView.bottomAnchor.constraint(equalTo: window!.bottomAnchor, constant: -(safeAreaInsets.bottom + 20)),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 350),
            
            // Stack view constraints
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
        
        return containerView
    }
}

// MARK: - ToastStyle
enum ToastStyle {
    case `default`
    case success
    case error
    case warning
    
    var backgroundColor: UIColor {
        switch self {
        case .default:
            return UIColor.systemGray6.withAlphaComponent(0.95)
        case .success:
            return UIColor.systemGreen.withAlphaComponent(0.9)
        case .error:
            return UIColor.systemRed.withAlphaComponent(0.9)
        case .warning:
            return UIColor.systemOrange.withAlphaComponent(0.9)
        }
    }
    
    var textColor: UIColor {
        switch self {
        case .default:
            return UIDesignSystem.Colors.primaryText
        case .success, .error, .warning:
            return UIColor.white
        }
    }
    
    var iconName: String? {
        switch self {
        case .default:
            return nil
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Global Function (for backward compatibility)
/// 전역 함수로 간편하게 토스트 메시지 표시
func showToast(message: String) {
    ToastManager.shared.showToast(message: message)
}

// MARK: - UIViewController Extension
extension UIViewController {
    /// 뷰 컨트롤러에서 간편하게 토스트 메시지 표시
    func showToast(message: String, duration: TimeInterval = 3.0) {
        ToastManager.shared.showToast(message: message, duration: duration)
    }
    
    func showSuccessToast(message: String) {
        ToastManager.shared.showSuccess(message: message)
    }
    
    func showErrorToast(message: String) {
        ToastManager.shared.showError(message: message)
    }
    
    func showWarningToast(message: String) {
        ToastManager.shared.showWarning(message: message)
    }
} 