import UIKit

// MARK: - ✅ TableView DataSource & Delegate Extension
extension EmotionDiaryViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleDiaryEntries.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: EmotionDiaryCell.identifier, for: indexPath) as? EmotionDiaryCell else {
            return UITableViewCell()
        }
        
        let entry = visibleDiaryEntries[indexPath.row]
        cell.configure(with: entry)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 140
    }
    
    // ✅ 무한스크롤 트리거: 하단 근접 시 다음 페이지 로드
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let threshold = max(0, visibleDiaryEntries.count - 3)
        if indexPath.row >= threshold {
            loadMoreDiariesIfNeeded()
        }
    }
    
    // ✅ 셀 탭으로 수정/삭제 옵션 표시
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let diary = visibleDiaryEntries[indexPath.row]
        showEditDiaryOptions(for: diary, at: indexPath)
    }
    
    private func showEditDiaryOptions(for diary: EmotionDiary, at indexPath: IndexPath) {
        let alert = UIAlertController(title: "📝 일기 관리", message: "이 일기를 어떻게 하시겠어요?", preferredStyle: .actionSheet)
        
        // 수정 옵션
        alert.addAction(UIAlertAction(title: "✏️ 수정하기", style: .default) { [weak self] _ in
            self?.editDiary(diary)
        })
        
        // 삭제 옵션
        alert.addAction(UIAlertAction(title: "🗑️ 삭제하기", style: .destructive) { [weak self] _ in
            self?.deleteDiary(diary, at: indexPath)
        })
        
        // 취소 옵션
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        // iPad 지원 - ✅ 타입 명시로 수정
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.tableView
            popover.sourceRect = self.tableView.rectForRow(at: indexPath)
        }
        
        present(alert, animated: true)
    }
    
    private func deleteDiary(_ diary: EmotionDiary, at indexPath: IndexPath) {
        let confirmAlert = UIAlertController(
            title: "🗑️ 일기 삭제",
            message: "정말로 이 일기를 삭제하시겠어요?\n삭제된 일기는 복구할 수 없습니다.",
            preferredStyle: .alert
        )
        
        confirmAlert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.performDelete(diary: diary, at: indexPath)
        })
        
        confirmAlert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        present(confirmAlert, animated: true)
    }
    
    private func performDelete(diary: EmotionDiary, at indexPath: IndexPath) {
        // 저장소에서 제거
        var allDiaries = SettingsManager.shared.loadEmotionDiary()
        allDiaries.removeAll { $0.id == diary.id }
        saveDiaryList(allDiaries)
        
        // 메모리 상태 동기화
        if let fullIndex = diaryEntries.firstIndex(where: { $0.id == diary.id }) {
            diaryEntries.remove(at: fullIndex)
        }
        if let visibleIndex = visibleDiaryEntries.firstIndex(where: { $0.id == diary.id }) {
            visibleDiaryEntries.remove(at: visibleIndex)
            tableView.deleteRows(at: [IndexPath(row: visibleIndex, section: 0)], with: .fade)
        } else {
            tableView.reloadData()
        }
        
        // 성공 알림
        self.showAlert(title: "✅", message: "일기가 삭제되었습니다.")
        
        // 인사이트 뷰 업데이트
        self.updateInsightView()
        self.updateScrollViewContentSize()
    }
    
    // ✅ editDiary 구현 (메인 클래스에서 제거됨)
    func editDiary(_ diary: EmotionDiary) {
        let editVC = EditDiaryViewController()
        editVC.diaryToEdit = diary
        editVC.onDiaryUpdated = { [weak self] updatedDiary in
            // 🔧 메인 스레드에서 UI 업데이트 보장
            guard Thread.isMainThread else {
                DispatchQueue.main.async {
                    self?.updateDiaryEntry(original: diary, updated: updatedDiary)
                    self?.loadDiaryData()
                }
                return
            }
            
            self?.updateDiaryEntry(original: diary, updated: updatedDiary)
            self?.loadDiaryData()
        }
        
        let navController = UINavigationController(rootViewController: editVC)
        present(navController, animated: true)
    }
    
    private func updateDiaryEntry(original: EmotionDiary, updated: EmotionDiary) {
        var allDiaries = SettingsManager.shared.loadEmotionDiary()
        
        if let index = allDiaries.firstIndex(where: { $0.id == original.id }) {
            allDiaries[index] = updated
            saveDiaryList(allDiaries)
        }
    }
    
    private func saveDiaryList(_ diaries: [EmotionDiary]) {
        if let encoded = try? JSONEncoder().encode(diaries) {
            UserDefaults.standard.set(encoded, forKey: "emotionDiary")
        }
    }
}
