import UIKit

/// 메인 화면 상단 중앙에 표시되는 프리미엄 D-배지
public final class PremiumBadgeView: UIView {
    private let label = UILabel()
    private let gradient = CAGradientLayer()
    private let shine = CAGradientLayer()

    public var daysRemaining: Int = 7 { didSet { updateText() } }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        layer.masksToBounds = true
        layer.cornerRadius = 16
        backgroundColor = .clear

        gradient.colors = [
            UIColor.systemPink.cgColor,
            UIColor.systemOrange.cgColor,
            UIColor.systemYellow.cgColor,
            UIColor.systemGreen.cgColor,
            UIColor.systemBlue.cgColor,
            UIColor.systemPurple.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = bounds
        gradient.cornerRadius = 16
        layer.addSublayer(gradient)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
        blur.isUserInteractionEnabled = false
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        blur.layer.cornerRadius = 16
        blur.clipsToBounds = true

        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        // Shine layer
        shine.colors = [UIColor.white.withAlphaComponent(0).cgColor,
                        UIColor.white.withAlphaComponent(0.6).cgColor,
                        UIColor.white.withAlphaComponent(0).cgColor]
        shine.startPoint = CGPoint(x: 0, y: 0.5)
        shine.endPoint = CGPoint(x: 1, y: 0.5)
        shine.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width, height: bounds.height)
        layer.addSublayer(shine)

        updateText()
        startAnimations()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        shine.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width, height: bounds.height)
    }

    private func updateText() {
        label.text = daysRemaining >= 0 ? "D-\(daysRemaining)" : "만료"
    }

    private func startAnimations() {
        // Rainbow shimmer
        let gradientAnimation = CABasicAnimation(keyPath: "locations")
        gradientAnimation.fromValue = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
        gradientAnimation.toValue = [0.2, 0.4, 0.6, 0.8, 1.0, 1.2]
        gradientAnimation.duration = 3.5
        gradientAnimation.repeatCount = .infinity
        gradient.add(gradientAnimation, forKey: "rainbow_move")

        // Shine sweep
        let shineAnimation = CABasicAnimation(keyPath: "position.x")
        shineAnimation.fromValue = -bounds.width
        shineAnimation.toValue = bounds.width * 2
        shineAnimation.duration = 2.2
        shineAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shineAnimation.repeatCount = .infinity
        shine.add(shineAnimation, forKey: "shine_sweep")
    }
}

