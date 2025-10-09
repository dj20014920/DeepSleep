import UIKit

/// 🌳 대나무숲 친구 선택 화면
/// 모델별 설명과 버블블록체크 형식의 UI로 AI 친구를 선택하는 화면
class AIModelSelectionViewController: UIViewController {

    // MARK: - Properties

    var currentSelectedModel: AIModelType = SettingsManager.shared.selectedLLM
    var onModelSelected: ((AIModelType) -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()

    private var modelCards: [AIModelCardView] = []
    // On-device progress UI refs
    private var onDeviceCardRef: AIModelCardView?
    private var onDeviceProgressTimer: Timer?
    private var onDeviceObserverTokens: [NSObjectProtocol] = []
    private var lastProgressLoggedPct: [String: Int] = [:]
    // 현재 다운로드/설치 진행 중인 온디바이스 모델 ID (해당 카드에만 진행률 표시)
    private var focusInstallingID: OnDeviceModelID?

    // 헤더 컴포넌트
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    // 확인 버튼
    private let confirmButton = UIButton(type: .system)



    // MARK: - Lifecycle

    private var hasAppearedOnce = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigation()
        createModelCards()
        setupOnDeviceObservers()
        refreshOnDeviceProgressUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 내부적으로 Alert/Paywall 등을 띄웠다가 닫힐 때도 viewWillAppear가 호출되어
        // 임시 선택 상태(체크박스)가 초기화되는 문제가 있었음.
        // 최초 1회에만 복원 로직을 실행하여 사용자의 현재 선택 상태를 유지.
        if !hasAppearedOnce {
            restoreSelectionState()
            hasAppearedOnce = true
        }
    }

