import UIKit

// MARK: - ✅ 일기 수정 전용 뷰 컨트롤러
class EditDiaryViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let emotionSelectionView = UIView()
    private let textView = UITextView()
    
    // MARK: - Properties
    var diaryToEdit: EmotionDiary?
    var onDiaryUpdated: ((EmotionDiary) -> Void)?
    
    private var selectedEmotion: String = "😊"
    private let emotions = ["😊", "😢", "😡", "😰", "😴", "🥰", "😞", "😤", "😱", "😪"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadDiaryData()
        setupKeyboardHandling()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "일기 수정"
        
        // 네비게이션 바 설정
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        
        // 스크롤 뷰 설정
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // 감정 선택 뷰 설정
        setupEmotionSelection()
        
        // 텍스트 뷰 설정
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.text = "오늘 하루는 어땠나요? 자유롭게 감정을 표현해보세요..."
        textView.textColor = .placeholderText
        textView.delegate = self
        contentView.addSubview(textView)
    }
    
    private func setupEmotionSelection() {
        emotionSelectionView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(emotionSelectionView)
        
        let titleLabel = UILabel()
        titleLabel.text = "오늘의 기분은 어떠세요?"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        emotionSelectionView.addSubview(titleLabel)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        emotionSelectionView.addSubview(stackView)
        
        for emotion in emotions {
            let button = UIButton(type: .system)
            button.setTitle(emotion, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 28)
            button.layer.cornerRadius = 8
            button.backgroundColor = UIColor.systemGray6
            button.addTarget(self, action: #selector(emotionSelected(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: emotionSelectionView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: emotionSelectionView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: emotionSelectionView.trailingAnchor),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: emotionSelectionView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: emotionSelectionView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: emotionSelectionView.bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 스크롤 뷰
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // 콘텐츠 뷰
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // 감정 선택 뷰
            emotionSelectionView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 20),
            emotionSelectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            emotionSelectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // 텍스트 뷰
            textView.topAnchor.constraint(equalTo: emotionSelectionView.bottomAnchor, constant: 30),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            textView.heightAnchor.constraint(equalToConstant: 300),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupKeyboardHandling() {
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
    
    private func loadDiaryData() {
        guard let diary = diaryToEdit else { return }
        
        selectedEmotion = diary.selectedEmotion
        textView.text = diary.userMessage  // ✅ userMessage 사용
        textView.textColor = .label
        
        // 선택된 감정 버튼 강조 표시
        updateEmotionSelection()
    }
    
    @objc private func emotionSelected(_ sender: UIButton) {
        guard let emotion = sender.titleLabel?.text else { return }
        selectedEmotion = emotion
        updateEmotionSelection()
    }
    
    private func updateEmotionSelection() {
        guard let stackView = emotionSelectionView.subviews.last as? UIStackView else { return }
        
        for view in stackView.arrangedSubviews {
            if let button = view as? UIButton {
                if button.titleLabel?.text == selectedEmotion {
                    button.backgroundColor = UIColor.systemBlue
                    button.setTitleColor(.white, for: .normal)
                } else {
                    button.backgroundColor = UIColor.systemGray6
                    button.setTitleColor(.label, for: .normal)
                }
            }
        }
    }
    
    @objc private func saveTapped() {
        guard let originalDiary = diaryToEdit,
              !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              textView.textColor != .placeholderText else {
            showAlert(title: "⚠️", message: "일기 내용을 입력해주세요.")
            return
        }
        
        // ✅ 수정된 일기 생성 - 올바른 초기화 사용
        let updatedDiary = EmotionDiary(
            id: originalDiary.id,
            selectedEmotion: selectedEmotion,
            userMessage: textView.text.trimmingCharacters(in: .whitespacesAndNewlines),
            aiResponse: originalDiary.aiResponse,  // 기존 AI 응답 유지
            date: originalDiary.date
        )
        
        onDiaryUpdated?(updatedDiary)
        dismiss(animated: true)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        
        let keyboardHeight = keyboardFrame.cgRectValue.height
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.3
        
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = keyboardHeight
            self.scrollView.scrollIndicatorInsets.bottom = keyboardHeight
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.3
        
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = 0
            self.scrollView.scrollIndicatorInsets.bottom = 0
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - TextView Delegate
extension EditDiaryViewController: UITextViewDelegate {
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .placeholderText {
            textView.text = ""
            textView.textColor = .label
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "오늘 하루는 어땠나요? 자유롭게 감정을 표현해보세요..."
            textView.textColor = .placeholderText
        }
    }
}
