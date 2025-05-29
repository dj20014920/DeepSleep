import UIKit

// MARK: - ✅ Actions Extension
extension EmotionDiaryViewController {
    
    // MARK: - ✅ 수정 버튼 액션
    @objc func editButtonTapped() {
        guard !diaryEntries.isEmpty else {
            showAlert(title: "📝", message: "수정할 일기가 없습니다.")
            return
        }
        
        let alert = UIAlertController(title: "📝 일기 관리", message: "어떻게 하시겠어요?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "✏️ 일기 수정하기", style: .default) { [weak self] _ in
            self?.showDiarySelectionForEdit()
        })
        
        alert.addAction(UIAlertAction(title: "🗑️ 전체 삭제", style: .destructive) { [weak self] _ in
            self?.clearAllData()
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        // iPad 지원
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func showDiarySelectionForEdit() {
        let alert = UIAlertController(title: "✏️ 수정할 일기 선택", message: "수정하고 싶은 일기를 선택해주세요", preferredStyle: .actionSheet)
        
        // 최근 10개 일기만 표시
        let recentDiaries = Array(diaryEntries.prefix(10))
        
        for (index, diary) in recentDiaries.enumerated() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd"
            let dateString = dateFormatter.string(from: diary.date)
            // ✅ content를 userMessage로 변경
            let content = diary.userMessage.count > 30 ? String(diary.userMessage.prefix(30)) + "..." : diary.userMessage
            
            let title = "\(diary.selectedEmotion) \(dateString) - \(content)"
            
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.editDiary(diary)
            })
        }
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        // iPad 지원
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func clearAllData() {
        let alert = UIAlertController(
            title: "⚠️ 전체 삭제",
            message: "모든 감정 일기를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            UserDefaults.standard.removeObject(forKey: "emotionDiary")
            self?.loadDiaryData()
            
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            
            self?.showAlert(title: "✅", message: "모든 일기가 삭제되었습니다.")
        })
        
        present(alert, animated: true)
    }
}
