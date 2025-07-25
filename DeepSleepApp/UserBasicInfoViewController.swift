import UIKit

/// 💬 사용자 기본 정보 입력 화면 (ChatGPT 스타일 페르소나)
/// AI가 사용자를 더 잘 이해할 수 있도록 돕는 개인화 정보 입력
class UserBasicInfoViewController: UIViewController {
    
    // MARK: - Properties
    var userInfo: UserSettingsModel = UserSettingsModel()
    var onInfoUpdated: ((UserSettingsModel) -> Void)?
    
    // MARK: - UI Components
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIDesignSystem.Colors.primary.withAlphaComponent(0.1)
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "대나무숲 친구에게 자신을 소개해주세요!"
        label.font = UIFont.boldSystemFont(ofSize: 22)
        label.textColor = UIDesignSystem.Colors.primaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "친구가 당신을 더 잘 이해하고 맞춤형 대화를 할 수 있도록 도와주세요. 자신만의 스타일로 작성해보세요."
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 페르소나 입력 섹션들
    private let personalityCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIDesignSystem.Colors.cardBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let nameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "닉네임을 입력해주세요"
        textField.borderStyle = .roundedRect
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let ageTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "나이 (선택사항)"
        textField.borderStyle = .roundedRect
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.keyboardType = .numberPad
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let personalityTextView: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = """
        예시: 안녕하세요! 저는 20대 대학생이고, 평소에 스트레스를 많이 받는 편이에요. 밤에 잠들기 전에 차분한 음악을 듣는 걸 좋아하고, 특히 클래식이나 로파이 음악을 선호해요. 
        
        성격은 내향적이고 완벽주의 성향이 있어서 작은 일에도 고민을 많이 하는 편입니다. 대나무숲 친구와 대화할 때는 친구처럼 편안하고 따뜻하게 대해주시면 좋겠어요.
        """
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIColor.systemGray3
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 빠른 선택 옵션들
    private let quickOptionsView: UIView = {
        let view = UIView()
        view.backgroundColor = UIDesignSystem.Colors.cardBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var personalityButtons: [UIButton] = []
    private var musicPreferenceButtons: [UIButton] = []
    private var tonePreferenceButtons: [UIButton] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        loadUserData()
        setupKeyboardHandling()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        navigationItem.title = "기본 정보"
        
        // 저장 버튼 추가
        let saveButton = UIBarButtonItem(
            title: "저장",
            style: .done,
            target: self,
            action: #selector(saveButtonTapped)
        )
        navigationItem.rightBarButtonItem = saveButton
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupHeaderSection()
        setupPersonalityCard()
        setupQuickOptions()
    }
    
    private func setupHeaderSection() {
        contentView.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
    }
    
    private func setupPersonalityCard() {
        contentView.addSubview(personalityCardView)
        
        let nameLabel = createSectionLabel(text: "👤 닉네임")
        let ageLabel = createSectionLabel(text: "🎂 나이")
        let personalityLabel = createSectionLabel(text: "💭 자기소개 (자유롭게 작성해주세요)")
        
        personalityCardView.addSubview(nameLabel)
        personalityCardView.addSubview(nameTextField)
        personalityCardView.addSubview(ageLabel)
        personalityCardView.addSubview(ageTextField)
        personalityCardView.addSubview(personalityLabel)
        personalityCardView.addSubview(personalityTextView)
        personalityCardView.addSubview(placeholderLabel)
        
        // 플레이스홀더 설정
        personalityTextView.delegate = self
        updatePlaceholderVisibility()
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: personalityCardView.topAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: personalityCardView.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: personalityCardView.trailingAnchor, constant: -20),
            
            nameTextField.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            nameTextField.leadingAnchor.constraint(equalTo: personalityCardView.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: personalityCardView.trailingAnchor, constant: -20),
            nameTextField.heightAnchor.constraint(equalToConstant: 44),
            
