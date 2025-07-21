import UIKit

/// 📋 설정 섹션을 표시하는 커스텀 뷰
class SettingsSectionView: UIView {
    
    // MARK: - UI Components
    
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let contentStackView = UIStackView()
    
    // MARK: - Properties
    
    weak var delegate: SettingsSectionDelegate?
    private var items: [SettingsItem] = []
    
    // MARK: - Initialization
    
    init(title: String, subtitle: String? = nil) {
        super.init(frame: .zero)
        setupUI()
        setupContent(title: title, subtitle: subtitle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        backgroundColor = UIDesignSystem.Colors.cardBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        
        // Header View 설정
        headerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerView)
        
        // Title Label 설정
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = UIDesignSystem.Colors.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)
        
        // Subtitle Label 설정
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIDesignSystem.Colors.secondaryText
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(subtitleLabel)
        
        // Content StackView 설정
        contentStackView.axis = .vertical
        contentStackView.spacing = 0
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStackView)
        
        setupConstraints()
    }
    
    private func setupContent(title: String, subtitle: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Header View
            headerView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Title Label
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            
            // Subtitle Label
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            
            // Content StackView
            contentStackView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Public Methods
    
    func addItem(_ item: SettingsItem) {
        items.append(item)
        
        let itemView = SettingsItemView(item: item)
        contentStackView.addArrangedSubview(itemView)
        
        // 마지막 아이템이 아니면 구분선 추가
        if items.count > 1 {
            let separatorView = UIView()
            separatorView.backgroundColor = UIDesignSystem.Colors.separatorColor
            separatorView.translatesAutoresizingMaskIntoConstraints = false
            
            let separatorContainer = UIView()
            separatorContainer.addSubview(separatorView)
            
            NSLayoutConstraint.activate([
                separatorView.heightAnchor.constraint(equalToConstant: 0.5),
                separatorView.leadingAnchor.constraint(equalTo: separatorContainer.leadingAnchor, constant: 16),
                separatorView.trailingAnchor.constraint(equalTo: separatorContainer.trailingAnchor, constant: -16),
                separatorView.centerYAnchor.constraint(equalTo: separatorContainer.centerYAnchor),
                separatorContainer.heightAnchor.constraint(equalToConstant: 1)
            ])
            
            contentStackView.insertArrangedSubview(separatorContainer, at: contentStackView.arrangedSubviews.count - 1)
        }
    }
    
    func updateItem(at index: Int, subtitle: String) {
        guard index < items.count else { return }
        items[index].subtitle = subtitle
        
        // UI 업데이트
        let itemViewIndex = index * 2 // 구분선 때문에 인덱스가 2배
        if itemViewIndex < contentStackView.arrangedSubviews.count,
           let itemView = contentStackView.arrangedSubviews[itemViewIndex] as? SettingsItemView {
            itemView.updateSubtitle(subtitle)
        }
    }
}

// MARK: - Settings Item View

/// 개별 설정 항목을 표시하는 뷰
class SettingsItemView: UIView {
    
    private let item: SettingsItem
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let accessoryImageView = UIImageView()
    private let switchControl = UISwitch()
    
    init(item: SettingsItem) {
        self.item = item
        super.init(frame: .zero)
        setupUI()
        setupGestureRecognizer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        // Title Label
        titleLabel.text = item.title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIDesignSystem.Colors.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        // Subtitle Label
        subtitleLabel.text = item.subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIDesignSystem.Colors.secondaryText
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)
        
        // Accessory 설정
        setupAccessory()
        
        setupConstraints()
    }
    
    private func setupAccessory() {
        switch item.type {
        case .navigation:
            accessoryImageView.image = UIImage(systemName: "chevron.right")
            accessoryImageView.tintColor = UIDesignSystem.Colors.secondaryText
            accessoryImageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(accessoryImageView)
            
        case .toggle:
            switchControl.isOn = item.isEnabled ?? false
            switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
            switchControl.translatesAutoresizingMaskIntoConstraints = false
            addSubview(switchControl)
            
        case .info:
            // 액세서리 없음
            break
        }
    }
    
    private func setupConstraints() {
        var constraints: [NSLayoutConstraint] = [
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ]
        
        switch item.type {
        case .navigation:
            constraints.append(contentsOf: [
                titleLabel.trailingAnchor.constraint(equalTo: accessoryImageView.leadingAnchor, constant: -8),
                subtitleLabel.trailingAnchor.constraint(equalTo: accessoryImageView.leadingAnchor, constant: -8),
                accessoryImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                accessoryImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                accessoryImageView.widthAnchor.constraint(equalToConstant: 12),
                accessoryImageView.heightAnchor.constraint(equalToConstant: 12)
            ])
            
        case .toggle:
            constraints.append(contentsOf: [
                titleLabel.trailingAnchor.constraint(equalTo: switchControl.leadingAnchor, constant: -8),
                subtitleLabel.trailingAnchor.constraint(equalTo: switchControl.leadingAnchor, constant: -8),
                switchControl.centerYAnchor.constraint(equalTo: centerYAnchor),
                switchControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
            ])
            
        case .info:
            constraints.append(contentsOf: [
                titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
            ])
        }
        
        NSLayoutConstraint.activate(constraints)
    }
    
    private func setupGestureRecognizer() {
        if item.action != nil {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(itemTapped))
            addGestureRecognizer(tapGesture)
        }
    }
    
    @objc private func itemTapped() {
        // 터치 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        item.action?()
    }
    
    @objc private func switchValueChanged() {
        item.isEnabled = switchControl.isOn
        item.action?()
    }
    
    func updateSubtitle(_ subtitle: String) {
        subtitleLabel.text = subtitle
    }
}

// MARK: - Supporting Types

/// 설정 항목 모델
class SettingsItem {
    let title: String
    var subtitle: String?
    let type: SettingsItemType
    var isEnabled: Bool?
    let action: (() -> Void)?
    
    init(title: String, subtitle: String? = nil, type: SettingsItemType, isEnabled: Bool? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// 설정 항목 타입
enum SettingsItemType {
    case navigation  // 화살표 있는 네비게이션
    case toggle      // 스위치 토글
    case info        // 정보 표시만
}

/// 설정 섹션 델리게이트
protocol SettingsSectionDelegate: AnyObject {
    func sectionDidUpdate(_ section: SettingsSectionView)
}