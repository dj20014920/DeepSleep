import UIKit

class PresetListViewController: UITableViewController {
    var presets: [Preset] = []
    var onPresetSelected: ((Preset) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "프리셋 관리"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        loadPresets()
    }

    func loadPresets() {
        presets = PresetManager.shared.loadPresets()
        tableView.reloadData()
    }

    // MARK: - TableView 기본 구성
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = presets[indexPath.row].name
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
                // 실제 삭제 로직
                PresetManager.shared.deletePreset(named: presetToDelete.name)
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
                    // 이름이 변경되면 덮어쓰기
                    let newPreset = Preset(name: newName, volumes: preset.volumes)
                    PresetManager.shared.deletePreset(named: preset.name)
                    PresetManager.shared.savePreset(name: newName, volumes: preset.volumes)
                    self?.presets = PresetManager.shared.loadPresets()
                    self?.tableView.reloadData()
                }
            }))
            self?.present(alert, animated: true)
            completion(true)
        }
        renameAction.backgroundColor = .systemBlue

        // 🔺 삭제 액션
        let deleteAction = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, completion in
            let confirm = UIAlertController(title: "삭제 확인", message: "'\(preset.name)' 프리셋을 삭제할까요?", preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: "취소", style: .cancel))
            confirm.addAction(UIAlertAction(title: "삭제", style: .destructive, handler: { _ in
                PresetManager.shared.deletePreset(named: preset.name)
                self?.presets = PresetManager.shared.loadPresets()
                self?.tableView.reloadData()
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

            PresetManager.shared.renamePreset(oldName: oldPreset.name, newName: newName)
            self?.loadPresets()
        }))
        present(alert, animated: true)
    }
}
