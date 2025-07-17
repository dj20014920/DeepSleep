//
//  ChatSettingsViewController.swift
//  DeepSleep
//
//  Created by Assistant on 2025-07-10.
//

import UIKit

// MARK: - ChatConfiguration
struct ChatConfiguration {
    let maxMessageLength: Int
    let typingIndicatorEnabled: Bool
    let autoScrollEnabled: Bool
    let soundEnabled: Bool
    let hapticFeedbackEnabled: Bool
    
    static let `default` = ChatConfiguration(
        maxMessageLength: 4000,
        typingIndicatorEnabled: true,
        autoScrollEnabled: true,
        soundEnabled: true,
        hapticFeedbackEnabled: true
    )
}

// MARK: - ChatSettingsDelegate
protocol ChatSettingsDelegate: AnyObject {
    func didUpdateChatSettings(_ settings: ChatConfiguration)
    func didRequestClearChat()
    func didRequestExportChat()
}

// MARK: - ChatSettingsViewController
class ChatSettingsViewController: UIViewController {
    weak var delegate: ChatSettingsDelegate?
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var configuration: ChatConfiguration = .default
    
    // Settings sections
    private let sections = ["일반 설정", "채팅 관리", "테마 설정"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "채팅 설정"
        view.backgroundColor = .systemBackground
        
        setupNavigationBar()
        setupTableView()
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Cell 등록
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: "SwitchCell")
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func doneButtonTapped() {
        delegate?.didUpdateChatSettings(configuration)
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource
extension ChatSettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3 // 일반 설정
        case 1: return 2 // 채팅 관리
        case 2: return 1 // 테마 설정
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section]
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0: // 일반 설정
            return configureGeneralSettingsCell(for: indexPath)
        case 1: // 채팅 관리
            return configureChatManagementCell(for: indexPath)
        case 2: // 테마 설정
            return configureThemeCell(for: indexPath)
        default:
            return UITableViewCell()
        }
    }
    
    private func configureGeneralSettingsCell(for indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0: // 타이핑 인디케이터
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            cell.configure(
                title: "타이핑 인디케이터",
                isOn: configuration.typingIndicatorEnabled
            ) { [weak self] isOn in
                self?.configuration = ChatConfiguration(
                    maxMessageLength: self?.configuration.maxMessageLength ?? 4000,
                    typingIndicatorEnabled: isOn,
                    autoScrollEnabled: self?.configuration.autoScrollEnabled ?? true,
                    soundEnabled: self?.configuration.soundEnabled ?? true,
                    hapticFeedbackEnabled: self?.configuration.hapticFeedbackEnabled ?? true
                )
            }
            return cell
        case 1: // 자동 스크롤
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            cell.configure(
                title: "자동 스크롤",
                isOn: configuration.autoScrollEnabled
            ) { [weak self] isOn in
                self?.configuration = ChatConfiguration(
                    maxMessageLength: self?.configuration.maxMessageLength ?? 4000,
                    typingIndicatorEnabled: self?.configuration.typingIndicatorEnabled ?? true,
                    autoScrollEnabled: isOn,
                    soundEnabled: self?.configuration.soundEnabled ?? true,
                    hapticFeedbackEnabled: self?.configuration.hapticFeedbackEnabled ?? true
                )
            }
            return cell
        case 2: // 햅틱 피드백
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchTableViewCell
            cell.configure(
                title: "햅틱 피드백",
                isOn: configuration.hapticFeedbackEnabled
            ) { [weak self] isOn in
                self?.configuration = ChatConfiguration(
                    maxMessageLength: self?.configuration.maxMessageLength ?? 4000,
                    typingIndicatorEnabled: self?.configuration.typingIndicatorEnabled ?? true,
                    autoScrollEnabled: self?.configuration.autoScrollEnabled ?? true,
                    soundEnabled: self?.configuration.soundEnabled ?? true,
                    hapticFeedbackEnabled: isOn
                )
            }
            return cell
        default:
            return UITableViewCell()
        }
    }
    
    private func configureChatManagementCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        switch indexPath.row {
        case 0: // 채팅 내역 삭제
            cell.textLabel?.text = "채팅 내역 삭제"
            cell.textLabel?.textColor = .systemRed
            cell.accessoryType = .none
        case 1: // 채팅 내보내기
            cell.textLabel?.text = "채팅 내보내기"
            cell.textLabel?.textColor = .systemBlue
            cell.accessoryType = .disclosureIndicator
        default:
            break
        }
        
        return cell
    }
    
    private func configureThemeCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = "테마 설정"
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ChatSettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 1: // 채팅 관리
            switch indexPath.row {
            case 0: // 채팅 내역 삭제
                delegate?.didRequestClearChat()
            case 1: // 채팅 내보내기
                delegate?.didRequestExportChat()
            default:
                break
            }
        case 2: // 테마 설정
            showThemeSelector()
        default:
            break
        }
    }
    
    private func showThemeSelector() {
        let alert = UIAlertController(title: "테마 선택", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "기본", style: .default) { _ in
            // 기본 테마 적용
        })
        
        alert.addAction(UIAlertAction(title: "다크", style: .default) { _ in
            // 다크 테마 적용
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        // iPad 지원
        if let popover = alert.popoverPresentationController {
            if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 2)) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }
        
        present(alert, animated: true)
    }
}

// MARK: - SwitchTableViewCell
class SwitchTableViewCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let switchControl = UISwitch()
    private var onValueChanged: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(switchControl)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            switchControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            switchControl.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 16)
        ])
        
        switchControl.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
    }
    
    func configure(title: String, isOn: Bool, onValueChanged: @escaping (Bool) -> Void) {
        titleLabel.text = title
        switchControl.isOn = isOn
        self.onValueChanged = onValueChanged
    }
    
    @objc private func switchValueChanged() {
        onValueChanged?(switchControl.isOn)
    }
}