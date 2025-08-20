import UIKit

public protocol PaywallViewControllerDelegate: AnyObject {
    func paywallDidRequestPurchaseMonthly(_ controller: PaywallViewController)
    func paywallDidRequestPurchaseYearly(_ controller: PaywallViewController)
    func paywallDidRequestRestore(_ controller: PaywallViewController)
    func paywallDidClose(_ controller: PaywallViewController)
}

/// 최소 스켈레톤: 월/연 토글, 가격/체험 배지/남은일수 표시, 복원 버튼
/// 실제 StoreKit 연동은 Manager에서 수행하고, 본 화면은 이벤트만 위임합니다.
public final class PaywallViewController: UIViewController {

    // MARK: - Public
    public weak var delegate: PaywallViewControllerDelegate?

    /// 현지화된 표시용 가격 문자열 (외부에서 주입)
    public var monthlyDisplayPrice: String? { didSet { updateUI() } }
    public var yearlyDisplayPrice: String? { didSet { updateUI() } }

    /// 7일 무료체험 남은 일수 (Trial 대상인 경우에만 설정)
    public var trialDaysRemaining: Int? { didSet { updateUI() } }

    // 옵저버 토큰
    private var subscriptionObserver: NSObjectProtocol?

    // MARK: - UI
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 22, weight: .bold)
        l.numberOfLines = 0
        l.text = "DeepSleep 프리미엄"
        return l
    }()

    private let trialBadgeLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = .white
        l.backgroundColor = UIColor.systemPink
        l.layer.cornerRadius = 12
        l.clipsToBounds = true
        l.text = "7일 무료체험"
        return l
    }()

    private let descriptionLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 14)
        l.numberOfLines = 0
        l.text = "체험 종료 후 자동으로 선택한 구독으로 갱신됩니다. 체험 중 언제든 취소하면 결제되지 않습니다."
        return l
    }()

    private let monthlyButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("월간 구독", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        return b
    }()

    private let yearlyButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("연간 구독", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        return b
    }()

    private let restoreButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("구매 복원", for: .normal)
        return b
    }()

    private let closeButton: UIButton = {
        let b = UIButton(type: .close)
        return b
    }()

    private let priceLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.numberOfLines = 0
        return l
    }()

    // MARK: - Lifecycle
public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureLayout()
        bind()
        updateUI()
        // 구독 상태 변경 시 자동 반영/닫힘 처리
        subscriptionObserver = NotificationCenter.default.addObserver(forName: .subscriptionStatusChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            // 프리미엄 활성화 시 자동 닫기
            if SubscriptionStatusCenter.shared.isPremium {
                self.dismiss(animated: true)
            } else {
                // 가격/Trial 정보 갱신 시도
                self.refreshPricesIfNeeded()
            }
        }
        // 최초 진입 시 가격/Trial 갱신 시도
        refreshPricesIfNeeded()
    }

    private func bind() {
        monthlyButton.addTarget(self, action: #selector(didTapMonthly), for: .touchUpInside)
        yearlyButton.addTarget(self, action: #selector(didTapYearly), for: .touchUpInside)
        restoreButton.addTarget(self, action: #selector(didTapRestore), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
    }

    private func configureLayout() {
        [titleLabel, closeButton, trialBadgeLabel, descriptionLabel, priceLabel, monthlyButton, yearlyButton, restoreButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),

            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            trialBadgeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            trialBadgeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            trialBadgeLabel.heightAnchor.constraint(equalToConstant: 24),
            trialBadgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            descriptionLabel.topAnchor.constraint(equalTo: trialBadgeLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            priceLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 16),
            priceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            priceLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            monthlyButton.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 24),
            monthlyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            yearlyButton.topAnchor.constraint(equalTo: monthlyButton.bottomAnchor, constant: 12),
            yearlyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            restoreButton.topAnchor.constraint(equalTo: yearlyButton.bottomAnchor, constant: 20),
            restoreButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func updateUI() {
        // 비어있으면 가격 로딩 시도
        if monthlyDisplayPrice == nil || yearlyDisplayPrice == nil {
            refreshPricesIfNeeded()
        }
        var priceText: [String] = []
        if let m = monthlyDisplayPrice { priceText.append("월간: \(m)") }
        if let y = yearlyDisplayPrice { priceText.append("연간: \(y)") }
        priceLabel.text = priceText.joined(separator: "\n")

        if let days = trialDaysRemaining, days >= 0 {
            trialBadgeLabel.isHidden = false
            trialBadgeLabel.text = "D-\(days)  |  7일 무료체험"
        } else {
            trialBadgeLabel.isHidden = true
    }

    private func refreshPricesIfNeeded() {
        Task { @MainActor in
            // 제품 로드 후 표시가/Trial 갱신
            await StoreKitSubscriptionManager.shared.loadProducts()
            if self.monthlyDisplayPrice == nil {
                self.monthlyDisplayPrice = StoreKitSubscriptionManager.shared.displayPrice(for: .monthly)
            }
            if self.yearlyDisplayPrice == nil {
                self.yearlyDisplayPrice = StoreKitSubscriptionManager.shared.displayPrice(for: .yearly)
            }
            if self.trialDaysRemaining == nil {
                // 월/연 중 하나라도 trial 대상이면 7로 표기(가장 관대한 표기)
                let m = StoreKitSubscriptionManager.shared.trialDaysRemaining(for: .monthly)
                let y = StoreKitSubscriptionManager.shared.trialDaysRemaining(for: .yearly)
                self.trialDaysRemaining = m ?? y
            }
        }
    }

    deinit {
        if let token = subscriptionObserver { NotificationCenter.default.removeObserver(token) }
    }
}

    // MARK: - Actions
    @objc private func didTapMonthly() {
        if let d = delegate { d.paywallDidRequestPurchaseMonthly(self); return }
        // 기본 동작: StoreKit2 구매 진행
        Task { @MainActor in
            do {
                try await StoreKitSubscriptionManager.shared.purchase(.monthly)
            } catch {
                // 필요시 사용자 알림 추가 가능
            }
        }
    }
    @objc private func didTapYearly() {
        if let d = delegate { d.paywallDidRequestPurchaseYearly(self); return }
        Task { @MainActor in
            do {
                try await StoreKitSubscriptionManager.shared.purchase(.yearly)
            } catch {
            }
        }
    }
    @objc private func didTapRestore() {
        if let d = delegate { d.paywallDidRequestRestore(self); return }
        Task {
            await StoreKitSubscriptionManager.shared.restore()
        }
    }
    @objc private func didTapClose() { delegate?.paywallDidClose(self); dismiss(animated: true) }
}
