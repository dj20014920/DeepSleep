//
//  PermissionSettingsViewController.swift
//  DeepSleep
//
//  Created on 2025-09-01.
//

import UIKit

/// 🔐 권한 설정 화면
/// 사용자가 앱에서 사용하는 모든 권한을 관리할 수 있는 화면
class PermissionSettingsViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    private let headerView = UIView()
    private let headerLabel = UILabel()
    private let headerDescriptionLabel = UILabel()
    
    // 권한별 섹션 뷰들
    private var permissionViews: [PermissionType: PermissionItemView] = [:]
    
    // MARK: - Properties
    private var permissionStatuses: [PermissionType: PermissionStatus] = [:]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadPermissionStatuses()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 화면이 나타날 때마다 권한 상태를 새로고침
        loadPermissionStatuses()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        
        setupScrollView()
        setupHeaderView()
        setupStackView()
        setupPermissionViews()
        setupConstraints()
    }
    
    private func setupNavigationBar() {
        title = "권한 설정"
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // 새로고침 버튼 추가
        let refreshButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshButtonTapped)
        )
        navigationItem.rightBarButtonItem = refreshButton
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
    }
    
    private func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIDesignSystem.Colors.cardBackground
        headerView.layer.cornerRadius = 12
        headerView.layer.shadowOpacity = 0.1
        headerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        headerView.layer.shadowRadius = 4
        
        // 헤더 라벨
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.text = "🔐 앱 권한 관리"
        headerLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        headerLabel.textColor = UIDesignSystem.Colors.primaryText
        
        // 설명 라벨
        headerDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        headerDescriptionLabel.text = "DeepSleep이 제대로 작동하기 위해 필요한 권한들을 관리하세요.\n권한이 거부된 경우 해당 기능을 사용할 수 없습니다."
        headerDescriptionLabel.font = UIFont.systemFont(ofSize: 14)
        headerDescriptionLabel.textColor = UIDesignSystem.Colors.secondaryText
        headerDescriptionLabel.numberOfLines = 0
        
        headerView.addSubview(headerLabel)
        headerView.addSubview(headerDescriptionLabel)
        contentView.addSubview(headerView)
    }
    
    private func setupStackView() {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        contentView.addSubview(stackView)
    }
    
    private func setupPermissionViews() {
        for permissionType in PermissionType.allCases {
            let permissionView = PermissionItemView(permissionType: permissionType)
            permissionView.delegate = self
            permissionViews[permissionType] = permissionView
            stackView.addArrangedSubview(permissionView)
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
            
            // HeaderView
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Header labels
            headerLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            headerDescriptionLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            headerDescriptionLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            headerDescriptionLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            headerDescriptionLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            
            // StackView
            stackView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Data Loading
    
    private func loadPermissionStatuses() {
        PermissionManager.shared.getAllPermissionStatuses { [weak self] statuses in
            DispatchQueue.main.async {
                self?.permissionStatuses = statuses
                self?.updatePermissionViews()
            }
        }
    }
    
    private func updatePermissionViews() {
        for (permissionType, status) in permissionStatuses {
            permissionViews[permissionType]?.updateStatus(status)
        }
    }
    
    // MARK: - Actions
    
    @objc private func refreshButtonTapped() {
        // 새로고침 애니메이션 표시
        navigationItem.rightBarButtonItem?.isEnabled = false
        
        // 디버그 로그 추가
        print("🔄 [PermissionSettings] 권한 상태 새로고침 시작")
        
        loadPermissionStatuses()
        
        // 1초 후 버튼 다시 활성화
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.navigationItem.rightBarButtonItem?.isEnabled = true
            print("✅ [PermissionSettings] 권한 상태 새로고침 완료")
        }
    }
}

// MARK: - PermissionItemViewDelegate
extension PermissionSettingsViewController: PermissionItemViewDelegate {
    
