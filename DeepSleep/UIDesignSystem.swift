import UIKit

// MARK: - 디자인 시스템
struct UIDesignSystem {
    
    // MARK: - 색상 시스템
    struct Colors {
        // Primary Colors
        static let primary = UIColor.systemBlue
        static let primaryLight = UIColor.systemBlue.withAlphaComponent(0.1)
        static let primaryDark = UIColor(red: 0.0, green: 0.48, blue: 0.84, alpha: 1.0)
        
        // Background Colors
        static let background = UIColor.systemBackground
        static let secondaryBackground = UIColor.secondarySystemBackground
        static let tertiaryBackground = UIColor.tertiarySystemBackground
        
        // Text Colors
        static let primaryText = UIColor.label
        static let secondaryText = UIColor.secondaryLabel
        static let tertiaryText = UIColor.tertiaryLabel
        
        // UI Element Colors
        static let separator = UIColor.separator
        static let border = UIColor.systemGray4
        static let shadow = UIColor.black.withAlphaComponent(0.1)
        
        // Status Colors
        static let success = UIColor.systemGreen
        static let warning = UIColor.systemOrange
        static let error = UIColor.systemRed
        static let info = UIColor.systemBlue
        
        // Emotion Colors
        static let happy = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
        static let sad = UIColor.systemBlue
        static let angry = UIColor.systemRed
        static let anxious = UIColor.systemOrange
        static let sleepy = UIColor.systemPurple
    }
    
    // MARK: - 폰트 시스템
    struct Fonts {
        // Title Fonts
        static let largeTitle = UIFont.systemFont(ofSize: 34, weight: .bold)
        static let title1 = UIFont.systemFont(ofSize: 28, weight: .bold)
        static let title2 = UIFont.systemFont(ofSize: 22, weight: .bold)
        static let title3 = UIFont.systemFont(ofSize: 20, weight: .semibold)
        
        // Body Fonts
        static let body = UIFont.systemFont(ofSize: 17, weight: .regular)
        static let bodyBold = UIFont.systemFont(ofSize: 17, weight: .semibold)
        static let callout = UIFont.systemFont(ofSize: 16, weight: .regular)
        static let subheadline = UIFont.systemFont(ofSize: 15, weight: .medium)
        
        // Small Fonts
        static let footnote = UIFont.systemFont(ofSize: 13, weight: .regular)
        static let caption1 = UIFont.systemFont(ofSize: 12, weight: .regular)
        static let caption2 = UIFont.systemFont(ofSize: 11, weight: .regular)
    }
    
    // MARK: - 간격 시스템
    struct Spacing {
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - 모서리 둥글기
    struct CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xl: CGFloat = 16
        static let circle: CGFloat = 50
    }
    
    // MARK: - 그림자
    struct Shadow {
        static func small() -> (color: CGColor, opacity: Float, offset: CGSize, radius: CGFloat) {
            return (Colors.shadow.cgColor, 0.1, CGSize(width: 0, height: 2), 4)
        }
        
        static func medium() -> (color: CGColor, opacity: Float, offset: CGSize, radius: CGFloat) {
            return (Colors.shadow.cgColor, 0.15, CGSize(width: 0, height: 4), 8)
        }
        
        static func large() -> (color: CGColor, opacity: Float, offset: CGSize, radius: CGFloat) {
            return (Colors.shadow.cgColor, 0.2, CGSize(width: 0, height: 8), 16)
        }
    }
}

// MARK: - UIView Extensions
extension UIView {
    func applyShadow(_ shadow: (color: CGColor, opacity: Float, offset: CGSize, radius: CGFloat)) {
        layer.shadowColor = shadow.color
        layer.shadowOpacity = shadow.opacity
        layer.shadowOffset = shadow.offset
        layer.shadowRadius = shadow.radius
        layer.masksToBounds = false
    }
    
    func addBorder(color: UIColor = UIDesignSystem.Colors.border, width: CGFloat = 1.0) {
        layer.borderColor = color.cgColor
        layer.borderWidth = width
    }
    
    func roundCorners(_ radius: CGFloat = UIDesignSystem.CornerRadius.medium) {
        layer.cornerRadius = radius
        layer.masksToBounds = true
    }
}

// MARK: - UIButton Extensions
extension UIButton {
    
    enum ButtonStyle {
        case primary
        case secondary
        case tertiary
        case danger
        case success
    }
    
