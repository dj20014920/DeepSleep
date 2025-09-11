import UIKit

final class PremiumBadgeView: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        backgroundColor = .systemPink
        layer.cornerRadius = 10
        label.textAlignment = .center
        label.text = "7일 무료체험"
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
        isAccessibilityElement = true
        accessibilityLabel = "7일 무료체험"
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    func setText(_ text: String) { label.text = text }
}

