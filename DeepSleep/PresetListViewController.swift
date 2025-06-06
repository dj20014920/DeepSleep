import UIKit
import CryptoKit

// MARK: - 즐겨찾기 기능을 위한 커스텀 셀
class PresetTableViewCell: UITableViewCell {
    static let identifier = "PresetTableViewCell"
    
    var onFavoriteToggle: (() -> Void)?
    
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
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        [titleLabel, subtitleLabel, favoriteButton].forEach {
            contentView.addSubview($0)
        }
        
        favoriteButton.addTarget(self, action: #selector(favoriteButtonTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -8),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -8),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            favoriteButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            favoriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            favoriteButton.widthAnchor.constraint(equalToConstant: 44),
            favoriteButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func favoriteButtonTapped() {
        onFavoriteToggle?()
    }
    
    func configure(with preset: SoundPreset, isFavorite: Bool) {
        titleLabel.text = preset.name
        subtitleLabel.text = preset.description ?? "프리셋"
        
        favoriteButton.setTitle(isFavorite ? "⭐️" : "☆", for: .normal)
        favoriteButton.setTitleColor(isFavorite ? .systemYellow : .systemGray3, for: .normal)
    }
}

class PresetListViewController: UITableViewController {
    var presets: [SoundPreset] = []
    var onPresetSelected: ((SoundPreset) -> Void)?
    
    // 즐겨찾기 ID들을 저장하는 Set (최대 4개)
    private var favoritePresetIds: Set<UUID> = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "프리셋 관리"
        tableView.register(PresetTableViewCell.self, forCellReuseIdentifier: PresetTableViewCell.identifier)
        setupNavigationBar()
        loadPresets()
        loadFavorites()
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
        
        navigationItem.rightBarButtonItem = importButton
    }
    


    func loadPresets() {
        presets = SettingsManager.shared.loadSoundPresets()
        tableView.reloadData()
    }
    
    private func loadFavorites() {
        let favoriteIds = UserDefaults.standard.array(forKey: "FavoritePresetIds") as? [String] ?? []
        favoritePresetIds = Set(favoriteIds.compactMap { UUID(uuidString: $0) })
    }
    
    private func saveFavorites() {
        let favoriteIdStrings = favoritePresetIds.map { $0.uuidString }
        UserDefaults.standard.set(favoriteIdStrings, forKey: "FavoritePresetIds")
    }
    
    private func toggleFavorite(for preset: SoundPreset) {
        if favoritePresetIds.contains(preset.id) {
            // 즐겨찾기에서 제거
            favoritePresetIds.remove(preset.id)
        } else {
            // 즐겨찾기에 추가 (최대 4개 제한)
            if favoritePresetIds.count >= 4 {
                showFavoriteLimitAlert()
                return
            }
            favoritePresetIds.insert(preset.id)
        }
        
        saveFavorites()
        
        // 해당 셀만 업데이트
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            let indexPath = IndexPath(row: index, section: 0)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
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
        
        cell.configure(with: preset, isFavorite: isFavorite)
        cell.onFavoriteToggle = { [weak self] in
            self?.toggleFavorite(for: preset)
        }
        
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onPresetSelected?(presets[indexPath.row])
        navigationController?.popViewController(animated: true)
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
        guard let shareURL = encodePresetAsURL(preset) else {
            showError(message: "프리셋 인코딩에 실패했습니다.")
            return
        }
        
        let message = """
        🎵 EmoZleep 프리셋: \(preset.name)
        
        아래 링크를 클릭하여 프리셋을 가져오세요:
        
        \(shareURL)
        
        (이 링크는 24시간 후 만료됩니다)
        """
        
        shareContent(message)
    }
    
