import UIKit

// 중앙집중형 처리: SharedModels.swift의 정의 사용

// MARK: - Neumorphism helpers
fileprivate final class PillLabel: UILabel {
    private let insets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}

fileprivate final class LargerHitButton: UIButton {
    var minHitSize: CGSize = CGSize(width: 44, height: 44)
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        var bounds = self.bounds
        let widthDelta = max(minHitSize.width - bounds.size.width, 0)
        let heightDelta = max(minHitSize.height - bounds.size.height, 0)
        if widthDelta > 0 || heightDelta > 0 {
            bounds = bounds.insetBy(dx: -widthDelta/2, dy: -heightDelta/2)
        }
        return bounds.contains(point)
    }
}

fileprivate extension UIView {
    func applyNeumorphicContainer(cornerRadius: CGFloat = 16, baseColor: UIColor? = nil) {
        let color = baseColor ?? UIColor.systemBackground
        backgroundColor = color
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = false
        // Remove existing custom sublayers
        layer.sublayers?.removeAll(where: { $0.name == "neumo.dark" || $0.name == "neumo.light" })
        
        // Dark shadow
        let dark = CALayer()
        dark.name = "neumo.dark"
        dark.frame = bounds
        dark.backgroundColor = color.cgColor
        dark.shadowColor = UIColor.black.withAlphaComponent(0.16).cgColor
        dark.shadowOffset = CGSize(width: 6, height: 6)
        dark.shadowRadius = 10
        dark.shadowOpacity = 1
        dark.cornerRadius = cornerRadius
        dark.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        layer.insertSublayer(dark, at: 0)
        
        // Light highlight
        let light = CALayer()
        light.name = "neumo.light"
        light.frame = bounds
        light.backgroundColor = color.cgColor
        light.shadowColor = UIColor.white.withAlphaComponent(0.9).cgColor
        light.shadowOffset = CGSize(width: -6, height: -6)
        light.shadowRadius = 10
        light.shadowOpacity = 1
        light.cornerRadius = cornerRadius
        light.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        layer.insertSublayer(light, above: dark)
        
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
    }
}

/// 📦 저장소 관리 화면
/// 사용자가 대화 데이터 용량을 확인하고 선택적으로 삭제할 수 있는 기능 제공
/// 온디바이스 모델 하나를 표시하는 뷰
class OnDeviceModelView: UIView {
    private let containerView = UIView()
    private let nameLabel = UILabel()
    private let sizeLabel = UILabel()
    private let deleteButton = UIButton()
    
    let modelID: OnDeviceModelID
    var onDelete: ((OnDeviceModelID) -> Void)?
    
    init(modelID: OnDeviceModelID, nickname: String, sizeBytes: Int) {
        self.modelID = modelID
        super.init(frame: .zero)
        setupUI(nickname: nickname, sizeBytes: sizeBytes)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }
    
    private func setupUI(nickname: String, sizeBytes: Int) {
        translatesAutoresizingMaskIntoConstraints = false
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIDesignSystem.Colors.cardBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIDesignSystem.Colors.border.cgColor
        addSubview(containerView)
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = nickname
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = UIDesignSystem.Colors.primaryText
        containerView.addSubview(nameLabel)
        
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        sizeLabel.text = formatBytes(sizeBytes)
        sizeLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        sizeLabel.textColor = UIDesignSystem.Colors.secondaryText
        containerView.addSubview(sizeLabel)
        
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setTitle("삭제", for: .normal)
        deleteButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.backgroundColor = .systemRed
        deleteButton.layer.cornerRadius = 8
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        containerView.addSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 60),
            
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            nameLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -8),
            
            sizeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            sizeLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: 8),
            
            deleteButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            deleteButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 60),
            deleteButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return String(format: "%.0f%@", value, units[unitIndex])
    }
    
    @objc private func deleteButtonTapped() {
        onDelete?(modelID)
    }
}

class StorageManagementViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 통계 섹션
    private let statisticsContainerView = UIView()
    private let totalSizeLabel = UILabel()
    private let fileCountLabel = UILabel()
    private let retentionLabel = UILabel()
    private let refreshButton = UIButton()
    
    // 통계 카드 내부 스택
    private let statsStack = UIStackView()
    // 빠른 정리: 별도 카드로 분리
    private let quickCleanupContainerView = UIView()
    private let quickStack = UIStackView()
    private let deleteOldButton = UIButton()
    private let compressButton = UIButton()
    private let deleteAllButton = UIButton()
    
    // 온디바이스 모델 관리 섹션
    private let modelManagementContainerView = UIView()
    private let modelStack = UIStackView()
    private var installedModelViews: [OnDeviceModelView] = []
    
    // 개별 관리 섹션
    private let tableView = UITableView()
    private var tableHeightConstraint: NSLayoutConstraint?
    private var dailyStorageData: [DailyStorageInfo] = []
    private var selectedDates: Set<String> = []
    
    // 로딩 및 상태
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private var isLoading = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadStorageStatistics()
        refreshModelList()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 갱신 시 컨테이너에 뉴모피즘 섀도우 재적용(프레임 반영)
        statisticsContainerView.applyNeumorphicContainer(cornerRadius: 16)
        // 테이블 높이 자동 보정
        adjustTableHeight()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "저장소 관리"
        // 뉴모피즘 느낌의 밝은 배경
        view.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.systemGray6 : UIColor(red: 0.93, green: 0.95, blue: 0.98, alpha: 1)
        }
        
        // 네비게이션 바 설정
        setupNavigationBar()
        
        // 스크롤뷰 설정
        setupScrollView()
        
        // 각 섹션 설정 (통계 카드에 빠른 정리 통합)
        setupStatisticsSection()
        setupModelManagementSection()
        setupTableView()
        
        // 레이아웃 설정
        setupLayout()
    }
    
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            customView: loadingIndicator
        )
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        // 이어서 대화하기 노티 수신 (해당 날짜 세션으로 이동)
        NotificationCenter.default.addObserver(self, selector: #selector(handleResumeConversationForDate(_:)), name: Notification.Name("ResumeConversationForDate"), object: nil)
        // 즐겨찾기 변경 노티 수신 → 즉시 재정렬/리로드
        NotificationCenter.default.addObserver(self, selector: #selector(handleFavoriteDatesChanged), name: Notification.Name("FavoriteDatesChanged"), object: nil)
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
    }
    
    private func setupStatisticsSection() {
        statisticsContainerView.translatesAutoresizingMaskIntoConstraints = false
        statisticsContainerView.applyNeumorphicContainer(cornerRadius: 16)
        
        // 제목 + 정책 요약을 하나의 레이블로 결합
        let protectionDays = SettingsManager.shared.protectedDaysWindow
        let headerLabel = UILabel()
        headerLabel.numberOfLines = 0
        let titleText = "📊 저장소 현황"
        let detailsText = "⭐ 즐겨찾기 제외 · 상한: 무료 3개/프리미엄·트라이얼 10개"
        let headerAttr = NSMutableAttributedString(
            string: titleText + "\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.label
            ]
        )
        headerAttr.append(NSAttributedString(
            string: detailsText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel
            ]
        ))
        headerLabel.attributedText = headerAttr
        
        // 통계 라벨들
        totalSizeLabel.font = .systemFont(ofSize: 16)
        totalSizeLabel.textColor = .label
        
        fileCountLabel.font = .systemFont(ofSize: 16)
        fileCountLabel.textColor = .label
        
        retentionLabel.font = .systemFont(ofSize: 14)
        retentionLabel.textColor = .secondaryLabel
        retentionLabel.numberOfLines = 0
        retentionLabel.lineBreakMode = .byWordWrapping
        
        // 빠른 정리 제목
        let quickCleanupTitleLabel = UILabel()
        quickCleanupTitleLabel.text = "🧹 빠른 정리"
        quickCleanupTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        quickCleanupTitleLabel.textColor = .label
        
        // 버튼들 설정
        setupCleanupButton(compressButton, title: "🗑️ 선택한 날짜 삭제", color: .systemBlue)
        setupCleanupButton(deleteAllButton, title: "⚠️ 모든 대화 삭제", color: .systemRed)
        
        // 액션
        compressButton.addTarget(self, action: #selector(compressOldConversationsTapped), for: .touchUpInside)
        deleteAllButton.addTarget(self, action: #selector(deleteAllConversationsTapped), for: .touchUpInside)
        
        // 통합된 메인 스택 (프로퍼티)
        statsStack.axis = .vertical
        statsStack.spacing = 12
        statsStack.alignment = .fill
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // 통계 정보들을 먼저 추가
        [headerLabel, totalSizeLabel, fileCountLabel, retentionLabel].forEach { 
            $0.translatesAutoresizingMaskIntoConstraints = false
            statsStack.addArrangedSubview($0) 
        }
        
        // 구분선 추가
        let separatorView = UIView()
        separatorView.backgroundColor = UIColor.separator.withAlphaComponent(0.3)
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        statsStack.addArrangedSubview(separatorView)
        
        // 빠른 정리 섹션 추가
        quickCleanupTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        statsStack.addArrangedSubview(quickCleanupTitleLabel)
        statsStack.addArrangedSubview(compressButton)
        statsStack.addArrangedSubview(deleteAllButton)
        
        statisticsContainerView.addSubview(statsStack)
        
        NSLayoutConstraint.activate([
            statsStack.topAnchor.constraint(equalTo: statisticsContainerView.topAnchor, constant: 16),
            statsStack.leadingAnchor.constraint(equalTo: statisticsContainerView.leadingAnchor, constant: 16),
            statsStack.trailingAnchor.constraint(equalTo: statisticsContainerView.trailingAnchor, constant: -16),
            statsStack.bottomAnchor.constraint(equalTo: statisticsContainerView.bottomAnchor, constant: -16),
            
            // 구분선 높이
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            
            // 버튼 높이
            compressButton.heightAnchor.constraint(equalToConstant: 48),
            deleteAllButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    
    private func setupCleanupButton(_ button: UIButton, title: String, color: UIColor) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(color, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.systemGray6 : UIColor(red: 0.94, green: 0.96, blue: 0.99, alpha: 1)
        }
        button.layer.cornerRadius = 14
        button.layer.masksToBounds = false
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        // Neumorphic soft shadow (raised button)
        button.layer.shadowColor = UIColor.black.withAlphaComponent(0.12).cgColor
        button.layer.shadowOpacity = 1
        button.layer.shadowOffset = CGSize(width: 4, height: 4)
        button.layer.shadowRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupModelManagementSection() {
        modelManagementContainerView.translatesAutoresizingMaskIntoConstraints = false
        modelManagementContainerView.applyNeumorphicContainer(cornerRadius: 16)
        
        let headerLabel = UILabel()
        headerLabel.text = "🤖 대나무숲 친구 관리"
        headerLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        headerLabel.textColor = UIColor.label
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "다운로드된 친구들을 관리하세요"
        subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.textColor = UIColor.secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        modelStack.translatesAutoresizingMaskIntoConstraints = false
        modelStack.axis = .vertical
        modelStack.spacing = 12
        
        modelManagementContainerView.addSubview(headerLabel)
        modelManagementContainerView.addSubview(subtitleLabel)
        modelManagementContainerView.addSubview(modelStack)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: modelManagementContainerView.topAnchor, constant: 20),
            headerLabel.leadingAnchor.constraint(equalTo: modelManagementContainerView.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(equalTo: modelManagementContainerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: modelManagementContainerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: modelManagementContainerView.trailingAnchor, constant: -20),
            
            modelStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            modelStack.leadingAnchor.constraint(equalTo: modelManagementContainerView.leadingAnchor, constant: 20),
            modelStack.trailingAnchor.constraint(equalTo: modelManagementContainerView.trailingAnchor, constant: -20),
            modelStack.bottomAnchor.constraint(equalTo: modelManagementContainerView.bottomAnchor, constant: -20),
        ])
        
        refreshModelList()
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(StorageManagementCell.self, forCellReuseIdentifier: "StorageCell")
        tableView.backgroundColor = .clear  // 투명하게 변경
        tableView.separatorStyle = .none  // 구분선 제거 (뉴모피즘 디자인)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        // 중첩 스크롤 방지: 외부 UIScrollView에서 스크롤을 담당하므로 테이블 자체 스크롤 비활성화
        tableView.isScrollEnabled = false
        
        // 헤더 뷰
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 60))
        let headerLabel = UILabel()
        headerLabel.text = "📅 일별 대화 데이터"
        headerLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        headerLabel.textColor = .label
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let deleteSelectedButton = UIButton()
        deleteSelectedButton.setTitle("선택 삭제", for: .normal)
        deleteSelectedButton.setTitleColor(.systemRed, for: .normal)
        deleteSelectedButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        deleteSelectedButton.isEnabled = false
        deleteSelectedButton.addTarget(self, action: #selector(deleteSelectedTapped), for: .touchUpInside)
        deleteSelectedButton.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(headerLabel)
        headerView.addSubview(deleteSelectedButton)
        
        NSLayoutConstraint.activate([
            headerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            headerLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            deleteSelectedButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            deleteSelectedButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
        
        tableView.tableHeaderView = headerView
        // 동적 높이 제약 추가 (컨텐츠 사이즈로 갱신)
        tableHeightConstraint = tableView.heightAnchor.constraint(equalToConstant: 0)
        tableHeightConstraint?.isActive = true
    }
    
    private func setupLayout() {
        contentView.addSubview(statisticsContainerView)
        contentView.addSubview(modelManagementContainerView)
        contentView.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            // 스크롤뷰 제약조건
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 컨텐트뷰 제약조건
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 통계 섹션 카드 (빠른 정리 통합)
            statisticsContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            statisticsContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statisticsContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // 모델 관리 섹션
            modelManagementContainerView.topAnchor.constraint(equalTo: statisticsContainerView.bottomAnchor, constant: 16),
            modelManagementContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            modelManagementContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // 테이블뷰 (모델 관리 섹션 아래)
            tableView.topAnchor.constraint(equalTo: modelManagementContainerView.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Model Management
    
    /// 온디바이스 모델 ID를 친근한 별명으로 변환 (용량 순서 기반)
    private func friendlyNickname(for modelID: OnDeviceModelID) -> String {
        switch modelID {
        case .qwen05b_q4km: return "작은 클로버"      // 412MB (가장 작음)
        case .hcx05b_q8_0: return "클로버"          // 693MB
        case .amoral_gemma1b_v2_q4km: return "작은 잼민이" // 769MB
        case .gemma1b_iq4xs: return "잼민이"        // 957MB (가장 큼)
        }
    }
    
    private func refreshModelList() {
        Task { [weak self] in
            guard let self = self else { return }
            
            let allModels = OnDeviceModelID.allCases
            var installedModels: [(OnDeviceModelID, Int)] = []
            
            for modelID in allModels {
                let status = await OnDeviceAdapter.shared.status(for: modelID)
                if case .installed = status {
                    let record = ModelCatalog.record(for: modelID)
                    installedModels.append((modelID, record.approxBytes))
                }
            }
            
            await MainActor.run {
                self.updateModelViews(with: installedModels)
            }
        }
    }
    
    private func updateModelViews(with installedModels: [(OnDeviceModelID, Int)]) {
        // 기존 뷰들 제거
        for view in installedModelViews {
            view.removeFromSuperview()
        }
        installedModelViews.removeAll()
        
        if installedModels.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "아직 친구가 없어요."
            emptyLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            emptyLabel.textColor = UIColor.secondaryLabel
            emptyLabel.textAlignment = .center
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            
            modelStack.addArrangedSubview(emptyLabel)
            NSLayoutConstraint.activate([
                emptyLabel.heightAnchor.constraint(equalToConstant: 40)
            ])
        } else {
            // 용량 순으로 정렬 (작은 것부터)
            let sortedModels = installedModels.sorted { $0.1 < $1.1 }
            
            for (modelID, sizeBytes) in sortedModels {
                let nickname = friendlyNickname(for: modelID)
                let modelView = OnDeviceModelView(modelID: modelID, nickname: nickname, sizeBytes: sizeBytes)
                
                modelView.onDelete = { [weak self] modelID in
                    self?.showDeleteModelConfirmation(for: modelID)
                }
                
                modelStack.addArrangedSubview(modelView)
                installedModelViews.append(modelView)
            }
        }
    }
    
    private func showDeleteModelConfirmation(for modelID: OnDeviceModelID) {
        let nickname = friendlyNickname(for: modelID)
        
        let alert = UIAlertController(
            title: "\(nickname) 나가!",
            message: "정말로 \(nickname)를 나가라고 할까요?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소!", style: .cancel))
        alert.addAction(UIAlertAction(title: "나가!", style: .destructive) { [weak self] _ in
            self?.deleteModel(modelID)
        })
        
        present(alert, animated: true)
    }
    
    private func deleteModel(_ modelID: OnDeviceModelID) {
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                try OnDeviceAdapter.shared.deleteInstalled(id: modelID)
                
                await MainActor.run {
                    let nickname = self.friendlyNickname(for: modelID)
                    self.showSuccessAlert("삭제 완료", message: "\(nickname) 친구가 삭제되었습니다.")
                    self.refreshModelList()
                    self.loadStorageStatistics() // 전체 저장소 통계도 업데이트
                }
            } catch {
                await MainActor.run {
                    let nickname = self.friendlyNickname(for: modelID)
                    self.showError("\(nickname) 삭제 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadStorageStatistics() {
        guard !isLoading else { return }
        
        isLoading = true
        loadingIndicator.startAnimating()
        
        Task {
            do {
                // SessionManager를 통한 스토리지 통계 (간소화)
            let allSessions = SessionManager.shared.getAllSessions()
            let totalMessages = allSessions.reduce(0) { $0 + $1.chatMessages.count }
            let totalFeedback = allSessions.reduce(0) { $0 + $1.feedbackData.count }
            let statistics = StorageStatistics(
                totalSizeKB: totalMessages * 2, // 추정치 (KB)
                feedbackCount: totalFeedback,
                feedbackSizeKB: totalFeedback * 1,
                diaryCount: totalMessages / 2,
                diarySizeKB: totalMessages,
                presetCount: 0,
                presetSizeKB: 0,
                retentionDays: 60
            )
                
                await MainActor.run {
                    self.updateUI(with: statistics)
                    self.isLoading = false
                    self.loadingIndicator.stopAnimating()
                    self.adjustTableHeight()
                }
                
            } catch {
                await MainActor.run {
                    self.showError("저장소 정보 로드 실패: \(error.localizedDescription)")
                    self.isLoading = false
                    self.loadingIndicator.stopAnimating()
                }
            }
        }
    }
    
    private func updateUI(with statistics: StorageStatistics) {
        // 통계 업데이트
        totalSizeLabel.text = "💾 전체 크기: \(ByteCountFormatter.string(fromByteCount: Int64(statistics.totalSizeKB * 1024), countStyle: .file))"
        // 총 세션 수 / 일자 수 카운트
        let allSessions = SessionManager.shared.getAllSessions()
        let sessionCount = allSessions.count
        // rebuild 전에 미리 그룹 수 계산
        let uniqueDayCount = Set(allSessions.map { SettingsManager.shared.dateKey(for: $0.createdAt) }).count
        fileCountLabel.text = "📁 총 세션: \(sessionCount) · 일자: \(uniqueDayCount)"
        let protectionDays = SettingsManager.shared.protectedDaysWindow
        retentionLabel.text = "📅 보관 정책: 30일 자동 삭제 · 즐겨찾기 날짜/보호 요일 제외 · 최근 \(protectionDays)일 보호"
        
        // 테이블 데이터 재구성 (세션 기준 일자 그룹화 + 즐겨찾기 우선 정렬)
        rebuildDailyStorageData()
        tableView.reloadData()
        adjustTableHeight()
        
        // 선택 초기화
        selectedDates.removeAll()
        updateDeleteButtonState()
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func refreshButtonTapped() {
        loadStorageStatistics()
    }
    
    @objc private func deleteOldConversationsTapped() {
        showConfirmationAlert(
            title: "60일 이전 대화 삭제",
            message: "60일 이전의 모든 대화를 삭제하시겠습니까?\n(최근 \(SettingsManager.shared.protectedDaysWindow)일 및 보호 요일은 제외)\n삭제된 데이터는 복구할 수 없습니다.",
            confirmTitle: "삭제",
            style: .destructive
        ) {
            self.performDeleteOldConversations()
        }
    }
    
    @objc private func compressOldConversationsTapped() {
        // 선택 삭제 UX: 선택된 날짜가 없으면 안내 및 스크롤
        guard !selectedDates.isEmpty else {
            let alert = UIAlertController(title: "날짜 선택 필요", message: "삭제할 날짜를 먼저 선택해주세요.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
                // 테이블로 스크롤 유도
                if self.dailyStorageData.count > 0 {
                    let indexPath = IndexPath(row: 0, section: 0)
                    self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                }
            })
            present(alert, animated: true)
            return
        }
        deleteSelectedTapped()
    }
    
    @objc private func deleteAllConversationsTapped() {
        // 1단계 확인
        showConfirmationAlert(
            title: "⚠️ 모든 대화 삭제",
            message: "모든 대화 데이터를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다!",
            confirmTitle: "계속",
            style: .destructive
        ) {
            // 2단계 최종 확인
            self.showConfirmationAlert(
                title: "정말로 모두 삭제하시겠어요?",
                message: "컨텍스트, 캐시, 핵심 기억까지 완전히 삭제됩니다.",
                confirmTitle: "진짜로 삭제",
                style: .destructive
            ) {
                self.performDeleteAllConversations()
            }
        }
    }
    
    @objc private func deleteSelectedTapped() {
        let selectedCount = selectedDates.count
        guard selectedCount > 0 else {
            showError("삭제할 날짜를 먼저 선택해주세요.")
            return
        }
        // 보호 항목 포함 여부 확인
        let info = computeProtectedInfo(for: selectedDates)
        if info.protectedKeys.count > 0 {
            let protectionDays = SettingsManager.shared.protectedDaysWindow
            let message = """
            선택한 날짜 중 보호 대상이 포함되어 있습니다.
            • 즐겨찾기: \(info.favorites)개
            • 최근 \(protectionDays)일: \(info.recent)개
            • 보호 요일: \(info.weekday)개
            
            어떻게 진행할까요?
            """
            let alert = UIAlertController(title: "보호 대상 포함됨", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "취소", style: .cancel))
            alert.addAction(UIAlertAction(title: "보호 제외하고 삭제", style: .destructive, handler: { _ in
                let filtered = self.selectedDates.subtracting(info.protectedKeys)
                if filtered.isEmpty {
                    self.showError("보호 제외 시 삭제할 항목이 없습니다.")
                    return
                }
                self.performDeleteConversations(for: filtered)
            }))
            alert.addAction(UIAlertAction(title: "모두 삭제(보호 무시)", style: .default, handler: { _ in
                self.performDeleteConversations(for: self.selectedDates)
            }))
            present(alert, animated: true)
            return
        }
        // 보호 대상이 없으면 일반 확인 후 진행
        showConfirmationAlert(
            title: "선택된 대화 삭제",
            message: "선택된 \(selectedCount)개의 대화를 삭제하시겠습니까?",
            confirmTitle: "삭제",
            style: .destructive
        ) {
            self.performDeleteConversations(for: self.selectedDates)
        }
    }
    
    // MARK: - Operations
    
    private func performDeleteOldConversations() {
        Task {
            do {
                let deletedCount = SessionManager.shared.cleanupOldSessions(olderThanDays: 60)
                
                await MainActor.run {
                    self.showSuccessAlert("삭제 완료", message: "\(deletedCount)개의 오래된 대화를 삭제했습니다.")
                    self.loadStorageStatistics()
                    
                    // 🔄 ChatViewController에 변경 사항 알림
                    NotificationCenter.default.post(name: Notification.Name("ChatStoreDidChange"), object: nil)
                    UnifiedLogger.shared.debug("✅ ChatStoreDidChange 노티피케이션 발송 (30일 이전 삭제)", category: .storage)
                }
                
            } catch {
                await MainActor.run {
                    self.showError("삭제 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func performCompressOldConversations() {
        Task {
            do {
                // 30일 이전 세션 삭제
                let deletedCount = SessionManager.shared.cleanupOldSessions(olderThanDays: 30)
                
                await MainActor.run {
                    self.showSuccessAlert("삭제 완료", message: "\(deletedCount)개의 30일 이전 대화를 삭제했습니다.")
                    self.loadStorageStatistics()
                    
                    // 🔄 ChatViewController에 변경 사항 알림
                    NotificationCenter.default.post(name: Notification.Name("ChatStoreDidChange"), object: nil)
                    UnifiedLogger.shared.debug("✅ ChatStoreDidChange 노티피케이션 발송 (30일 이전 삭제)", category: .storage)
                }
                
            } catch {
                await MainActor.run {
                    self.showError("삭제 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func performDeleteAllConversations() {
        Task {
            do {
                let allDates = dailyStorageData.map { $0.date }
                // 모든 세션 삭제
                let allSessions = SessionManager.shared.getAllSessions()
                for session in allSessions {
                    _ = SessionManager.shared.deleteSession(by: session.id)
                }
                // 컨텍스트/캐시/핵심기억 삭제
                AIContextManager.shared.clearCache(reason: .manual, caller: "StorageManagementViewController.deleteAll")
                MemoryManager.shared.resetAll()
                SessionManager.shared.invalidateCache()
                
                await MainActor.run {
                    self.showSuccessAlert("삭제 완료", message: "모든 대화 및 관련 컨텍스트/캐시/핵심기억이 삭제되었습니다.")
                    self.loadStorageStatistics()
                    
                    // 🔄 ChatViewController에 변경 사항 알림
                    NotificationCenter.default.post(name: Notification.Name("ChatStoreDidChange"), object: nil)
                    UnifiedLogger.shared.debug("✅ ChatStoreDidChange 노티피케이션 발송 (모든 대화 삭제)", category: .storage)
                }
                
            } catch {
                await MainActor.run {
                    self.showError("삭제 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func performDeleteSelectedConversations() {
        // 기존 메서드는 선택된 날짜 전체 삭제로 위임
        performDeleteConversations(for: selectedDates)
    }

    private func performDeleteConversations(for dateKeys: Set<String>) {
        Task {
            do {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                
                let sessions = SessionManager.shared.getAllSessions()
                var totalDeleted = 0
                
                for key in dateKeys {
                    guard let date = formatter.date(from: key) else { continue }
                    let startOfDay = Calendar.current.startOfDay(for: date)
                    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
                    
                    // 해당 날짜 범위의 세션을 찾아 삭제
                    let targets = sessions.filter { $0.createdAt >= startOfDay && $0.createdAt < endOfDay }
                    for s in targets {
                        if SessionManager.shared.deleteSession(by: s.id) { totalDeleted += 1 }
                    }
                }
                
                await MainActor.run {
                    self.showSuccessAlert("삭제 완료", message: "\(totalDeleted)개의 선택된 대화를 삭제했습니다.")
                    // 선택 집합에서 삭제된 키 제거
                    self.selectedDates.subtract(dateKeys)
                    self.loadStorageStatistics()
                    
                    // 🔄 ChatViewController에 변경 사항 알림
                    NotificationCenter.default.post(name: Notification.Name("ChatStoreDidChange"), object: nil)
                    UnifiedLogger.shared.debug("✅ ChatStoreDidChange 노티피케이션 발송 (선택 삭제)", category: .storage)
                }
                
            } catch {
                await MainActor.run {
                    self.showError("삭제 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func adjustTableHeight() {
        // 컨텐츠 사이즈 기반 높이 갱신
        DispatchQueue.main.async {
            self.tableView.layoutIfNeeded()
            let height = self.tableView.contentSize.height
            if height > 0 {
                self.tableHeightConstraint?.constant = height
            }
        }
    }
    
    @objc private func handleFavoriteDatesChanged() {
        rebuildDailyStorageData()
        tableView.reloadData()
        adjustTableHeight()
    }
    
    private func toggleSelection(for date: Date) {
        let key = SettingsManager.shared.dateKey(for: date)
        if selectedDates.contains(key) {
            selectedDates.remove(key)
        } else {
            selectedDates.insert(key)
        }
        updateDeleteButtonState()
        // 성능을 위해 전체 리로드 대신 해당 행만 갱신할 수도 있으나, 단순화를 위해 리로드
        tableView.reloadData()
    }
    
    private func updateDeleteButtonState() {
        if let headerView = tableView.tableHeaderView,
           let deleteButton = headerView.subviews.compactMap({ $0 as? UIButton }).first {
            deleteButton.isEnabled = !selectedDates.isEmpty
            deleteButton.alpha = selectedDates.isEmpty ? 0.5 : 1.0
        }
    }
    
    // MARK: - Daily Data Builder
    
    /// 세션들을 일자별로 그룹화하여 DailyStorageInfo 배열을 구성합니다.
    private func rebuildDailyStorageData() {
        let sessions = SessionManager.shared.getAllSessions()
        guard !sessions.isEmpty else {
            dailyStorageData = []
            return
        }
        
        // yyyy-MM-dd 키 기준 그룹화
        var grouped: [String: (date: Date, messages: Int, sessions: Int)] = [:]
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        
        for s in sessions {
            let key = SettingsManager.shared.dateKey(for: s.createdAt)
            let date = f.date(from: key) ?? Calendar.current.startOfDay(for: s.createdAt)
            let msgCount = s.chatMessages.count
            if var bucket = grouped[key] {
                bucket.messages += msgCount
                bucket.sessions += 1
                grouped[key] = bucket
            } else {
                grouped[key] = (date: date, messages: msgCount, sessions: 1)
            }
        }
        
        // DailyStorageInfo 구성 (크기 추정: 메시지당 2KB)
        var result: [DailyStorageInfo] = []
        result.reserveCapacity(grouped.count)
        for (_, tuple) in grouped {
            let totalKB = tuple.messages * 2
            let info = DailyStorageInfo(
                date: tuple.date,
                totalSizeKB: totalKB,
                feedbackSizeKB: 0,
                diarySizeKB: 0,
                presetSizeKB: 0,
                itemCount: tuple.messages
            )
            result.append(info)
        }
        
        // 정렬: 즐겨찾기 날짜(최신순) 먼저, 그 다음 일반 날짜(최신순)
        let favKeys = SettingsManager.shared.favoriteDates
        let favs = result.filter { favKeys.contains(SettingsManager.shared.dateKey(for: $0.date)) }
            .sorted { $0.date > $1.date }
        let normals = result.filter { !favKeys.contains(SettingsManager.shared.dateKey(for: $0.date)) }
            .sorted { $0.date > $1.date }
        dailyStorageData = favs + normals
    }
    
    // MARK: - Utility Methods
    
    private func showConfirmationAlert(title: String, message: String, confirmTitle: String, style: UIAlertAction.Style, action: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: confirmTitle, style: style) { _ in
            action()
        })
        
        present(alert, animated: true)
    }
    
    private func showSuccessAlert(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    // MARK: - 보호 정책 정보 계산
    private func computeProtectedInfo(for keys: Set<String>) -> (protectedKeys: Set<String>, favorites: Int, recent: Int, weekday: Int) {
        var protected: Set<String> = []
        var favCount = 0
        var recentCount = 0
        var weekdayCount = 0
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        let now = SettingsManager.shared.currentDate()
        let protectedDays = SettingsManager.shared.protectedDaysWindow
        let protectedWeekdays = SettingsManager.shared.protectedWeekdays
        let cal = Calendar.current
        let startOfNow = cal.startOfDay(for: now)
        
        for key in keys {
            guard let date = f.date(from: key) else { continue }
            var isProtected = false
            if SettingsManager.shared.favoriteDates.contains(key) {
                favCount += 1
                isProtected = true
            }
            let startOfDate = cal.startOfDay(for: date)
            if let diff = cal.dateComponents([.day], from: startOfDate, to: startOfNow).day, diff >= 0, diff < protectedDays {
                recentCount += 1
                isProtected = true
            }
            let weekday = cal.component(.weekday, from: date)
            if protectedWeekdays.contains(weekday) {
                weekdayCount += 1
                isProtected = true
            }
            if isProtected { protected.insert(key) }
        }
        return (protected, favCount, recentCount, weekdayCount)
    }

    // MARK: - 즐겨찾기 상한 정보
    @objc private func showFavoriteCapInfo() {
        let isPremium = SubscriptionStatusCenter.shared.isPremium
        let cap = isPremium ? 10 : 3
        let message = """
        즐겨찾기 상한 정책
        • 무료: 최대 3개
        • 프리미엄/체험: 최대 10개
        
        구독 변경으로 상한이 낮아질 경우, 가장 오래된 즐겨찾기부터 자동 정리됩니다(최신 즐겨찾기는 유지).
        현재 상한: \(cap)개
        """
        let alert = UIAlertController(title: "즐겨찾기 상한 안내", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    private func openReadOnlyPreview(for date: Date) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let sessions = SessionManager.shared.getAllSessions()
        let matches = sessions.filter { $0.createdAt >= startOfDay && $0.createdAt < endOfDay }
        guard let target = matches.sorted(by: { $0.lastActivityAt > $1.lastActivityAt }).first else {
            let alert = UIAlertController(title: "대화 없음", message: "선택한 날짜에는 대화가 없습니다.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
            return
        }
        let chatVC = ChatRouter.chatViewController()
        chatVC.resumeSessionId = target.id
        navigationController?.pushViewController(chatVC, animated: true)
    }
    
    @objc private func handleResumeConversationForDate(_ notification: Notification) {
        guard let date = notification.object as? Date else { return }
        openReadOnlyPreview(for: date)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension StorageManagementViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dailyStorageData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StorageCell", for: indexPath) as! StorageManagementCell
        let dailyInfo = dailyStorageData[indexPath.row]
        
        let key = SettingsManager.shared.dateKey(for: dailyInfo.date)
        cell.configure(with: dailyInfo, isSelected: selectedDates.contains(key))
        // 선택 토글 콜백 연결 (DRY: 하나의 토글 로직 재사용)
        cell.onToggleSelect = { [weak self] date in
            self?.toggleSelection(for: date)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let dailyInfo = dailyStorageData[indexPath.row]
        // 날짜 탭 시 바로 읽기 전용 미리보기(해당 날짜의 최신 세션)로 이동
        openReadOnlyPreview(for: dailyInfo.date)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86  // 뉴모피즘 디자인을 위한 증가된 높이
    }
    
    // 스와이프 액션으로 선택/해제 지원
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let info = dailyStorageData[indexPath.row]
        let key = SettingsManager.shared.dateKey(for: info.date)
        let isSelected = selectedDates.contains(key)
        let title = isSelected ? "선택 해제" : "선택"
        let action = UIContextualAction(style: .normal, title: title) { [weak self] _, _, completion in
            guard let self = self else { completion(false); return }
            self.toggleSelection(for: info.date)
            completion(true)
        }
        action.backgroundColor = isSelected ? .systemGray : .systemBlue
        return UISwipeActionsConfiguration(actions: [action])
    }
}

// MARK: - Custom Cell


class StorageManagementCell: UITableViewCell {
    
    private let containerView = UIView()
    private let dateLabel = UILabel()
    private let sizeLabel = UILabel()
    private let messageCountLabel = UILabel()
    private let checkButton = LargerHitButton(type: .system)
    private let favoriteButton = UIButton(type: .system)
    private let resumeButton = UIButton(type: .system)
    private let protectionBadge = UILabel()
    
    // 외부에서 주입되는 선택 토글 콜백
    var onToggleSelect: ((Date) -> Void)?
    private var currentDate: Date?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // 뉴모피즘 컨테이너
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.systemGray6 : UIColor(red: 0.94, green: 0.96, blue: 0.99, alpha: 1)
        }
        containerView.layer.cornerRadius = 12
        contentView.addSubview(containerView)
        
        // 날짜 라벨
        dateLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        dateLabel.textColor = .label
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 크기 라벨
        sizeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        sizeLabel.textColor = .systemBlue
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 메시지 개수 라벨
        messageCountLabel.font = .systemFont(ofSize: 12)
        messageCountLabel.textColor = .secondaryLabel
        messageCountLabel.translatesAutoresizingMaskIntoConstraints = false
        messageCountLabel.numberOfLines = 1
        
        containerView.addSubview(dateLabel)
        containerView.addSubview(sizeLabel)
        containerView.addSubview(messageCountLabel)
        
        // 보호 배지 초기화 및 추가
        protectionBadge.text = "🛡 보호"
        protectionBadge.font = .systemFont(ofSize: 10, weight: .bold)
        protectionBadge.textColor = .white
        protectionBadge.backgroundColor = .systemTeal
        protectionBadge.layer.cornerRadius = 8
        protectionBadge.clipsToBounds = true
        protectionBadge.textAlignment = .center
        protectionBadge.translatesAutoresizingMaskIntoConstraints = false
        protectionBadge.isHidden = true
        containerView.addSubview(protectionBadge)
        
        // 체크 버튼(선택 토글)
        checkButton.translatesAutoresizingMaskIntoConstraints = false
        checkButton.tintColor = .systemBlue
        (checkButton as? LargerHitButton)?.minHitSize = CGSize(width: 44, height: 44)
        checkButton.addTarget(self, action: #selector(toggleSelectTapped), for: .touchUpInside)
        containerView.addSubview(checkButton)
        
        // 즐겨찾기 버튼(⭐︎)
        favoriteButton.setTitle("☆", for: .normal)
        favoriteButton.setTitleColor(.systemYellow, for: .normal)
        favoriteButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .medium)
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(favoriteButton)
        
        // 이어서 대화 버튼 - 최근 타입 버튼으로 변경
        resumeButton.setTitle("최근", for: .normal)
        resumeButton.setTitleColor(.white, for: .normal)
        resumeButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
        resumeButton.backgroundColor = .systemBlue
        resumeButton.layer.cornerRadius = 8
        resumeButton.clipsToBounds = true
        resumeButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        resumeButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(resumeButton)
        
        NSLayoutConstraint.activate([
            // 컨테이너 뷰
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // 날짜 라벨
            dateLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            dateLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            dateLabel.trailingAnchor.constraint(lessThanOrEqualTo: favoriteButton.leadingAnchor, constant: -8),
            
            // 메시지 카운트
            messageCountLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            messageCountLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            messageCountLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkButton.leadingAnchor, constant: -12),
            
            // 크기 라벨
            sizeLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            sizeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 14),
            
            // 보호 배지
            protectionBadge.centerYAnchor.constraint(equalTo: messageCountLabel.centerYAnchor),
            protectionBadge.trailingAnchor.constraint(lessThanOrEqualTo: favoriteButton.leadingAnchor, constant: -8),
            protectionBadge.leadingAnchor.constraint(greaterThanOrEqualTo: messageCountLabel.trailingAnchor, constant: 6),
            protectionBadge.heightAnchor.constraint(equalToConstant: 18),
            protectionBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            
        // 최근 버튼
        resumeButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
        resumeButton.trailingAnchor.constraint(equalTo: checkButton.leadingAnchor, constant: -12),
        resumeButton.heightAnchor.constraint(equalToConstant: 20),
            
            // 체크 버튼
            checkButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            checkButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -14),
            checkButton.widthAnchor.constraint(equalToConstant: 28),
            checkButton.heightAnchor.constraint(equalToConstant: 28),
            
            // 즐겨찾기 버튼
            favoriteButton.centerYAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            favoriteButton.trailingAnchor.constraint(equalTo: checkButton.leadingAnchor, constant: -12),
            favoriteButton.widthAnchor.constraint(equalToConstant: 32),
            favoriteButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    func configure(with dailyInfo: DailyStorageInfo, isSelected: Bool) {
        // 뉴모피즘 그림자 효과 적용
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = isSelected ? 0.08 : 0.04
        containerView.layer.shadowOffset = isSelected ? CGSize(width: 2, height: 2) : CGSize(width: 3, height: 3)
        containerView.layer.shadowRadius = isSelected ? 4 : 6
        
        dateLabel.text = dailyInfo.displayDate
        sizeLabel.text = "💾 " + dailyInfo.formattedSize
        messageCountLabel.text = "\(dailyInfo.messageCount)개 메시지, \(dailyInfo.conversationCount)개 대화"
        
        let imgName = isSelected ? "checkmark.circle.fill" : "circle"
        checkButton.setImage(UIImage(systemName: imgName), for: .normal)
        checkButton.tintColor = isSelected ? .systemBlue : .systemGray4
        
        let key = SettingsManager.shared.dateKey(for: dailyInfo.date)
        let isFav = SettingsManager.shared.favoriteDates.contains(key)
        favoriteButton.setTitle(isFav ? "★" : "☆", for: .normal)
        
        // 날짜 관련 계산 (DRY 원칙: 한 번만 계산)
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: SettingsManager.shared.currentDate())
        let dateStart = cal.startOfDay(for: dailyInfo.date)
        let daysDiff = cal.dateComponents([.day], from: dateStart, to: todayStart).day ?? Int.max
        let weekday = cal.component(.weekday, from: dailyInfo.date)
        
        // 보호 상태 판단
        let isRecentProtected = daysDiff >= 0 && daysDiff < SettingsManager.shared.protectedDaysWindow
        let isWeekdayProtected = SettingsManager.shared.protectedWeekdays.contains(weekday)
        
        // 보호 배지 표시
        var tags: [String] = []
        if isFav { tags.append("즐겨") }
        if isRecentProtected { tags.append("최근") }
        if isWeekdayProtected { tags.append("요일") }
        let needsBadge = !tags.isEmpty
        protectionBadge.isHidden = !needsBadge
        if needsBadge {
            protectionBadge.text = "🛡 " + tags.joined(separator: "·")
            protectionBadge.sizeToFit()
            protectionBadge.layoutIfNeeded()
        }
        
        // 최근 버튼 표시/숨김 (7일 이내만)
        resumeButton.isHidden = daysDiff > 7
        
        // 액션 바인딩(중복 addTarget 방지 위해 제거 후 재추가)
        favoriteButton.removeTarget(nil, action: nil, for: .allEvents)
        resumeButton.removeTarget(nil, action: nil, for: .allEvents)
        
        favoriteButton.addTarget(self, action: #selector(toggleFavorite), for: .touchUpInside)
        resumeButton.addTarget(self, action: #selector(resumeConversation), for: .touchUpInside)
        
        // tag/상태 보관
        let ts = Int(dailyInfo.date.timeIntervalSince1970)
        favoriteButton.tag = ts
        resumeButton.tag = ts
        currentDate = dailyInfo.date
        
        // 선택 상태에 따른 컨테이너 배경색 조정
        containerView.backgroundColor = UIColor { trait in
            if isSelected {
                return trait.userInterfaceStyle == .dark ? 
                    UIColor.systemBlue.withAlphaComponent(0.15) : 
                    UIColor.systemBlue.withAlphaComponent(0.08)
            } else {
                return trait.userInterfaceStyle == .dark ? 
                    UIColor.systemGray6 : 
                    UIColor(red: 0.94, green: 0.96, blue: 0.99, alpha: 1)
            }
        }
        backgroundColor = .clear
    }
    
    @objc private func toggleSelectTapped() {
        guard let date = currentDate else { return }
        onToggleSelect?(date)
    }
    
    @objc private func toggleFavorite(_ sender: UIButton) {
        let date = Date(timeIntervalSince1970: TimeInterval(sender.tag))
        let key = SettingsManager.shared.dateKey(for: date)
        var favs = SettingsManager.shared.favoriteDates
        let isFav = favs.contains(key)
        if isFav {
            favs.remove(key)
            SettingsManager.shared.favoriteDates = favs
            sender.setTitle("☆", for: .normal)
            NotificationCenter.default.post(name: Notification.Name("FavoriteDatesChanged"), object: nil)
        } else {
            // 제한: 무료 3개, 프리미엄(또는 유예/체험 활성 포함) 10개
            let isPremium = SubscriptionStatusCenter.shared.isPremium
            let cap = isPremium ? 10 : 3
            if favs.count >= cap {
                // 초과 시 자동 정리(오래된 항목부터)
                let removed = SettingsManager.shared.enforceFavoriteCap(cap: cap)
                if removed > 0 {
                    ToastManager.shared.showWarning(message: "즐겨찾기 상한 초과로 \(removed)개가 자동 정리되었습니다.")
                }
            }
            // 현재 키 추가(상한 확인 후)
            favs = SettingsManager.shared.favoriteDates
            favs.insert(key)
            SettingsManager.shared.favoriteDates = favs
            sender.setTitle("★", for: .normal)
            NotificationCenter.default.post(name: Notification.Name("FavoriteDatesChanged"), object: nil)
        }
    }
    
    @objc private func resumeConversation(_ sender: UIButton) {
        let date = Date(timeIntervalSince1970: TimeInterval(sender.tag))
        NotificationCenter.default.post(name: Notification.Name("ResumeConversationForDate"), object: date)
    }
}