    func permissionItemView(_ view: PermissionItemView, didRequestPermission permissionType: PermissionType) {
        PermissionManager.shared.requestPermission(for: permissionType) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.showSuccessAlert(for: permissionType)
                } else {
                    self?.showPermissionDeniedAlert(for: permissionType)
                }
                // 권한 상태 새로고침
                self?.loadPermissionStatuses()
            }
        }
    }
    
    func permissionItemView(_ view: PermissionItemView, didRequestSettingsFor permissionType: PermissionType) {
        showSettingsAlert(for: permissionType)
    }
    
    private func showSuccessAlert(for permissionType: PermissionType) {
        let alert = UIAlertController(
            title: "권한 허용됨",
            message: "\(permissionType.displayName) 권한이 허용되었습니다.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    private func showPermissionDeniedAlert(for permissionType: PermissionType) {
        let message: String
        
        switch permissionType {
        case .calendar:
            message = "📅 캘린더 권한이 거부되었습니다.\n\n할 일을 시스템 캘린더에 동기화하려면 설정에서 직접 권한을 허용해주세요.\n\n설정 > 개인정보보호 > 캘린더 > DeepSleep"
        case .notification:
            message = "🔔 알림 권한이 거부되었습니다.\n\n할 일 미리 알림을 받으려면 설정에서 직접 권한을 허용해주세요."
        case .health:
            message = "❤️ 건강 데이터 권한이 거부되었습니다.\n\n수면 분석 및 마음챙김 데이터를 사용하려면 설정에서 직접 권한을 허용해주세요."
        case .backgroundAudio:
            message = "🎵 백그라운드 오디오는 앱 설정에서 관리됩니다."
        }
        
        let alert = UIAlertController(
            title: "권한 거부됨",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "설정으로 이동", style: .default) { _ in
            PermissionManager.shared.openSpecificPermissionSettings(for: permissionType)
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showSettingsAlert(for permissionType: PermissionType) {
        let alert = UIAlertController(
            title: "설정으로 이동",
            message: "\(permissionType.displayName) 권한을 변경하시겠습니까?\niOS 설정 앱으로 이동합니다.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "설정으로 이동", style: .default) { _ in
            PermissionManager.shared.openSpecificPermissionSettings(for: permissionType)
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - PermissionItemView Delegate Protocol
protocol PermissionItemViewDelegate: AnyObject {
    func permissionItemView(_ view: PermissionItemView, didRequestPermission permissionType: PermissionType)
    func permissionItemView(_ view: PermissionItemView, didRequestSettingsFor permissionType: PermissionType)
}

// MARK: - PermissionItemView
/// 개별 권한 항목을 표시하는 뷰
class PermissionItemView: UIView {
    
    // MARK: - Properties
    weak var delegate: PermissionItemViewDelegate?
    private let permissionType: PermissionType
    private var currentStatus: PermissionStatus = .notDetermined
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let iconLabel = UILabel()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let statusLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    
    // MARK: - Initialization
    
    init(permissionType: PermissionType) {
        self.permissionType = permissionType
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        setupContainerView()
        setupLabels()
        setupActionButton()
        setupConstraints()
    }
    
    private func setupContainerView() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIDesignSystem.Colors.cardBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4
        addSubview(containerView)
    }
    
    private func setupLabels() {
        // 아이콘
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.text = permissionType.icon
        iconLabel.font = UIFont.systemFont(ofSize: 24)
        
        // 제목
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = permissionType.displayName
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = UIDesignSystem.Colors.primaryText
        
        // 설명
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.text = permissionType.description
        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = UIDesignSystem.Colors.secondaryText
        descriptionLabel.numberOfLines = 0
        
        // 상태
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 8
        statusLabel.layer.masksToBounds = true
        
        containerView.addSubview(iconLabel)
        containerView.addSubview(titleLabel)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(statusLabel)
    }
    
    private func setupActionButton() {
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        actionButton.layer.cornerRadius = 8
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        containerView.addSubview(actionButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            
            // Icon
            iconLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            iconLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconLabel.widthAnchor.constraint(equalToConstant: 30),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -8),
            
            // Description
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Status
            statusLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            statusLabel.widthAnchor.constraint(equalToConstant: 80),
            statusLabel.heightAnchor.constraint(equalToConstant: 24),
            
            // Action Button
            actionButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            actionButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            actionButton.widthAnchor.constraint(equalToConstant: 100),
            actionButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    // MARK: - Update Status
    
    func updateStatus(_ status: PermissionStatus) {
        currentStatus = status
        
        // 상태 라벨 업데이트
        statusLabel.text = status.displayName
        statusLabel.backgroundColor = status.color.withAlphaComponent(0.2)
        statusLabel.textColor = status.color
        
        // 액션 버튼 업데이트
        updateActionButton()
    }
    
    private func updateActionButton() {
        switch currentStatus {
        case .notDetermined:
            actionButton.setTitle("권한 요청", for: .normal)
            actionButton.backgroundColor = UIColor.systemBlue
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.isEnabled = true
            
        case .denied, .restricted:
            actionButton.setTitle("설정으로", for: .normal)
            actionButton.backgroundColor = UIColor.systemOrange
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.isEnabled = true
            
        case .authorized, .provisional:
            actionButton.setTitle("설정 변경", for: .normal)
            actionButton.backgroundColor = UIColor.systemGray5
            actionButton.setTitleColor(UIColor.systemBlue, for: .normal)
            actionButton.isEnabled = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func actionButtonTapped() {
        switch currentStatus {
        case .notDetermined:
            delegate?.permissionItemView(self, didRequestPermission: permissionType)
        case .denied, .restricted, .authorized, .provisional:
            delegate?.permissionItemView(self, didRequestSettingsFor: permissionType)
        }
    }
}