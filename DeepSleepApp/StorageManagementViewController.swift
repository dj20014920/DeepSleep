import UIKit

// 중앙집중형 처리: SharedModels.swift의 정의 사용

/// 📦 저장소 관리 화면
/// 사용자가 대화 데이터 용량을 확인하고 선택적으로 삭제할 수 있는 기능 제공
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
    
    // 빠른 정리 섹션
    private let quickCleanupContainerView = UIView()
    private let deleteOldButton = UIButton()
    private let compressButton = UIButton()
    private let deleteAllButton = UIButton()
    
    // 개별 관리 섹션
    private let tableView = UITableView()
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
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "저장소 관리"
        view.backgroundColor = .systemBackground
        
        // 네비게이션 바 설정
        setupNavigationBar()
        
        // 스크롤뷰 설정
        setupScrollView()
        
        // 각 섹션 설정
        setupStatisticsSection()
        setupQuickCleanupSection()
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
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
    }
    
    private func setupStatisticsSection() {
        statisticsContainerView.backgroundColor = .secondarySystemBackground
        statisticsContainerView.layer.cornerRadius = 12
        statisticsContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 제목
        let titleLabel = UILabel()
        titleLabel.text = "📊 저장소 현황"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 통계 라벨들
        totalSizeLabel.font = .systemFont(ofSize: 16)
        totalSizeLabel.textColor = .label
        totalSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        fileCountLabel.font = .systemFont(ofSize: 16)
        fileCountLabel.textColor = .label
        fileCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        retentionLabel.font = .systemFont(ofSize: 16)
        retentionLabel.textColor = .secondaryLabel
        retentionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 새로고침 버튼
        refreshButton.setTitle("🔄 새로고침", for: .normal)
        refreshButton.setTitleColor(.systemBlue, for: .normal)
        refreshButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        refreshButton.addTarget(self, action: #selector(refreshButtonTapped), for: .touchUpInside)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        
        statisticsContainerView.addSubview(titleLabel)
        statisticsContainerView.addSubview(totalSizeLabel)
        statisticsContainerView.addSubview(fileCountLabel)
        statisticsContainerView.addSubview(retentionLabel)
        statisticsContainerView.addSubview(refreshButton)
        
        // 정책 배지(상단 고정): 최근 N일 보호, 즐겨찾기 제외
        let protectionDays = SettingsManager.shared.protectedDaysWindow
        let policyRecentBadge = UILabel()
        policyRecentBadge.text = "🔒 최근 \(protectionDays)일 보호"
        policyRecentBadge.font = .systemFont(ofSize: 12, weight: .semibold)
        policyRecentBadge.textColor = .white
        policyRecentBadge.backgroundColor = .systemBlue
        policyRecentBadge.layer.cornerRadius = 6
        policyRecentBadge.clipsToBounds = true
        policyRecentBadge.textAlignment = .center
        policyRecentBadge.translatesAutoresizingMaskIntoConstraints = false
        
        let policyFavoriteBadge = UILabel()
        policyFavoriteBadge.text = "⭐ 즐겨찾기 제외"
        policyFavoriteBadge.font = .systemFont(ofSize: 12, weight: .semibold)
        policyFavoriteBadge.textColor = .white
        policyFavoriteBadge.backgroundColor = .systemOrange
        policyFavoriteBadge.layer.cornerRadius = 6
        policyFavoriteBadge.clipsToBounds = true
        policyFavoriteBadge.textAlignment = .center
        policyFavoriteBadge.translatesAutoresizingMaskIntoConstraints = false
        
        statisticsContainerView.addSubview(policyRecentBadge)
        statisticsContainerView.addSubview(policyFavoriteBadge)
        
        // ⭐️ 즐겨찾기 상한 배지 + 자세히 버튼
        let capBadge = UILabel()
        capBadge.text = "⭐️ 즐겨찾기 상한: 무료 3개 · 프리미엄/트라이얼 10개"
        capBadge.font = .systemFont(ofSize: 13, weight: .semibold)
        capBadge.textColor = .systemYellow
        capBadge.translatesAutoresizingMaskIntoConstraints = false
        statisticsContainerView.addSubview(capBadge)
        
        let capInfoButton = UIButton(type: .system)
        capInfoButton.setTitle("자세히", for: .normal)
        capInfoButton.setTitleColor(.systemBlue, for: .normal)
        capInfoButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        capInfoButton.addTarget(self, action: #selector(showFavoriteCapInfo), for: .touchUpInside)
        capInfoButton.translatesAutoresizingMaskIntoConstraints = false
        statisticsContainerView.addSubview(capInfoButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: statisticsContainerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: statisticsContainerView.leadingAnchor, constant: 16),
            
            totalSizeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            totalSizeLabel.leadingAnchor.constraint(equalTo: statisticsContainerView.leadingAnchor, constant: 16),
            
            fileCountLabel.topAnchor.constraint(equalTo: totalSizeLabel.bottomAnchor, constant: 8),
            fileCountLabel.leadingAnchor.constraint(equalTo: statisticsContainerView.leadingAnchor, constant: 16),
            
            retentionLabel.topAnchor.constraint(equalTo: fileCountLabel.bottomAnchor, constant: 8),
            retentionLabel.leadingAnchor.constraint(equalTo: statisticsContainerView.leadingAnchor, constant: 16),
            
            policyRecentBadge.topAnchor.constraint(equalTo: retentionLabel.bottomAnchor, constant: 6),
            policyRecentBadge.leadingAnchor.constraint(equalTo: statisticsContainerView.leadingAnchor, constant: 16),
            policyRecentBadge.heightAnchor.constraint(equalToConstant: 22),
            
            policyFavoriteBadge.centerYAnchor.constraint(equalTo: policyRecentBadge.centerYAnchor),
            policyFavoriteBadge.leadingAnchor.constraint(equalTo: policyRecentBadge.trailingAnchor, constant: 8),
            policyFavoriteBadge.heightAnchor.constraint(equalToConstant: 22),
            policyFavoriteBadge.trailingAnchor.constraint(lessThanOrEqualTo: statisticsContainerView.trailingAnchor, constant: -16),
            
            capBadge.topAnchor.constraint(equalTo: policyRecentBadge.bottomAnchor, constant: 6),
            capBadge.leadingAnchor.constraint(equalTo: statisticsContainerView.leadingAnchor, constant: 16),
            
            capInfoButton.centerYAnchor.constraint(equalTo: capBadge.centerYAnchor),
            capInfoButton.leadingAnchor.constraint(equalTo: capBadge.trailingAnchor, constant: 8),
            capInfoButton.trailingAnchor.constraint(lessThanOrEqualTo: statisticsContainerView.trailingAnchor, constant: -16),
            
            refreshButton.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            refreshButton.trailingAnchor.constraint(equalTo: statisticsContainerView.trailingAnchor, constant: -16),
            
            capInfoButton.bottomAnchor.constraint(equalTo: statisticsContainerView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupQuickCleanupSection() {
        quickCleanupContainerView.backgroundColor = .secondarySystemBackground
        quickCleanupContainerView.layer.cornerRadius = 12
        quickCleanupContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        // 제목
        let titleLabel = UILabel()
        titleLabel.text = "🧹 빠른 정리"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 버튼들 설정
        setupCleanupButton(compressButton, title: "🗑️ 선택한 날짜 삭제", color: .systemBlue)
        setupCleanupButton(deleteAllButton, title: "⚠️ 모든 대화 삭제", color: .systemRed)
        
        // 액션
        compressButton.addTarget(self, action: #selector(compressOldConversationsTapped), for: .touchUpInside)
        deleteAllButton.addTarget(self, action: #selector(deleteAllConversationsTapped), for: .touchUpInside)
        
        quickCleanupContainerView.addSubview(titleLabel)
        quickCleanupContainerView.addSubview(compressButton)
        quickCleanupContainerView.addSubview(deleteAllButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: quickCleanupContainerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: quickCleanupContainerView.leadingAnchor, constant: 16),
            
            compressButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            compressButton.leadingAnchor.constraint(equalTo: quickCleanupContainerView.leadingAnchor, constant: 16),
            compressButton.trailingAnchor.constraint(equalTo: quickCleanupContainerView.trailingAnchor, constant: -16),
            compressButton.heightAnchor.constraint(equalToConstant: 44),
            
            deleteAllButton.topAnchor.constraint(equalTo: compressButton.bottomAnchor, constant: 8),
            deleteAllButton.leadingAnchor.constraint(equalTo: quickCleanupContainerView.leadingAnchor, constant: 16),
            deleteAllButton.trailingAnchor.constraint(equalTo: quickCleanupContainerView.trailingAnchor, constant: -16),
            deleteAllButton.heightAnchor.constraint(equalToConstant: 44),
            deleteAllButton.bottomAnchor.constraint(equalTo: quickCleanupContainerView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupCleanupButton(_ button: UIButton, title: String, color: UIColor) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(color, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = color.withAlphaComponent(0.1)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = color.withAlphaComponent(0.3).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(StorageManagementCell.self, forCellReuseIdentifier: "StorageCell")
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .singleLine
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
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
    }
    
    private func setupLayout() {
        contentView.addSubview(statisticsContainerView)
        contentView.addSubview(quickCleanupContainerView)
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
            
            // 통계 섹션
            statisticsContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            statisticsContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statisticsContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // 빠른 정리 섹션
            quickCleanupContainerView.topAnchor.constraint(equalTo: statisticsContainerView.bottomAnchor, constant: 16),
            quickCleanupContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            quickCleanupContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // 테이블뷰
            tableView.topAnchor.constraint(equalTo: quickCleanupContainerView.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.heightAnchor.constraint(equalToConstant: 400), // 고정 높이
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
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
        fileCountLabel.text = "📁 피드백 개수: \(statistics.feedbackCount)개"
        let protectionDays = SettingsManager.shared.protectedDaysWindow
        retentionLabel.text = "📅 보관 정책: 30일 자동 삭제 · 즐겨찾기 날짜/보호 요일 제외 · 최근 \(protectionDays)일 보호"
        
        // 테이블 데이터 업데이트 (간소화)
        dailyStorageData = []
        tableView.reloadData()
        
        // 선택 초기화
        selectedDates.removeAll()
        updateDeleteButtonState()
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
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
    
    private func updateDeleteButtonState() {
        if let headerView = tableView.tableHeaderView,
           let deleteButton = headerView.subviews.compactMap({ $0 as? UIButton }).first {
            deleteButton.isEnabled = !selectedDates.isEmpty
            deleteButton.alpha = selectedDates.isEmpty ? 0.5 : 1.0
        }
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
    @objc private func handleResumeConversationForDate(_ notification: Notification) {
        guard let date = notification.object as? Date else { return }
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
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let dailyInfo = dailyStorageData[indexPath.row]
        let key = SettingsManager.shared.dateKey(for: dailyInfo.date)
        
        if selectedDates.contains(key) {
            selectedDates.remove(key)
        } else {
            selectedDates.insert(key)
        }
        
        tableView.reloadRows(at: [indexPath], with: .none)
        updateDeleteButtonState()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
}

// MARK: - Custom Cell

class StorageManagementCell: UITableViewCell {
    
    private let dateLabel = UILabel()
    private let sizeLabel = UILabel()
    private let messageCountLabel = UILabel()
    private let checkmarkImageView = UIImageView()
    private let favoriteButton = UIButton(type: .system)
    private let resumeButton = UIButton(type: .system)
    private let protectionBadge = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // 날짜 라벨
        dateLabel.font = .systemFont(ofSize: 16, weight: .medium)
        dateLabel.textColor = .label
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 크기 라벨
        sizeLabel.font = .systemFont(ofSize: 14)
        sizeLabel.textColor = .systemBlue
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 메시지 개수 라벨
        messageCountLabel.font = .systemFont(ofSize: 14)
        messageCountLabel.textColor = .secondaryLabel
        messageCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 체크마크
        checkmarkImageView.image = UIImage(systemName: "circle")
        checkmarkImageView.tintColor = .systemGray3
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(dateLabel)
        contentView.addSubview(sizeLabel)
        contentView.addSubview(messageCountLabel)
        contentView.addSubview(checkmarkImageView)
        
        // 보호 배지
        protectionBadge.text = "🛡 보호"
        protectionBadge.font = .systemFont(ofSize: 12, weight: .semibold)
        protectionBadge.textColor = .white
        protectionBadge.backgroundColor = .systemTeal
        protectionBadge.layer.cornerRadius = 6
        protectionBadge.clipsToBounds = true
        protectionBadge.textAlignment = .center
        protectionBadge.translatesAutoresizingMaskIntoConstraints = false
        protectionBadge.isHidden = true
        contentView.addSubview(protectionBadge)
        
        // 즐겨찾기 버튼(⭐︎)
        favoriteButton.setTitle("☆", for: .normal)
        favoriteButton.setTitleColor(.systemYellow, for: .normal)
        favoriteButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(favoriteButton)
        
        // 이어서 대화 버튼
        resumeButton.setTitle("이어서 대화", for: .normal)
        resumeButton.setTitleColor(.systemBlue, for: .normal)
        resumeButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        resumeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(resumeButton)
        
        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            sizeLabel.topAnchor.constraint(equalTo: dateLabel.topAnchor),
            sizeLabel.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -12),
            
            messageCountLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            messageCountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            protectionBadge.centerYAnchor.constraint(equalTo: messageCountLabel.centerYAnchor),
            protectionBadge.leadingAnchor.constraint(equalTo: messageCountLabel.trailingAnchor, constant: 8),
            protectionBadge.heightAnchor.constraint(equalToConstant: 20),
            protectionBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
            
            messageCountLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24),
            
            favoriteButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            favoriteButton.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -12),
            
            resumeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            resumeButton.topAnchor.constraint(equalTo: messageCountLabel.bottomAnchor, constant: 4)
        ])
    }
    
    func configure(with dailyInfo: DailyStorageInfo, isSelected: Bool) {
        dateLabel.text = dailyInfo.displayDate
        sizeLabel.text = dailyInfo.formattedSize
        messageCountLabel.text = "💬 \(dailyInfo.messageCount)개 메시지, \(dailyInfo.conversationCount)개 대화"
        
        checkmarkImageView.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        checkmarkImageView.tintColor = isSelected ? .systemBlue : .systemGray3
        
        let key = SettingsManager.shared.dateKey(for: dailyInfo.date)
        let isFav = SettingsManager.shared.favoriteDates.contains(key)
        favoriteButton.setTitle(isFav ? "★" : "☆", for: .normal)
        
        // 보호 배지 표시 여부 계산
        // 보호 조건: 즐겨찾기 OR 최근 보호창 OR 보호 요일
        // 라벨 조합: "🛡 즐겨·최근·요일" (해당되는 항목만 결합)
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: SettingsManager.shared.currentDate())
        let dateStart = cal.startOfDay(for: dailyInfo.date)
        let diff = cal.dateComponents([.day], from: dateStart, to: todayStart).day ?? Int.max
        let isRecentProtected = diff >= 0 && diff < SettingsManager.shared.protectedDaysWindow
        let weekday = cal.component(.weekday, from: dailyInfo.date)
        let isWeekdayProtected = SettingsManager.shared.protectedWeekdays.contains(weekday)
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
        
        // 액션 바인딩(중복 addTarget 방지 위해 제거 후 재추가)
        favoriteButton.removeTarget(nil, action: nil, for: .allEvents)
        resumeButton.removeTarget(nil, action: nil, for: .allEvents)
        
        favoriteButton.addTarget(self, action: #selector(toggleFavorite), for: .touchUpInside)
        resumeButton.addTarget(self, action: #selector(resumeConversation), for: .touchUpInside)
        
        // tag에 날짜 타임스탬프를 보관하여 액션에서 식별
        favoriteButton.tag = Int(dailyInfo.date.timeIntervalSince1970)
        resumeButton.tag = Int(dailyInfo.date.timeIntervalSince1970)
        
        backgroundColor = isSelected ? .systemBlue.withAlphaComponent(0.1) : .systemBackground
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
        } else {
            // 제한: 무료 3개, 프리미엄(또는 유예/체험 활성 포함) 10개
            let isPremium = SubscriptionStatusCenter.shared.isPremium
            let cap = isPremium ? 10 : 3
            if favs.count >= cap {
                ToastManager.shared.showWarning(message: "즐겨찾기는 최대 \(cap)개까지 가능합니다.")
                return
            }
            favs.insert(key)
            SettingsManager.shared.favoriteDates = favs
            sender.setTitle("★", for: .normal)
        }
    }
    
    @objc private func resumeConversation(_ sender: UIButton) {
        let date = Date(timeIntervalSince1970: TimeInterval(sender.tag))
        NotificationCenter.default.post(name: Notification.Name("ResumeConversationForDate"), object: date)
    }
}