    // MARK: - Lifecycle
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 화면 이탈 시에는 옵저버만 정리(폴링 타이머는 유지). 폴링 중지는 완료/취소/오류 시에만 수행.
        for t in onDeviceObserverTokens {
            NotificationCenter.default.removeObserver(t)
        }
        onDeviceObserverTokens.removeAll()
    }

    // 화면 완전 이탈 시 안전장치(safeguard):
    // - 설치가 진행 중이 아니라면 폴링 타이머를 정리해 메모리 누수를 방지
    // - 설치가 진행 중이면 타이머를 유지하여 백그라운드에서도 진행률이 UI로 푸시되도록 함
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        Task { [weak self] in
            guard let self = self else { return }
            let s1 = await OnDeviceAdapter.shared.status(for: .amoral_gemma3_1b_v2_q5_k_m)
            let s2 = await OnDeviceAdapter.shared.status(for: .hyperclovax_seed_text_instruct_0_5b_q4_k_m)
            let s3 = await OnDeviceAdapter.shared.status(for: .hyperclovax_seed_text_instruct_1_5b_q4_k_m)
            let s4 = await OnDeviceAdapter.shared.status(for: .hyperclovax_seed_text_instruct_0_5b_q8_0)
            let installing = [s1, s2, s3, s4].contains { state in
                if case .installing = state { return true } else { return false }
            }
            if !installing {
                self.stopOnDeviceProgressPolling()
            }
        }
    }

    // MARK: - Setup Methods

    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground

        // 스크롤뷰 설정
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        // 스택뷰 설정
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        contentView.addSubview(stackView)

        // 헤더 설정
        setupHeader()

        // 확인 버튼 설정
        setupConfirmButton()

        // 제약조건 설정
        setupConstraints()
    }

    private func setupNavigation() {
        title = "대나무숲 친구 선택"
        navigationController?.navigationBar.prefersLargeTitles = false

        // 닫기 버튼
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        navigationItem.leftBarButtonItem = closeButton
    }

    private func setupHeader() {
        headerView.translatesAutoresizingMaskIntoConstraints = false

        // 타이틀
        titleLabel.text = "🌸 대나무숲에 살고 있는 친구들을 소개할게요!"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = UIDesignSystem.Colors.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 서브타이틀
        subtitleLabel.text = "각자의 특별한 재능으로 당신을 도와줄 거예요!\n용량이 큰 친구들은 더 똑똑하고 말을 잘해요! ✨"
        subtitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = UIDesignSystem.Colors.secondaryText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
        ])

        stackView.addArrangedSubview(headerView)
    }

    private func setupConfirmButton() {
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.setTitle("이 친구와 대화하기", for: .normal)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        confirmButton.backgroundColor = UIDesignSystem.Colors.accent
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.layer.cornerRadius = 25
        confirmButton.addTarget(self, action: #selector(confirmButtonTapped), for: .touchUpInside)

        // 그림자 효과
        confirmButton.layer.shadowColor = UIDesignSystem.Colors.accent.cgColor
        confirmButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        confirmButton.layer.shadowRadius = 8
        confirmButton.layer.shadowOpacity = 0.3

        view.addSubview(confirmButton)
    }

    private func createModelCards() {
        // 4개 버블 카드(온디/제미니/지피티/하이퍼클로바)를 각각 특정 온디바이스 모델로 매핑
        // - 용량 작은 순으로 정렬(상단 배치)
        let mappings:
            [(
                type: AIModelType, id: OnDeviceModelID, personality: String, specialties: [String],
                strengths: String, bestFor: String
            )] = [
                (
                    type: .onDevice, id: .amoral_gemma3_1b_v2_q5_k_m,
                    personality: "개인정보 보호와 저지연 대화",
                    specialties: ["온디바이스 처리", "저지연 응답", "백그라운드 설치/재개", "무결성 검증"],
                    strengths: "네트워크 품질과 무관하게 안정적이고 빠른 대화",
                    bestFor: "빠른 반응, 오프라인/저연결, 프라이버시"
                ),
                (
                    type: .gemini, id: .hyperclovax_seed_text_instruct_1_5b_q4_k_m,
                    personality: "자유롭고 창의적인 성격",
                    specialties: ["상상력 풍부한 조언", "예술적 표현", "새로운 관점", "재미있는 대화"],
                    strengths: "독특하고 창의적인 시각으로 새로운 해결책을 제시",
                    bestFor: "창의적 고민, 예술적 영감, 색다른 관점"
                ),
                (
                    type: .gpt4, id: .hyperclovax_seed_text_instruct_0_5b_q8_0,
                    personality: "밝고 적극적인 성격",
                    specialties: ["빠른 분석", "실용적 조언", "목표 설정", "동기부여"],
                    strengths: "신속하고 명확한 답변으로 즉시 도움",
                    bestFor: "빠른 상담, 일상 조언, 스트레스 해소"
                ),
                (
                    type: .naver, id: .hyperclovax_seed_text_instruct_0_5b_q4_k_m,
                    personality: "정겨우면서도 현실적인 성격",
                    specialties: ["한국 문화 이해", "현실적 조언", "공감 대화", "진솔한 소통"],
                    strengths: "한국인의 정서/문화를 깊이 이해하고 현실적 조언",
                    bestFor: "한국적 고민, 사회생활 조언, 인간관계"
                ),
            ]

        let sorted = mappings.sorted {
            ModelCatalog.record(for: $0.id).approxBytes
                < ModelCatalog.record(for: $1.id).approxBytes
        }

        // Persisted selection (type + on-device preferred ID) for restoring check state
        let selectedType = SettingsManager.shared.selectedLLM
        let selectedOnDeviceID = SettingsManager.shared.preferredOnDeviceModelID
            ?? OnDeviceAdapter.shared.activeModelID
            ?? ModelCatalog.defaultModelID  // defaultModelID가 사용자 선호 우선으로 동작

        for m in sorted {
            let rec = ModelCatalog.record(for: m.id)
            // 실제 파일 크기를 사용 (설치된 경우), 미설치시 근사치 사용
            let actualSize = ModelCatalog.actualFileSize(for: m.id)
            let size = OnDevicePromptProfile.ProgressBuilder.humanSize(actualSize)
            let card = AIModelCardView(
                model: m.type,
                personality: m.personality,
                specialties: m.specialties,
                strengths: m.strengths,
                bestFor: m.bestFor,
                titleOverride: m.id.friendlyNickname,
                subtitleOverride: "온디바이스 • \(size)",
                onDeviceID: m.id
            )
            // Restore persisted selection: highlight card if matches saved selection
            // - onDevice: 선택된 온디바이스 ID와 일치하는 카드만 선택
            // - 기타 모델: 타입 일치 카드 선택
            if selectedType == .onDevice {
                card.isSelected = (m.id == selectedOnDeviceID)
            } else {
                card.isSelected = (m.type == selectedType)
            }
            card.onTap = { [weak self, weak card] in
                guard let self = self, let card = card else { return }
                // 4개 버블 모두 온디바이스 설치/활성화 플로우를 사용
                // 사용자가 탭한 즉시, 해당 모델만 진행률을 보이도록 포커스 지정
                self.focusInstallingID = m.id

                // 체크박스 유지(재진입 복원) 위해 즉시 영속화
                SettingsManager.shared.updateSelectedModelAtomically(.onDevice)
                SettingsManager.shared.preferredOnDeviceModelID = m.id
                self.currentSelectedModel = .onDevice

                // 온디바이스 설치/활성화 플로우 진행
                self.handleOnDeviceSelection(for: m.id, card: card)
            }

            modelCards.append(card)
            stackView.addArrangedSubview(card)
        }

        // 애플 파운데이션 모델 카드(다운로드 없음)
        do {
            let appleCard = AIModelCardView(
                model: .apple,
                personality: "시스템 최적화와 안정적인 경험",
                specialties: ["iOS 통합", "프라이버시", "저전력", "일관된 응답"],
                strengths: "추가 설치 없이 즉시 사용, 시스템 수준 최적화",
                bestFor: "빠르고 가벼운 소통, 배터리 효율",
                titleOverride: "Apple Foundation Models",
                subtitleOverride: "온디바이스 • 시스템 제공"
            )
            appleCard.isSelected = (currentSelectedModel == .apple)
            appleCard.onTap = { [weak self, weak appleCard] in
                guard let self = self, appleCard != nil else { return }
                // 다운로드/진행률 UI 비적용
                self.onDeviceCardRef = nil
                self.selectModel(.apple)
            }
            modelCards.append(appleCard)
            stackView.addArrangedSubview(appleCard)
        }

        // 하단 여백
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 100).isActive = true
        stackView.addArrangedSubview(spacer)
    }

    /// 온디바이스 모델 선택 처리:
    /// - 설치됨: 즉시 활성화 + 선택 상태 유지(앱 재시작 후에도 유지)
    /// - 미설치: "친구를 불러올까요?" 확인 후 다운로드 시작(프리사인/ CDN 경유), 진행률은 해당 버블 카드에 표시
    private func handleOnDeviceSelection(for id: OnDeviceModelID, card: AIModelCardView) {
        // 진행 표시를 해당 카드에 바인딩
        self.onDeviceCardRef = card

        // 먼저 선택 애니메이션을 즉시 실행 (애플 파운데이션 모델과 동일한 UX)
        // 해당 카드만 직접 선택 (다른 AIModelType 때문에 selectModel(.onDevice)가 안 먹힘)
        for c in modelCards { c.isSelected = false }
        card.isSelected = true
        self.currentSelectedModel = .onDevice

        // 선택 애니메이션이 완전히 보일 수 있도록 적절한 지연 후 비동기 로직 실행
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self else { return }

            Task { [weak self] in
                guard let self = self else { return }
            let st = await OnDeviceAdapter.shared.status(for: id)
            switch st {
            case .installed:
                do {
                    try await Task.sleep(nanoseconds: 180_000_000)
                    try await OnDeviceAdapter.shared.activate(id: id)
                    // 온디바이스 고정 선택 및 선호 모델 보존(재실행 시에도 유지)
                    SettingsManager.shared.updateSelectedModelAtomically(.onDevice)
                    SettingsManager.shared.preferredOnDeviceModelID = id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        ToastManager.shared.showSuccess(message: "친구가 대나무숲에서 기다려요!")
                    }
                    self.onModelSelected?(self.currentSelectedModel)
                    // 뷰는 유지하여 선택 모션과 토스트를 충분히 보여줍니다 (dismiss 제거)
                } catch {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        ToastManager.shared.showError(
                            message: "친구가 도망쳤어요!: \(error.localizedDescription)")
                    }
                }

            case .notInstalled:
                fallthrough
            case .installing(let _):
                let alert = UIAlertController(
                    title: "친구를 불러올까요?",
                    message: "친구를 불러올까요?",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "취소", style: .cancel))
                alert.addAction(
                    UIAlertAction(title: "불러와요", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        // 다운로드 진행률 폴링 + 푸시 알림 기반 UI 업데이트
                        self.startOnDeviceProgressPolling()
                        Task.detached {
                            do {
                                _ = try await OnDeviceAdapter.shared.ensureInstalled(id: id)
                                // 다운로드 완료 브로드캐스트에서 자동 활성화 처리됨
                                SettingsManager.shared.preferredOnDeviceModelID = id
                            } catch {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                    ToastManager.shared.showError(
                                        message: "친구가 도망쳤어요!: \(error.localizedDescription)"
                                    )
                                }
                            }
                        }
                    })
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    self.present(alert, animated: true)
                }
            case .failed(let errorDescription):
                let alert = UIAlertController(
                    title: "모델 준비 실패",
                    message: "친구가 도망쳤어요!.\n\n이유: \(errorDescription)\n\n다시 데려오거나 다른 친구를 선택해 주세요.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "취소", style: .cancel))
                alert.addAction(
                    UIAlertAction(title: "다시 시도", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        // 재시도: 모델 재설치 시도
                        Task {
                            do {
                                _ = try await OnDeviceAdapter.shared.ensureInstalled(id: id)
                                SettingsManager.shared.preferredOnDeviceModelID = id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                    ToastManager.shared.showSuccess(message: "친구가 같이 와줬어요!")
                                }
                            } catch {
                                ToastManager.shared.showError(
                                    message: "재시도 실패: \(error.localizedDescription)"
                                )
                            }
                        }
                    })
                self.present(alert, animated: true)
            }
            }
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // StackView
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Confirm Button
            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            confirmButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            confirmButton.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    // MARK: - On-device progress (push-based via NotificationCenter)
    private func setupOnDeviceObservers() {
        // 기존 옵저버 정리
        for t in onDeviceObserverTokens {
            NotificationCenter.default.removeObserver(t)
        }
        onDeviceObserverTokens.removeAll()

        let center = NotificationCenter.default

        // 진행률 업데이트
        let p1 = center.addObserver(forName: .onDeviceDownloadProgress, object: nil, queue: .main) {
            [weak self] note in
            if let info = note.userInfo, let file = info["fileName"] as? String,
                let p = info["progress"] as? Double
            {
                let pct = Int(p * 100)
                if [0, 25, 50, 75, 100].contains(pct) {
                    let last = self?.lastProgressLoggedPct[file] ?? -1
                    if last != pct {
                        print("📊 [OnDeviceUI] progress \(file) \(pct)%")
                        self?.lastProgressLoggedPct[file] = pct
                    }
                }
            }
            guard let self = self, let card = self.onDeviceCardRef else { return }
            Task { [weak self] in
                guard let self = self else { return }
                let s1 = await OnDeviceAdapter.shared.status(for: .amoral_gemma3_1b_v2_q5_k_m)
                let s2 = await OnDeviceAdapter.shared.status(for: .hyperclovax_seed_text_instruct_0_5b_q4_k_m)
                let s3 = await OnDeviceAdapter.shared.status(for: .hyperclovax_seed_text_instruct_1_5b_q4_k_m)
                let s4 = await OnDeviceAdapter.shared.status(for: .hyperclovax_seed_text_instruct_0_5b_q8_0)
                var entries = self.buildOnDeviceProgressEntries(s1: s1, s2: s2, s3: s3, s4: s4)
                // UX: 사용자가 탭한 모델만 진행률을 보이도록 필터링 (초보자 혼동 방지)
                if let focus = self.focusInstallingID {
                    entries = entries.filter { $0.2 == focus }
                }
                DispatchQueue.main.async {
                    card.updateOnDeviceProgress(entries: entries)
                }
            }
        }

        // 완료
        let p2 = center.addObserver(forName: .onDeviceDownloadFinished, object: nil, queue: .main) {
            [weak self] note in
            if let fn = note.userInfo?["fileName"] as? String,
                let url = note.userInfo?["localURL"] as? URL
            {
                print("✅ [OnDeviceUI] finished \(fn) → \(url.lastPathComponent)")
            } else {
                print("✅ [OnDeviceUI] finished")
            }
            guard let self = self, let card = self.onDeviceCardRef else { return }
            self.refreshOnDeviceProgressUI()
            self.stopOnDeviceProgressPolling()
            // 포커스 해제: 설치 완료되면 진행률 표시를 초기화
            self.focusInstallingID = nil

            // 자동 활성화: 사용자가 온디바이스를 선택한 경우에만
            guard self.currentSelectedModel == .onDevice else {
                ToastManager.shared.showSuccess(message: "친구가 대나무숲에서 기다려요!")
                return
            }

            // 어떤 모델이 설치되었는지 fileName → OnDeviceModelID로 매핑
            var installedID: OnDeviceModelID?
            if let fileName = note.userInfo?["fileName"] as? String {
                installedID = OnDeviceModelID.id(forFileName: fileName)
            }
            if installedID == nil, let url = note.userInfo?["localURL"] as? URL {
                installedID = OnDeviceModelID.id(forFileName: url.lastPathComponent)
            }

            guard let id = installedID else {
                ToastManager.shared.showSuccess(message: "친구가 대나무숲에서 기다려요!")
                return
            }

            // 설치 완료 시 자동 활성화/전환
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    try await OnDeviceAdapter.shared.activate(id: id)
                    SettingsManager.shared.preferredOnDeviceModelID = id
                    SettingsManager.shared.updateSelectedModelAtomically(.onDevice)
                    ToastManager.shared.showSuccess(message: "친구가 대나무숲에서 기다려요!")
                } catch {
                    ToastManager.shared.showError(
                        message: "설치 완료 후 활성화 실패: \(error.localizedDescription)"
                    )
                }
            }
        }

        // 취소
        let p3 = center.addObserver(forName: .onDeviceDownloadCancelled, object: nil, queue: .main)
        { [weak self] note in
            if let fn = note.userInfo?["fileName"] as? String {
                print("🛑 [OnDeviceUI] cancelled \(fn)")
            } else {
                print("🛑 [OnDeviceUI] cancelled")
            }
            guard let self = self, let card = self.onDeviceCardRef else { return }
            self.refreshOnDeviceProgressUI()
            self.stopOnDeviceProgressPolling()
            ToastManager.shared.showWarning(message: "온디바이스 모델 설치가 중단/취소되었습니다")
        }

        // 실패
        let p4 = center.addObserver(forName: .onDeviceDownloadFailed, object: nil, queue: .main) {
            [weak self] note in
            let fn = note.userInfo?["fileName"] as? String ?? "unknown"
            let err = note.userInfo?["error"] as? String ?? "unknown"
            print("❌ [OnDeviceUI] failed \(fn): \(err)")
            guard let self = self, let card = self.onDeviceCardRef else { return }
            self.refreshOnDeviceProgressUI()
            self.stopOnDeviceProgressPolling()
            ToastManager.shared.showError(message: "온디바이스 모델 다운로드 실패")
        }

        onDeviceObserverTokens.append(contentsOf: [p1, p2, p3, p4])
    }

    // 푸시 기반 진행률 갱신을 위한 공통 리프레시 함수 (DRY)
    private func refreshOnDeviceProgressUI() {
        guard let card = self.onDeviceCardRef else { return }
        Task { [weak self] in
            guard let self = self else { return }
            let s1 = await OnDeviceAdapter.shared.status(for: .amoral_gemma3_1b_v2_q5_k_m)
            let s2 = await OnDeviceAdapter.shared.status(for: .hyperclovax_seed_text_instruct_0_5b_q4_k_m)
            let s3 = await OnDeviceAdapter.shared.status(for: .hyperclovax_seed_text_instruct_1_5b_q4_k_m)
            let s4 = await OnDeviceAdapter.shared.status(for: .hyperclovax_seed_text_instruct_0_5b_q8_0)
            var entries = self.buildOnDeviceProgressEntries(s1: s1, s2: s2, s3: s3, s4: s4)
                // UX: 사용자가 탭한 모델만 진행률을 보이도록 필터링 (초보자 혼동 방지)
                if let focus = self.focusInstallingID {
                    entries = entries.filter { $0.2 == focus }
                }
                DispatchQueue.main.async {
                    card.updateOnDeviceProgress(entries: entries)
                }
        }
    }

    // MARK: - On-device progress polling
    private func startOnDeviceProgressPolling() {
        onDeviceProgressTimer?.invalidate()
        onDeviceProgressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            guard let self = self, let card = self.onDeviceCardRef else { return }
            self.refreshOnDeviceProgressUI()
        }
    }

    private func stopOnDeviceProgressPolling() {
        onDeviceProgressTimer?.invalidate()
        onDeviceProgressTimer = nil
    }

    private func buildOnDeviceProgressEntries(
        s1: BackgroundAssetState,
        s2: BackgroundAssetState,
        s3: BackgroundAssetState,
        s4: BackgroundAssetState
    ) -> [(String, Double, OnDeviceModelID)] {
        var entries: [(String, Double, OnDeviceModelID)] = []
        let r1 = ModelCatalog.record(for: .amoral_gemma3_1b_v2_q5_k_m)
        let r2 = ModelCatalog.record(for: .hyperclovax_seed_text_instruct_0_5b_q4_k_m)
        let r3 = ModelCatalog.record(for: .hyperclovax_seed_text_instruct_1_5b_q4_k_m)
        let r4 = ModelCatalog.record(for: .hyperclovax_seed_text_instruct_0_5b_q8_0)

        if case .installing(let p) = s1 {
            entries.append((OnDeviceModelID.amoral_gemma3_1b_v2_q5_k_m.friendlyNickname, p, .amoral_gemma3_1b_v2_q5_k_m))
        }
        if case .installing(let p) = s2 {
            entries.append((OnDeviceModelID.hyperclovax_seed_text_instruct_0_5b_q4_k_m.friendlyNickname, p, .hyperclovax_seed_text_instruct_0_5b_q4_k_m))
        }
        if case .installing(let p) = s3 {
            entries.append((OnDeviceModelID.hyperclovax_seed_text_instruct_1_5b_q4_k_m.friendlyNickname, p, .hyperclovax_seed_text_instruct_1_5b_q4_k_m))
        }
        if case .installing(let p) = s4 {
            entries.append((OnDeviceModelID.hyperclovax_seed_text_instruct_0_5b_q8_0.friendlyNickname, p, .hyperclovax_seed_text_instruct_0_5b_q8_0))
        }
        return entries
    }

    private func humanSize(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var v = Double(bytes)
        var i = 0
        while v >= 1024 && i < units.count - 1 {
            v /= 1024
            i += 1
        }
        return String(format: "%.0f%@", v, units[i])
    }

    // moved to AIModelCardView.updateOnDeviceProgress(text:progress:)

    // MARK: - Selection State Management

    /// 저장된 설정에 따라 모든 카드의 선택 상태를 복원합니다
    private func restoreSelectionState() {
        let savedModel = SettingsManager.shared.selectedLLM
        let savedOnDeviceID = SettingsManager.shared.preferredOnDeviceModelID
            ?? OnDeviceAdapter.shared.activeModelID
            ?? ModelCatalog.defaultModelID

        // 현재 선택된 모델 업데이트
        currentSelectedModel = savedModel

        // createModelCards와 동일한 로직으로 선택 상태 복원
        // 각 카드가 어떤 온디바이스 모델 ID에 매핑되는지 확인해야 함
        let mappings: [(type: AIModelType, id: OnDeviceModelID)] = [
            (.onDevice, .amoral_gemma3_1b_v2_q5_k_m),
            (.gemini, .hyperclovax_seed_text_instruct_1_5b_q4_k_m),
            (.gpt4, .hyperclovax_seed_text_instruct_0_5b_q8_0),
            (.naver, .hyperclovax_seed_text_instruct_0_5b_q4_k_m)
        ]

        // 모든 카드의 선택 상태 업데이트
        for card in modelCards {
            if card.model == .apple {
                card.isSelected = (savedModel == .apple)
                continue
            }
            if savedModel == .onDevice {
                // 카드가 보유한 onDeviceID와 저장된 ID를 직접 비교
                card.isSelected = (card.onDeviceID == savedOnDeviceID)
            } else {
                card.isSelected = (card.model == savedModel)
            }
        }
    }

    // MARK: - Actions

    private func selectModel(_ model: AIModelType) {
        // 무료 사용자는 제한 모델 선택 불가 → 결제 유도
        if !isModelAllowed(model) {
            presentPaywall()
            return
        }
        // 모든 카드의 선택 상태 업데이트 (단순 규칙)
        // - 온디바이스의 구체적 ID 반영은 restoreSelectionState()가 담당
        // 즉시 영속화: X로 닫거나 뒤로가도 체크 유지
        SettingsManager.shared.updateSelectedModelAtomically(model)

        for card in modelCards {
            card.isSelected = (card.model == model)
        }

        currentSelectedModel = model

        // 버튼 애니메이션
        UIView.animate(
            withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5
        ) {
            self.confirmButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.confirmButton.transform = .identity
            }
        }
    }

    @objc private func confirmButtonTapped() {
        // 단일 진입점으로 모델 변경 처리
        SettingsManager.shared.updateSelectedModelAtomically(currentSelectedModel)
        onModelSelected?(currentSelectedModel)
        dismiss(animated: true)
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }

    // MARK: - Gating Helpers
    private func isPremiumOrTrial() -> Bool {
        return SubscriptionStatusCenter.shared.isPremium
    }
    private func isModelAllowed(_ model: AIModelType) -> Bool {
        if isPremiumOrTrial() { return true }
        // Free 티어는 온디바이스(기존 GGUF)와 Apple Foundation Models 모두 허용
        return model == .onDevice || model == .apple
    }
    private func presentPaywall() {
        PaywallPresenter.present(from: self)
    }
}

