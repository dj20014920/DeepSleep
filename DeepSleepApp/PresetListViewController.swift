import UIKit
import CryptoKit

// MARK: - 즐겨찾기 기능을 위한 커스텀 셀
class PresetTableViewCell: UITableViewCell {
    static let identifier = "PresetTableViewCell"
    
    var onFavoriteToggle: (() -> Void)?
    var onSelectionToggle: (() -> Void)?
    
    // Constraint references for dynamic adjustment
    private var titleLeadingConstraint: NSLayoutConstraint!
    private var subtitleLeadingConstraint: NSLayoutConstraint!
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let favoriteButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 20)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let selectionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 24)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        [titleLabel, subtitleLabel, favoriteButton, selectionButton].forEach {
            contentView.addSubview($0)
        }
        
        favoriteButton.addTarget(self, action: #selector(favoriteButtonTapped), for: .touchUpInside)
        selectionButton.addTarget(self, action: #selector(selectionButtonTapped), for: .touchUpInside)
        
        // Create constraint references for dynamic adjustment
        titleLeadingConstraint = titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        subtitleLeadingConstraint = subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLeadingConstraint,
            titleLabel.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -8),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLeadingConstraint,
            subtitleLabel.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            selectionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            selectionButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            selectionButton.widthAnchor.constraint(equalToConstant: 30),
            selectionButton.heightAnchor.constraint(equalToConstant: 30),
            
            favoriteButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            favoriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            favoriteButton.widthAnchor.constraint(equalToConstant: 44),
            favoriteButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func favoriteButtonTapped() {
        onFavoriteToggle?()
    }
    
    @objc private func selectionButtonTapped() {
        onSelectionToggle?()
    }
    
    func configure(with preset: SoundPreset, isFavorite: Bool, isSelected: Bool = false, isInSelectionMode: Bool = false) {
        titleLabel.text = preset.name
        subtitleLabel.text = preset.description ?? "프리셋"
        
        favoriteButton.setTitle(isFavorite ? "⭐️" : "☆", for: .normal)
        favoriteButton.setTitleColor(isFavorite ? .systemYellow : .systemGray3, for: .normal)
        
        // 선택 모드 UI 업데이트
        selectionButton.isHidden = !isInSelectionMode
        
        updateSelectionMode(isInSelectionMode)
        
        if isInSelectionMode {
            selectionButton.setTitle(isSelected ? "☑️" : "☐", for: .normal)
            selectionButton.setTitleColor(isSelected ? .systemBlue : .systemGray3, for: .normal)
        }
    }
    
    func updateSelectionMode(_ isSelectionMode: Bool) {
        selectionButton.isHidden = !isSelectionMode
        
        // Update leading constraints based on selection mode
        titleLeadingConstraint.constant = isSelectionMode ? 54 : 16  // 16 + 30 + 8 = 54
        subtitleLeadingConstraint.constant = isSelectionMode ? 54 : 16
        
        UIView.animate(withDuration: 0.2) {
            self.layoutIfNeeded()
        }
    }
}

class PresetListViewController: UITableViewController {
    private var subscriptionObserver: NSObjectProtocol?
    var presets: [SoundPreset] = []
    var onPresetSelected: ((SoundPreset) -> Void)?
    
    // 즐겨찾기 ID들을 저장하는 Set (최대 4개)
    private var favoritePresetIds: Set<UUID> = []
    
    // 선택 삭제 모드 관련 프로퍼티
    private var isInSelectionMode = false
    private var selectedPresetIds: Set<UUID> = []
    private var selectAllButton: UIBarButtonItem!
    private var deleteSelectedButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "프리셋 관리"
        tableView.register(PresetTableViewCell.self, forCellReuseIdentifier: PresetTableViewCell.identifier)
        setupNavigationBar()
        loadPresets()
        loadFavorites()
        
