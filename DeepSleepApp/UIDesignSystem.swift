import UIKit

// MARK: - 디자인 시스템
public struct UIDesignSystem {
    
    // MARK: - 색상 시스템 (다크모드: 블랙&화이트, 일반모드: 밝은 파스텔톤)
    struct Colors {
        // Primary Colors - 다크모드와 일반모드 구분
        static var primary: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.white // 다크모드에서 흰색
                default:
                    return UIColor.systemBlue // 일반모드에서 파란색
                }
            }
        }
        
        static let primaryLight = UIColor.systemBlue.withAlphaComponent(0.1)
        static let primaryDark = UIColor(red: 0.0, green: 0.48, blue: 0.84, alpha: 1.0)
        
        // Background Colors - 다크모드는 완전 검은색, 일반모드는 밝은 파스텔
        static let background = UIColor.white // 라이트: 흰색, 다크: 검은색
        static let secondaryBackground = UIColor.secondarySystemBackground 
        static let tertiaryBackground = UIColor.tertiarySystemBackground 
        static let groupedBackground = UIColor.systemGroupedBackground 
        
        // 개선된 배경색들 - 다크모드는 완전 검은색, 일반모드는 밝은 파스텔
        static var adaptiveBackground: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.black // 완전한 검은색
                default:
                    return UIColor.white // 순수 하얀색
                }
            }
        }
        
        static var adaptiveSecondaryBackground: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.black // 완전한 검은색
                default:
                    return UIColor.white // 순수 하얀색
                }
            }
        }
        
        static var adaptiveTertiaryBackground: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) // 아주 어두운 회색 (버튼용)
                default:
                    return UIColor.systemGray6 // 일반모드에서는 시스템 기본 회색
                }
            }
        }
        
        // Text Colors - 다크모드는 흰색, 일반모드는 자동
        static var primaryText: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.white // 완전한 흰색
                default:
                    return UIColor.label // 시스템 기본
                }
            }
        }
        
        static var secondaryText: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.lightGray // 밝은 회색
                default:
                    return UIColor.secondaryLabel // 시스템 기본
                }
            }
        }
        
        static var tertiaryText: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.gray // 회색
                default:
                    return UIColor.tertiaryLabel // 시스템 기본
                }
            }
        }
        
        static let quaternaryText = UIColor.quaternaryLabel // 비활성화된 텍스트
        
        // UI Element Colors
        static var separator: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.darkGray // 어두운 회색
                default:
                    return UIColor.separator // 시스템 기본
                }
            }
        }
        
        static var border: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.darkGray // 어두운 회색
                default:
                    return UIColor.systemGray4 // 시스템 기본
                }
            }
        }
        
        static let shadow = UIColor.black.withAlphaComponent(0.1)
        
        // Fill Colors
        static var fill: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.darkGray // 어두운 회색
                default:
                    return UIColor.systemFill // 시스템 기본
                }
            }
        }
        
        static let secondaryFill = UIColor.secondarySystemFill
        static let tertiaryFill = UIColor.tertiarySystemFill
        static let quaternaryFill = UIColor.quaternarySystemFill
        
        // Status Colors
        static let success = UIColor.systemGreen
        static let warning = UIColor.systemOrange
        static let error = UIColor.systemRed
        static let info = UIColor.systemBlue
        
        // Accent Colors - 앱의 주요 테마 색상
        static let accent = UIColor.systemPurple  // 메인 테마 색상 (보라색)
        static let accentLight = UIColor.systemPurple.withAlphaComponent(0.1)  // 연한 보라색 (배경용)
        static let accentDark = UIColor.systemIndigo  // 진한 보라색/남색
        static let secondary = UIColor.systemPink  // 보조 색상 (핑크)
        
        // Settings UI Colors
        static var cardBackground: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) // 어두운 카드
                default:
                    return UIColor.systemBackground // 밝은 카드
                }
            }
        }
        
        static var separatorColor: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.darkGray
                default:
                    return UIColor.separator
                }
            }
        }
        
        static var tagBackground: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
                default:
                    return UIColor.systemGray6
                }
            }
        }
        
        // Emotion Colors - 다크모드에서도 잘 보이는 색상들
        static var emotionHappy: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.yellow // 밝은 노란색
                default:
                    return UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0)
                }
            }
        }
        
        static var emotionSad: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.cyan // 밝은 블루
                default:
                    return UIColor.systemBlue
                }
            }
        }
        
        static var emotionAngry: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.red // 밝은 레드
                default:
                    return UIColor.systemRed
                }
            }
        }
        
        static var emotionAnxious: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.orange // 밝은 오렌지
                default:
                    return UIColor.systemOrange
                }
            }
        }
        
        static var emotionSleepy: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.magenta // 밝은 퍼플
                default:
                    return UIColor.systemPurple
                }
            }
        }
        
        static var emotionNeutral: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.lightGray // 밝은 그레이
                default:
                    return UIColor.systemGray
                }
            }
        }
        
        // 호환성을 위한 기존 이름들
        static var happy: UIColor { emotionHappy }
        static var sad: UIColor { emotionSad }
        static var angry: UIColor { emotionAngry }
        static var anxious: UIColor { emotionAnxious }
        static var sleepy: UIColor { emotionSleepy }
        
        // Slider Colors - 다크모드에서 하얀색
        static var sliderTrack: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.white // 다크모드에서 하얀색
                default:
                    return UIColor.systemBlue // 일반모드에서 파란색
                }
            }
        }
        
        static var sliderThumb: UIColor {
            return UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.white // 다크모드에서 하얀색
                default:
                    return UIColor.systemBlue // 일반모드에서 파란색
                }
            }
        }
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
        if #available(iOS 15.0, *) {
            // iOS 15+ uses UIButtonConfiguration
            var config: UIButton.Configuration
            switch style {
            case .primary:
                config = UIButton.Configuration.filled()
                config.baseBackgroundColor = UIDesignSystem.Colors.primary
                config.baseForegroundColor = .white
            case .secondary:
                config = UIButton.Configuration.filled()
                config.baseBackgroundColor = UIDesignSystem.Colors.primaryLight
                config.baseForegroundColor = UIDesignSystem.Colors.primary
            case .tertiary:
                config = UIButton.Configuration.bordered()
                config.baseForegroundColor = UIDesignSystem.Colors.primary
            case .danger:
                config = UIButton.Configuration.filled()
                config.baseBackgroundColor = UIDesignSystem.Colors.error
                config.baseForegroundColor = .white
            case .success:
                config = UIButton.Configuration.filled()
                config.baseBackgroundColor = UIDesignSystem.Colors.success
                config.baseForegroundColor = .white
            }
            config.contentInsets = NSDirectionalEdgeInsets(
                top: UIDesignSystem.Spacing.small,
                leading: UIDesignSystem.Spacing.medium,
                bottom: UIDesignSystem.Spacing.small,
                trailing: UIDesignSystem.Spacing.medium
            )
            configuration = config
        } else {
            // iOS 14 and below
            contentEdgeInsets = UIEdgeInsets(
                top: UIDesignSystem.Spacing.small,
                left: UIDesignSystem.Spacing.medium,
                bottom: UIDesignSystem.Spacing.small,
                right: UIDesignSystem.Spacing.medium
            )
        }
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
        minimumTrackTintColor = UIDesignSystem.Colors.sliderTrack
        maximumTrackTintColor = UIDesignSystem.Colors.border
        thumbTintColor = UIDesignSystem.Colors.sliderThumb
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
