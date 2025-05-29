import UIKit

class PresetListViewController: UITableViewController {
    var presets: [SoundPreset] = []
    var onPresetSelected: ((SoundPreset) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "프리셋 관리"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        loadPresets()
    }

    func loadPresets() {
        presets = SettingsManager.shared.loadSoundPresets()
        tableView.reloadData()
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let preset = presets[indexPath.row]
        
        // 프리셋 이름만 표시 (타입 태그 제거)
        cell.textLabel?.text = preset.name
        
        // 설명이 있으면 상세 텍스트로 표시
        if let description = preset.description {
            cell.detailTextLabel?.text = description
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
        renameAction.backgroundColor = UIColor.systemBlue  // UIColor 명시적 지정

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

        return UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
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

            // 새 프리셋 생성하고 기존 것 삭제
            let newPreset = SoundPreset(
                name: newName,
                volumes: oldPreset.volumes,
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
}