        // 구독 상태 옵저버 등록: 프리미엄 프리셋 잠금 해제 즉시 반영
        subscriptionObserver = NotificationCenter.default.addObserver(forName: .subscriptionStatusChanged, object: nil, queue: .main) { [weak self] _ in
            self?.tableView.reloadData()
        }
    }
    
    private func setupNavigationBar() {
        // 가져오기 버튼 추가
        let importButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.down"),
            style: .plain,
            target: self,
            action: #selector(importPresetTapped)
        )
        importButton.title = "가져오기"
        
        // 선택 삭제 버튼
        let deleteButton = UIBarButtonItem(
            image: UIImage(systemName: "trash.circle"),
            style: .plain,
            target: self,
            action: #selector(deleteButtonTapped)
        )
        deleteButton.title = "선택삭제"
        deleteButton.tintColor = .systemRed
        
        // 선택 모드용 버튼들 (처음에는 숨김)
        selectAllButton = UIBarButtonItem(
            title: "전체선택",
            style: .plain,
            target: self,
            action: #selector(selectAllTapped)
        )
        
        deleteSelectedButton = UIBarButtonItem(
            title: "삭제",
            style: .plain,
            target: self,
            action: #selector(deleteSelectedTapped)
        )
        deleteSelectedButton.tintColor = .systemRed
        
        navigationItem.rightBarButtonItems = [importButton, deleteButton]
    }
    
    func loadPresets() {
        presets = SettingsManager.shared.loadSoundPresets()
        tableView.reloadData()
    }
    
    private func loadFavorites() {
        let favoriteIds = UserDefaults.standard.array(forKey: "FavoritePresetIds") as? [String] ?? []
        let allUUIDs = favoriteIds.compactMap { UUID(uuidString: $0) }
        
        // 실제 존재하는 프리셋들만 필터링 (고아 참조 제거)
        let allPresets = SettingsManager.shared.loadSoundPresets()
        let existingPresetIds = Set(allPresets.map { $0.id })
        let validFavoriteIds = allUUIDs.filter { existingPresetIds.contains($0) }
        
        favoritePresetIds = Set(validFavoriteIds)
        
        print("📂 [loadFavorites] 원본: \(favoriteIds.count)개, 유효한 UUID: \(allUUIDs.count)개, 실제 존재: \(validFavoriteIds.count)개")
        
        // 고아 참조가 있었거나 4개 초과인 경우 정리
        let needsCleanup = favoriteIds.count != validFavoriteIds.count || favoritePresetIds.count > 4
        
        if needsCleanup {
            if favoritePresetIds.count > 4 {
                let limitedIds = Array(favoritePresetIds.prefix(4))
                favoritePresetIds = Set(limitedIds)
                print("⚠️ [loadFavorites] 즐겨찾기 4개 초과로 제한됨")
            }
            
            saveFavorites() // 즉시 저장하여 데이터 정리
            print("🧹 [loadFavorites] 고아 참조 제거 및 데이터 정리 완료")
        }
        
        print("✅ [loadFavorites] 최종 즐겨찾기: \(favoritePresetIds.count)개")
    }
    
    private func saveFavorites() {
        // 최대 4개 제한 재확인
        if favoritePresetIds.count > 4 {
            let limitedIds = Array(favoritePresetIds.prefix(4))
            favoritePresetIds = Set(limitedIds)
            print("⚠️ [saveFavorites] 저장 전 4개로 제한됨")
        }
        
        let favoriteIdStrings = favoritePresetIds.map { $0.uuidString }
        UserDefaults.standard.set(favoriteIdStrings, forKey: "FavoritePresetIds")
        UserDefaults.standard.synchronize() // 강제 동기화
        
        print("💾 [saveFavorites] \(favoriteIdStrings.count)개 즐겨찾기 저장 완료")
    }
    
    private func toggleFavorite(for preset: SoundPreset) {
        print("🌟 [toggleFavorite] 시작: \(preset.name), 현재 카운트: \(favoritePresetIds.count)")
        print("  - 현재 즐겨찾기 ID들: \(favoritePresetIds.map { $0.uuidString.prefix(8) })")
        
        let wasInFavorites = favoritePresetIds.contains(preset.id)
        
        if wasInFavorites {
            // 즐겨찾기에서 제거
            let removed = favoritePresetIds.remove(preset.id)
            if removed != nil {
                print("  - ✅ 즐겨찾기에서 정상 제거됨: \(preset.id.uuidString.prefix(8))")
                print("  - 새 카운트: \(favoritePresetIds.count)")
            } else {
                print("  - ⚠️ 제거 실패: 프리셋이 Set에 없었음")
            }
        } else {
            // 즐겨찾기에 추가 (최대 4개 제한)
            if favoritePresetIds.count >= 4 {
                showFavoriteLimitAlert()
                print("  - ❌ 즐겨찾기 한도 초과로 추가 실패 (현재: \(favoritePresetIds.count)/4)")
                return
            }
            favoritePresetIds.insert(preset.id)
            print("  - ✅ 즐겨찾기에 추가됨: \(preset.id.uuidString.prefix(8))")
            print("  - 새 카운트: \(favoritePresetIds.count)")
        }
        
        // 중간 검증
        print("  - 중간 검증: 카운트=\(favoritePresetIds.count), 포함여부=\(favoritePresetIds.contains(preset.id))")
        
        // UserDefaults에 즉시 저장
        saveFavorites()
        
        // 저장 후 검증 (강화된 로깅)
        let reloadedIds = UserDefaults.standard.array(forKey: "FavoritePresetIds") as? [String] ?? []
        let reloadedCount = reloadedIds.count
        print("  - 저장 후 검증: UserDefaults에 \(reloadedCount)개 저장됨")
        print("  - 저장된 ID들: \(reloadedIds.map { String($0.prefix(8)) })")
        
        // 메모리와 디스크 일치성 확인
        if favoritePresetIds.count != reloadedCount {
            print("  - ⚠️ 메모리(\(favoritePresetIds.count))와 디스크(\(reloadedCount)) 불일치!")
            print("  - 메모리 ID들: \(favoritePresetIds.map { $0.uuidString.prefix(8) })")
            print("  - 디스크 ID들: \(reloadedIds.map { String($0.prefix(8)) })")
            
            // 강제 재동기화
            loadFavorites()
            print("  - 강제 재동기화 완료: 새 카운트 \(favoritePresetIds.count)")
        }
        
        // 해당 셀만 업데이트
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            let indexPath = IndexPath(row: index, section: 0)
            DispatchQueue.main.async {
                self.tableView.reloadRows(at: [indexPath], with: .none)
            }
        }
        
        // 메인 화면 프리셋 블록 업데이트 알림
        NotificationCenter.default.post(name: NSNotification.Name("FavoritesUpdated"), object: nil)
        
        print("✅ [toggleFavorite] 완료: \(preset.name), 최종 카운트: \(favoritePresetIds.count)")
    }
    
    private func showFavoriteLimitAlert() {
        let alert = UIAlertController(
            title: "즐겨찾기 한도 초과",
            message: "즐겨찾기는 최대 4개까지만 등록할 수 있습니다.\n다른 즐겨찾기를 해제한 후 시도해주세요.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    // 즐겨찾기 프리셋들을 가져오는 메서드 (메인 화면 프리셋 블록에서 사용)
    func getFavoritePresets() -> [SoundPreset] {
        return presets.filter { favoritePresetIds.contains($0.id) }
    }
    
    // MARK: - 선택 삭제 기능
    
    @objc private func deleteButtonTapped() {
        toggleSelectionMode()
    }
    
    @objc private func selectAllTapped() {
        if selectedPresetIds.count == presets.count {
            // 전체 해제
            selectedPresetIds.removeAll()
            selectAllButton.title = "전체선택"
        } else {
            // 전체 선택
            selectedPresetIds = Set(presets.map { $0.id })
            selectAllButton.title = "전체해제"
        }
        updateDeleteButtonState()
        tableView.reloadData()
    }
    
    @objc private func deleteSelectedTapped() {
        guard !selectedPresetIds.isEmpty else { return }
        
        let alert = UIAlertController(
            title: "프리셋 삭제",
            message: "\(selectedPresetIds.count)개의 프리셋을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.performBatchDelete()
        })
        
        present(alert, animated: true)
    }
    
    private func toggleSelectionMode() {
        isInSelectionMode.toggle()
        selectedPresetIds.removeAll()
        
        if isInSelectionMode {
            // 선택 모드 진입
            title = "삭제할 프리셋 선택"
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "취소",
                style: .plain,
                target: self,
                action: #selector(cancelSelectionMode)
            )
            navigationItem.rightBarButtonItems = [selectAllButton, deleteSelectedButton]
            selectAllButton.title = "전체선택"
            updateDeleteButtonState()
        } else {
            // 선택 모드 종료
            title = "프리셋 관리"
            navigationItem.leftBarButtonItem = nil
            let importButton = UIBarButtonItem(
                image: UIImage(systemName: "square.and.arrow.down"),
                style: .plain,
                target: self,
                action: #selector(importPresetTapped)
            )
            let deleteButton = UIBarButtonItem(
                image: UIImage(systemName: "trash.circle"),
                style: .plain,
                target: self,
                action: #selector(deleteButtonTapped)
            )
            deleteButton.tintColor = .systemRed
            navigationItem.rightBarButtonItems = [importButton, deleteButton]
        }
        
        tableView.reloadData()
    }
    
    @objc private func cancelSelectionMode() {
        isInSelectionMode = false
        selectedPresetIds.removeAll()
        toggleSelectionMode()
    }
    
    private func updateDeleteButtonState() {
        deleteSelectedButton.isEnabled = !selectedPresetIds.isEmpty
        deleteSelectedButton.title = selectedPresetIds.isEmpty ? "삭제" : "삭제(\(selectedPresetIds.count))"
    }
    
    private func toggleSelection(for preset: SoundPreset) {
        if selectedPresetIds.contains(preset.id) {
            selectedPresetIds.remove(preset.id)
        } else {
            selectedPresetIds.insert(preset.id)
        }
        
        // 전체선택/해제 버튼 텍스트 업데이트
        selectAllButton.title = selectedPresetIds.count == presets.count ? "전체해제" : "전체선택"
        
        updateDeleteButtonState()
        
        // 해당 셀만 업데이트
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            let indexPath = IndexPath(row: index, section: 0)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    
    private func performBatchDelete() {
        let presetsToDelete = presets.filter { selectedPresetIds.contains($0.id) }
        
        print("🗑️ [performBatchDelete] \(presetsToDelete.count)개 프리셋 삭제 시작")
        
        // 즐겨찾기에서도 제거
        for preset in presetsToDelete {
            favoritePresetIds.remove(preset.id)
            SettingsManager.shared.deleteSoundPreset(id: preset.id)
        }
        
        // 즐겨찾기 저장
        saveFavorites()
        
        // 메인 화면 업데이트 알림
        NotificationCenter.default.post(name: NSNotification.Name("FavoritesUpdated"), object: nil)
        
        // 프리셋 목록 새로고침
        loadPresets()
        
        // 선택 모드 종료
        toggleSelectionMode()
        
        print("✅ [performBatchDelete] 삭제 완료")
        
        // 성공 메시지
        let alert = UIAlertController(
            title: "삭제 완료",
            message: "\(presetsToDelete.count)개의 프리셋이 삭제되었습니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    // MARK: - TableView 기본 구성
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if presets.isEmpty {
            // 빈 상태 메시지 표시
            let emptyLabel = UILabel()
            emptyLabel.text = "저장된 프리셋이 없습니다.\n'저장' 버튼을 눌러 프리셋을 만들어 보세요."
            emptyLabel.textAlignment = .center
            emptyLabel.numberOfLines = 0
            emptyLabel.textColor = .systemGray
            emptyLabel.font = .systemFont(ofSize: 16)
            tableView.backgroundView = emptyLabel
            return 0
        } else {
            tableView.backgroundView = nil
            return presets.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: PresetTableViewCell.identifier, for: indexPath) as? PresetTableViewCell else {
            return UITableViewCell()
        }
        
        let preset = presets[indexPath.row]
        let isFavorite = favoritePresetIds.contains(preset.id)
        let isSelected = selectedPresetIds.contains(preset.id)
        
        cell.configure(with: preset, isFavorite: isFavorite, isSelected: isSelected, isInSelectionMode: isInSelectionMode)
        
        cell.onFavoriteToggle = { [weak self] in
            self?.toggleFavorite(for: preset)
        }
        
        cell.onSelectionToggle = { [weak self] in
            self?.toggleSelection(for: preset)
        }
        
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let preset = presets[indexPath.row]
        
        if isInSelectionMode {
            // 선택 모드일 때는 프리셋 선택/해제
            toggleSelection(for: preset)
        } else {
            // 일반 모드일 때는 프리셋 적용하고 돌아가기
            onPresetSelected?(preset)
            navigationController?.popViewController(animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let presetToDelete = presets[indexPath.row]
            
            // 삭제 전 알림 표시
            let alert = UIAlertController(
                title: "프리셋 삭제",
                message: "'\(presetToDelete.name)' 프리셋을 삭제하시겠습니까?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "취소", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "삭제", style: .destructive, handler: { _ in
                // ✅ 즐겨찾기에서도 제거
                if self.favoritePresetIds.contains(presetToDelete.id) {
                    self.favoritePresetIds.remove(presetToDelete.id)
                    self.saveFavorites()
                    print("🗑️ 프리셋 삭제 시 즐겨찾기에서도 제거: \(presetToDelete.name)")
                    
                    // 메인 화면 즐겨찾기 블록 업데이트
                    NotificationCenter.default.post(name: NSNotification.Name("FavoritesUpdated"), object: nil)
                }
                
                // 실제 삭제 로직 - SettingsManager 사용
                SettingsManager.shared.deleteSoundPreset(id: presetToDelete.id)
                self.presets.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }))
            
            present(alert, animated: true)
        }
    }
    
    // MARK: - 이름 변경 (스와이프 액션)
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let preset = presets[indexPath.row]
        
        // 🔗 공유 액션
        let shareAction = UIContextualAction(style: .normal, title: "공유") { [weak self] _, _, completion in
            self?.showShareOptions(for: preset)
            completion(true)
        }
        shareAction.backgroundColor = UIColor.systemGreen
        shareAction.image = UIImage(systemName: "square.and.arrow.up")
        
        // 🔹 이름 변경 액션
        let renameAction = UIContextualAction(style: .normal, title: "이름 변경") { [weak self] _, _, completion in
            let alert = UIAlertController(title: "이름 변경", message: "새 이름을 입력하세요", preferredStyle: .alert)
            alert.addTextField { $0.text = preset.name }
            alert.addAction(UIAlertAction(title: "취소", style: .cancel))
            alert.addAction(UIAlertAction(title: "확인", style: .default, handler: { _ in
                guard let newName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !newName.isEmpty else { return }
                
                if newName != preset.name {
                    // 기존 프리셋 삭제하고 새 이름으로 저장
                    let newPreset = SoundPreset(
                        name: newName,
                        volumes: preset.volumes,
                        emotion: preset.emotion,
                        isAIGenerated: preset.isAIGenerated,
                        description: preset.description
                    )
                    SettingsManager.shared.deleteSoundPreset(id: preset.id)
                    SettingsManager.shared.saveSoundPreset(newPreset)
                    self?.loadPresets()
                }
            }))
            self?.present(alert, animated: true)
            completion(true)
        }
        renameAction.backgroundColor = UIColor.systemBlue

        // 🔺 삭제 액션
        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            let confirm = UIAlertController(title: "삭제 확인", message: "'\(preset.name)' 프리셋을 삭제할까요?", preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: "취소", style: .cancel))
            confirm.addAction(UIAlertAction(title: "삭제", style: .destructive, handler: { _ in
                // ✅ 즐겨찾기에서도 제거
                if self?.favoritePresetIds.contains(preset.id) == true {
                    self?.favoritePresetIds.remove(preset.id)
                    self?.saveFavorites()
                    print("🗑️ 스와이프 삭제 시 즐겨찾기에서도 제거: \(preset.name)")
                    
                    // 메인 화면 즐겨찾기 블록 업데이트
                    NotificationCenter.default.post(name: NSNotification.Name("FavoritesUpdated"), object: nil)
                }
                
                SettingsManager.shared.deleteSoundPreset(id: preset.id)
                self?.loadPresets()
            }))
            self?.present(confirm, animated: true)
            completion(true)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction, renameAction, shareAction])
    }
    
    func showRenameAlert(for indexPath: IndexPath) {
        let oldPreset = presets[indexPath.row]

        let alert = UIAlertController(title: "이름 변경", message: "새 이름을 입력하세요", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = oldPreset.name
        }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "저장", style: .default, handler: { [weak self] _ in
            guard let newName = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !newName.isEmpty else { return }

            // 새 프리셋 생성하고 기존 것 삭제 (버전 정보 유지)
            let newPreset = SoundPreset(
                name: newName,
                volumes: oldPreset.volumes,
                selectedVersions: oldPreset.selectedVersions ?? SoundPresetCatalog.defaultVersions,
                emotion: oldPreset.emotion,
                isAIGenerated: oldPreset.isAIGenerated,
                description: oldPreset.description
            )
            SettingsManager.shared.deleteSoundPreset(id: oldPreset.id)
            SettingsManager.shared.saveSoundPreset(newPreset)
            self?.loadPresets()
        }))
        present(alert, animated: true)
    }
    
    // MARK: - 프리셋 공유 기능
    
    @objc private func importPresetTapped() {
        let alert = UIAlertController(
            title: "🎵 프리셋 가져오기",
            message: "친구로부터 받은 공유 코드를 입력하세요",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "EZ... (16자리) 또는 emozleep://..."
            textField.clearButtonMode = .whileEditing
        }
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "가져오기", style: .default) { [weak self] _ in
            guard let shareCode = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !shareCode.isEmpty else { return }
            
            self?.importPreset(from: shareCode)
        })
        
        present(alert, animated: true)
    }
    
    private func showShareOptions(for preset: SoundPreset) {
        let alert = UIAlertController(
            title: "🎵 프리셋 공유",
            message: "'\(preset.name)' 프리셋을 어떻게 공유하시겠습니까?",
            preferredStyle: .actionSheet
        )
        
        // URL 링크로 공유
        alert.addAction(UIAlertAction(title: "링크로 공유", style: .default) { [weak self] _ in
            self?.sharePresetAsURL(preset)
        })
        
        // 숫자 코드로 공유
        alert.addAction(UIAlertAction(title: "숫자 코드로 공유", style: .default) { [weak self] _ in
            self?.sharePresetAsCode(preset)
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        // iPad 지원
        if let popover = alert.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = CGRect(x: tableView.bounds.midX, y: tableView.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true)
    }
    
    private func sharePresetAsURL(_ preset: SoundPreset) {
        // PresetSharingManager의 통일된 메서드 사용
        PresetSharingManager.shared.sharePreset(preset, from: self, preferNumericCode: false)
    }
    
    private func sharePresetAsCode(_ preset: SoundPreset) {
        // PresetSharingManager의 통일된 메서드 사용
        PresetSharingManager.shared.sharePreset(preset, from: self, preferNumericCode: true)
    }
    
    private func shareContent(_ content: String) {
        let activityVC = UIActivityViewController(
            activityItems: [content],
            applicationActivities: nil
        )
        
        // iPad 지원
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    // MARK: - 프리셋 인코딩/디코딩 (PresetSharingManager로 위임)
    
    private func importPreset(from shareCode: String) {
        // PresetSharingManager의 통일된 메서드 사용
        PresetSharingManager.shared.importPreset(from: shareCode) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let preset):
                    self?.showImportSuccess(preset)
                case .failure(let error):
                    self?.showError(message: error.localizedDescription)
                }
            }
        }
    }

    private func showImportSuccess(_ preset: SoundPreset) {
        let alert = UIAlertController(
            title: "✅ 가져오기 성공",
            message: "'\(preset.name)' 프리셋을 가져왔습니다.\n저장하고 적용하시겠습니까?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "저장 & 적용", style: .default) { [weak self] _ in
            // 프리셋 저장
            SettingsManager.shared.saveSoundPreset(preset)
            self?.loadPresets()
            
            // 프리셋 적용 (부모 뷰컨트롤러로 콜백)
            self?.onPresetSelected?(preset)
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showError(message: String) {
        let alert = UIAlertController(
            title: "오류",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - URL 스키마에서 호출되는 메서드
    
    func handleIncomingShareCode(_ shareCode: String) {
        // 자동으로 가져오기 처리
        importPreset(from: shareCode)
    }
}

// MARK: - 공유 기능은 PresetSharingManager로 위임됨
