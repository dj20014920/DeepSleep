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

    private enum Tier { case pro, max }
    private var selectedTier: Tier = .pro { didSet { updatePricesForSelectedTier(); updatePurchaseButtonsEnabled() } }

    // 가격 캐시(프로/맥스 × 월/연)
    private var proMonthlyPriceCache: String?
    private var proYearlyPriceCache: String?
    private var maxMonthlyPriceCache: String?
    private var maxYearlyPriceCache: String?

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
        l.text = "EmoZleep 프리미엄"
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

    private let tierControl: UISegmentedControl = {
        let s = UISegmentedControl(items: ["Pro", "Max"])
        s.selectedSegmentIndex = 0
        return s
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
        tierControl.addTarget(self, action: #selector(didChangeTier), for: .valueChanged)
        monthlyButton.addTarget(self, action: #selector(didTapMonthly), for: .touchUpInside)
        yearlyButton.addTarget(self, action: #selector(didTapYearly), for: .touchUpInside)
        restoreButton.addTarget(self, action: #selector(didTapRestore), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)

        // 초기에는 제품이 로드될 때까지 구매 버튼 비활성화
        updatePurchaseButtonsEnabled()

        // 제품 갱신 알림 수신하여 버튼 상태/가격 라벨 갱신
        NotificationCenter.default.addObserver(self, selector: #selector(productsUpdated), name: .iapProductsUpdated, object: nil)
    }

    private func configureLayout() {
        [titleLabel, closeButton, trialBadgeLabel, descriptionLabel, priceLabel, tierControl, monthlyButton, yearlyButton, restoreButton].forEach {
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

            tierControl.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 16),
            tierControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            monthlyButton.topAnchor.constraint(equalTo: tierControl.bottomAnchor, constant: 16),
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

        // Trial 배지 및 설명 카피(중앙 포맷터 사용)
        if let days = trialDaysRemaining, days >= 0 {
            trialBadgeLabel.isHidden = false
            trialBadgeLabel.text = "D-\(days)  |  7일 무료체험"
            descriptionLabel.text = SubscriptionUIMessageFormatter.free(isTrialEligible: true) + "\nPro에는 대나무숲 친구 선택 가능"
        } else {
            let eligible = StoreKitSubscriptionManager.shared.isTrialEligible
            if eligible {
                trialBadgeLabel.isHidden = false
                trialBadgeLabel.text = "7일 무료체험"
            } else {
                trialBadgeLabel.isHidden = true
            }
            descriptionLabel.text = SubscriptionUIMessageFormatter.free(isTrialEligible: eligible) + "\nPro에는 대나무숲 친구 선택 가능"
        }

        // 제품 로딩 상태에 따라 버튼 활성화
        updatePurchaseButtonsEnabled()
    }

    private func refreshPricesIfNeeded() {
        Task { @MainActor in
            // 제품 로드 후 표시가/Trial 갱신
            await StoreKitSubscriptionManager.shared.loadProducts()
            // 가격 캐시 채우기
            self.proMonthlyPriceCache = StoreKitSubscriptionManager.shared.displayPrice(for: .proMonthly)
            self.proYearlyPriceCache  = StoreKitSubscriptionManager.shared.displayPrice(for: .proYearly)
            self.maxMonthlyPriceCache = StoreKitSubscriptionManager.shared.displayPrice(for: .maxMonthly)
            self.maxYearlyPriceCache  = StoreKitSubscriptionManager.shared.displayPrice(for: .maxYearly)
            // 현재 선택된 티어 기준 표시가 반영
            self.updatePricesForSelectedTier()
            if self.trialDaysRemaining == nil {
                self.trialDaysRemaining = StoreKitSubscriptionManager.shared.isTrialEligible ? 7 : nil
            }
            // 제품 로드 이후 버튼 상태 갱신
            self.updatePurchaseButtonsEnabled()
        }
    }

    deinit {
        if let token = subscriptionObserver { NotificationCenter.default.removeObserver(token) }
        NotificationCenter.default.removeObserver(self, name: .iapProductsUpdated, object: nil)
    }

    // MARK: - Actions

    private func updatePurchaseButtonsEnabled() {
        let hasMonthly: Bool
        let hasYearly: Bool
        switch selectedTier {
        case .pro:
            hasMonthly = StoreKitSubscriptionManager.shared.hasProduct(.proMonthly)
            hasYearly  = StoreKitSubscriptionManager.shared.hasProduct(.proYearly)
        case .max:
            hasMonthly = StoreKitSubscriptionManager.shared.hasProduct(.maxMonthly)
            hasYearly  = StoreKitSubscriptionManager.shared.hasProduct(.maxYearly)
        }
        let enabled = hasMonthly || hasYearly
        monthlyButton.isEnabled = hasMonthly
        yearlyButton.isEnabled = hasYearly
        // 복원은 항상 가능
        restoreButton.isEnabled = true
        // 가격 라벨이 없고 제품도 없으면 로딩 유도 텍스트
        if !enabled && (monthlyDisplayPrice == nil && yearlyDisplayPrice == nil) {
            priceLabel.text = "상품 정보를 불러오는 중..."
        }
    }

    @objc private func productsUpdated() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.productsUpdated() }
            return
        }
        // 제품이 갱신되면 가격/버튼 상태 갱신
        // 제품이 갱신되면 캐시를 갱신하고 현재 티어 표시 업데이트
        self.proMonthlyPriceCache = StoreKitSubscriptionManager.shared.displayPrice(for: .proMonthly)
        self.proYearlyPriceCache  = StoreKitSubscriptionManager.shared.displayPrice(for: .proYearly)
        self.maxMonthlyPriceCache = StoreKitSubscriptionManager.shared.displayPrice(for: .maxMonthly)
        self.maxYearlyPriceCache  = StoreKitSubscriptionManager.shared.displayPrice(for: .maxYearly)
        self.updatePricesForSelectedTier()
        updatePurchaseButtonsEnabled()
    }
    @objc private func didTapMonthly() {
        print("[Paywall] Monthly button tapped")
        if let d = delegate { d.paywallDidRequestPurchaseMonthly(self); return }
        // 기본 동작: StoreKit2 구매 진행
        Task { @MainActor in
            do {
                await StoreKitSubscriptionManager.shared.loadProducts()
                switch selectedTier {
                case .pro:
                    try await StoreKitSubscriptionManager.shared.purchase(.proMonthly)
                case .max:
                    try await StoreKitSubscriptionManager.shared.purchase(.maxMonthly)
                }
                print("[Paywall] Monthly purchase flow initiated")
            } catch {
                print("[Paywall][Error] Monthly purchase failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func didTapYearly() {
        print("[Paywall] Yearly button tapped")
        if let d = delegate { d.paywallDidRequestPurchaseYearly(self); return }
        Task { @MainActor in
            do {
                await StoreKitSubscriptionManager.shared.loadProducts()
                switch selectedTier {
                case .pro:
                    try await StoreKitSubscriptionManager.shared.purchase(.proYearly)
                case .max:
                    try await StoreKitSubscriptionManager.shared.purchase(.maxYearly)
                }
                print("[Paywall] Yearly purchase flow initiated")
            } catch {
                print("[Paywall][Error] Yearly purchase failed: \(error.localizedDescription)")
            }
        }
    }

    @objc private func didTapRestore() {
        print("[Paywall] Restore button tapped")
        if let d = delegate { d.paywallDidRequestRestore(self); return }
        Task {
            await StoreKitSubscriptionManager.shared.restore()
            print("[Paywall] Restore flow initiated")
        }
    }

    @objc private func didTapClose() {
        delegate?.paywallDidClose(self)
        dismiss(animated: true)
    }
    @objc private func didChangeTier() {
        selectedTier = (tierControl.selectedSegmentIndex == 0) ? .pro : .max
    }

    private func updatePricesForSelectedTier() {
        switch selectedTier {
        case .pro:
            self.monthlyDisplayPrice = proMonthlyPriceCache
            self.yearlyDisplayPrice  = proYearlyPriceCache
        case .max:
            self.monthlyDisplayPrice = maxMonthlyPriceCache
            self.yearlyDisplayPrice  = maxYearlyPriceCache
        }
    }
}
