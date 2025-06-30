import UIKit

class TodaysFortuneViewController: UIViewController {
    
    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "🔮 오늘의 운세"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        label.text = formatter.string(from: Date())
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .systemGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 사용자 정보 입력
    private let userInfoCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let ageInfoLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let birthDatePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.locale = Locale(identifier: "ko_KR")
        picker.maximumDate = Date()
        picker.minimumDate = Calendar.current.date(byAdding: .year, value: -100, to: Date())
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()
    
    private let genderSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["남성", "여성", "기타"])
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let getFortuneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("✨ 오늘의 운세 보기", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = UIDesignSystem.Colors.primary
        button.tintColor = .white
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // 운세 결과 표시
    private let fortuneResultView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let zodiacInfoLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let fortuneStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("📱 운세 공유하기", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = UIDesignSystem.Colors.success
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Data
    private var currentFortune: DailyFortune?
    private let fortuneGenerator = FortuneGenerator()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        loadUserPreferences()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground
        navigationItem.title = "오늘의 운세"
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(dateLabel)
        
        contentView.addSubview(userInfoCardView)
        setupUserInfoCard()
        
        contentView.addSubview(fortuneResultView)
        setupFortuneResultView()
        
        contentView.addSubview(shareButton)
    }
    
    private func setupUserInfoCard() {
        let birthDateLabel = createLabel(text: "🎂 생년월일", font: .boldSystemFont(ofSize: 16))
        let genderLabel = createLabel(text: "👤 성별", font: .boldSystemFont(ofSize: 16))
        
        userInfoCardView.addSubview(birthDateLabel)
        userInfoCardView.addSubview(birthDatePicker)
        userInfoCardView.addSubview(ageInfoLabel)
        userInfoCardView.addSubview(genderLabel)
        userInfoCardView.addSubview(genderSegmentedControl)
        userInfoCardView.addSubview(getFortuneButton)
        
        // 생년월일 변경 시 나이 업데이트
        birthDatePicker.addTarget(self, action: #selector(birthDateChanged), for: .valueChanged)
        
        NSLayoutConstraint.activate([
            birthDateLabel.topAnchor.constraint(equalTo: userInfoCardView.topAnchor, constant: 20),
            birthDateLabel.leadingAnchor.constraint(equalTo: userInfoCardView.leadingAnchor, constant: 20),
            
            birthDatePicker.topAnchor.constraint(equalTo: birthDateLabel.bottomAnchor, constant: 8),
            birthDatePicker.leadingAnchor.constraint(equalTo: userInfoCardView.leadingAnchor, constant: 20),
            birthDatePicker.trailingAnchor.constraint(equalTo: userInfoCardView.trailingAnchor, constant: -20),
            
            ageInfoLabel.topAnchor.constraint(equalTo: birthDatePicker.bottomAnchor, constant: 8),
            ageInfoLabel.leadingAnchor.constraint(equalTo: userInfoCardView.leadingAnchor, constant: 20),
            ageInfoLabel.trailingAnchor.constraint(equalTo: userInfoCardView.trailingAnchor, constant: -20),
            
            genderLabel.topAnchor.constraint(equalTo: ageInfoLabel.bottomAnchor, constant: 16),
            genderLabel.leadingAnchor.constraint(equalTo: userInfoCardView.leadingAnchor, constant: 20),
            
            genderSegmentedControl.topAnchor.constraint(equalTo: genderLabel.bottomAnchor, constant: 8),
            genderSegmentedControl.leadingAnchor.constraint(equalTo: userInfoCardView.leadingAnchor, constant: 20),
            genderSegmentedControl.trailingAnchor.constraint(equalTo: userInfoCardView.trailingAnchor, constant: -20),
            
            getFortuneButton.topAnchor.constraint(equalTo: genderSegmentedControl.bottomAnchor, constant: 20),
            getFortuneButton.leadingAnchor.constraint(equalTo: userInfoCardView.leadingAnchor, constant: 20),
            getFortuneButton.trailingAnchor.constraint(equalTo: userInfoCardView.trailingAnchor, constant: -20),
            getFortuneButton.bottomAnchor.constraint(equalTo: userInfoCardView.bottomAnchor, constant: -20),
            getFortuneButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // 초기 나이 설정
        updateAgeInfo()
    }
    
    @objc private func birthDateChanged() {
        updateAgeInfo()
    }
    
    private func updateAgeInfo() {
        let age = calculateAge(from: birthDatePicker.date)
        let ageGroup = getAgeGroup(age: age)
        ageInfoLabel.text = "만 \(age)세 (\(ageGroup))"
    }
    
    private func calculateAge(from birthDate: Date) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
        return ageComponents.year ?? 0
    }
    
    private func getAgeGroup(age: Int) -> String {
        switch age {
        case 0...12:
            return "어린이"
        case 13...19:
            return "청소년"
        case 20...30:
            return "청년"
        case 31...59:
            return "중년"
        case 60...:
            return "시니어"
        default:
            return "성인"
        }
    }
    
    private func setupFortuneResultView() {
        fortuneResultView.addSubview(zodiacInfoLabel)
        fortuneResultView.addSubview(fortuneStackView)
        
        NSLayoutConstraint.activate([
            zodiacInfoLabel.topAnchor.constraint(equalTo: fortuneResultView.topAnchor, constant: 20),
            zodiacInfoLabel.leadingAnchor.constraint(equalTo: fortuneResultView.leadingAnchor, constant: 20),
            zodiacInfoLabel.trailingAnchor.constraint(equalTo: fortuneResultView.trailingAnchor, constant: -20),
            
            fortuneStackView.topAnchor.constraint(equalTo: zodiacInfoLabel.bottomAnchor, constant: 20),
            fortuneStackView.leadingAnchor.constraint(equalTo: fortuneResultView.leadingAnchor, constant: 20),
            fortuneStackView.trailingAnchor.constraint(equalTo: fortuneResultView.trailingAnchor, constant: -20),
            fortuneStackView.bottomAnchor.constraint(equalTo: fortuneResultView.bottomAnchor, constant: -20)
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
            headerView.heightAnchor.constraint(equalToConstant: 120),
            
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            dateLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            dateLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            
            // UserInfoCardView
            userInfoCardView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 20),
            userInfoCardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            userInfoCardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // FortuneResultView
            fortuneResultView.topAnchor.constraint(equalTo: userInfoCardView.bottomAnchor, constant: 20),
            fortuneResultView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            fortuneResultView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // ShareButton
            shareButton.topAnchor.constraint(equalTo: fortuneResultView.bottomAnchor, constant: 20),
            shareButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            shareButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            shareButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            shareButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupActions() {
        getFortuneButton.addTarget(self, action: #selector(getFortuneButtonTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
    }
    
    private func loadUserPreferences() {
        if let savedBirthDate = UserDefaults.standard.object(forKey: "userBirthDate") as? Date {
            birthDatePicker.date = savedBirthDate
        }
        
        let savedGender = UserDefaults.standard.integer(forKey: "userGender")
        genderSegmentedControl.selectedSegmentIndex = savedGender
    }
    
    private func saveUserPreferences() {
        UserDefaults.standard.set(birthDatePicker.date, forKey: "userBirthDate")
        UserDefaults.standard.set(genderSegmentedControl.selectedSegmentIndex, forKey: "userGender")
    }
    
    // MARK: - Actions
    @objc private func getFortuneButtonTapped() {
        saveUserPreferences()
        
        let gender = genderSegmentedControl.selectedSegmentIndex
        let fortune = fortuneGenerator.generateDailyFortune(for: Date(), birthDate: birthDatePicker.date, gender: gender)
        
        currentFortune = fortune
        displayFortune(fortune)
        
        UIView.animate(withDuration: 0.5, delay: 0.2, options: .curveEaseInOut) {
            self.fortuneResultView.isHidden = false
            self.shareButton.isHidden = false
            self.fortuneResultView.alpha = 1.0
            self.shareButton.alpha = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.scrollView.scrollRectToVisible(self.fortuneResultView.frame, animated: true)
        }
    }
    
    @objc private func shareButtonTapped() {
        guard let fortune = currentFortune else { return }
        
        let shareText = generateShareText(fortune: fortune)
        let activityController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        
        present(activityController, animated: true)
    }
    
    // MARK: - Enhanced Fortune Display
    private func displayFortune(_ fortune: DailyFortune) {
        fortuneStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let age = calculateAge(from: birthDatePicker.date)
        let ageGroup = getAgeGroup(age: age)
        
        // 개선된 별자리 정보 표시
        zodiacInfoLabel.text = """
        \(fortune.zodiacSign) • 만 \(age)세 (\(ageGroup))
        """
        
        // 나이별 맞춤 운세 카드들
        let fortuneCards = [
            ("🌟 총운 (\(ageGroup) 맞춤)", fortune.generalFortune),
            ("💖 애정운", fortune.loveFortune),
            ("💼 직업운", fortune.workFortune),
            ("💪 건강운", fortune.healthFortune),
            ("💰 금전운", "돈 관리에 신중함이 필요한 시기입니다.")
        ]
        
        for (title, content) in fortuneCards {
            let card = createEnhancedFortuneCard(title: title, content: content)
            fortuneStackView.addArrangedSubview(card)
        }
        
        // 별자리별 특성 정보
        let traitInfo = "✨ \(fortune.zodiacSign) 특성: 오늘은 특별한 에너지가 흐르는 날입니다."
        let traitCard = createEnhancedFortuneCard(title: "🔮 별자리 특성", content: traitInfo)
        traitCard.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.1)
        fortuneStackView.addArrangedSubview(traitCard)
        
        // 행운 정보 (개선된 버전)
        let luckyInfo = """
        🎨 행운의 색: \(fortune.luckyColor)
        🔢 행운의 숫자: \(fortune.luckyNumber)
        💎 행운의 아이템: \(fortune.luckyItem)
        ⭐ 행운 지수: \(generateLuckyScore())%
        """
        let luckyCard = createEnhancedFortuneCard(title: "🍀 오늘의 행운 정보", content: luckyInfo)
        luckyCard.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        fortuneStackView.addArrangedSubview(luckyCard)
        
        // 나이별 맞춤 조언
        let adviceContent = generateAdviceForAge(ageGroup: ageGroup)
        let adviceCard = createEnhancedFortuneCard(title: "💡 \(ageGroup)을 위한 조언", content: adviceContent)
        adviceCard.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.1)
        fortuneStackView.addArrangedSubview(adviceCard)
        
        // 개인 맞춤 메시지
        let messageContent = generatePositiveMessage()
        let messageCard = createEnhancedFortuneCard(title: "💝 당신에게 전하는 메시지", content: messageContent)
        messageCard.backgroundColor = UIColor.systemPink.withAlphaComponent(0.1)
        fortuneStackView.addArrangedSubview(messageCard)
        
        // 오늘의 추천 활동
        let activityCard = createEnhancedFortuneCard(title: "🎯 오늘의 추천 활동", content: generateTodaysActivity(ageGroup: ageGroup))
        activityCard.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.1)
        fortuneStackView.addArrangedSubview(activityCard)
    }
    
    private func generateLuckyScore() -> Int {
        return Int.random(in: 75...95) // 긍정적인 점수 범위
    }
    
    private func generateTodaysActivity(ageGroup: String) -> String {
        let activities: [String: [String]] = [
            "어린이": ["친구들과 재미있게 놀기", "새로운 책 읽어보기", "그림 그리기나 만들기", "가족과 함께 시간 보내기"],
            "청소년": ["좋아하는 음악 듣기", "친구들과 대화하기", "새로운 취미 찾아보기", "운동이나 스포츠 하기"],
            "청년": ["자기계발 도서 읽기", "새로운 사람들과 네트워킹", "운동이나 헬스장 가기", "여행 계획 세우기"],
            "중년": ["가족과 함께하는 시간", "건강 관리 활동", "새로운 취미 개발", "재테크 공부하기"],
            "시니어": ["산책이나 가벼운 운동", "친구들과 만남", "문화 활동 참여", "손자녀와 시간 보내기"],
            "성인": ["운동이나 건강 관리", "독서나 학습 활동", "사람들과 만남", "취미 활동 즐기기"]
        ]
        
        let activityList = activities[ageGroup] ?? activities["성인"]!
        return activityList.randomElement() ?? "긍정적인 마음으로 하루 보내기"
    }
    
    private func createFortuneCard(title: String, content: String) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .secondarySystemBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        cardView.layer.shadowOpacity = 0.1
        
        let titleLabel = createLabel(text: title, font: .boldSystemFont(ofSize: 16))
        titleLabel.textColor = UIDesignSystem.Colors.primary
        
        let contentLabel = createLabel(text: content, font: .systemFont(ofSize: 14))
        contentLabel.numberOfLines = 0
        contentLabel.textColor = .label
        
        cardView.addSubview(titleLabel)
        cardView.addSubview(contentLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            contentLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            contentLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
        
        return cardView
    }
    
    private func createEnhancedFortuneCard(title: String, content: String) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOpacity = 0.12
        
        // 제목 부분
        let titleContainer = UIView()
        titleContainer.backgroundColor = UIColor.systemGray6
        titleContainer.layer.cornerRadius = 12
        titleContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = createLabel(text: title, font: .boldSystemFont(ofSize: 17))
        titleLabel.textColor = UIDesignSystem.Colors.primary
        titleLabel.textAlignment = .left
        
        titleContainer.addSubview(titleLabel)
        
        // 내용 부분
        let contentLabel = createLabel(text: content, font: .systemFont(ofSize: 15, weight: .medium))
        contentLabel.numberOfLines = 0
        contentLabel.textColor = .label
        contentLabel.lineBreakMode = .byWordWrapping
        
        // 장식용 분리선
        let separatorView = UIView()
        separatorView.backgroundColor = UIColor.systemGray4
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        
        cardView.addSubview(titleContainer)
        cardView.addSubview(separatorView)
        cardView.addSubview(contentLabel)
        
        NSLayoutConstraint.activate([
            // 제목 컨테이너
            titleContainer.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            titleContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            // 제목 라벨
            titleLabel.topAnchor.constraint(equalTo: titleContainer.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(equalTo: titleContainer.bottomAnchor, constant: -8),
            
            // 분리선
            separatorView.topAnchor.constraint(equalTo: titleContainer.bottomAnchor, constant: 12),
            separatorView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            separatorView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            
            // 내용 라벨
            contentLabel.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 12),
            contentLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            contentLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            contentLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20)
        ])
        
        return cardView
    }
    
    private func createLabel(text: String, font: UIFont) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func generateShareText(fortune: DailyFortune) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        let dateString = formatter.string(from: Date())
        
        return """
        🔮 \(dateString) 오늘의 운세
        
        \(fortune.zodiacSign)
        
        🌟 총운: \(fortune.generalFortune)
        💖 애정운: \(fortune.loveFortune)
        💼 직업운: \(fortune.workFortune)
        
        🍀 행운의 색: \(fortune.luckyColor)
        🔢 행운의 숫자: \(fortune.luckyNumber)
        💎 행운의 아이템: \(fortune.luckyItem)
        
        #오늘의운세 #DeepSleep
        """
    }
    
    private func generateAdviceForAge(ageGroup: String) -> String {
        let adviceMap: [String: [String]] = [
            "어린이": [
                "호기심을 가지고 새로운 것을 탐험해보세요.",
                "친구들과 함께 즐거운 시간을 보내세요.",
                "부모님의 말씀을 잘 듣고 공부도 열심히 하세요.",
                "책을 읽으면서 상상력을 키워보세요."
            ],
            "청소년": [
                "자신만의 꿈과 목표를 설정해보세요.",
                "친구들과의 우정을 소중히 여기세요.",
                "새로운 취미나 관심사를 찾아보세요.",
                "어려움이 있어도 포기하지 말고 도전하세요."
            ],
            "청년": [
                "인생의 방향성을 고민하며 성장하세요.",
                "다양한 경험을 통해 자신을 발견하세요.",
                "건강한 인간관계를 형성하세요.",
                "실패를 두려워하지 말고 도전하세요."
            ],
            "중년": [
                "가족과의 시간을 소중히 여기세요.",
                "건강 관리에 더욱 신경 쓰세요.",
                "새로운 목표를 설정하여 활력을 찾으세요.",
                "경험을 바탕으로 지혜롭게 판단하세요."
            ],
            "시니어": [
                "건강을 최우선으로 생각하세요.",
                "가족, 친구들과의 소중한 시간을 보내세요.",
                "새로운 취미나 활동으로 활기를 유지하세요.",
                "젊은 세대에게 지혜를 나누어주세요."
            ],
            "성인": [
                "일과 생활의 균형을 맞추세요.",
                "꾸준한 자기계발에 투자하세요.",
                "건강한 라이프스타일을 유지하세요.",
                "주변 사람들과의 관계를 소중히 하세요."
            ]
        ]
        
        let adviceList = adviceMap[ageGroup] ?? adviceMap["성인"]!
        return adviceList.randomElement() ?? "긍정적인 마음가짐으로 하루를 시작하세요."
    }
    
    private func generatePositiveMessage() -> String {
        let messages = [
            "오늘도 당신의 밝은 미소가 세상을 아름답게 만듭니다.",
            "작은 것에서 기쁨을 찾는 하루가 되길 바랍니다.",
            "당신의 따뜻한 마음이 주변을 행복하게 합니다.",
            "오늘 하루도 당신답게 멋지게 보내세요.",
            "긍정적인 에너지로 가득한 하루가 되기를 바랍니다.",
            "당신이 있어 세상이 더 밝아집니다.",
            "오늘도 새로운 가능성이 당신을 기다리고 있습니다.",
            "당신의 꿈과 희망이 현실이 되기를 응원합니다."
        ]
        
        return messages.randomElement() ?? "행복한 하루 되세요!"
    }
} 