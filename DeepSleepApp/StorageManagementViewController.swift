import UIKit

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
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: statisticsContainerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: statisticsContainerView.leadingAnchor, constant: 16),
            
            totalSizeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            totalSizeLabel.leadingAnchor.constraint(equalTo: statisticsContainerView.leadingAnchor, constant: 16),
            
            fileCountLabel.topAnchor.constraint(equalTo: totalSizeLabel.bottomAnchor, constant: 8),
            fileCountLabel.leadingAnchor.constraint(equalTo: statisticsContainerView.leadingAnchor, constant: 16),
            
            retentionLabel.topAnchor.constraint(equalTo: fileCountLabel.bottomAnchor, constant: 8),
            retentionLabel.leadingAnchor.constraint(equalTo: statisticsContainerView.leadingAnchor, constant: 16),
            
            refreshButton.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            refreshButton.trailingAnchor.constraint(equalTo: statisticsContainerView.trailingAnchor, constant: -16),
            
            retentionLabel.bottomAnchor.constraint(equalTo: statisticsContainerView.bottomAnchor, constant: -16)
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
        setupCleanupButton(deleteOldButton, title: "🗑️ 30일 이전 삭제", color: .systemOrange)
        setupCleanupButton(compressButton, title: "📦 오래된 대화 압축", color: .systemBlue)
        setupCleanupButton(deleteAllButton, title: "⚠️ 모든 대화 삭제", color: .systemRed)
        
        deleteOldButton.addTarget(self, action: #selector(deleteOldConversationsTapped), for: .touchUpInside)
        compressButton.addTarget(self, action: #selector(compressOldConversationsTapped), for: .touchUpInside)
        deleteAllButton.addTarget(self, action: #selector(deleteAllConversationsTapped), for: .touchUpInside)
        
        quickCleanupContainerView.addSubview(titleLabel)
        quickCleanupContainerView.addSubview(deleteOldButton)
        quickCleanupContainerView.addSubview(compressButton)
        quickCleanupContainerView.addSubview(deleteAllButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: quickCleanupContainerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: quickCleanupContainerView.leadingAnchor, constant: 16),
            
            deleteOldButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            deleteOldButton.leadingAnchor.constraint(equalTo: quickCleanupContainerView.leadingAnchor, constant: 16),
            deleteOldButton.trailingAnchor.constraint(equalTo: quickCleanupContainerView.trailingAnchor, constant: -16),
            deleteOldButton.heightAnchor.constraint(equalToConstant: 44),
            
            compressButton.topAnchor.constraint(equalTo: deleteOldButton.bottomAnchor, constant: 8),
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
                let statistics = try await ChatManager.shared.getStorageStatistics()
                
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
        totalSizeLabel.text = "💾 전체 크기: \(statistics.formattedSize)"
        fileCountLabel.text = "📁 파일 개수: \(statistics.fileCount)개"
        retentionLabel.text = "📅 보관 기간: \(statistics.retentionDays)일"
        
        // 테이블 데이터 업데이트
        dailyStorageData = statistics.dailyBreakdown
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
            title: "30일 이전 대화 삭제",
            message: "30일 이전의 모든 대화를 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.",
            confirmTitle: "삭제",
            style: .destructive
        ) {
            self.performDeleteOldConversations()
        }
    }
    
    @objc private func compressOldConversationsTapped() {
        showConfirmationAlert(
            title: "오래된 대화 압축",
            message: "60일 이전의 대화를 압축하여 저장공간을 절약하시겠습니까?\n중요한 메시지만 보관됩니다.",
            confirmTitle: "압축",
            style: .default
        ) {
            self.performCompressOldConversations()
        }
    }
    
    @objc private func deleteAllConversationsTapped() {
        showConfirmationAlert(
            title: "⚠️ 모든 대화 삭제",
            message: "모든 대화 데이터를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다!",
            confirmTitle: "모두 삭제",
            style: .destructive
        ) {
            self.performDeleteAllConversations()
        }
    }
    
    @objc private func deleteSelectedTapped() {
        let selectedCount = selectedDates.count
        showConfirmationAlert(
            title: "선택된 대화 삭제",
            message: "선택된 \(selectedCount)개의 대화를 삭제하시겠습니까?",
            confirmTitle: "삭제",
            style: .destructive
        ) {
            self.performDeleteSelectedConversations()
        }
    }
    
    // MARK: - Operations
    
    private func performDeleteOldConversations() {
        Task {
            do {
                let deletedCount = try await ChatManager.shared.deleteConversationsOlderThan(days: 30)
                
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
                let compressedCount = try await ChatManager.shared.compressOldConversations(olderThanDays: 60)
                
                await MainActor.run {
                    self.showSuccessAlert("압축 완료", message: "\(compressedCount)개의 대화를 압축했습니다.")
                    self.loadStorageStatistics()
                    
                    // 🔄 ChatViewController에 변경 사항 알림
                    NotificationCenter.default.post(name: Notification.Name("ChatStoreDidChange"), object: nil)
                    UnifiedLogger.shared.debug("✅ ChatStoreDidChange 노티피케이션 발송 (압축 완료)", category: .storage)
                }
                
            } catch {
                await MainActor.run {
                    self.showError("압축 실패: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func performDeleteAllConversations() {
        Task {
            do {
                let allDates = dailyStorageData.map { $0.date }
                try await ChatManager.shared.deleteConversations(for: allDates)
                
                await MainActor.run {
                    self.showSuccessAlert("삭제 완료", message: "모든 대화를 삭제했습니다.")
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
        Task {
            do {
                try await ChatManager.shared.deleteConversations(for: Array(selectedDates))
                
                await MainActor.run {
                    self.showSuccessAlert("삭제 완료", message: "\(self.selectedDates.count)개의 선택된 대화를 삭제했습니다.")
                    self.selectedDates.removeAll()
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
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension StorageManagementViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dailyStorageData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StorageCell", for: indexPath) as! StorageManagementCell
        let dailyInfo = dailyStorageData[indexPath.row]
        
        cell.configure(with: dailyInfo, isSelected: selectedDates.contains(dailyInfo.date))
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let dailyInfo = dailyStorageData[indexPath.row]
        
        if selectedDates.contains(dailyInfo.date) {
            selectedDates.remove(dailyInfo.date)
        } else {
            selectedDates.insert(dailyInfo.date)
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
        
        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            sizeLabel.topAnchor.constraint(equalTo: dateLabel.topAnchor),
            sizeLabel.trailingAnchor.constraint(equalTo: checkmarkImageView.leadingAnchor, constant: -12),
            
            messageCountLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            messageCountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            messageCountLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func configure(with dailyInfo: DailyStorageInfo, isSelected: Bool) {
        dateLabel.text = dailyInfo.displayDate
        sizeLabel.text = dailyInfo.formattedSize
        messageCountLabel.text = "💬 \(dailyInfo.messageCount)개 메시지, \(dailyInfo.conversationCount)개 대화"
        
        checkmarkImageView.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        checkmarkImageView.tintColor = isSelected ? .systemBlue : .systemGray3
        
        backgroundColor = isSelected ? .systemBlue.withAlphaComponent(0.1) : .systemBackground
    }
}