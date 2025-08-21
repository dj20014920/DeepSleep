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
        
        // Stop existing animations
        stopAnimation()
        
        // Update text and colors based on state
        switch state {
        case .pro:
            label.text = "Pro"
            setupRainbowColors()
            
        case .free:
            label.text = "Free"
            setupGrayscaleColors()
            
        case .trial(let days):
            if days >= 0 {
                label.text = "D-\(days) | 7일 무료체험"
            } else {
                label.text = "체험 만료"
            }
            setupRainbowColors()  // Trial uses rainbow like Pro
        }
        
        // Apply initial gradient
        updateGradientText()
        
        // Start smooth animation
        startAnimation()
    }
    
    /// Determine current badge state from subscription center
    public static func determineBadgeState() -> BadgeState {
        let center = SubscriptionStatusCenter.shared
        
        // Check trial status first
        if let monthlyDays = StoreKitSubscriptionManager.shared.trialDaysRemaining(for: .monthly),
           monthlyDays >= 0 {
            return .trial(days: monthlyDays)
        }
        
        if let yearlyDays = StoreKitSubscriptionManager.shared.trialDaysRemaining(for: .yearly),
           yearlyDays >= 0 {
            return .trial(days: yearlyDays)
        }
        
        // Check premium status (includes refund grace period)
        if center.isPremium {
            return .pro
        }
        
        return .free
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
        stopAnimation()
        
        // Use CADisplayLink for buttery smooth 60fps animation
        displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
        displayLink?.add(to: .main, forMode: .common)
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
    
    deinit {
        stopAnimation()
    }
}

