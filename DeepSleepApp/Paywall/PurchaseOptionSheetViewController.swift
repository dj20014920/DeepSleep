import UIKit

/// 간편 결제 시트: 티어(Pro/Max)와 기간(월/연)을 선택하고 바로 결제
final class PurchaseOptionSheetViewController: UIViewController {
    enum Tier { case pro, max }
    enum Term { case monthly, yearly }

    struct Model {
        let tier: Tier
        let term: Term
        let trialDays: Int?
    }

    var model: Model

    init(model: Model) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // UI
    private let titleLabel = UILabel()
    private let descLabel = UILabel()
    private let tierSegment = UISegmentedControl(items: ["Pro", "Max"])
    private let termSegment = UISegmentedControl(items: ["월간", "연간"])
    private let benefitsLabel = UILabel()
    private let usageSummaryLabel = UILabel()
    private let priceLabel = UILabel()
    private let trialInfoButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)
    private let restoreButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let legalNoticeLabel = UILabel()

    private var selectedTier: Tier = .pro
    private var selectedTerm: Term = .monthly

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setup()
        bind()
        Task { @MainActor in
            await StoreKitSubscriptionManager.shared.loadProducts()
            updateTrialLabel()
            updatePrice()
        }
    }

    private func setup() {
        selectedTier = model.tier
        selectedTerm = model.term

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)

        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        descLabel.font = .systemFont(ofSize: 14)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 0
        descLabel.textAlignment = .center

        priceLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        priceLabel.textAlignment = .center

        benefitsLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        benefitsLabel.textColor = .label
        benefitsLabel.numberOfLines = 0
        benefitsLabel.textAlignment = .center

        usageSummaryLabel.font = .systemFont(ofSize: 13)
        usageSummaryLabel.textColor = .secondaryLabel
        usageSummaryLabel.numberOfLines = 0
        usageSummaryLabel.textAlignment = .center

        tierSegment.selectedSegmentIndex = (selectedTier == .pro) ? 0 : 1
        termSegment.selectedSegmentIndex = (selectedTerm == .monthly) ? 0 : 1
        tierSegment.addTarget(self, action: #selector(changeSelection), for: .valueChanged)
        termSegment.addTarget(self, action: #selector(changeSelection), for: .valueChanged)

        confirmButton.setTitle("Apple로 구독 진행", for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        confirmButton.layer.cornerRadius = 12
        confirmButton.backgroundColor = UIColor.systemBlue
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        confirmButton.addTarget(self, action: #selector(tapConfirm), for: .touchUpInside)

        cancelButton.setTitle("취소", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        cancelButton.layer.cornerRadius = 12
        cancelButton.backgroundColor = UIColor.secondarySystemBackground
        cancelButton.setTitleColor(.label, for: .normal)
        cancelButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        cancelButton.addTarget(self, action: #selector(tapCancel), for: .touchUpInside)

        // 안내 링크(구독/체험 안내)
        trialInfoButton.setTitle("구독/체험 안내", for: .normal)
        trialInfoButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        trialInfoButton.setTitleColor(.link, for: .normal)
        trialInfoButton.addTarget(self, action: #selector(openTrialInfo), for: .touchUpInside)

        // 구매 복원(시트 내 진입점 추가)
        restoreButton.setTitle("구매 복원", for: .normal)
        restoreButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        restoreButton.setTitleColor(.link, for: .normal)
        restoreButton.addTarget(self, action: #selector(tapRestore), for: .touchUpInside)

        // 하단 자동갱신 고지 레이블
        legalNoticeLabel.font = .systemFont(ofSize: 11)
        legalNoticeLabel.textColor = .secondaryLabel
        legalNoticeLabel.numberOfLines = 0
        legalNoticeLabel.textAlignment = .left

        [titleLabel,
         descLabel,
         benefitsLabel,
         usageSummaryLabel,
         tierSegment,
         termSegment,
         priceLabel,
         trialInfoButton,
         confirmButton,
         restoreButton,
         cancelButton,
         legalNoticeLabel].forEach { stack.addArrangedSubview($0) }
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor)
        ])
    }

    private func bind() {
        titleLabel.text = "간편 결제"
        updateTrialLabel()
        benefitsLabel.text = SubscriptionUIMessageFormatter.summaryBenefitsKO()
        updateUsageSummary()
        updatePrice()
        // 하단 자동갱신/취소 고지 표준 카피
        legalNoticeLabel.text = SubscriptionUIMessageFormatter.autoRenewNoticeKO()
    }

    private func updateTrialLabel() {
        // 모델 전달값 우선, 없으면 StoreKit 휴리스틱 사용
        if let d = model.trialDays, d >= 0 {
            descLabel.text = "D-\(d) • 7일 무료체험 포함"
            return
        }
        let eligible = StoreKitSubscriptionManager.shared.isTrialEligible
        descLabel.text = eligible ? "7일 무료체험 포함(대상자)" : "무료체험은 첫 구독자 대상"
    }

    private func updatePrice() {
        let product = productForSelection()
        if let base = StoreKitSubscriptionManager.shared.displayPrice(for: product) {
            let suffix = (product == .proMonthly || product == .maxMonthly) ? "/월" : "/년"
            priceLabel.text = base + suffix
            confirmButton.isEnabled = StoreKitSubscriptionManager.shared.hasProduct(product)
            confirmButton.alpha = confirmButton.isEnabled ? 1.0 : 0.5
        } else {
            priceLabel.text = "가격 정보 로딩 중…"
            confirmButton.isEnabled = true // 구매 시 내부에서 로딩 재시도
            confirmButton.alpha = 1.0
        }
    }

    private func productForSelection() -> SubscriptionProduct {
        switch (selectedTier, selectedTerm) {
        case (.pro, .monthly): return .proMonthly
        case (.pro, .yearly):  return .proYearly
        case (.max, .monthly): return .maxMonthly
        case (.max, .yearly):  return .maxYearly
        }
    }

    @objc private func changeSelection() {
        selectedTier = (tierSegment.selectedSegmentIndex == 0) ? .pro : .max
        selectedTerm = (termSegment.selectedSegmentIndex == 0) ? .monthly : .yearly
        updatePrice()
    }

    private func updateUsageSummary() {
        // 1) 일일 채팅 한도
        let free = ConfigReader.int("AI_LIMITS_CHAT") ?? 0
        let pro  = ConfigReader.int("AI_LIMITS_CHAT_PRO") ?? 0
        let max  = ConfigReader.int("AI_LIMITS_CHAT_MAX") ?? 0
        var parts: [String] = []
        if free > 0 { parts.append("무료 \(free)회") }
        if pro  > 0 { parts.append("Pro \(pro)회") }
        if max  > 0 { parts.append("Max \(max)회") }
        let chatLine = parts.isEmpty ? "일일 채팅: 구성 필요" : ("일일 채팅: " + parts.joined(separator: " · "))

        // 2) 프리셋 추천 및 할일 조언(개별)
        let presetF = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_FREE") ?? 0
        let presetP = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_PRO") ?? 0
        let presetM = ConfigReader.int("AI_LIMITS_PRESET_RECOMMENDATION_MAX") ?? 0
        let todoF = ConfigReader.int("AI_LIMITS_TODO_ADVICE_FREE") ?? 0
        let todoP = ConfigReader.int("AI_LIMITS_TODO_ADVICE_PRO") ?? 0
        let todoM = ConfigReader.int("AI_LIMITS_TODO_ADVICE_MAX") ?? 0
        let presetsLine = "프리셋 \(presetF)→\(presetP)/\(presetM), 할일조언 \(todoF)→\(todoP)/\(todoM)"

        // 3) 오늘 전체 조언 & 일기 이야기하기(대나무숲)
        let overallF = ConfigReader.int("AI_LIMITS_TODO_OVERALL_ADVICE_FREE") ?? 0
        let overallP = ConfigReader.int("AI_LIMITS_TODO_OVERALL_ADVICE_PRO") ?? 0
        let overallM = ConfigReader.int("AI_LIMITS_TODO_OVERALL_ADVICE_MAX") ?? 0
        let diaryF = ConfigReader.int("AI_LIMITS_DIARY_ANALYSIS_FREE") ?? 0
        let diaryP = ConfigReader.int("AI_LIMITS_DIARY_ANALYSIS_PRO") ?? 0
        let diaryM = ConfigReader.int("AI_LIMITS_DIARY_ANALYSIS_MAX") ?? 0
        let extrasLine = "오늘 전체 조언 \(overallF)→\(overallP)/\(overallM), 일기 이야기 \(diaryF)→\(diaryP)/\(diaryM)"

        // 한 화면 요약
        usageSummaryLabel.text = [chatLine, presetsLine, extrasLine].joined(separator: "\n")
    }

    @objc private func tapConfirm() {
        let product = productForSelection()
        Task { @MainActor in
            do {
                await StoreKitSubscriptionManager.shared.loadProducts()
                try await StoreKitSubscriptionManager.shared.purchase(product)
                self.dismiss(animated: true)
            } catch {
                let alert = UIAlertController(title: "오류", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "확인", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    @objc private func tapCancel() { dismiss(animated: true) }

    @objc private func tapRestore() {
        Task { @MainActor in
            await StoreKitSubscriptionManager.shared.restore()
            // 상태 반영되면 시트 유지(사용자가 확인 후 닫도록)
        }
    }

    @objc private func openTrialInfo() {
        // 웹 문서(/legal/trial)로 이동 — 실제 배포 URL 확정 시 여기만 교체하면 됨
        if let url = URL(string: "https://emozleep.space") {
            UIApplication.shared.open(url)
        }
    }
}
