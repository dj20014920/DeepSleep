import UIKit

class DiaryWriteViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emotionSelectionView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emotionLabel: UILabel = {
        let label = UILabel()
        label.text = "오늘의 기분을 선택해주세요"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emotionStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let diaryTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16)
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.backgroundColor = .systemBackground
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "오늘 하루는 어떠셨나요?\n마음 편히 적어보세요..."
        label.font = .systemFont(ofSize: 16)
        label.textColor = .placeholderText
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("일기 저장", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let aiChatButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("AI와 이 일기에 대해 대화하기", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 12
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties
    private let emotions = ["😊", "😢", "😠", "😰", "😴", "🥰", "😔", "😤", "😌", "🤔"]
    private var selectedEmotion: String = ""
    private var emotionButtons: [UIButton] = []
    private var savedDiaryEntry: EmotionDiary?
    private var isDiarySaved: Bool = false // ✅ 일기 저장 상태 추가
    
    var diaryToEdit: EmotionDiary?
    var onDiarySaved: (() -> Void)?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNotifications()
        setupTapGesture() // ✅ 탭 제스처 추가
        configureForEditing() // <--- 추가된 메서드 호출
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        // title = "일기 쓰기" // configureForEditing에서 설정하도록 이동
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "취소",
            style: .plain,
            target: self,
            action: #selector(rightBarButtonTapped)
        )
        
        setupScrollView()
        setupEmotionSelection()
        setupDiaryTextView()
        setupButtons()
        setupConstraints()
    }
    
    // ✅ 화면 탭으로 키보드 내리기
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }
    
    private func setupEmotionSelection() {
        contentView.addSubview(emotionSelectionView)
        emotionSelectionView.addSubview(emotionLabel)
        emotionSelectionView.addSubview(emotionStackView)
        
        // 감정 버튼들 생성
        for (index, emotion) in emotions.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(emotion, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 24)
            button.backgroundColor = .systemBackground
            button.layer.cornerRadius = 8
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.clear.cgColor
            button.tag = index
            button.addTarget(self, action: #selector(emotionSelected(_:)), for: .touchUpInside)
            
            emotionButtons.append(button)
            
            // 첫 번째 줄 (5개)
            if index < 5 {
                emotionStackView.addArrangedSubview(button)
            }
        }
        
        // 두 번째 줄 생성
        let secondRowStackView = UIStackView()
        secondRowStackView.axis = .horizontal
        secondRowStackView.spacing = 12
        secondRowStackView.distribution = .fillEqually
        secondRowStackView.translatesAutoresizingMaskIntoConstraints = false
        
        for index in 5..<emotions.count {
            secondRowStackView.addArrangedSubview(emotionButtons[index])
        }
        
        emotionSelectionView.addSubview(secondRowStackView)
        
        NSLayoutConstraint.activate([
            secondRowStackView.topAnchor.constraint(equalTo: emotionStackView.bottomAnchor, constant: 12),
            secondRowStackView.leadingAnchor.constraint(equalTo: emotionSelectionView.leadingAnchor, constant: 16),
            secondRowStackView.trailingAnchor.constraint(equalTo: emotionSelectionView.trailingAnchor, constant: -16),
            secondRowStackView.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupDiaryTextView() {
        contentView.addSubview(diaryTextView)
        diaryTextView.addSubview(placeholderLabel)
        
        diaryTextView.delegate = self
        
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: diaryTextView.topAnchor, constant: 8),
            placeholderLabel.leadingAnchor.constraint(equalTo: diaryTextView.leadingAnchor, constant: 8),
            placeholderLabel.trailingAnchor.constraint(equalTo: diaryTextView.trailingAnchor, constant: -8)
        ])
    }
    
    private func setupButtons() {
        contentView.addSubview(saveButton)
        contentView.addSubview(aiChatButton)
        
        saveButton.addTarget(self, action: #selector(saveDiary), for: .touchUpInside)
        aiChatButton.addTarget(self, action: #selector(showAIChatAlert), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 감정 선택 영역
            emotionSelectionView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            emotionSelectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            emotionSelectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            emotionLabel.topAnchor.constraint(equalTo: emotionSelectionView.topAnchor, constant: 16),
            emotionLabel.leadingAnchor.constraint(equalTo: emotionSelectionView.leadingAnchor, constant: 16),
            emotionLabel.trailingAnchor.constraint(equalTo: emotionSelectionView.trailingAnchor, constant: -16),
            
            emotionStackView.topAnchor.constraint(equalTo: emotionLabel.bottomAnchor, constant: 12),
            emotionStackView.leadingAnchor.constraint(equalTo: emotionSelectionView.leadingAnchor, constant: 16),
            emotionStackView.trailingAnchor.constraint(equalTo: emotionSelectionView.trailingAnchor, constant: -16),
            emotionStackView.heightAnchor.constraint(equalToConstant: 40),
            emotionStackView.bottomAnchor.constraint(equalTo: emotionSelectionView.bottomAnchor, constant: -64),
            
            // 일기 텍스트뷰
            diaryTextView.topAnchor.constraint(equalTo: emotionSelectionView.bottomAnchor, constant: 20),
            diaryTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            diaryTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            diaryTextView.heightAnchor.constraint(equalToConstant: 250),
            
            // 저장 버튼
            saveButton.topAnchor.constraint(equalTo: diaryTextView.bottomAnchor, constant: 20),
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            
            // AI 대화 버튼
            aiChatButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 12),
            aiChatButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            aiChatButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            aiChatButton.heightAnchor.constraint(equalToConstant: 50),
            aiChatButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    // MARK: - Actions
    @objc private func emotionSelected(_ sender: UIButton) {
        // 이전 선택 해제
        emotionButtons.forEach { button in
            button.layer.borderColor = UIColor.clear.cgColor
            button.backgroundColor = .systemBackground
        }
        
        // 새 선택 표시
        sender.layer.borderColor = UIColor.systemBlue.cgColor
        sender.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        
        selectedEmotion = emotions[sender.tag]
        updateSelectedEmotionButtonUI(selectedEmoji: selectedEmotion) // UI 업데이트 분리
        
        // 햅틱 피드백
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()
    }
    
    @objc private func saveDiary() {
        guard !selectedEmotion.isEmpty else {
            showAlert(title: "감정을 선택해주세요", message: "오늘의 기분을 먼저 선택해주세요.")
            return
        }
        
        guard !diaryTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "일기를 작성해주세요", message: "오늘의 이야기를 들려주세요.")
            return
        }
        
        let diaryMessage = diaryTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentDiaryEntry: EmotionDiary

        if let existingDiary = diaryToEdit {
            // 수정 모드: 기존 ID 사용, 날짜는 유지하거나 현재로 업데이트 (여기서는 기존 날짜 유지)
            currentDiaryEntry = EmotionDiary(
                id: existingDiary.id, // 기존 ID 사용
                selectedEmotion: selectedEmotion,
                userMessage: diaryMessage,
                aiResponse: existingDiary.aiResponse, // AI 응답은 유지하거나 초기화 (여기서는 유지)
                date: existingDiary.date // 기존 날짜 사용
            )
        } else {
            // 새 일기 모드
            currentDiaryEntry = EmotionDiary(
            selectedEmotion: selectedEmotion,
                userMessage: diaryMessage,
            aiResponse: "저장된 일기입니다. AI와 대화하기를 눌러 분석을 받아보세요."
                // date는 기본값으로 현재 날짜 사용됨
            )
        }
        
        SettingsManager.shared.saveEmotionDiary(currentDiaryEntry) // 저장 (ID가 같으면 덮어쓰기 가정)
        savedDiaryEntry = currentDiaryEntry
        isDiarySaved = true
        
        // UI 업데이트
        saveButton.setTitle("✓ 수정 완료", for: .normal) // 수정 모드일 수도 있으므로 "수정 완료" 또는 "저장 완료"
        if diaryToEdit != nil {
            saveButton.setTitle("✓ 수정 완료", for: .normal)
        } else {
        saveButton.setTitle("✓ 저장 완료", for: .normal)
        }
        saveButton.backgroundColor = .systemGreen
        saveButton.isEnabled = false
        
        aiChatButton.isHidden = false
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "완료",
            style: .done,
            target: self,
            action: #selector(rightBarButtonTapped)
        )
        
        view.endEditing(true)
        
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        onDiarySaved?()
        
        showAlert(
            title: diaryToEdit == nil ? "📝 일기가 저장되었습니다" : "📝 일기가 수정되었습니다",
            message: "AI와 대화하기 버튼을 눌러 감정 분석을 받아보세요!"
        )
    }
    
    @objc private func showAIChatAlert() {
        guard let diaryEntry = savedDiaryEntry else { return }
        
        let alert = UIAlertController(
            title: "🔒 개인정보 보호 안내",
            message: """
            AI와 대화하기 위해 다음 정보가 전송됩니다:
            
            • 선택한 감정: \(diaryEntry.selectedEmotion)
            • 작성한 일기 내용
            
            ⚠️ 주의사항:
            • 개인 식별 정보 (이름, 전화번호 등)가 
              포함된 경우 전송하지 않는 것을 권장합니다
            • 대화 종료 후 데이터는 즉시 삭제됩니다
            • 민감한 개인정보는 삭제 후 진행하시기 바랍니다
            
            계속하시겠습니까?
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "AI와 대화하기", style: .default) { [weak self] _ in
            self?.startAIChat()
        })
        
        present(alert, animated: true)
    }
    
    private func startAIChat() {
        guard let diaryEntry = savedDiaryEntry else { return }
        let chatVC = ChatViewController()
        // 필수 데이터 검증
        chatVC.diaryContext = DiaryContext(from: diaryEntry)
        chatVC.initialUserText = "일기를 분석해줘"
        chatVC.onPresetApply = { [weak self] recommendation in
            NotificationCenter.default.post(
                name: NSNotification.Name("ApplyPresetFromChat"),
                object: nil,
                userInfo: [
                    "volumes": recommendation.volumes,
                    "presetName": recommendation.presetName,
                    "selectedVersions": recommendation.selectedVersions
                ]
            )
            // dismiss 중첩/race condition 방지
            if let presented = self?.presentedViewController {
                presented.dismiss(animated: true) {
                    // TabBar 이동 및 popToRoot 일관성
                    if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
                       let tabBarController = sceneDelegate.window?.rootViewController as? UITabBarController {
                        tabBarController.selectedIndex = 0
                        if let navController = tabBarController.viewControllers?[0] as? UINavigationController {
                            navController.popToRootViewController(animated: false)
                        }
                    }
                }
            } else {
                // TabBar 이동 및 popToRoot 일관성
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
                   let tabBarController = sceneDelegate.window?.rootViewController as? UITabBarController {
                    tabBarController.selectedIndex = 0
                    if let navController = tabBarController.viewControllers?[0] as? UINavigationController {
                        navController.popToRootViewController(animated: false)
                    }
                }
            }
        }
        let navController = UINavigationController(rootViewController: chatVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
    
    // ✅ 오른쪽 버튼 액션 - 저장 상태에 따라 다르게 동작
    @objc private func rightBarButtonTapped() {
        if isDiarySaved {
            // 일기가 저장된 경우 - 바로 돌아가기
            dismiss(animated: true)
        } else {
            // 일기가 저장되지 않은 경우 - 기존 취소 로직
            if !diaryTextView.text.isEmpty || !selectedEmotion.isEmpty {
                let alert = UIAlertController(
                    title: "작성 중인 일기가 있습니다",
                    message: "저장하지 않고 나가시겠습니까?",
                    preferredStyle: .alert
                )
                
                alert.addAction(UIAlertAction(title: "계속 작성", style: .cancel))
                alert.addAction(UIAlertAction(title: "나가기", style: .destructive) { [weak self] _ in
                    self?.dismiss(animated: true)
                })
                
                present(alert, animated: true)
            } else {
                dismiss(animated: true)
            }
        }
    }
    
    // MARK: - Keyboard Handling
    @objc private func keyboardWillShow(notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let keyboardHeight = keyboardFrame.height
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
        
        // ✅ 텍스트뷰가 키보드에 가려지지 않도록 스크롤
        if diaryTextView.isFirstResponder {
            let textViewFrame = diaryTextView.convert(diaryTextView.bounds, to: scrollView)
            let visibleArea = scrollView.bounds.height - keyboardHeight
            
            if textViewFrame.maxY > visibleArea {
                let scrollOffset = textViewFrame.maxY - visibleArea + 20
                scrollView.setContentOffset(CGPoint(x: 0, y: scrollOffset), animated: true)
            }
        }
    }
    
    @objc private func keyboardWillHide(notification: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
    
    // MARK: - Utilities
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Configuration for Editing
    private func configureForEditing() {
        if let diary = diaryToEdit {
            title = "일기 수정"
            diaryTextView.text = diary.userMessage
            placeholderLabel.isHidden = !diary.userMessage.isEmpty
            selectedEmotion = diary.selectedEmotion
            updateSelectedEmotionButtonUI(selectedEmoji: diary.selectedEmotion) // 감정 버튼 UI 업데이트

            savedDiaryEntry = diary // AI 채팅을 위해 미리 설정
            isDiarySaved = true // 수정 모드에서는 이미 저장된 상태로 간주 (AI 채팅 버튼 활성화 등)

            saveButton.setTitle("일기 수정", for: .normal)
            aiChatButton.isHidden = false // 수정 모드에서는 AI 채팅 버튼 바로 표시
            
            // 네비게이션 바 버튼도 "완료" 상태로 시작할 수 있음 (저장 후와 동일하게)
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "완료",
                style: .done,
                target: self,
                action: #selector(rightBarButtonTapped)
            )
        } else {
            title = "일기 쓰기"
            // 새 일기 작성 시 기본 placeholder 및 버튼 상태 유지
            placeholderLabel.isHidden = diaryTextView.text.isEmpty
            aiChatButton.isHidden = true
             navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "취소",
                style: .plain,
                target: self,
                action: #selector(rightBarButtonTapped)
            )
        }
    }
    
    private func updateSelectedEmotionButtonUI(selectedEmoji: String) {
        emotionButtons.forEach { button in
            if button.title(for: .normal) == selectedEmoji {
                button.layer.borderColor = UIColor.systemBlue.cgColor
                button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            } else {
                button.layer.borderColor = UIColor.clear.cgColor
                button.backgroundColor = .systemBackground
            }
        }
    }
}

// MARK: - UITextViewDelegate
extension DiaryWriteViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        placeholderLabel.isHidden = true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
}