    func applyStyle(_ style: ButtonStyle) {
        layer.cornerRadius = UIDesignSystem.CornerRadius.medium
        titleLabel?.font = UIDesignSystem.Fonts.bodyBold
        
        switch style {
        case .primary:
            backgroundColor = UIDesignSystem.Colors.primary
            setTitleColor(.white, for: .normal)
            setTitleColor(.white.withAlphaComponent(0.7), for: .highlighted)
            
        case .secondary:
            backgroundColor = UIDesignSystem.Colors.primaryLight
            setTitleColor(UIDesignSystem.Colors.primary, for: .normal)
            setTitleColor(UIDesignSystem.Colors.primaryDark, for: .highlighted)
            
        case .tertiary:
            backgroundColor = .clear
            setTitleColor(UIDesignSystem.Colors.primary, for: .normal)
            setTitleColor(UIDesignSystem.Colors.primaryDark, for: .highlighted)
            addBorder(color: UIDesignSystem.Colors.primary)
            
        case .danger:
            backgroundColor = UIDesignSystem.Colors.error
            setTitleColor(.white, for: .normal)
            setTitleColor(.white.withAlphaComponent(0.7), for: .highlighted)
            
        case .success:
            backgroundColor = UIDesignSystem.Colors.success
            setTitleColor(.white, for: .normal)
            setTitleColor(.white.withAlphaComponent(0.7), for: .highlighted)
        }
        
        // 공통 속성
        contentEdgeInsets = UIEdgeInsets(
            top: UIDesignSystem.Spacing.small,
            left: UIDesignSystem.Spacing.medium,
            bottom: UIDesignSystem.Spacing.small,
            right: UIDesignSystem.Spacing.medium
        )
    }
    
    func addTouchAnimation() {
        addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    
    @objc private func buttonTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func buttonTouchUp() {
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform.identity
        }
    }
}

// MARK: - UITextField Extensions
extension UITextField {
    func applyStandardStyle() {
        borderStyle = .none
        backgroundColor = UIDesignSystem.Colors.tertiaryBackground
        textColor = UIDesignSystem.Colors.primaryText
        font = UIDesignSystem.Fonts.body
        layer.cornerRadius = UIDesignSystem.CornerRadius.medium
        
        // 패딩 추가
        leftView = UIView(frame: CGRect(x: 0, y: 0, width: UIDesignSystem.Spacing.medium, height: frame.height))
        leftViewMode = .always
        rightView = UIView(frame: CGRect(x: 0, y: 0, width: UIDesignSystem.Spacing.medium, height: frame.height))
        rightViewMode = .always
        
        // 높이 설정
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 48).isActive = true
    }
}

// MARK: - UILabel Extensions
extension UILabel {
    func applyStyle(font: UIFont, color: UIColor = UIDesignSystem.Colors.primaryText) {
        self.font = font
        self.textColor = color
    }
    
    func setEmotionText(_ emotion: String) {
        let emotionMap: [String: (emoji: String, color: UIColor)] = [
            "happy": ("😊", UIDesignSystem.Colors.happy),
            "sad": ("😢", UIDesignSystem.Colors.sad),
            "angry": ("😠", UIDesignSystem.Colors.angry),
            "anxious": ("😰", UIDesignSystem.Colors.anxious),
            "sleepy": ("😴", UIDesignSystem.Colors.sleepy)
        ]
        
        if let emotionData = emotionMap[emotion.lowercased()] {
            text = "\(emotionData.emoji) \(emotion)"
            textColor = emotionData.color
        } else {
            text = emotion
            textColor = UIDesignSystem.Colors.primaryText
        }
    }
}

// MARK: - UISlider Extensions
extension UISlider {
    func applyStandardStyle() {
        minimumTrackTintColor = UIDesignSystem.Colors.primary
        maximumTrackTintColor = UIDesignSystem.Colors.border
        thumbTintColor = UIDesignSystem.Colors.primary
    }
}

// MARK: - UITableView Extensions
extension UITableView {
    func applyStandardStyle() {
        backgroundColor = UIDesignSystem.Colors.background
        separatorStyle = .none
        showsVerticalScrollIndicator = false
    }
}

// MARK: - UINavigationController Extensions
extension UINavigationController {
    func applyStandardStyle() {
        navigationBar.prefersLargeTitles = false
        navigationBar.tintColor = UIDesignSystem.Colors.primary
        navigationBar.titleTextAttributes = [
            .foregroundColor: UIDesignSystem.Colors.primaryText,
            .font: UIDesignSystem.Fonts.title3
        ]
    }
}

// MARK: - 햅틱 피드백 시스템
struct HapticFeedback {
    static func light() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
    
    static func medium() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
    }
    
    static func heavy() {
        let feedback = UIImpactFeedbackGenerator(style: .heavy)
        feedback.impactOccurred()
    }
    
    static func success() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
    
    static func warning() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.warning)
    }
    
    static func error() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.error)
    }
}

// MARK: - 애니메이션 시스템
struct Animations {
    static func fadeIn(_ view: UIView, duration: TimeInterval = 0.3) {
        view.alpha = 0
        UIView.animate(withDuration: duration) {
            view.alpha = 1
        }
    }
    
    static func fadeOut(_ view: UIView, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: duration, animations: {
            view.alpha = 0
        }) { _ in
            completion?()
        }
    }
    
    static func slideUp(_ view: UIView, duration: TimeInterval = 0.3) {
        let originalTransform = view.transform
        view.transform = CGAffineTransform(translationX: 0, y: 50)
        view.alpha = 0
        
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            view.transform = originalTransform
            view.alpha = 1
        }
    }
    
    static func bounce(_ view: UIView) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            view.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                view.transform = CGAffineTransform.identity
            }
        }
    }
} 