// MARK: - AI Model Card View

/// 개별 AI 모델 카드 뷰
class AIModelCardView: UIView {

    // MARK: - Properties

    let model: AIModelType
    let onDeviceID: OnDeviceModelID?
    var isSelected: Bool = false {
        didSet {
            updateSelectionState()
        }
    }
    var onTap: (() -> Void)?

    // UI Components
    private let containerView = UIView()
    private let checkboxView = UIView()
    private let checkmarkImageView = UIImageView()
    private let contentStackView = UIStackView()
    private let progressStack = UIStackView()

    // Update per-model progress rows inside the on-device card
    public func updateOnDeviceProgress(entries: [(String, Double, OnDeviceModelID)]) {
        // In-place 업데이트: 기존 row 재사용, 존재하지 않으면 생성, 사라진 항목은 제거
        // 라벨 업데이트는 0/25/50/75/100 스냅샷에서만 수행(게이지는 매 tick 부드럽게 애니메이션)
        let currentIDs = Set(entries.map { $0.2.rawValue })

        // 1) 제거: 더 이상 보고되지 않는 id의 행 제거
        for case let row as UIStackView in progressStack.arrangedSubviews {
            let rid = row.accessibilityIdentifier ?? ""
            if !currentIDs.contains(rid) {
                progressStack.removeArrangedSubview(row)
                row.removeFromSuperview()
            }
        }

        // 2) 추가/갱신
        for (title, progress, id) in entries {
            let idStr = id.rawValue
            let clamped = max(0.0, min(1.0, progress))
            let pct = Int(clamped * 100.0)
            let snapped = min(100, (pct / 25) * 25)  // 0,25,50,75,100 로 스냅

            // 기존 row 탐색
            let existingRow =
                progressStack.arrangedSubviews.first {
                    ($0 as? UIStackView)?.accessibilityIdentifier == idStr
                } as? UIStackView

            if let row = existingRow {
                // 기존 요소 찾기
                let label = row.arrangedSubviews.compactMap { $0 as? UILabel }.first
                let bar = row.arrangedSubviews.compactMap { $0 as? UIProgressView }.first

                // 게이지는 항상 부드럽게 업데이트
                bar?.setProgress(Float(clamped), animated: true)

                // 라벨은 매 tick 업데이트(연속 동기화), 중앙 정렬
                if let label = label {
                    label.textAlignment = .center
                    let baseTitle = title.replacingOccurrences(
                        of: #"\s+\d+%$"#, with: "", options: .regularExpression)
                    label.text = "\(baseTitle) \(pct)%"
                    label.tag = snapped
                }
            } else {
                // 새 행 생성
                let row = UIStackView()
                row.axis = .vertical
                row.spacing = 6
                row.accessibilityIdentifier = idStr

                let label = UILabel()
                let baseTitle = title.replacingOccurrences(
                    of: #"\s+\d+%$"#, with: "", options: .regularExpression)
                label.text = "\(baseTitle) \(pct)%"
                label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
                label.textColor = UIDesignSystem.Colors.secondaryText
                label.numberOfLines = 1
                label.textAlignment = .center
                label.tag = snapped  // 스냅샷 % 기록

                // Progress bar
                let bar = UIProgressView(progressViewStyle: .default)
                bar.setProgress(Float(clamped), animated: true)
                bar.translatesAutoresizingMaskIntoConstraints = false
                // 먼저 추가한 뒤 제약 활성화(공통 조상 보장)
                row.addArrangedSubview(bar)
                NSLayoutConstraint.activate([
                    bar.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
                    bar.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
                ])

                // Controls: 중단/취소 버튼
                let controls = UIStackView()
                controls.axis = .horizontal
                controls.spacing = 8
                controls.alignment = .center
                controls.translatesAutoresizingMaskIntoConstraints = false

                let cancelBtn = UIButton(type: .system)
                cancelBtn.setTitle("중단/취소", for: .normal)
                cancelBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
                cancelBtn.setTitleColor(UIDesignSystem.Colors.accent, for: .normal)
                cancelBtn.addAction(
                    UIAction { _ in
                        Task { OnDeviceAdapter.shared.cancelInstall(id: id) }
                    }, for: .touchUpInside)

                controls.addArrangedSubview(cancelBtn)
                // 먼저 추가한 뒤 제약 활성화(공통 조상 보장)
                row.addArrangedSubview(controls)
                NSLayoutConstraint.activate([
                    controls.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                    controls.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                ])

                // 라벨은 맨 위로 배치
                row.insertArrangedSubview(label, at: 0)
                progressStack.addArrangedSubview(row)
            }
        }

        // 3) 표시 상태
        progressStack.isHidden = progressStack.arrangedSubviews.isEmpty
    }

    private let headerStackView = UIStackView()
    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let personalityLabel = UILabel()
    private let specialtiesContainer = UIView()
    private let strengthsLabel = UILabel()
    private let bestForLabel = UILabel()

    // Data
    private let personality: String
    private let specialties: [String]
    private let strengths: String
    private let bestFor: String
    private let titleOverride: String?
    private let subtitleOverride: String?

    // MARK: - Initialization

    init(
        model: AIModelType, personality: String, specialties: [String], strengths: String,
        bestFor: String, titleOverride: String? = nil, subtitleOverride: String? = nil,
        onDeviceID: OnDeviceModelID? = nil
    ) {
        self.model = model
        self.onDeviceID = onDeviceID
        self.personality = personality
        self.specialties = specialties
        self.strengths = strengths
        self.bestFor = bestFor
        self.titleOverride = titleOverride
        self.subtitleOverride = subtitleOverride

        super.init(frame: .zero)
        setupUI()
        setupGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup Methods

    private func setupUI() {
        // Container View
        containerView.backgroundColor = UIDesignSystem.Colors.cardBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOpacity = 0.08
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        // Checkbox (버블블록 체크박스)
        checkboxView.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        checkboxView.layer.cornerRadius = 12
        checkboxView.layer.borderWidth = 2
        checkboxView.layer.borderColor = UIDesignSystem.Colors.border.cgColor
        checkboxView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(checkboxView)

        // Checkmark
        checkmarkImageView.image = UIImage(systemName: "checkmark")
        checkmarkImageView.tintColor = .white
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.alpha = 0
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkboxView.addSubview(checkmarkImageView)

        // Content Stack View
        contentStackView.axis = .vertical
        contentStackView.spacing = 16
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(contentStackView)

        // Header
        setupHeader()

        // Content
        setupContent()
        // On-device progress stack (hidden by default; shows one row per active download)
        progressStack.axis = .vertical
        progressStack.spacing = 8
        progressStack.alignment = .fill
        progressStack.isHidden = true
        contentStackView.addArrangedSubview(progressStack)

        // Constraints
        setupConstraints()
    }

    private func setupHeader() {
        headerStackView.axis = .horizontal
        headerStackView.spacing = 12
        headerStackView.alignment = .center

        // Icon
        iconLabel.text = model.icon
        iconLabel.font = UIFont.systemFont(ofSize: 40)

        // Name and Subtitle Stack
        let nameStackView = UIStackView()
        nameStackView.axis = .vertical
        nameStackView.spacing = 4

        nameLabel.text = titleOverride ?? model.displayName
        nameLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        nameLabel.textColor = UIDesignSystem.Colors.primaryText

        subtitleLabel.text = subtitleOverride ?? model.description
        subtitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = UIDesignSystem.Colors.accent

        nameStackView.addArrangedSubview(nameLabel)
        nameStackView.addArrangedSubview(subtitleLabel)

        headerStackView.addArrangedSubview(iconLabel)
        headerStackView.addArrangedSubview(nameStackView)
        headerStackView.addArrangedSubview(UIView())  // Spacer

        contentStackView.addArrangedSubview(headerStackView)
    }

    private func setupContent() {

        let specialtiesFlowLayout = UIView()
        specialtiesFlowLayout.translatesAutoresizingMaskIntoConstraints = false
        setupSpecialtiesTags(in: specialtiesFlowLayout)
        contentStackView.addArrangedSubview(specialtiesFlowLayout)
        // 성격
        personalityLabel.attributedText = createAttributedText(title: "성격", content: personality)
        personalityLabel.numberOfLines = 0
        contentStackView.addArrangedSubview(personalityLabel)
        // 특별한 장점
        strengthsLabel.attributedText = createAttributedText(title: "특별한 장점", content: strengths)
        strengthsLabel.numberOfLines = 0
        contentStackView.addArrangedSubview(strengthsLabel)

        // 추천 상황
        bestForLabel.attributedText = createAttributedText(title: "이럴 때 추천", content: bestFor)
        bestForLabel.numberOfLines = 0
        contentStackView.addArrangedSubview(bestForLabel)

    }

    private func setupSpecialtiesTags(in container: UIView) {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        let spacing: CGFloat = 8
        let lineHeight: CGFloat = 32

        for specialty in specialties {
            let tag = createTag(text: specialty)
            container.addSubview(tag)

            // 태그 크기 계산
            let size = tag.sizeThatFits(CGSize(width: .greatestFiniteMagnitude, height: lineHeight))

            // 줄바꿈 체크
            if currentX + size.width > UIScreen.main.bounds.width * 0.95 {
                currentX = 0
                currentY += lineHeight + spacing
            }

            tag.frame = CGRect(x: currentX, y: currentY, width: size.width, height: lineHeight)
            currentX += size.width + spacing
        }

        container.heightAnchor.constraint(equalToConstant: currentY + lineHeight).isActive = true
    }

    private func createTag(text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIDesignSystem.Colors.tagBackground
        container.layer.cornerRadius = 16

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
        ])

        return container
    }

    private func createAttributedText(title: String, content: String, isQuote: Bool = false)
        -> NSAttributedString
    {
        let attributedString = NSMutableAttributedString()

        // 타이틀
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIDesignSystem.Colors.primaryText,
        ]
        attributedString.append(
            NSAttributedString(string: "• \(title): ", attributes: titleAttributes))

        // 내용
        let contentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: isQuote ? .medium : .regular),
            .foregroundColor: isQuote
                ? UIDesignSystem.Colors.accent : UIDesignSystem.Colors.secondaryText,
        ]
        attributedString.append(NSAttributedString(string: content, attributes: contentAttributes))

        return attributedString
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Checkbox
            checkboxView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            checkboxView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -20),
            checkboxView.widthAnchor.constraint(equalToConstant: 24),
            checkboxView.heightAnchor.constraint(equalToConstant: 24),

            // Checkmark
            checkmarkImageView.centerXAnchor.constraint(equalTo: checkboxView.centerXAnchor),
            checkmarkImageView.centerYAnchor.constraint(equalTo: checkboxView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 16),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 16),

            // Content
            contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            contentStackView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(
                equalTo: checkboxView.leadingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(
                equalTo: containerView.bottomAnchor, constant: -24),
        ])
    }

    private func setupGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }

    // MARK: - Actions

    @objc private func handleTap() {
        // 즉시 탭 피드백(햅틱 + 펄스) → 선택 애니메이션이 먼저 보이도록 보장
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        UIView.animate(
            withDuration: 0.08,
            delay: 0,
            options: [.allowUserInteraction, .curveEaseOut]
        ) {
            self.containerView.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            self.checkboxView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        } completion: { _ in
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                options: [.allowUserInteraction, .curveEaseIn]
            ) {
                self.containerView.transform = .identity
                self.checkboxView.transform = .identity
            } completion: { _ in
                // 카드 자체의 onTap 로직은 펄스 애니메이션 이후에 실행하여
                // 사용자에게 선택 모션이 우선 보이도록 한다.
                self.onTap?()
            }
        }
    }

    private func updateSelectionState() {
        if self.isSelected {
            // 즉시 햅틱 + 체크박스/체크마크 키프레임 애니메이션(우상단 체크 동작을 강조)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            // 시작 상태(체크마크는 작게/투명, 체크박스는 살짝 축소)
            self.checkmarkImageView.alpha = 0
            self.checkmarkImageView.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
            self.checkboxView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)

            UIView.animateKeyframes(
                withDuration: 0.28, delay: 0, options: [.allowUserInteraction]
            ) {
                // 0~50%: 카드 강조(테두리/배경), 체크박스 채우기 + 경계색 전환, 체크박스 팝
                UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.5) {
                    self.containerView.layer.borderWidth = 2
                    self.containerView.layer.borderColor = UIDesignSystem.Colors.accent.cgColor
                    self.containerView.backgroundColor = UIDesignSystem.Colors.accentLight

                    self.checkboxView.backgroundColor = UIDesignSystem.Colors.accent
                    self.checkboxView.layer.borderColor = UIDesignSystem.Colors.accent.cgColor
                    self.checkboxView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                }
                // 50~100%: 체크마크 페이드+팝 인, 체크박스/카드 정착
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                    self.checkmarkImageView.alpha = 1
                    self.checkmarkImageView.transform = .identity
                    self.checkboxView.transform = .identity
                    self.containerView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                }
            }
        } else {
            // 해제 시 부드럽게 원복
            UIView.animate(
                withDuration: 0.22, delay: 0, options: [.allowUserInteraction]
            ) {
                self.containerView.layer.borderWidth = 0
                self.containerView.layer.borderColor = UIDesignSystem.Colors.border.cgColor
                self.containerView.backgroundColor = UIDesignSystem.Colors.cardBackground

                self.checkboxView.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
                self.checkboxView.layer.borderColor = UIDesignSystem.Colors.border.cgColor
                self.checkmarkImageView.alpha = 0

                self.checkboxView.transform = .identity
                self.checkmarkImageView.transform = .identity
                self.containerView.transform = .identity
            }
        }
    }
}