            ageLabel.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 16),
            ageLabel.leadingAnchor.constraint(equalTo: personalityCardView.leadingAnchor, constant: 20),
            ageLabel.trailingAnchor.constraint(equalTo: personalityCardView.trailingAnchor, constant: -20),
            
            ageTextField.topAnchor.constraint(equalTo: ageLabel.bottomAnchor, constant: 8),
            ageTextField.leadingAnchor.constraint(equalTo: personalityCardView.leadingAnchor, constant: 20),
            ageTextField.trailingAnchor.constraint(equalTo: personalityCardView.trailingAnchor, constant: -20),
            ageTextField.heightAnchor.constraint(equalToConstant: 44),
            
            personalityLabel.topAnchor.constraint(equalTo: ageTextField.bottomAnchor, constant: 16),
            personalityLabel.leadingAnchor.constraint(equalTo: personalityCardView.leadingAnchor, constant: 20),
            personalityLabel.trailingAnchor.constraint(equalTo: personalityCardView.trailingAnchor, constant: -20),
            
            personalityTextView.topAnchor.constraint(equalTo: personalityLabel.bottomAnchor, constant: 8),
            personalityTextView.leadingAnchor.constraint(equalTo: personalityCardView.leadingAnchor, constant: 20),
            personalityTextView.trailingAnchor.constraint(equalTo: personalityCardView.trailingAnchor, constant: -20),
            personalityTextView.bottomAnchor.constraint(equalTo: personalityCardView.bottomAnchor, constant: -20),
            personalityTextView.heightAnchor.constraint(equalToConstant: 200),
            
            placeholderLabel.topAnchor.constraint(equalTo: personalityTextView.topAnchor, constant: 12),
            placeholderLabel.leadingAnchor.constraint(equalTo: personalityTextView.leadingAnchor, constant: 16),
            placeholderLabel.trailingAnchor.constraint(equalTo: personalityTextView.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupQuickOptions() {
        contentView.addSubview(quickOptionsView)
        
        let quickLabel = createSectionLabel(text: "⚡ 빠른 선택 (선택사항)")
        let personalitySubLabel = createSubLabel(text: "성격 특성")
        let musicSubLabel = createSubLabel(text: "음악 취향")
        let toneSubLabel = createSubLabel(text: "대화 스타일")
        
        quickOptionsView.addSubview(quickLabel)
        quickOptionsView.addSubview(personalitySubLabel)
        quickOptionsView.addSubview(musicSubLabel)
        quickOptionsView.addSubview(toneSubLabel)
        
        // 성격 특성 버튼들
        let personalityTraits = ["내향적", "외향적", "완벽주의", "낙천적", "신중한", "즉흥적"]
        let personalityStackView = createButtonStackView(items: personalityTraits, tag: 100)
        personalityButtons = personalityStackView.arrangedSubviews.compactMap { $0 as? UIButton }
        quickOptionsView.addSubview(personalityStackView)
        
        // 음악 취향 버튼들
        let musicPreferences = ["클래식", "로파이", "재즈", "팝", "일렉트로닉", "자연소리"]
        let musicStackView = createButtonStackView(items: musicPreferences, tag: 200)
        musicPreferenceButtons = musicStackView.arrangedSubviews.compactMap { $0 as? UIButton }
        quickOptionsView.addSubview(musicStackView)
        
        // 대화 스타일 버튼들
        let tonePreferences = ["친근한", "정중한", "유머러스", "차분한", "격려하는", "전문적인"]
        let toneStackView = createButtonStackView(items: tonePreferences, tag: 300)
        tonePreferenceButtons = toneStackView.arrangedSubviews.compactMap { $0 as? UIButton }
        quickOptionsView.addSubview(toneStackView)
        
        NSLayoutConstraint.activate([
            quickLabel.topAnchor.constraint(equalTo: quickOptionsView.topAnchor, constant: 20),
            quickLabel.leadingAnchor.constraint(equalTo: quickOptionsView.leadingAnchor, constant: 20),
            quickLabel.trailingAnchor.constraint(equalTo: quickOptionsView.trailingAnchor, constant: -20),
            
            personalitySubLabel.topAnchor.constraint(equalTo: quickLabel.bottomAnchor, constant: 16),
            personalitySubLabel.leadingAnchor.constraint(equalTo: quickOptionsView.leadingAnchor, constant: 20),
            
            personalityStackView.topAnchor.constraint(equalTo: personalitySubLabel.bottomAnchor, constant: 8),
            personalityStackView.leadingAnchor.constraint(equalTo: quickOptionsView.leadingAnchor, constant: 20),
            personalityStackView.trailingAnchor.constraint(equalTo: quickOptionsView.trailingAnchor, constant: -20),
            
            musicSubLabel.topAnchor.constraint(equalTo: personalityStackView.bottomAnchor, constant: 16),
            musicSubLabel.leadingAnchor.constraint(equalTo: quickOptionsView.leadingAnchor, constant: 20),
            
            musicStackView.topAnchor.constraint(equalTo: musicSubLabel.bottomAnchor, constant: 8),
            musicStackView.leadingAnchor.constraint(equalTo: quickOptionsView.leadingAnchor, constant: 20),
            musicStackView.trailingAnchor.constraint(equalTo: quickOptionsView.trailingAnchor, constant: -20),
            
            toneSubLabel.topAnchor.constraint(equalTo: musicStackView.bottomAnchor, constant: 16),
            toneSubLabel.leadingAnchor.constraint(equalTo: quickOptionsView.leadingAnchor, constant: 20),
            
            toneStackView.topAnchor.constraint(equalTo: toneSubLabel.bottomAnchor, constant: 8),
            toneStackView.leadingAnchor.constraint(equalTo: quickOptionsView.leadingAnchor, constant: 20),
            toneStackView.trailingAnchor.constraint(equalTo: quickOptionsView.trailingAnchor, constant: -20),
            toneStackView.bottomAnchor.constraint(equalTo: quickOptionsView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // HeaderView
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            // PersonalityCardView
            personalityCardView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            personalityCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            personalityCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // QuickOptionsView
            quickOptionsView.topAnchor.constraint(equalTo: personalityCardView.bottomAnchor, constant: 20),
            quickOptionsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            quickOptionsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            quickOptionsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }
    
    // MARK: - Helper Methods
    
    private func createSectionLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = UIDesignSystem.Colors.primaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func createSubLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func createButtonStackView(items: [String], tag: Int) -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 2줄로 배치하기 위한 컨테이너
        let containerStack = UIStackView()
        containerStack.axis = .vertical
        containerStack.spacing = 8
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        
        var currentRowStack: UIStackView?
        
        for (index, item) in items.enumerated() {
            if index % 3 == 0 {
                // 새 줄 시작
                currentRowStack = UIStackView()
                currentRowStack?.axis = .horizontal
                currentRowStack?.distribution = .fillEqually
                currentRowStack?.spacing = 8
                currentRowStack?.translatesAutoresizingMaskIntoConstraints = false
                containerStack.addArrangedSubview(currentRowStack!)
            }
            
            let button = createSelectionButton(title: item, tag: tag + index)
            currentRowStack?.addArrangedSubview(button)
        }
        
        return containerStack
    }
    
    private func createSelectionButton(title: String, tag: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.tag = tag
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
        button.setTitleColor(.white, for: .selected)
        button.backgroundColor = UIColor.systemGray6
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        button.addTarget(self, action: #selector(quickOptionButtonTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return button
    }
    
    private func setupActions() {
        nameTextField.addTarget(self, action: #selector(textFieldChanged(_:)), for: .editingChanged)
        ageTextField.addTarget(self, action: #selector(textFieldChanged(_:)), for: .editingChanged)
    }
    
    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        // 화면 탭으로 키보드 닫기
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    
    @objc private func quickOptionButtonTapped(_ sender: UIButton) {
        sender.isSelected.toggle()
        
        if sender.isSelected {
            sender.backgroundColor = UIDesignSystem.Colors.primary
            sender.layer.borderColor = UIDesignSystem.Colors.primary.cgColor
        } else {
            sender.backgroundColor = UIColor.systemGray6
            sender.layer.borderColor = UIColor.systemGray4.cgColor
        }
        
        updateUserInfoFromSelections()
    }
    
    @objc private func textFieldChanged(_ textField: UITextField) {
        updateUserInfoFromFields()
    }
    
    @objc private func saveButtonTapped() {
        saveUserData()
        onInfoUpdated?(userInfo)
        
        let alert = UIAlertController(
            title: "저장 완료",
            message: "기본 정보가 성공적으로 저장되었습니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.scrollIndicatorInsets.bottom = keyboardHeight
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.scrollIndicatorInsets.bottom = 0
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Data Management
    
    private func loadUserData() {
        nameTextField.text = userInfo.nickname
        ageTextField.text = userInfo.age != nil ? "\(userInfo.age!)" : ""
        personalityTextView.text = userInfo.personalityDescription
        updatePlaceholderVisibility()
        
        // 빠른 선택 옵션들 복원
        restoreQuickSelections()
    }
    
    private func saveUserData() {
        updateUserInfoFromFields()
        updateUserInfoFromSelections()
        userInfo.saveToUserDefaults()
    }
    
    private func updateUserInfoFromFields() {
        userInfo.nickname = nameTextField.text ?? ""
        userInfo.age = Int(ageTextField.text ?? "")
        userInfo.personalityDescription = personalityTextView.text ?? ""
    }
    
    private func updateUserInfoFromSelections() {
        // 선택된 성격 특성들
        userInfo.personalityTraits = personalityButtons.filter { $0.isSelected }.compactMap { $0.title(for: .normal) }
        
        // 선택된 음악 취향들
        userInfo.musicPreferences = musicPreferenceButtons.filter { $0.isSelected }.compactMap {
            guard let title = $0.title(for: .normal) else { return nil }
            return MusicStyle(rawValue: title) ?? .other
        }
        
        // 선택된 대화 스타일들
        userInfo.conversationTones = tonePreferenceButtons.filter { $0.isSelected }.compactMap { $0.title(for: .normal) }
    }
    
    private func restoreQuickSelections() {
        // 성격 특성 복원
        for button in personalityButtons {
            if let title = button.title(for: .normal), userInfo.personalityTraits.contains(title) {
                button.isSelected = true
                button.backgroundColor = UIDesignSystem.Colors.primary
                button.layer.borderColor = UIDesignSystem.Colors.primary.cgColor
            }
        }
        
        // 음악 취향 복원
        for button in musicPreferenceButtons {
            if let title = button.title(for: .normal) {
                let musicStyle = MusicStyle(rawValue: title) ?? .other
                if userInfo.musicPreferences.contains(musicStyle) {
                    button.isSelected = true
                    button.backgroundColor = UIDesignSystem.Colors.primary
                    button.layer.borderColor = UIDesignSystem.Colors.primary.cgColor
                }
            }
        }
        
        // 대화 스타일 복원
        for button in tonePreferenceButtons {
            if let title = button.title(for: .normal), userInfo.conversationTones.contains(title) {
                button.isSelected = true
                button.backgroundColor = UIDesignSystem.Colors.primary
                button.layer.borderColor = UIDesignSystem.Colors.primary.cgColor
            }
        }
    }
    
    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !personalityTextView.text.isEmpty
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITextViewDelegate

extension UserBasicInfoViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
        updateUserInfoFromFields()
    }
}
