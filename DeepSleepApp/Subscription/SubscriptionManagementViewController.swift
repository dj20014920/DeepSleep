import UIKit

/// 설정 > 사용자 정보 > 구독 및 복원
/// - KISS: 단일 화면에서 구독 상태 확인, 결제 시트 호출, 구매 복원, 시스템 구독 관리 이동
final class SubscriptionManagementViewController: UIViewController {
    // UI
    private let scroll = UIScrollView()
    private let content = UIStackView()

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let priceSummaryLabel = UILabel()
    private let benefitsLabel = UILabel()

    private let subscribeButton = UIButton(type: .system)
    private let restoreButton = UIButton(type: .system)
    private let manageButton = UIButton(type: .system)

    private var binder: SubscriptionUIBinder?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "구독 및 복원"
        buildUI()
        bind()
        Task { @MainActor in
            await StoreKitSubscriptionManager.shared.loadProducts()
            updatePrices()
            updateStatus()
        }
    }

    private func buildUI() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 16
        content.isLayoutMarginsRelativeArrangement = true
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 40, trailing: 20)
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            content.topAnchor.constraint(equalTo: scroll.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.widthAnchor)
        ])

        titleLabel.text = "플랜 및 복원"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .left

        statusLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0

        priceSummaryLabel.font = .systemFont(ofSize: 15)
        priceSummaryLabel.textColor = .label
        priceSummaryLabel.numberOfLines = 0

        benefitsLabel.font = .systemFont(ofSize: 14)
        benefitsLabel.textColor = .secondaryLabel
        benefitsLabel.numberOfLines = 0
        benefitsLabel.text = SubscriptionUIMessageFormatter.summaryBenefitsKO()

        styleCTA(subscribeButton, title: "구독/변경하기")
        subscribeButton.addTarget(self, action: #selector(tapSubscribe), for: .touchUpInside)

        styleSecondary(restoreButton, title: "구매 복원")
        restoreButton.addTarget(self, action: #selector(tapRestore), for: .touchUpInside)

        styleLink(manageButton, title: "구독 관리 (iOS 설정)")
        manageButton.addTarget(self, action: #selector(tapManage), for: .touchUpInside)

        [titleLabel, statusLabel, priceSummaryLabel, benefitsLabel, subscribeButton, restoreButton, manageButton].forEach {
            content.addArrangedSubview($0)
        }
    }

    private func styleCTA(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        SubscriptionUIStyleHelper.styleCTAButton(button, isPremium: SubscriptionStatusCenter.shared.isPremium)
    }

    private func styleSecondary(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.backgroundColor = UIColor.secondarySystemBackground
        button.setTitleColor(.label, for: .normal)
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
    }

    private func styleLink(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.setTitleColor(.link, for: .normal)
        button.contentHorizontalAlignment = .leading
    }

    private func bind() {
        binder = SubscriptionUIBinder.attach(to: self) { [weak self] _ in
            self?.updateStatus()
        }
    }

    private func updatePrices() {
        let s = StoreKitSubscriptionManager.shared
        let proM = s.displayPrice(for: .proMonthly) ?? "—"
        let proY = s.displayPrice(for: .proYearly) ?? "—"
        let maxM = s.displayPrice(for: .maxMonthly) ?? "—"
        let maxY = s.displayPrice(for: .maxYearly) ?? "—"
        priceSummaryLabel.text = "가격: Pro \(proM) · \(proY) / Max \(maxM) · \(maxY)"
    }

    private func updateStatus() {
        let center = SubscriptionStatusCenter.shared
        let tier: String
        switch StoreKitSubscriptionManager.shared.currentTier {
        case .free: tier = "Free"
        case .pro:  tier = "Pro"
        case .max:  tier = "Max"
        }
        if let exp = center.expiration {
            let df = DateFormatter()
            df.locale = Locale(identifier: "ko_KR")
            df.dateFormat = "yyyy.MM.dd a h:mm"
            statusLabel.text = "현재 상태: \(tier) · 만료 \(df.string(from: exp))"
        } else {
            statusLabel.text = "현재 상태: \(tier)"
        }
        SubscriptionUIStyleHelper.styleCTAButton(subscribeButton, isPremium: center.isPremium)
    }

    @objc private func tapSubscribe() {
        PaywallPresenter.present(from: self)
    }

    @objc private func tapRestore() {
        Task { @MainActor in
            await StoreKitSubscriptionManager.shared.restore()
            updateStatus()
        }
    }

    @objc private func tapManage() {
        // Apple 권장 경로: 계정 구독 관리 링크 열기
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

