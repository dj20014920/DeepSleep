import UIKit

// MARK: - EmotionCalendarViewController Diary Extension
extension EmotionCalendarViewController {
    
    // MARK: - ✅ 일기 상세보기 - 남은 횟수 표시 추가
    func showDiaryDetail(for date: Date, emotion: String) {
        let calendar = Calendar.current
        let targetEntries = diaryEntries.filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }
        
        guard let entry = targetEntries.first else { return }
        
        let dateString = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        
        let alert = UIAlertController(
            title: "\(emotion) \(dateString)",
            message: entry.userMessage,
            preferredStyle: .alert
        )
        
        // AI 응답 보기 버튼
        alert.addAction(UIAlertAction(title: "AI 응답 보기", style: .default) { _ in
            let responseAlert = UIAlertController(
                title: "AI 응답",
                message: entry.aiResponse,
                preferredStyle: .alert
            )
            responseAlert.addAction(UIAlertAction(title: "확인", style: .default))
            self.present(responseAlert, animated: true)
        })
        
        // ✅ 일기 분석 대화 버튼 - 남은 횟수 표시
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .diaryAnalysis)
        let diaryAnalysisTitle = remainingCount > 0 ?
            "💬 이 일기를 AI와 깊이 분석 (남은 횟수: \(remainingCount))" :
            "💬 일기 분석 대화 (오늘 사용 완료)"
        
        alert.addAction(UIAlertAction(title: diaryAnalysisTitle, style: .default) { _ in
            self.startDiaryConversation(with: entry)
        })
        
        // 일기 전체 내용 보기 버튼 (긴 일기인 경우)
        if entry.userMessage.count > 100 {
            alert.addAction(UIAlertAction(title: "📖 전체 내용 보기", style: .default) { _ in
                self.showFullDiaryContent(entry: entry)
            })
        }
        
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel))
        present(alert, animated: true)
    }
    
    // MARK: - ✅ 일기 대화 시작 - 하루 1회 제한 추가 & 안전한 데이터 전달
    func startDiaryConversation(with entry: EmotionDiary) {
        // ✅ 하루 1회 제한 체크
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .diaryAnalysis)
        
        guard remainingCount > 0 else {
            let limitAlert = UIAlertController(
                title: "📝 일일 일기 분석 완료",
                message: """
                오늘 일기 분석 대화를 이미 사용하셨습니다.
                
                깊이 있는 일기 분석을 위해 하루 1회로 제한하고 있어요.
                대신 충분한 시간 동안 AI와 깊이 있게 대화할 수 있습니다.
                
                내일 다시 이용해보세요! 😊
                
                💡 일반 채팅으로 감정 상담을 받아보시는 건 어떨까요?
                """,
                preferredStyle: .alert
            )
            
            limitAlert.addAction(UIAlertAction(title: "확인", style: .default))
            present(limitAlert, animated: true)
            return
        }
        
        // 🛡️ 안전한 데이터 검증 및 준비
        guard !entry.userMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let errorAlert = UIAlertController(
                title: "오류",
                message: "일기 내용이 비어있어 AI와 대화할 수 없습니다.",
                preferredStyle: .alert
            )
            errorAlert.addAction(UIAlertAction(title: "확인", style: .default))
            present(errorAlert, animated: true)
            return
        }
        
        // 🛡️ 필수 데이터 확인
        let verifiedEmotion = entry.selectedEmotion.isEmpty ? "😐" : entry.selectedEmotion
        let verifiedMessage = entry.userMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let verifiedAIResponse = entry.aiResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 [일기 대화 시작] 데이터 검증:")
        print("  - 감정: \(verifiedEmotion)")
        print("  - 일기 길이: \(verifiedMessage.count)자")
        print("  - AI 응답 길이: \(verifiedAIResponse.count)자")
        print("  - 날짜: \(entry.date)")
        
        // ✅ 사용 횟수 증가 (실제 대화 시작 직전에)
        AIUsageManager.shared.recordUsage(for: .diaryAnalysis)
        
        // 🛡️ ChatViewController 생성 및 안전한 데이터 설정
        let chatVC = ChatRouter.chatViewController()
        
        // 🛡️ 확실한 일기 컨텍스트 생성
        let safeEntry = EmotionDiary(
            selectedEmotion: verifiedEmotion,
            userMessage: verifiedMessage,
            aiResponse: verifiedAIResponse,
            date: entry.date
        )
        
        // 🛡️ 여러 방법으로 데이터 전달 (안전성 보장)
        let diaryContext = DiaryContext(from: safeEntry)
        chatVC.diaryContext = diaryContext
        
        // 🛡️ 초기 사용자 텍스트 설정
        chatVC.initialUserText = "일기_분석_모드_확인"
        
        // 🛡️ 타이틀 통일
        // chatVC.title = "#Todays_Mood"
        
        // 🛡️ 프리셋 적용 콜백 설정
        chatVC.onPresetApply = { [weak self] recommendation in
            self?.applyPresetFromCalendar(recommendation)
        }
        
        // 🛡️ 네비게이션 설정 및 표시
        let navController = UINavigationController(rootViewController: chatVC)
        navController.navigationBar.prefersLargeTitles = false
        navController.navigationBar.tintColor = .systemBlue
        navController.modalPresentationStyle = .fullScreen
        navController.modalTransitionStyle = .coverVertical
        
        present(navController, animated: true) {
            // 🛡️ 표시 완료 후 데이터 전달 재확인
            print("✅ [일기 대화] ChatViewController 표시 완료")
            print("  - diaryContext 설정됨: \(chatVC.diaryContext != nil)")
            print("  - initialUserText: \(chatVC.initialUserText ?? "없음")")
        }
    }
    private func applyPresetFromCalendar(_ recommendation: RecommendationResponse) {
        NotificationCenter.default.post(
            name: NSNotification.Name("ApplyPresetFromChat"),
            object: nil,
            userInfo: [
                "volumes": recommendation.volumes,
                "presetName": recommendation.presetName
            ]
        )
    }
    func showFullDiaryContent(entry: EmotionDiary) {
        let detailVC = UIViewController()
        detailVC.title = "일기 상세"
        detailVC.view.backgroundColor = .systemBackground
        
        let scrollView = UIScrollView()
        let textView = UITextView()
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        textView.text = """
        날짜: \(DateFormatter.localizedString(from: entry.date, dateStyle: .full, timeStyle: .short))
        감정: \(entry.selectedEmotion)
        
        일기 내용:
        \(entry.userMessage)
        
        AI 응답:
        \(entry.aiResponse)
        """
        
        textView.font = .systemFont(ofSize: 16)
        textView.isEditable = false
        textView.backgroundColor = .systemBackground
        
        detailVC.view.addSubview(scrollView)
        scrollView.addSubview(textView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: detailVC.view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: detailVC.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: detailVC.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: detailVC.view.safeAreaLayoutGuide.bottomAnchor),
            
            textView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            textView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        let closeButton = UIBarButtonItem(title: "닫기", style: .plain, target: self, action: #selector(closeDiaryDetail))
        
        // ✅ AI 대화 버튼도 제한 체크
        let remainingCount = AIUsageManager.shared.getRemainingCount(for: .diaryAnalysis)
        let chatButtonTitle = remainingCount > 0 ? "💬 AI 분석" : "💬 분석 완료"
        let chatButton = UIBarButtonItem(title: chatButtonTitle, style: .plain, target: self, action: #selector(startChatFromDetail))
        
        detailVC.navigationItem.leftBarButtonItem = closeButton
        detailVC.navigationItem.rightBarButtonItem = chatButton
        
        objc_setAssociatedObject(detailVC, "diaryEntry", entry, .OBJC_ASSOCIATION_RETAIN)
        
        let navController = UINavigationController(rootViewController: detailVC)
        present(navController, animated: true)
    }
    
    @objc func closeDiaryDetail() {
        dismiss(animated: true)
    }
    
    @objc func startChatFromDetail() {
        guard let presentedNav = presentedViewController as? UINavigationController,
              let detailVC = presentedNav.topViewController,
              let entry = objc_getAssociatedObject(detailVC, "diaryEntry") as? EmotionDiary else { return }
        
        presentedNav.dismiss(animated: true) { [weak self] in
            self?.startDiaryConversation(with: entry)
        }
    }
}