    private func sharePresetAsCode(_ preset: SoundPreset) {
        guard let shareCode = encodePresetAsCode(preset) else {
            showError(message: "프리셋 인코딩에 실패했습니다.")
            return
        }
        
        let message = """
        🎵 EmoZleep 프리셋: \(preset.name)
        
        아래 코드를 EmoZleep 앱에서 가져오기하여 프리셋을 사용하세요:
        
        \(shareCode)
        
        (이 코드는 24시간 후 만료됩니다)
        """
        
        shareContent(message)
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
    
    // MARK: - 프리셋 인코딩/디코딩
    
    private func encodePresetAsURL(_ preset: SoundPreset) -> String? {
        do {
            let shareablePreset = ShareablePreset(from: preset)
            let jsonData = try JSONEncoder().encode(shareablePreset)
                         let base64String = jsonData.base64EncodedString()
             
             return "emozleep://preset?data=\(base64String)"
        } catch {
            print("❌ 프리셋 인코딩 실패: \(error)")
            return nil
        }
    }
    
    private func encodePresetAsCode(_ preset: SoundPreset) -> String? {
        let volumes = preset.compatibleVolumes
        let versions = preset.compatibleVersions
        
        var code = "EZL"  // EmoZleep 식별자
        code += "v10"     // 버전 정보
        
        // 볼륨 정보 (각각 2자리, 00-99)
        for volume in volumes {
            let normalizedVolume = Int(min(99, max(0, volume)))
            code += String(format: "%02d", normalizedVolume)
        }
        
        // 버전 선택 정보 (각각 1자리, 0-9)
        for version in versions {
            code += String(min(9, max(0, version)))
        }
        
        // 체크섬 (4자리)
        let dataToHash = volumes.map { String(Int($0)) }.joined() + versions.map { String($0) }.joined()
        let hash = dataToHash.hash
        let checksum = String(format: "%04d", abs(hash % 10000))
        code += checksum
        
        return code
    }
    
    private func importPreset(from shareCode: String) {
        // URL 스키마 처리
        if shareCode.hasPrefix("emozleep://") {
            importFromURL(shareCode)
        }
        // 숫자 코드 처리
        else if shareCode.hasPrefix("EZ") {
            importFromCode(shareCode)
        }
        // Base64 직접 처리
        else {
            importFromBase64(shareCode)
        }
    }
    
    private func importFromURL(_ urlString: String) {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let dataItem = queryItems.first(where: { $0.name == "data" }),
              let base64Data = dataItem.value else {
            showError(message: "올바르지 않은 링크 형식입니다.")
            return
        }
        
        importFromBase64(base64Data)
    }
    
    private func importFromBase64(_ base64String: String) {
        guard let data = Data(base64Encoded: base64String) else {
            showError(message: "올바르지 않은 형식의 공유 코드입니다.")
            return
        }
        
        do {
            let shareablePreset = try JSONDecoder().decode(ShareablePreset.self, from: data)
            
            // 만료 시간 검증
            if shareablePreset.expiresAt < Date() {
                showError(message: "공유 코드가 만료되었습니다. (24시간 제한)")
                return
            }
            
            // 프리셋 생성 및 저장
            let preset = SoundPreset(
                name: shareablePreset.name,
                volumes: shareablePreset.volumes,
                selectedVersions: shareablePreset.versions ?? SoundPresetCatalog.defaultVersions,
                emotion: shareablePreset.emotion,
                isAIGenerated: false,
                description: "공유받은 프리셋"
            )
            
            showImportSuccess(preset)
            
        } catch {
            showError(message: "공유 코드 해석에 실패했습니다.")
        }
    }
    
    private func importFromCode(_ code: String) {
        // EZ + (11자리 볼륨) + (1자리 버전) + (2자리 체크섬) = 16자리
        guard code.count == 16 else {
            showError(message: "올바르지 않은 코드 길이입니다. (16자리 필요)")
            return
        }
        
        let prefix = String(code.prefix(2))  // EZ
        guard prefix == "EZ" else {
            showError(message: "올바르지 않은 코드 형식입니다.")
            return
        }
        
        // 볼륨 추출 (11자리, Base36 디코딩)
        var volumes: [Float] = []
        let volumeStart = code.index(code.startIndex, offsetBy: 2)
        for i in 0..<11 {
            let index = code.index(volumeStart, offsetBy: i)
            let volumeChar = String(code[index])
            
            guard let compressed = Int(volumeChar, radix: 36) else {
                showError(message: "코드의 볼륨 데이터가 손상되었습니다.")
                return
            }
            
            // 0-35를 0-100으로 복원
            let volume = Float(compressed * 100 / 35)
            volumes.append(min(100, volume))
        }
        
        // 버전 정보 추출 (1자리)
        let versionIndex = code.index(code.startIndex, offsetBy: 13)
        let versionChar = String(code[versionIndex])
        guard let versionBits = Int(versionChar, radix: 36) else {
            showError(message: "코드의 버전 데이터가 손상되었습니다.")
            return
        }
        
        // 기본 버전 배열 생성
        var versions = SoundPresetCatalog.defaultVersions
        
        // 비트마스크 디코딩
        if versionBits & 1 != 0 { versions[4] = 1 }  // 비 V2
        if versionBits & 2 != 0 { versions[9] = 1 }  // 키보드 V2
        
        // 체크섬 검증 (2자리)
        let checksumPart = String(code.suffix(2))
        guard let receivedChecksum = Int(checksumPart) else {
            showError(message: "코드의 체크섬이 손상되었습니다.")
            return
        }
        
        let volumeSum = volumes.reduce(0, +)
        let expectedChecksum = Int(volumeSum) % 100
        
        guard receivedChecksum == expectedChecksum else {
            showError(message: "코드의 무결성 검증에 실패했습니다.")
            return
        }
        
        // 프리셋 생성
        let preset = SoundPreset(
            name: "공유받은 프리셋",
            volumes: volumes,
            selectedVersions: versions,
            emotion: nil,
            isAIGenerated: false,
            description: "친구로부터 공유받은 프리셋"
        )
        
        showImportSuccess(preset)
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

// MARK: - 공유 데이터 모델
private struct ShareablePreset: Codable {
    let version: String
    let name: String
    let volumes: [Float]
    let versions: [Int]?
    let emotion: String?
    let description: String?
    let createdAt: Date
    let expiresAt: Date
    let checksum: String
    
    init(from preset: SoundPreset) {
        self.version = "v1.0"
        self.name = preset.name
        self.volumes = preset.compatibleVolumes
        self.versions = preset.compatibleVersions
        self.emotion = preset.emotion
        self.description = preset.description
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(24 * 3600) // 24시간 후 만료
        
        // 체크섬 계산
        let volumeString = volumes.map { String(format: "%.2f", $0) }.joined(separator: ",")
        let versionString = (versions ?? []).map { String($0) }.joined(separator: ",")
        let dataToHash = "\(name)|\(volumeString)|\(versionString)|\(createdAt.timeIntervalSince1970)"
        
        let data = Data(dataToHash.utf8)
        let hashed = SHA256.hash(data: data)
        self.checksum = hashed.compactMap { String(format: "%02x", $0) }.joined().prefix(8).lowercased()
    }
}
