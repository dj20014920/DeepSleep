import UIKit

/// 메인 화면 상단 중앙에 표시되는 구독 상태 배지
public final class PremiumBadgeView: UIView {
    
    // MARK: - Badge State
    public enum BadgeState {
        case pro          // 유료 구독 (환불 유예기간 포함)
        case free         // 무료 사용자
        case trial(days: Int)  // 무료 체험 중 (남은 일수)
    }
    
    // MARK: - Properties
    private let label = UILabel()
    private var displayLink: CADisplayLink?
    private var currentState: BadgeState = .free
    private var gradientColors: [UIColor] = []
    private var animationProgress: CGFloat = 0
    private var toggleTimer: Timer?
    private var showCountdown: Bool = true
    
    // MARK: - Initialization
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup
    private func setup() {
        // Remove all background and border
        backgroundColor = .clear
        layer.borderWidth = 0
        clipsToBounds = false
        
        // Setup label
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .bold)
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(equalTo: widthAnchor),
            label.heightAnchor.constraint(equalTo: heightAnchor)
        ])
        
        // Set initial state
        let initialState = Self.determineBadgeState()
        updateState(initialState)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // Update gradient if needed
        updateGradientText()
    }
    
    // MARK: - State Management
    
    /// Update badge state and appearance
    public func updateState(_ state: BadgeState) {
        currentState = state
        
        // Stop existing animations only when 색상 팔레트가 바뀌는 경우
        stopAnimation()
        
        // Update text and colors based on state
        switch state {
        case .pro:
            label.text = "Pro"
            setupRainbowColors()
            stopTrialToggle()
        case .free:
            label.text = "Free"
            setupGrayscaleColors()
            stopTrialToggle()
        case .trial:
            // Trial: 무지개 그라데이션 유지 + 5초 토글 시작
            setupRainbowColors()
            startTrialToggle()
        }
        
        // Apply initial gradient
        updateGradientText()
        
        // Start smooth animation
        startAnimation()
    }
    
    /// Determine current badge state from subscription center
    public static func determineBadgeState() -> BadgeState {
        let center = SubscriptionStatusCenter.shared
        // trial/active 판단: 만료 예정일이 있고 7일 이내면 trial로 간주
        switch center.state {
        case .active(let premiumUntil), .gracePeriod(let premiumUntil):
            if let until = premiumUntil, until > Date() {
                let remaining = until.timeIntervalSinceNow
                let sevenDays: TimeInterval = 7 * 24 * 60 * 60
                if remaining <= sevenDays {
                    let days = Int(ceil(remaining / (24 * 60 * 60)))
                    return .trial(days: max(0, days))
                }
                return .pro
            }
            return center.isPremium ? .pro : .free
        case .refunded(let graceUntil):
            // 환불 유예도 프리미엄 취급
            if graceUntil > Date() { return .pro } else { return .free }
        case .expired:
            return .free
        case .free:
            return .free
        }
    }
    
    // MARK: - Color Configurations
    
    private func setupRainbowColors() {
        // Expanded color array for smoother gradients
        gradientColors = [
            UIColor.systemPink,
            blend(UIColor.systemPink, UIColor.systemRed),
            UIColor.systemRed,
            blend(UIColor.systemRed, UIColor.systemOrange),
            UIColor.systemOrange,
            blend(UIColor.systemOrange, UIColor.systemYellow),
            UIColor.systemYellow,
            blend(UIColor.systemYellow, UIColor.systemGreen),
            UIColor.systemGreen,
            blend(UIColor.systemGreen, UIColor.systemTeal),
            UIColor.systemTeal,
            blend(UIColor.systemTeal, UIColor.systemCyan),
            UIColor.systemCyan,
            blend(UIColor.systemCyan, UIColor.systemBlue),
            UIColor.systemBlue,
            blend(UIColor.systemBlue, UIColor.systemIndigo),
            UIColor.systemIndigo,
            blend(UIColor.systemIndigo, UIColor.systemPurple),
            UIColor.systemPurple,
            blend(UIColor.systemPurple, UIColor.systemPink),
            UIColor.systemPink  // Loop back
        ]
    }
    
    private func setupGrayscaleColors() {
        // Smooth grayscale gradient
        gradientColors = [
            UIColor(white: 0.3, alpha: 1.0),
            UIColor(white: 0.35, alpha: 1.0),
            UIColor(white: 0.4, alpha: 1.0),
            UIColor(white: 0.45, alpha: 1.0),
            UIColor(white: 0.5, alpha: 1.0),
            UIColor(white: 0.55, alpha: 1.0),
            UIColor(white: 0.6, alpha: 1.0),
            UIColor(white: 0.65, alpha: 1.0),
            UIColor(white: 0.7, alpha: 1.0),
            UIColor(white: 0.65, alpha: 1.0),
            UIColor(white: 0.6, alpha: 1.0),
            UIColor(white: 0.55, alpha: 1.0),
            UIColor(white: 0.5, alpha: 1.0),
            UIColor(white: 0.45, alpha: 1.0),
            UIColor(white: 0.4, alpha: 1.0),
            UIColor(white: 0.35, alpha: 1.0),
            UIColor(white: 0.3, alpha: 1.0)  // Loop back
        ]
    }
    
    // Helper function to blend two colors
    private func blend(_ color1: UIColor, _ color2: UIColor) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return UIColor(
            red: (r1 + r2) / 2,
            green: (g1 + g2) / 2,
            blue: (b1 + b2) / 2,
            alpha: (a1 + a2) / 2
        )
    }
    
    // MARK: - Gradient Text Update
    
    private func updateGradientText() {
        guard let text = label.text, !text.isEmpty else { return }
        
        let attributed = NSMutableAttributedString(string: text)
        let textLength = text.count
        
        // Apply smooth gradient to text
        for i in 0..<textLength {
            // Calculate smooth color position
            let position = (CGFloat(i) / CGFloat(textLength)) + animationProgress
            let colorIndex = Int(position * CGFloat(gradientColors.count)) % gradientColors.count
            let nextIndex = (colorIndex + 1) % gradientColors.count
            
            // Interpolate between colors for extra smoothness
            let fraction = (position * CGFloat(gradientColors.count)).truncatingRemainder(dividingBy: 1)
            let color = interpolateColor(from: gradientColors[colorIndex], to: gradientColors[nextIndex], fraction: fraction)
            
            attributed.addAttribute(
                .foregroundColor,
                value: color,
                range: NSRange(location: i, length: 1)
            )
        }
        
        label.attributedText = attributed
    }
    
    // Interpolate between two colors
    private func interpolateColor(from: UIColor, to: UIColor, fraction: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return UIColor(
            red: r1 + (r2 - r1) * fraction,
            green: g1 + (g2 - g1) * fraction,
            blue: b1 + (b2 - b1) * fraction,
            alpha: a1 + (a2 - a1) * fraction
        )
    }
    
    // MARK: - Animations
    
    private func startAnimation() {
        // Use CADisplayLink for buttery smooth 60fps animation
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
            displayLink?.add(to: .main, forMode: .common)
        }
    }
    
    @objc private func updateAnimation() {
        // Very slow increment for smooth animation
        animationProgress += 0.0075  // Much slower than before
        if animationProgress > 1.0 {
            animationProgress -= 1.0
        }
        updateGradientText()
    }
    
    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // MARK: - Trial Toggle
    private func startTrialToggle() {
        stopTrialToggle()
        showCountdown = true
        toggleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateTrialLabel()
            self.showCountdown.toggle()
        }
        // 즉시 한 번 표시 업데이트
        updateTrialLabel()
    }
    private func stopTrialToggle() {
        toggleTimer?.invalidate()
        toggleTimer = nil
    }
    private func updateTrialLabel() {
        guard case .trial = currentState else { return }
        if showCountdown, let until = trialExpirationDateWithin7Days() {
            label.text = self.formatCountdown(to: until)
        } else {
            label.text = "7일 무료체험"
        }
        // 그라데이션은 유지, 텍스트만 교체 후 즉시 적용
        updateGradientText()
    }
    private func trialExpirationDateWithin7Days() -> Date? {
        switch SubscriptionStatusCenter.shared.state {
        case .active(let until), .gracePeriod(let until):
            guard let u = until, u > Date() else { return nil }
            let sevenDays: TimeInterval = 7 * 24 * 60 * 60
            if u.timeIntervalSinceNow <= sevenDays { return u }
            return nil
        default:
            return nil
        }
    }
    private func formatCountdown(to date: Date) -> String {
        let now = Date()
        let interval = max(0, Int(date.timeIntervalSince(now)))
        let days = interval / (24 * 3600)
        let hours = (interval % (24 * 3600)) / 3600
        let minutes = (interval % 3600) / 60
        return String(format: "D-%02d:%02d:%02d", days, hours, minutes)
    }
    
    deinit {
        stopAnimation()
    }
}

