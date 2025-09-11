import UIKit
import StoreKit

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

    private let benefitsLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.numberOfLines = 0
        l.text = SubscriptionUIMessageFormatter.summaryBenefitsKO()
        return l
    }()

    private let usageSummaryLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.numberOfLines = 0
        l.textColor = .label
        l.text = "일일 채팅: 더 많은 채팅\n채팅 모델 설정 가능"
        return l
    }()

    private let descriptionLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 13)
        l.numberOfLines = 0
        l.textColor = .secondaryLabel
        l.text = SubscriptionUIMessageFormatter.free(isTrialEligible: true)
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
        b.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        b.layer.cornerRadius = 12
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.separator.cgColor
        b.backgroundColor = UIColor.secondarySystemBackground
        b.accessibilityLabel = "월간 구독"
        return b
    }()

    private let yearlyButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("연간 구독", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        b.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        b.layer.cornerRadius = 12
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.separator.cgColor
        b.backgroundColor = UIColor.secondarySystemBackground
        b.accessibilityLabel = "연간 구독"
        return b
    }()

    private let annualDiscountLabel: UILabel = {
        let l = UILabel()
        l.text = "연간은 월 대비 할인 (-33%)"
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = .systemGreen
        l.textAlignment = .center
        return l
    }()

    private let restoreButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("구매 복원", for: .normal)
        b.accessibilityLabel = "구매 복원"
        return b
    }()

    private let termsButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("개인정보 처리방침", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 13)
        b.setTitleColor(.link, for: .normal)
        b.accessibilityLabel = "개인정보 처리방침"
        return b
    }()

    private let privacyChoicesButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("개인정보 선택사항", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 13)
        b.setTitleColor(.link, for: .normal)
        b.accessibilityLabel = "개인정보 선택사항"
        return b
    }()

    private let autoRenewNoticeLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 11)
        l.textColor = .secondaryLabel
        l.text = SubscriptionUIMessageFormatter.autoRenewNoticeKO()
        return l
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
        termsButton.addTarget(self, action: #selector(openPrivacy), for: .touchUpInside)
        privacyChoicesButton.addTarget(self, action: #selector(openPrivacyChoices), for: .touchUpInside)

        // 초기에는 제품이 로드될 때까지 구매 버튼 비활성화
        updatePurchaseButtonsEnabled()

        // 제품 갱신 알림 수신하여 버튼 상태/가격 라벨 갱신
        NotificationCenter.default.addObserver(self, selector: #selector(productsUpdated), name: .iapProductsUpdated, object: nil)
    }

    private func configureLayout() {
        [titleLabel, closeButton, trialBadgeLabel, benefitsLabel, usageSummaryLabel, descriptionLabel, priceLabel, tierControl, monthlyButton, yearlyButton, annualDiscountLabel, restoreButton, termsButton, privacyChoicesButton, autoRenewNoticeLabel].forEach {
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

            benefitsLabel.topAnchor.constraint(equalTo: trialBadgeLabel.bottomAnchor, constant: 12),
            benefitsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            benefitsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            usageSummaryLabel.topAnchor.constraint(equalTo: benefitsLabel.bottomAnchor, constant: 6),
            usageSummaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            usageSummaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            descriptionLabel.topAnchor.constraint(equalTo: usageSummaryLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            priceLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            priceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            priceLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            tierControl.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 12),
            tierControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            monthlyButton.topAnchor.constraint(equalTo: tierControl.bottomAnchor, constant: 16),
            monthlyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            monthlyButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),

            yearlyButton.topAnchor.constraint(equalTo: monthlyButton.bottomAnchor, constant: 12),
            yearlyButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            yearlyButton.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),

            annualDiscountLabel.topAnchor.constraint(equalTo: yearlyButton.bottomAnchor, constant: 4),
            annualDiscountLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            restoreButton.topAnchor.constraint(equalTo: annualDiscountLabel.bottomAnchor, constant: 16),
            restoreButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            termsButton.topAnchor.constraint(equalTo: restoreButton.bottomAnchor, constant: 12),
            termsButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -8),

            privacyChoicesButton.centerYAnchor.constraint(equalTo: termsButton.centerYAnchor),
            privacyChoicesButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 8),

            autoRenewNoticeLabel.topAnchor.constraint(equalTo: termsButton.bottomAnchor, constant: 12),
            autoRenewNoticeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            autoRenewNoticeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            autoRenewNoticeLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
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
        // 버튼 라벨에 가격 포함(접근성/CTA 명확성)
        SubscriptionUIBinder.setPriceTitle(button: monthlyButton, title: "월간 구독", price: monthlyDisplayPrice)
        SubscriptionUIBinder.setPriceTitle(button: yearlyButton,  title: "연간 구독",  price: yearlyDisplayPrice)

        // Trial 배지 및 설명 카피(중앙 포맷터 사용)
        if let days = trialDaysRemaining, days >= 0 {
            trialBadgeLabel.isHidden = false
            trialBadgeLabel.text = "D-\(days)  |  7일 무료체험"
            let presetF = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_FREE") ?? 0
            let presetP = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_PRO") ?? 0
            let presetM = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_MAX") ?? 0
            let todoF = ConfigReader.int("AI_LIMITS_TODO_ADVICE_FREE") ?? 0
            let todoP = ConfigReader.int("AI_LIMITS_TODO_ADVICE_PRO") ?? 0
            let todoM = ConfigReader.int("AI_LIMITS_TODO_ADVICE_MAX") ?? 0
            let short = "대나무숲 친구 선택 가능 • 프리셋 \(presetF)→\(presetP)/\(presetM) • 할일조언 \(todoF)→\(todoP)/\(todoM)"
            descriptionLabel.text = SubscriptionUIMessageFormatter.free(isTrialEligible: true) + "\n" + short
        } else {
            let eligible = StoreKitSubscriptionManager.shared.isTrialEligible
            if eligible {
                trialBadgeLabel.isHidden = false
                trialBadgeLabel.text = "7일 무료체험"
            } else {
                trialBadgeLabel.isHidden = true
            }
            // 간단 설명(동기화): 대나무숲 친구 선택 + 조언/프리셋 증분 요약
            let presetF = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_FREE") ?? 0
            let presetP = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_PRO") ?? 0
            let presetM = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_MAX") ?? 0
            let todoF = ConfigReader.int("AI_LIMITS_TODO_ADVICE_FREE") ?? 0
            let todoP = ConfigReader.int("AI_LIMITS_TODO_ADVICE_PRO") ?? 0
            let todoM = ConfigReader.int("AI_LIMITS_TODO_ADVICE_MAX") ?? 0
            let short = "대나무숲 친구 선택 가능 • 프리셋 \(presetF)→\(presetP)/\(presetM) • 할일조언 \(todoF)→\(todoP)/\(todoM)"
            descriptionLabel.text = SubscriptionUIMessageFormatter.free(isTrialEligible: eligible) + "\n" + short
        }

        // 사용량 요약 업데이트(일일 채팅 한도 및 모델 설정 안내)
        updateUsageSummary()

        // 제품 로딩 상태에 따라 버튼 활성화
        updatePurchaseButtonsEnabled()
    }

    private func updateUsageSummary() {
        let free = ConfigReader.int("AI_LIMITS_CHAT") ?? 0
        let pro  = ConfigReader.int("AI_LIMITS_CHAT_PRO") ?? 0
        let max  = ConfigReader.int("AI_LIMITS_CHAT_MAX") ?? 0
        var parts: [String] = []
        if free > 0 { parts.append("무료 \(free)회") }
        if pro  > 0 { parts.append("Pro \(pro)회") }
        if max  > 0 { parts.append("Max \(max)회") }
        let chatLine = parts.isEmpty ? "일일 채팅: 구성 필요" : ("일일 채팅: " + parts.joined(separator: " · "))
        let modelLine = "대나무숲 친구(모델) 선택 가능"
        // 업그레이드 요약(프리셋/할일조언): Free→Pro/Max 변화 강조
        let presetF = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_FREE") ?? 0
        let presetP = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_PRO") ?? 0
        let presetM = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_MAX") ?? 0
        let todoF = ConfigReader.int("AI_LIMITS_TODO_ADVICE_FREE") ?? 0
        let todoP = ConfigReader.int("AI_LIMITS_TODO_ADVICE_PRO") ?? 0
        let todoM = ConfigReader.int("AI_LIMITS_TODO_ADVICE_MAX") ?? 0
        let diffLine = "프리셋 \(presetF)→\(presetP)/\(presetM), 할일조언 \(todoF)→\(todoP)/\(todoM)"
        usageSummaryLabel.text = [chatLine, modelLine, diffLine].joined(separator: "\n")
    }

    private func readFirstInt(_ keys: [String]) -> Int? {
        for k in keys { if let v = ConfigReader.int(k) { return v } }
        return nil
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
        // 가격 라벨이 없고 제품도 없으면 로딩 유도 텍스트(단, 스크린샷 모드에서는 금지)
        if !enabled && (monthlyDisplayPrice == nil && yearlyDisplayPrice == nil) {
            // StoreKitSubscriptionManager가 스크린샷 모드면 displayPrice가 존재하도록 하므로 통상 여기 오지 않음
            priceLabel.text = ""
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
        UnifiedLogger.shared.logUI("paywall_select_term term=monthly tier=\(selectedTier == .pro ? "pro" : "max")")
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
                UnifiedLogger.shared.logUI("purchase_started productId=\(selectedTier == .pro ? "com.emozleep.pro.monthly" : "com.emozleep.max.monthly")")
            } catch {
                UnifiedLogger.shared.error("purchase_fail monthly: \(error.localizedDescription)", category: .ui)
                presentRetry(error: error)
            }
        }
    }

    @objc private func didTapYearly() {
        UnifiedLogger.shared.logUI("paywall_select_term term=yearly tier=\(selectedTier == .pro ? "pro" : "max")")
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
                UnifiedLogger.shared.logUI("purchase_started productId=\(selectedTier == .pro ? "com.emozleep.pro.yearly" : "com.emozleep.max.yearly")")
            } catch {
                UnifiedLogger.shared.error("purchase_fail yearly: \(error.localizedDescription)", category: .ui)
                presentRetry(error: error)
            }
        }
    }

    @objc private func didTapRestore() {
        UnifiedLogger.shared.logUI("paywall_restore")
        if let d = delegate { d.paywallDidRequestRestore(self); return }
        Task { @MainActor in
            await StoreKitSubscriptionManager.shared.restore()
        }
    }

    @objc private func didTapClose() {
        delegate?.paywallDidClose(self)
        dismiss(animated: true)
    }
    @objc private func didChangeTier() {
        selectedTier = (tierControl.selectedSegmentIndex == 0) ? .pro : .max
        UnifiedLogger.shared.logUI("paywall_select_plan plan=\(selectedTier == .pro ? "pro" : "max")")
    }

    @objc private func openPrivacy() {
        guard let url = URL(string: "https://emozleep.space/legal/privacy/") else { return }
        UIApplication.shared.open(url)
    }

    @objc private func openPrivacyChoices() {
        guard let url = URL(string: "https://emozleep.space/legal/privacy-choices/") else { return }
        UIApplication.shared.open(url)
    }

    private func presentRetry(error: Error) {
        let alert = UIAlertController(title: "오류", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        alert.addAction(UIAlertAction(title: "재시도", style: .default, handler: { [weak self] _ in
            self?.refreshPricesIfNeeded()
        }))
        present(alert, animated: true)
    }

    private func updatePricesForSelectedTier() {
        switch selectedTier {
        case .pro:
            self.monthlyDisplayPrice = proMonthlyPriceCache ?? StoreKitSubscriptionManager.shared.displayPrice(for: .proMonthly)
            self.yearlyDisplayPrice  = proYearlyPriceCache  ?? StoreKitSubscriptionManager.shared.displayPrice(for: .proYearly)
        case .max:
            self.monthlyDisplayPrice = maxMonthlyPriceCache ?? StoreKitSubscriptionManager.shared.displayPrice(for: .maxMonthly)
            self.yearlyDisplayPrice  = maxYearlyPriceCache  ?? StoreKitSubscriptionManager.shared.displayPrice(for: .maxYearly)
        }
        SubscriptionUIBinder.setPriceTitle(button: monthlyButton, title: "월간 구독", price: monthlyDisplayPrice)
        SubscriptionUIBinder.setPriceTitle(button: yearlyButton,  title: "연간 구독",  price: yearlyDisplayPrice)
        // 단순 할인 안내 라벨 유지(정확 할인율 계산은 로컬/실서버 가격 구성이 다를 수 있으므로 문구형)
        annualDiscountLabel.isHidden = (yearlyDisplayPrice == nil)
    }
}
