import UIKit

/// 구독 티어 선택 화면 (Free / Pro / Max)
/// - Free: 현재 상태 안내 + 업그레이드 CTA
/// - Pro: 월간/연간 선택(기존 StoreKit 제품과 매핑)
/// - Max: 추후 도입 예정(설명만 표시)
final class SubscriptionTierSelectionViewController: UIViewController {
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "구독 선택"
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])

        // Free 카드
        stack.addArrangedSubview(makeTierCard(
            title: "Free",
            subtitle: "기본 기능 이용 가능 • 7일 체험 대상 여부는 Paywall에서 확인",
            accent: .systemBlue,
            ctaTitle: "Pro로 업그레이드",
            action: #selector(openPaywall)
        ))

        // Pro 카드 (현재 StoreKit 월/연과 매핑)
        stack.addArrangedSubview(makeTierCard(
            title: "Pro",
            subtitle: "무제한 대화/상향 한도 • 월간/연간 선택",
            accent: .systemGreen,
            ctaTitle: "Pro 구독하기",
            action: #selector(openPaywall)
        ))

        // Max 카드 (추후 도입 예정)
        stack.addArrangedSubview(makeTierCard(
            title: "Max (예정)",
            subtitle: "고급 분석/독점 사운드팩/우선 지원 (준비 중)",
            accent: .systemPurple,
            ctaTitle: "준비 중",
            action: #selector(disabledMax)
        ))
    }

    private func makeTierCard(title: String, subtitle: String, accent: UIColor, ctaTitle: String, action: Selector) -> UIView {
        let container = UIView()
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.separator.cgColor
        container.backgroundColor = UIColor.secondarySystemBackground
        container.translatesAutoresizingMaskIntoConstraints = false

        let v = UIStackView()
        v.axis = .vertical
        v.spacing = 8
        v.alignment = .fill
        v.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = accent

        let subLabel = UILabel()
        subLabel.text = subtitle
        subLabel.font = .systemFont(ofSize: 14)
        subLabel.textColor = .secondaryLabel
        subLabel.numberOfLines = 0

        let button = UIButton(type: .system)
        button.setTitle(ctaTitle, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = accent.withAlphaComponent(0.15)
        button.setTitleColor(accent, for: .normal)
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        button.addTarget(self, action: action, for: .touchUpInside)

        v.addArrangedSubview(titleLabel)
        v.addArrangedSubview(subLabel)
        v.addArrangedSubview(button)

        container.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            v.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            v.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            v.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        return container
    }

    @objc private func openPaywall() {
        // 기존 PaywallViewController 재사용
        let paywall = PaywallViewController()
        let nav = UINavigationController(rootViewController: paywall)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    @objc private func disabledMax() {
        let alert = UIAlertController(title: "준비 중", message: "Max 티어는 준비 중입니다.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

