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
        view.backgroundColor = UIDesignSystem.Colors.cardBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false

        // 카드 톤 일관화: 보더/섀도우 적용
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.4).cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1

        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "🔮 오늘의 운세 🔮"
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
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // 사용자 정보 입력
    private let userInfoCardView: UIView = {
        let view = UIView()
        view.backgroundColor = UIDesignSystem.Colors.cardBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        view.translatesAutoresizingMaskIntoConstraints = false

        // 미세한 테두리 추가
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.4).cgColor

        return view
    }()

    private let ageInfoLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIDesignSystem.Colors.primary
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let birthDatePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = Locale(identifier: "ko_KR")
        picker.maximumDate = Date()
        picker.minimumDate = Calendar.current.date(byAdding: .year, value: -100, to: Date())
        picker.translatesAutoresizingMaskIntoConstraints = false

        // 더 예쁜 스타일링
                picker.backgroundColor = UIColor.white
                picker.layer.cornerRadius = 12
                picker.clipsToBounds = true
                picker.tintColor = UIColor.systemBlue

        return picker
    }()

    private let genderSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["남성", "여성", "기타"])
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false

        // 더 예쁜 스타일링
        control.backgroundColor = UIColor.white
        control.layer.borderWidth = 1
        control.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.4).cgColor
        control.selectedSegmentTintColor = UIColor.white
        control.setTitleTextAttributes([.foregroundColor: UIColor.label], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor.systemBlue], for: .selected)
        control.layer.cornerRadius = 8

        return control
    }()

    private let getFortuneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("✨ 오늘의 운세 보기", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.tintColor = UIColor.systemBlue
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false

        // 화이트 카드 톤 버튼
        button.backgroundColor = UIColor.white
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.4).cgColor
        button.setTitleColor(UIColor.systemBlue, for: .normal)

        // 그림자 효과
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        button.layer.shadowOpacity = 0.1

        return button
    }()

    // 운세 결과 표시
    private let fortuneResultView: UIView = {
        let view = UIView()
        view.backgroundColor = UIDesignSystem.Colors.cardBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        view.isHidden = true
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray4.withAlphaComponent(0.4).cgColor
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

    private let disclaimerLabel: UILabel = {
        let label = UILabel()
        label.text = "⚠️ 본 콘텐츠는 엔터테인먼트 목적이며, 전문적 조언이 아닙니다. 재미로만 봐주세요."
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIDesignSystem.Colors.secondaryText
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Data
    private var currentFortune: DailyFortune?
    private let fortuneGenerator = FortuneGenerator()

    // MARK: - Fortune Data Collections
    private let ageGroupAdvice: [String: [String]] = [
        "어린이": [
            "호기심을 가지고 새로운 것을 탐험해보세요.",
            "친구들과 함께 즐거운 시간을 보내세요.",
            "부모님의 말씀을 잘 듣고 공부도 열심히 하세요.",
            "책을 읽으면서 상상력을 키워보세요.",
            "운동을 통해 건강한 몸을 만들어가세요.",
            "예의 바른 말과 행동을 실천해보세요.",
            "새로운 친구들과 사이좋게 지내세요.",
            "창의적인 놀이를 통해 재능을 발견해보세요.",
            "자연을 관찰하며 호기심을 키워보세요.",
            "가족과 함께하는 시간을 소중히 여기세요.",
            "규칙적인 생활 습관을 만들어보세요.",
            "어려운 일이 있어도 용기를 내보세요.",
            "다른 사람을 도와주는 기쁨을 느껴보세요.",
            "새로운 것을 배우는 즐거움을 찾아보세요.",
            "건강한 음식을 골고루 먹는 습관을 기르세요.",
            "충분한 잠으로 성장하는 시간을 가지세요.",
            "웃음이 가득한 하루를 만들어보세요.",
            "꿈을 크게 가지고 상상력을 펼쳐보세요.",
            "감사하는 마음을 표현해보세요.",
            "작은 것에도 기쁨을 찾아보세요.",
            "정리정돈 습관을 통해 책임감을 기르세요.",
            "다양한 색깔로 그림을 그려보세요.",
            "음악을 들으며 감성을 키워보세요.",
            "동물과 식물을 사랑하는 마음을 가지세요.",
            "새로운 놀이를 만들어보는 창의성을 발휘하세요.",
            "친구들과 함께 협력하는 법을 배워보세요.",
            "실패해도 다시 도전하는 용기를 가지세요.",
            "어른들께 예쁜 말로 인사드리세요.",
            "깨끗이 손을 씻는 좋은 습관을 유지하세요.",
            "모험심을 가지고 새로운 경험을 해보세요.",
            "친구의 마음을 이해하려고 노력해보세요.",
            "자신만의 특별한 재능을 찾아보세요.",
            "매일 조금씩 새로운 것을 배워가세요.",
            "건강한 간식으로 몸을 챙겨주세요.",
            "밝은 웃음으로 주변을 환하게 만들어보세요.",
            "부모님께 사랑한다는 말을 전해보세요.",
            "스스로 할 수 있는 일들을 찾아 실천해보세요.",
            "친구들과 나누는 기쁨을 경험해보세요.",
            "꾸준히 독서하는 습관을 만들어보세요.",
            "자연 속에서 뛰어놀며 건강함을 키우세요."
        ],

        "청소년": [
            "자신만의 꿈과 목표를 설정해보세요.",
            "친구들과의 우정을 소중히 여기세요.",
            "새로운 취미나 관심사를 찾아보세요.",
            "어려움이 있어도 포기하지 말고 도전하세요.",
            "부모님과 선생님의 조언에 귀 기울여보세요.",
            "건강한 생활 습관을 만들어가세요.",
            "독서를 통해 지식의 폭을 넓혀보세요.",
            "자신의 감정을 건전하게 표현하는 법을 배우세요.",
            "다양한 사람들과 소통하는 능력을 기르세요.",
            "미래를 위한 준비를 차근차근 해나가세요.",
            "자신만의 개성을 발견하고 키워보세요.",
            "스트레스를 건전하게 해소하는 방법을 찾으세요.",
            "팀워크의 중요성을 배우고 실천해보세요.",
            "리더십을 발휘할 수 있는 기회를 만들어보세요.",
            "창의적인 사고력을 기르는 활동을 해보세요.",
            "봉사활동을 통해 사회에 기여하는 기쁨을 느껴보세요.",
            "자신의 강점과 약점을 객관적으로 파악해보세요.",
            "시간 관리 능력을 향상시켜보세요.",
            "다른 문화와 언어에 관심을 가져보세요.",
            "자신의 가치관을 정립해나가세요.",
            "건전한 경쟁 의식을 가지고 성장하세요.",
            "예술 활동을 통해 감성을 풍부하게 하세요.",
            "운동을 통해 체력과 정신력을 단련하세요.",
            "진로에 대해 진지하게 고민해보는 시간을 가지세요.",
            "어른들의 경험담에서 지혜를 얻어보세요.",
            "자신만의 학습법을 찾아 실천해보세요.",
            "실수를 통해 배우는 자세를 가지세요.",
            "긍정적인 사고방식을 기르도록 노력하세요.",
            "다양한 경험을 통해 견문을 넓혀보세요.",
            "자신의 꿈을 위해 꾸준히 노력하세요.",
            "친구들과의 건전한 관계를 유지하세요.",
            "자기 주도적인 학습 능력을 기르세요.",
            "멘토를 찾아 조언을 구해보세요.",
            "인내심을 기르는 연습을 해보세요.",
            "자신만의 철학을 만들어가세요.",
            "사회 이슈에 관심을 가지고 생각해보세요.",
            "자립심을 기르는 기회를 만들어보세요.",
            "새로운 도전을 두려워하지 마세요.",
            "자신의 감정을 솔직하게 표현하는 용기를 가지세요.",
            "미래의 자신을 위한 투자를 시작하세요."
        ],

        "청년": [
            "인생의 방향성을 고민하며 성장하세요.",
            "다양한 경험을 통해 자신을 발견하세요.",
            "건강한 인간관계를 형성하세요.",
            "실패를 두려워하지 말고 도전하세요.",
            "자기계발에 꾸준히 투자하세요.",
            "인생의 목표를 명확히 설정하세요.",
            "전문성을 기르는데 집중하세요.",
            "네트워킹의 중요성을 인식하고 실천하세요.",
            "균형 잡힌 라이프스타일을 추구하세요.",
            "경제적 독립을 위한 계획을 세우세요.",
            "새로운 기술과 트렌드에 관심을 가지세요.",
            "창업이나 사업 아이디어를 고민해보세요.",
            "글로벌 역량을 기르는 노력을 하세요.",
            "멘토와 멘티 관계를 적극 활용하세요.",
            "자신만의 브랜드를 만들어가세요.",
            "투자와 재테크에 대해 공부해보세요.",
            "사회적 책임을 의식하고 실천하세요.",
            "창의적 문제해결 능력을 기르세요.",
            "리더십과 팔로워십을 균형있게 발전시키세요.",
            "다문화 감수성을 기르는 노력을 하세요.",
            "지속적인 학습 습관을 만드세요.",
            "스트레스 관리 방법을 터득하세요.",
            "자신의 강점을 최대한 활용하세요.",
            "새로운 산업과 분야에 관심을 가져보세요.",
            "개인 브랜딩을 위한 노력을 시작하세요.",
            "건강한 생활 패턴을 유지하세요.",
            "인생의 롤모델을 찾아보세요.",
            "자신만의 철학과 가치관을 정립하세요.",
            "위험을 감수하는 용기를 기르세요.",
            "타인의 의견을 존중하는 자세를 가지세요.",
            "자기 반성과 성찰의 시간을 가지세요.",
            "변화에 적응하는 유연성을 기르세요.",
            "진정성 있는 소통 능력을 개발하세요.",
            "자신만의 경쟁력을 찾아 키우세요.",
            "사회 문제에 관심을 가지고 참여하세요.",
            "장기적인 비전을 가지고 행동하세요.",
            "다양한 분야의 사람들과 교류하세요.",
            "자신의 한계를 뛰어넘는 도전을 하세요.",
            "지혜로운 선택을 위한 판단력을 기르세요.",
            "미래 사회에 필요한 역량을 개발하세요."
        ],

        "중년": [
            "가족과의 시간을 소중히 여기세요.",
            "건강 관리에 더욱 신경 쓰세요.",
            "새로운 목표를 설정하여 활력을 찾으세요.",
            "경험을 바탕으로 지혜롭게 판단하세요.",
            "후배들에게 멘토 역할을 해보세요.",
            "인생의 두 번째 막을 준비하세요.",
            "자녀 교육에 현명함을 발휘하세요.",
            "부모님께 더 많은 관심을 기울이세요.",
            "자기만족보다는 가족의 행복을 우선하세요.",
            "건전한 취미 활동을 통해 스트레스를 해소하세요.",
            "동년배 친구들과의 모임을 소중히 하세요.",
            "새로운 기술 습득에 도전해보세요.",
            "사회적 책임을 더욱 진중하게 받아들이세요.",
            "정신적, 육체적 건강의 균형을 맞추세요.",
            "자산 관리와 노후 준비를 체계적으로 하세요.",
            "젊은 세대와의 소통 방법을 익혀보세요.",
            "인생의 우선순위를 재점검해보세요.",
            "지역사회 활동에 적극 참여해보세요.",
            "자신만의 전문분야를 더욱 깊이 파세요.",
            "가족 여행을 통해 소중한 추억을 만드세요.",
            "건강한 식습관을 만들어가세요.",
            "정기적인 건강검진을 받는 습관을 만드세요.",
            "스마트폰과 디지털 기기 활용법을 배워보세요.",
            "봉사활동으로 사회에 기여하는 기쁨을 느껴보세요.",
            "자녀의 독립을 준비하고 지원하세요.",
            "배우자와의 관계를 더욱 돈독히 하세요.",
            "인생의 황혼기를 위한 계획을 세우세요.",
            "젊었을 때 못 해본 일들을 시작해보세요.",
            "건전한 투자로 경제적 안정을 도모하세요.",
            "문화 활동을 통해 삶의 질을 높이세요.",
            "자신의 인생 스토리를 정리해보세요.",
            "후배들에게 경험담을 전수해주세요.",
            "건강한 인간관계를 유지하고 확장하세요.",
            "새로운 분야에 대한 학습 의욕을 가지세요.",
            "가족의 건강과 행복을 최우선으로 생각하세요.",
            "자신만의 인생 철학을 완성해가세요.",
            "사회 경험을 바탕으로 현명한 조언을 해주세요.",
            "변화하는 세상에 적응하려고 노력하세요.",
            "내면의 평화와 안정을 추구하세요.",
            "다음 세대를 위한 기반을 마련하세요."
        ],

        "시니어": [
            "건강을 최우선으로 생각하세요.",
            "가족, 친구들과의 소중한 시간을 보내세요.",
            "새로운 취미나 활동으로 활기를 유지하세요.",
            "젊은 세대에게 지혜를 나누어주세요.",
            "규칙적인 운동으로 건강을 유지하세요.",
            "평생학습의 자세로 새로운 것을 배워보세요.",
            "봉사활동을 통해 보람을 찾아보세요.",
            "손자녀들과의 즐거운 시간을 만끽하세요.",
            "동년배 친구들과의 교류를 활발히 하세요.",
            "문화 활동에 적극적으로 참여해보세요.",
            "자서전이나 회고록을 써보세요.",
            "정기적인 건강관리로 질병을 예방하세요.",
            "가족들에게 사랑을 표현하는 것을 잊지 마세요.",
            "여행을 통해 새로운 경험을 쌓아보세요.",
            "독서를 통해 지적 호기심을 충족하세요.",
            "젊은이들의 멘토 역할을 자처해보세요.",
            "전통과 문화를 전승하는 역할을 해보세요.",
            "자연과 함께하는 시간을 늘려보세요.",
            "긍정적인 마음가짐을 유지하세요.",
            "가정의 평화를 위해 지혜를 발휘하세요.",
            "건강한 식단으로 몸을 돌보세요.",
            "충분한 수면으로 건강을 유지하세요.",
            "사회 활동에 꾸준히 참여해보세요.",
            "새로운 사람들과의 만남을 소중히 하세요.",
            "과거의 경험을 현재에 잘 활용하세요.",
            "스트레스를 줄이고 마음의 평안을 찾으세요.",
            "가족 화합을 위해 노력하세요.",
            "건전한 오락 활동으로 즐거움을 찾으세요.",
            "종교 활동이나 명상으로 마음을 다스리세요.",
            "지역 사회의 어르신으로서 역할을 다하세요.",
            "건강한 생활 습관을 꾸준히 유지하세요.",
            "자녀들의 성공을 응원하고 지지해주세요.",
            "과거의 추억을 소중히 간직하세요.",
            "새로운 기술에도 관심을 가져보세요.",
            "동시대를 살아온 사람들과 소통하세요.",
            "인생의 마지막까지 학습하는 자세를 유지하세요.",
            "감사하는 마음으로 하루하루를 살아가세요.",
            "후세에게 좋은 유산을 남기려고 노력하세요.",
            "건강한 노년을 위한 생활 패턴을 만드세요.",
            "인생의 지혜를 다음 세대와 나누세요."
        ],

        "성인": [
            "일과 생활의 균형을 맞추세요.",
            "꾸준한 자기계발에 투자하세요.",
            "건강한 라이프스타일을 유지하세요.",
            "주변 사람들과의 관계를 소중히 하세요.",
            "새로운 도전을 두려워하지 마세요.",
            "재정 관리를 체계적으로 해보세요.",
            "전문성을 기르는데 집중하세요.",
            "네트워킹을 통해 인맥을 넓혀보세요.",
            "스트레스를 건전하게 관리하세요.",
            "목표 설정과 달성에 집중하세요.",
            "창의적 사고력을 기르세요.",
            "리더십 능력을 개발하세요.",
            "글로벌 감각을 기르는 노력을 하세요.",
            "디지털 역량을 강화하세요.",
            "지속적인 학습 습관을 만드세요.",
            "건강한 인간관계를 형성하고 유지하세요.",
            "사회적 책임을 의식하고 실천하세요.",
            "변화에 유연하게 대응하는 능력을 기르세요.",
            "자신만의 경쟁력을 찾아 개발하세요.",
            "효율적인 시간 관리를 실천하세요.",
            "정신적, 육체적 건강을 동시에 챙기세요.",
            "새로운 트렌드와 기술에 관심을 가지세요.",
            "멘토링을 주고받는 관계를 만드세요.",
            "창업이나 부업에 대해 고민해보세요.",
            "투자와 재테크 공부를 시작하세요.",
            "문화 활동으로 삶의 질을 높이세요.",
            "봉사 활동으로 사회에 기여하세요.",
            "가족과의 시간을 의도적으로 늘리세요.",
            "자신의 가치관을 명확히 정립하세요.",
            "실패를 성장의 기회로 받아들이세요.",
            "다양한 분야의 사람들과 교류하세요.",
            "장기적인 인생 계획을 세워보세요.",
            "자기 성찰과 반성의 시간을 가지세요.",
            "전문 분야에서의 전문성을 높이세요.",
            "소통 능력을 지속적으로 개선하세요.",
            "혁신적인 아이디어를 생각해보세요.",
            "인생의 롤모델을 찾아 본받으세요.",
            "건전한 경쟁 의식을 가지세요.",
            "자신만의 브랜드를 만들어가세요.",
            "미래 사회에 필요한 역량을 개발하세요."
        ]
    ]

    private let positiveMessages: [String] = [
        "오늘도 당신의 밝은 미소가 세상을 아름답게 만듭니다.",
        "작은 것에서 기쁨을 찾는 하루가 되길 바랍니다.",
        "당신의 따뜻한 마음이 주변을 행복하게 합니다.",
        "오늘 하루도 당신답게 멋지게 보내세요.",
        "긍정적인 에너지로 가득한 하루가 되기를 바랍니다.",
        "당신이 있어 세상이 더 밝아집니다.",
        "오늘도 새로운 가능성이 당신을 기다리고 있습니다.",
        "당신의 꿈과 희망이 현실이 되기를 응원합니다.",
        "행복은 마음에서 시작됩니다. 오늘도 행복하세요.",
        "당신의 노력이 반드시 결실을 맺을 것입니다.",
        "작은 발걸음이 큰 변화를 만들어낼 것입니다.",
        "오늘도 당신만의 특별함이 빛을 발할 것입니다.",
        "긍정적인 생각이 긍정적인 결과를 만들어냅니다.",
        "당신의 친절함이 누군가에게 희망이 될 것입니다.",
        "오늘 하루도 감사할 일들이 가득할 것입니다.",
        "당신의 용기가 새로운 기회를 열어줄 것입니다.",
        "작은 성취도 큰 기쁨이 될 수 있습니다.",
        "당신의 존재 자체가 누군가에게는 선물입니다.",
        "오늘도 당신의 꿈에 한 걸음 더 가까워지세요.",
        "당신의 밝은 에너지가 모든 것을 가능하게 만듭니다.",
        "새로운 하루, 새로운 기회가 당신을 기다립니다.",
        "당신의 진심이 담긴 노력은 절대 헛되지 않습니다.",
        "오늘도 당신만의 아름다운 이야기를 써내려가세요.",
        "당신의 웃음소리가 세상을 더 따뜻하게 만듭니다.",
        "어려움도 당신의 성장을 위한 소중한 경험입니다.",
        "당신의 꿈을 향한 열정이 모든 장벽을 넘어설 것입니다.",
        "오늘도 당신답게 최선을 다하는 것만으로 충분합니다.",
        "당신의 선한 영향력이 더 넓은 세상으로 퍼져나갈 것입니다.",
        "작은 변화의 시작이 큰 기적을 만들어낼 것입니다.",
        "당신의 마음속 희망의 불씨가 오늘도 타오르길 바랍니다.",
        "실패는 성공으로 가는 또 다른 길일 뿐입니다.",
        "당신의 고유한 매력이 오늘도 빛을 발할 것입니다.",
        "오늘 하루도 당신에게 소중한 깨달음이 있기를 바랍니다.",
        "당신의 인내심이 반드시 아름다운 열매를 맺을 것입니다.",
        "새로운 만남과 경험이 당신을 더욱 풍부하게 만들어줄 것입니다.",
        "당신의 꾸준함이 언젠가는 큰 성공으로 돌아올 것입니다.",
        "오늘도 당신의 마음이 사랑으로 가득 차기를 바랍니다.",
        "당신의 지혜로운 선택이 더 나은 미래를 만들어낼 것입니다.",
        "작은 배려가 큰 감동을 선사할 수 있습니다.",
        "당신의 열정이 모든 불가능을 가능으로 바꿔놓을 것입니다.",
        "오늘 하루도 당신만의 특별한 순간들이 기다리고 있습니다.",
        "당신의 순수한 마음이 세상을 더 아름답게 만듭니다.",
        "실수조차도 당신을 더 강하게 만들어주는 디딤돌입니다.",
        "당신의 진정성이 사람들의 마음을 움직일 것입니다.",
        "오늘도 당신의 꿈을 향해 한 걸음씩 나아가세요.",
        "당신의 밝은 미래가 이미 시작되었습니다.",
        "작은 친절이 누군가의 하루를 완전히 바꿔놓을 수 있습니다.",
        "당신의 노력하는 모습이 누군가에게는 큰 영감이 됩니다.",
        "오늘도 당신답게 솔직하고 진실되게 살아가세요.",
        "당신의 따뜻한 말 한마디가 기적을 만들어낼 것입니다."
    ]

    private let personalizationScores: [String: [String]] = [
        "어린이": ["매우 높음", "높음", "우수", "뛰어남", "탁월함"],
        "청소년": ["매우 높음", "높음", "우수", "뛰어남", "최고"],
        "청년": ["매우 높음", "높음", "우수", "최적", "완벽"],
        "중년": ["매우 높음", "높음", "우수", "안정적", "신뢰할만함"],
        "시니어": ["매우 높음", "높음", "우수", "지혜로움", "완숙함"],
        "성인": ["매우 높음", "높음", "우수", "전문적", "효과적"],
        "기본": ["우수", "높음", "매우 높음"]
    ]

    private let zodiacTraits: [String: String] = [
        "♈ 양자리": "열정적이고 도전적인 에너지",
        "♉ 황소자리": "안정적이고 인내심 강한 모습",
        "♊ 쌍둥이자리": "호기심 많고 소통 능력이 뛰어난 성향",
        "♋ 게자리": "배려심 깊고 가족 중심적인 성격",
        "♌ 사자자리": "리더십이 강하고 자신감 넘치는 모습",
        "♍ 처녀자리": "세심하고 완벽주의적인 성향",
        "♎ 천칭자리": "균형감각과 조화를 중시하는 성격",
        "♏ 전갈자리": "집중력이 강하고 열정적인 모습",
        "♐ 사수자리": "자유롭고 모험심 강한 성향",
        "♑ 염소자리": "책임감이 강하고 목표가 명확한 성격",
        "♒ 물병자리": "독창적이고 미래 지향적인 에너지",
        "♓ 물고기자리": "감성적이고 직관적인 성향"
    ]

    private let ageSpecificTraits: [String: [String]] = [
        "어린이": [
            "순수함과 호기심이 빛을 발하며",
            "새로운 것을 배우는 즐거움이 커지고",
            "친구들과의 우정이 더욱 돈독해지며",
            "상상력과 창의성이 폭발적으로 증가하고",
            "부모님의 사랑을 더욱 깊이 느끼며"
        ],
        "청소년": [
            "꿈과 이상을 향한 열망이 커지고",
            "자아 정체성을 찾아가는 여정에서",
            "친구들과의 깊은 유대감을 형성하며",
            "새로운 도전에 대한 용기가 샘솟고",
            "미래에 대한 희망찬 비전이 생기며"
        ],
        "청년": [
            "인생의 가능성이 무한대로 펼쳐지고",
            "전문성을 키워가는 과정에서",
            "사회적 책임감이 더욱 강화되며",
            "인간관계의 깊이가 더해지고",
            "자신만의 길을 개척해 나가며"
        ],
        "중년": [
            "인생의 깊은 지혜가 축적되어",
            "가족에 대한 사랑이 더욱 깊어지고",
            "사회적 영향력이 확대되며",
            "경험에서 우러나는 통찰력이 빛을 발하고",
            "후배들을 이끄는 리더십이 발휘되며"
        ],
        "시니어": [
            "인생의 완숙한 지혜가 빛을 발하고",
            "가족들에게 든든한 지지자 역할을 하며",
            "젊은 세대에게 귀감이 되는 모습으로",
            "평생 쌓아온 경험이 빛을 발하고",
            "인생의 여유로움이 주변을 따뜻하게 하며"
        ],
        "성인": [
            "성숙한 판단력과 실행력이 조화를 이루고",
            "전문 분야에서의 역량이 극대화되며",
            "균형 잡힌 인생관이 빛을 발하고",
            "사회적 기여도가 높아지며",
            "개인적 성취와 사회적 책임이 조화롭게 어우러져"
        ]
    ]

    private let genderSpecificTraits: [String: [String]] = [
        "남성": [
            "강인한 의지력과 추진력이 더욱 강화되고",
            "리더십 있는 모습으로 주변을 이끌며",
            "목표 지향적인 성향이 빛을 발하고",
            "합리적 판단력이 더욱 예리해지며",
            "책임감 있는 모습으로 신뢰를 쌓아가고"
        ],
        "여성": [
            "섬세한 감성과 직관력이 더욱 예리해지고",
            "따뜻한 배려심으로 주변을 감싸 안으며",
            "조화로운 관계 형성 능력이 빛을 발하고",
            "창의적 사고력이 더욱 풍부해지며",
            "공감 능력을 바탕으로 깊은 소통을 이루어내고"
        ],
        "기타": [
            "독특한 개성과 창의성이 빛을 발하고",
            "포용적인 마음으로 다양성을 받아들이며",
            "균형 잡힌 시각으로 세상을 바라보고",
            "열린 마음으로 새로운 가능성을 탐구하며",
            "자유로운 사고로 혁신적인 아이디어를 만들어내고"
        ]
    ]

    private let zodiacTraitDescriptions: [String] = [
        "이러한 특성을 활용해 좋은 하루를 만들어보세요.",
        "오늘은 이런 면이 특히 도움이 될 것입니다.",
        "이 에너지를 긍정적으로 활용해보세요.",
        "당신만의 독특한 매력이 빛을 발할 것입니다.",
        "이런 특성이 새로운 기회를 가져다줄 수 있습니다.",
        "오늘의 상황에서 이런 면이 큰 힘이 될 것입니다.",
        "이러한 장점을 최대한 발휘해보세요.",
        "당신의 이런 모습이 주변 사람들에게 좋은 영향을 줄 것입니다.",
        "이 특별한 에너지로 멋진 하루를 만들어가세요.",
        "오늘은 이런 면에서 특별한 성과를 거둘 수 있을 것입니다."
    ]

    private let todaysActivities: [String: [String]] = [
        "어린이": [
            "친구들과 재미있게 놀기", "새로운 책 읽어보기", "그림 그리기나 만들기", "가족과 함께 시간 보내기",
            "공원에서 뛰어놀기", "퍼즐 맞추기", "블록 놀이하기", "동화책 듣기",
            "색칠공부하기", "점토로 만들기", "숨바꼭질하기", "자전거 타기",
            "동물원 방문하기", "박물관 견학하기", "새로운 놀이 배우기", "노래 부르기",
            "춤추기", "간단한 요리 도와주기", "화분에 물주기", "일기 쓰기",
            "장난감 정리하기", "형제자매와 놀기", "할머니 할아버지께 안부 인사드리기", "새로운 단어 배우기",
            "공 던지고 받기", "줄넘기하기", "모래놀이하기", "물놀이하기",
            "곤충 관찰하기", "별 보기", "구름 모양 맞추기", "꽃 관찰하기",
            "음악 감상하기", "악기 배우기", "만화 그리기", "종이접기하기",
            "레고 조립하기", "보드게임하기", "카드놀이하기", "인형놀이하기"
        ],

        "청소년": [
            "좋아하는 음악 듣기", "친구들과 대화하기", "새로운 취미 찾아보기", "운동이나 스포츠 하기",
            "독서하며 상상력 키우기", "영화 감상하기", "게임하기", "그림이나 만화 그리기",
            "악기 연주하기", "댄스 배우기", "요리 배우기", "외국어 공부하기",
            "프로그래밍 배우기", "사진 촬영하기", "블로그 쓰기", "봉사활동 참여하기",
            "동아리 활동하기", "스케이트보드 타기", "자전거 라이딩하기", "등산하기",
            "캠핑 가기", "여행 계획 세우기", "새로운 앱 탐색하기", "온라인 강의 듣기",
            "친구들과 스터디 그룹 만들기", "진로 탐색하기", "포트폴리오 만들기", "인턴십 지원하기",
            "창작 활동하기", "영상 제작하기", "팟캐스트 듣기", "웹툰 그리기",
            "패션 스타일링하기", "헤어스타일 바꿔보기", "새로운 메이크업 시도하기", "옷 리폼하기",
            "펜팔 친구 만들기", "언어교환 파트너 찾기", "문화 체험하기", "전시회 관람하기"
        ],

        "청년": [
            "자기계발 도서 읽기", "새로운 사람들과 네트워킹", "운동이나 헬스장 가기", "여행 계획 세우기",
            "온라인 강의 수강하기", "전문 세미나 참석하기", "업계 컨퍼런스 참가하기", "멘토 만나기",
            "새로운 기술 배우기", "창업 아이디어 구상하기", "부업 시작하기", "투자 공부하기",
            "어학 실력 향상시키기", "자격증 준비하기", "포트폴리오 업데이트하기", "이력서 개선하기",
            "인맥 관리하기", "산업 트렌드 분석하기", "경쟁사 분석하기", "시장 조사하기",
            "프로젝트 기획하기", "팀 빌딩 활동하기", "리더십 교육 받기", "코칭 받기",
            "요가나 명상하기", "마라톤 준비하기", "등산 동호회 가입하기", "수영 배우기",
            "새로운 레스토랑 탐방하기", "와인 테이스팅하기", "쿠킹 클래스 참여하기", "바리스타 과정 수강하기",
            "사진 전시회 가기", "연극 관람하기", "콘서트 참석하기", "뮤지컬 보기",
            "독서 모임 참여하기", "토론 클럽 가입하기", "철학 카페 방문하기", "인문학 강의 듣기"
        ],

        "중년": [
            "가족과 함께하는 시간", "건강 관리 활동", "새로운 취미 개발", "재테크 공부하기",
            "정기 건강검진 받기", "운동 루틴 만들기", "식단 관리하기", "충분한 수면 취하기",
            "스트레스 관리법 익히기", "명상이나 요가하기", "마사지 받기", "온천 방문하기",
            "자녀와 대화 시간 갖기", "배우자와 데이트하기", "부모님께 안부 인사드리기", "형제자매 모임 갖기",
            "동창회 참석하기", "동네 이웃과 친목 도모하기", "종교 활동 참여하기", "봉사활동하기",
            "새로운 언어 배우기", "악기 배우기", "그림 그리기", "도예 체험하기",
            "가드닝하기", "등산하기", "골프 배우기", "테니스 치기",
            "문화센터 강의 듣기", "평생교육원 수강하기", "독서 클럽 가입하기", "서예 배우기",
            "부동산 투자 공부하기", "주식 투자 배우기", "연금 설계하기", "보험 점검하기",
            "여행 계획 세우기", "국내 여행하기", "해외여행 준비하기", "캠핑 가기",
            "맛집 탐방하기", "전통시장 구경하기", "박물관 관람하기", "전시회 보기"
        ],

        "시니어": [
            "산책이나 가벼운 운동", "친구들과 만남", "문화 활동 참여", "손자녀와 시간 보내기",
            "공원에서 산책하기", "태극권 배우기", "게이트볼 하기", "수영하기",
            "실버 체조 참여하기", "건강 댄스 배우기", "요가 클래스 참여하기", "스트레칭하기",
            "동년배 친구들과 차 마시기", "화투나 바둑 두기", "장기 두기", "당구 치기",
            "노인정 활동 참여하기", "경로당 모임 참석하기", "동호회 활동하기", "봉사활동하기",
            "손자녀에게 옛날 이야기 들려주기", "전통 놀이 가르쳐주기", "요리법 전수하기", "인생 조언하기",
            "가족사진 정리하기", "추억 앨범 만들기", "자서전 쓰기", "일기 쓰기",
            "도서관에서 신문 읽기", "라디오 듣기", "TV 시청하기", "팟캐스트 듣기",
            "원예 활동하기", "텃밭 가꾸기", "화분 키우기", "분재 만들기",
            "전통시장 구경하기", "공원 벤치에서 휴식하기", "새 관찰하기", "일출 감상하기",
            "온천 방문하기", "찜질방 가기", "마사지 받기", "한의원 방문하기",
            "종교 활동 참여하기", "명상하기", "108배하기", "기도하기",
            "문화센터 프로그램 참여하기", "평생교육 강좌 듣기", "컴퓨터 배우기", "스마트폰 사용법 익히기"
        ],

        "성인": [
            "운동이나 건강 관리", "독서나 학습 활동", "사람들과 만남", "취미 활동 즐기기",
            "헬스장에서 운동하기", "홈트레이닝하기", "러닝하기", "사이클링하기",
            "수영하기", "등산하기", "요가하기", "필라테스하기",
            "전문서적 읽기", "자기계발서 읽기", "소설 읽기", "잡지 읽기",
            "온라인 강의 듣기", "세미나 참석하기", "워크숍 참여하기", "컨퍼런스 참가하기",
            "친구들과 식사하기", "동료들과 회식하기", "가족 모임 갖기", "새로운 사람과 만나기",
            "네트워킹 이벤트 참석하기", "업계 모임 참가하기", "스터디 그룹 활동하기", "토론 모임 참여하기",
            "영화 감상하기", "연극 관람하기", "콘서트 참석하기", "전시회 관람하기",
            "뮤지컬 보기", "오페라 감상하기", "발레 공연 보기", "클래식 음악회 가기",
            "새로운 레스토랑 방문하기", "요리 클래스 참여하기", "와인 테이스팅하기", "맥주 양조장 투어하기",
            "여행 계획 세우기", "주말 여행하기", "캠핑 가기", "백패킹하기",
            "사진 촬영하기", "그림 그리기", "도예하기", "목공예 배우기",
            "악기 연주하기", "노래 배우기", "춤 배우기", "글쓰기하기"
        ]
    ]

    private let luckyItems: [String: [String]] = [
        "기본": [
            "긍정적인 마음", "밝은 웃음", "따뜻한 말", "친절한 행동", "감사하는 마음",
            "용기", "희망", "사랑", "지혜", "인내심",
            "작은 선물", "꽃 한 송이", "좋은 책", "향기로운 차", "달콤한 음악",
            "편안한 옷", "좋아하는 색깔", "행운의 열쇠고리", "작은 인형", "예쁜 스티커"
        ],
        "어린이": [
            "새 연필", "색연필 세트", "예쁜 지우개", "귀여운 스티커", "작은 장난감",
            "좋아하는 캐릭터 용품", "컬러풀한 양말", "반짝이는 머리핀", "작은 인형", "미니카",
            "만화책", "스케치북", "크레파스", "비눗방울", "바람개비",
            "예쁜 필통", "귀여운 가방", "좋아하는 간식", "색깔 테이프", "반짝이 펜"
        ],
        "청소년": [
            "좋아하는 음악 앨범", "헤드폰", "스마트폰 케이스", "예쁜 다이어리", "볼펜 세트",
            "마스킹 테이프", "포토카드", "키링", "브레슬릿", "목걸이",
            "좋아하는 브랜드 용품", "운동화", "백팩", "모자", "선글라스",
            "향수", "립밤", "핸드크림", "이어폰", "파워뱅크"
        ],
        "청년": [
            "고급 볼펜", "노트북", "플래너", "명함 케이스", "지갑",
            "시계", "향수", "커피", "차", "건강기능식품",
            "운동용품", "요가 매트", "텀블러", "블루투스 이어폰", "스마트워치",
            "책", "와인", "선물용 꽃다발", "캔들", "디퓨저"
        ],
        "중년": [
            "건강차", "영양제", "마사지 도구", "아로마 오일", "편안한 쿠션",
            "독서용 돋보기", "혈압계", "만보기", "요가 매트", "등산용품",
            "화분", "원예용품", "가족사진", "앨범", "일기장",
            "좋은 차", "건강식품", "마사지 쿠폰", "온천 이용권", "문화센터 수강권"
        ],
        "시니어": [
            "건강차", "따뜻한 담요", "편안한 방석", "돋보기", "지팡이",
            "혈압계", "혈당측정기", "만보기", "라디오", "확대경",
            "약물 보관함", "온열 패드", "마사지 기계", "편안한 신발", "모자",
            "손자녀 사진", "가족 앨범", "일기장", "큰 글자 달력", "건강 수첩"
        ],
        "남성": [
            "시계", "지갑", "넥타이", "커프스 단추", "향수",
            "면도기", "헤어 제품", "운동용품", "골프용품", "낚시용품",
            "공구 세트", "차량용품", "전자제품", "게임", "술"
        ],
        "여성": [
            "액세서리", "향수", "화장품", "핸드크림", "립스틱",
            "스카프", "가방", "신발", "꽃", "캔들",
            "아로마 제품", "스킨케어 제품", "주얼리", "헤어 액세서리", "네일용품"
        ]
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
        loadUserPreferences()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // updateGradientFrames() removed: unified white card tone
    }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
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

        contentView.addSubview(disclaimerLabel)
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

        // 성별 변경 시 저장
        genderSegmentedControl.addTarget(self, action: #selector(genderChanged), for: .valueChanged)

        NSLayoutConstraint.activate([
            birthDateLabel.topAnchor.constraint(equalTo: userInfoCardView.topAnchor, constant: 20),
            birthDateLabel.leadingAnchor.constraint(equalTo: userInfoCardView.leadingAnchor, constant: 20),

            birthDatePicker.topAnchor.constraint(equalTo: birthDateLabel.bottomAnchor, constant: 12),
            birthDatePicker.leadingAnchor.constraint(equalTo: userInfoCardView.leadingAnchor, constant: 20),
            birthDatePicker.trailingAnchor.constraint(equalTo: userInfoCardView.trailingAnchor, constant: -20),
            birthDatePicker.heightAnchor.constraint(equalToConstant: 132),

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
        saveUserPreferences()
    }

    @objc private func genderChanged() {
        saveUserPreferences()
    }

    private func updateAgeInfo() {
        let age = calculateAge(from: birthDatePicker.date)
        let ageGroup = getAgeGroup(age: age)
        ageInfoLabel.text = "✨ 만 \(age)세 (\(ageGroup))"

        // 나이 정보에 색상 추가
        let attributedText = NSMutableAttributedString(string: ageInfoLabel.text ?? "")
        let range = (ageInfoLabel.text! as NSString).range(of: "만 \(age)세")
        attributedText.addAttributes([
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.boldSystemFont(ofSize: 16)
        ], range: range)
        ageInfoLabel.attributedText = attributedText
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

    private func updateGradientFrames() {
        // 헤더뷰 그라데이션 업데이트
        // 그라데이션 제거됨: 일관된 화이트 카드 톤 적용으로 별도 프레임 업데이트 불필요
    }

    private func saveUserPreferences() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(birthDatePicker.date, forKey: "fortune_birth_date")
        userDefaults.set(genderSegmentedControl.selectedSegmentIndex, forKey: "fortune_gender")
    }

    private func loadUserPreferences() {
        let userDefaults = UserDefaults.standard

        // 생년월일 로드
        if let savedDate = userDefaults.object(forKey: "fortune_birth_date") as? Date {
            birthDatePicker.date = savedDate
        }

        // 성별 로드
        let savedGender = userDefaults.integer(forKey: "fortune_gender")
        if savedGender >= 0 && savedGender < genderSegmentedControl.numberOfSegments {
            genderSegmentedControl.selectedSegmentIndex = savedGender
        }

        // 나이 정보 업데이트
        updateAgeInfo()
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
            // Disclaimer
            disclaimerLabel.topAnchor.constraint(equalTo: fortuneResultView.bottomAnchor, constant: 12),
            disclaimerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            disclaimerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // Share button under disclaimer
            shareButton.topAnchor.constraint(equalTo: disclaimerLabel.bottomAnchor, constant: 12),
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
            self.disclaimerLabel.isHidden = false
            self.fortuneResultView.alpha = 1.0
            self.shareButton.alpha = 1.0
            self.disclaimerLabel.alpha = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.scrollView.scrollRectToVisible(self.fortuneResultView.frame, animated: true)
        }
    }

    @objc private func shareButtonTapped() {
        guard let fortune = currentFortune else { return }

        let shareText = generateShareText(fortune: fortune)
        let masked = SettingsManager.shared.maskPIIForExport(shareText)
        let activityController = UIActivityViewController(
            activityItems: [masked],
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

        // 개선된 별자리 및 개인 정보 표시
        let genderText = genderSegmentedControl.selectedSegmentIndex == 0 ? "남성" : (genderSegmentedControl.selectedSegmentIndex == 1 ? "여성" : "기타")
        zodiacInfoLabel.text = """
        \(fortune.zodiacSign) • 만 \(age)세 (\(ageGroup)) • \(genderText)
        🎯 나이와 성별을 고려한 맞춤형 운세입니다
        """

        // 나이별 맞춤 운세 카드들 - 개선된 레이아웃
        let fortuneCards = [
            ("🌟 총운 (\(ageGroup) 맞춤)", fortune.generalFortune, UIDesignSystem.Colors.primary),
            ("💖 애정운 (\(genderText) 특화)", fortune.loveFortune, UIDesignSystem.Colors.accent),
            ("💼 직업운 (\(ageGroup) 중심)", fortune.workFortune, UIDesignSystem.Colors.info),
            ("💪 건강운 ", fortune.healthFortune, UIDesignSystem.Colors.success),
            ("💰 금전운 ", fortune.moneyFortune, UIDesignSystem.Colors.warning)
        ]

        for (index, (title, content, color)) in fortuneCards.enumerated() {
            let card = createEnhancedFortuneCard(title: title, content: content, accentColor: color)

            // 금전운 카드에 특별한 표시 추가
            // if index == 4 { // 금전운
            //     let badge = createNewFeatureBadge()
            //     card.addSubview(badge)
            //     NSLayoutConstraint.activate([
            //         badge.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            //         badge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8)
            //     ])
            // }

            fortuneStackView.addArrangedSubview(card)
        }

        // 별자리별 특성 정보 - 개선된 버전
        let traitInfo = generateZodiacTraits(zodiacSign: fortune.zodiacSign, ageGroup: ageGroup, gender: genderText)
        let traitCard = createEnhancedFortuneCard(title: "🔮 \(fortune.zodiacSign) 특성 (맞춤형 분석)", content: traitInfo, accentColor: UIDesignSystem.Colors.accent)
        fortuneStackView.addArrangedSubview(traitCard)

        // 행운 정보 (개선된 버전)
        let luckyInfo = """
        🎨 행운의 색: \(fortune.luckyColor)
        🔢 행운의 숫자: \(fortune.luckyNumber)
        💎 행운의 아이템: \(fortune.luckyItem)
        ⭐ 행운 지수: \(generateLuckyScore())%
        🎈 개인화 지수: \(generatePersonalizationScore(ageGroup: ageGroup))
        """
        let luckyCard = createEnhancedFortuneCard(title: "🍀 오늘의 행운 정보", content: luckyInfo, accentColor: UIDesignSystem.Colors.success)
        fortuneStackView.addArrangedSubview(luckyCard)

        // 나이별 맞춤 조언 - 강화된 버전
        let adviceContent = generateAdviceForAge(ageGroup: ageGroup)
        let adviceCard = createEnhancedFortuneCard(title: "💡 \(ageGroup)을 위한 전문 조언", content: adviceContent, accentColor: UIDesignSystem.Colors.warning)
        fortuneStackView.addArrangedSubview(adviceCard)

        // 개인 맞춤 메시지
        let messageContent = generatePositiveMessage()
        let messageCard = createEnhancedFortuneCard(title: "💝 당신에게 전하는 메시지", content: messageContent)
        messageCard.backgroundColor = UIDesignSystem.Colors.info.withAlphaComponent(0.1)
        fortuneStackView.addArrangedSubview(messageCard)

        // 오늘의 추천 활동
        let activityCard = createEnhancedFortuneCard(title: "🎯 오늘의 추천 활동", content: generateTodaysActivity(ageGroup: ageGroup))
        activityCard.backgroundColor = UIDesignSystem.Colors.primary.withAlphaComponent(0.08)
        fortuneStackView.addArrangedSubview(activityCard)
    }

    private func generateLuckyScore() -> Int {
        return Int.random(in: 75...95) // 긍정적인 점수 범위
    }

    private func generatePersonalizationScore(ageGroup: String) -> String {
        let scores = personalizationScores[ageGroup] ?? personalizationScores["기본"]!
        return scores.randomElement() ?? "우수"
    }

    private func generateZodiacTraits(zodiacSign: String, ageGroup: String, gender: String) -> String {
        let baseTrait = zodiacTraits[zodiacSign] ?? "특별한 에너지와 매력"
        let ageSpecific = ageSpecificTraits[ageGroup] ?? []
        let genderSpecific = genderSpecificTraits[gender] ?? []

        let additionalTrait = (ageSpecific + genderSpecific).randomElement() ?? ""
        let traitDescription = zodiacTraitDescriptions.randomElement() ?? "이러한 특성을 활용해 좋은 하루를 만들어보세요."

        return "오늘은 \(baseTrait)이 \(ageGroup) \(gender)에게 특히 잘 나타날 것입니다. \(additionalTrait) \(traitDescription)"
    }

    private func generateTodaysActivity(ageGroup: String) -> String {
        let activities = todaysActivities[ageGroup] ?? todaysActivities["성인"]!
        return activities.randomElement() ?? "긍정적인 마음으로 하루 보내기"
    }

    private func createFortuneCard(title: String, content: String) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIDesignSystem.Colors.cardBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        cardView.layer.shadowOpacity = 0.1

        let titleLabel = createLabel(text: title, font: .boldSystemFont(ofSize: 16))
        titleLabel.textColor = UIDesignSystem.Colors.primary

        let contentLabel = createLabel(text: content, font: .systemFont(ofSize: 14))
        contentLabel.numberOfLines = 0
        contentLabel.textColor = UIDesignSystem.Colors.primaryText

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

    private func createEnhancedFortuneCard(title: String, content: String, accentColor: UIColor? = nil) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = UIDesignSystem.Colors.cardBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOpacity = 0.12

        // 제목 부분
        let titleContainer = UIView()
        let color = accentColor ?? UIDesignSystem.Colors.primary
        titleContainer.backgroundColor = color.withAlphaComponent(0.1)
        titleContainer.layer.cornerRadius = 12
        titleContainer.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = createLabel(text: title, font: .boldSystemFont(ofSize: 17))
        titleLabel.textColor = color
        titleLabel.textAlignment = .left

        titleContainer.addSubview(titleLabel)

        // 내용 부분
        let contentLabel = createLabel(text: content, font: .systemFont(ofSize: 15, weight: .medium))
        contentLabel.numberOfLines = 0
        contentLabel.textColor = UIDesignSystem.Colors.primaryText
        contentLabel.lineBreakMode = .byWordWrapping

        // 장식용 분리선
        let separatorView = UIView()
        separatorView.backgroundColor = color.withAlphaComponent(0.2)
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

        // 나이 및 성별 정보 가져오기
        let age = calculateAge(from: birthDatePicker.date)
        let ageGroup = getAgeGroup(age: age)
        let genderText = genderSegmentedControl.selectedSegmentIndex == 0 ? "남성" : (genderSegmentedControl.selectedSegmentIndex == 1 ? "여성" : "기타")
        let luckyScore = generateLuckyScore()
        let personalization = generatePersonalizationScore(ageGroup: ageGroup)
        let advice = generateAdviceForAge(ageGroup: ageGroup)
        let message = generatePositiveMessage()
        let activity = generateTodaysActivity(ageGroup: ageGroup)
        let trait = generateZodiacTraits(zodiacSign: fortune.zodiacSign, ageGroup: ageGroup, gender: genderText)

        return """
        🔮 \(dateString) 오늘의 운세

        \(fortune.zodiacSign) • 만 \(age)세 (\(ageGroup)) • \(genderText)

        🌟 총운: \(fortune.generalFortune)
        💖 애정운: \(fortune.loveFortune)
        💼 직업운: \(fortune.workFortune)
        💪 건강운: \(fortune.healthFortune)
        💰 금전운: \(fortune.moneyFortune)
        ⭐ 총점: \(fortune.overallScore)/5

        🍀 행운의 색: \(fortune.luckyColor)
        🔢 행운의 숫자: \(fortune.luckyNumber)
        💎 행운의 아이템: \(fortune.luckyItem)
        ⭐ 행운 지수: \(luckyScore)%
        🎈 개인화 지수: \(personalization)

        🔮 별자리 특성: \(trait)
        💡 맞춤 조언: \(advice)
        💝 메시지: \(message)
        🎯 추천 활동: \(activity)

        ⚠️ 본 콘텐츠는 엔터테인먼트 목적이며, 전문적 조언이 아닙니다. 재미로만 봐주세요.

        #오늘의운세 #DeepSleep #맞춤운세
        """
    }

    private func generateAdviceForAge(ageGroup: String) -> String {
        let adviceList = ageGroupAdvice[ageGroup]
        ?? ageGroupAdvice["청년"]
        ?? ageGroupAdvice.values.first
        ?? []
        return adviceList.randomElement() ?? "긍정적인 마음가짐으로 하루를 시작하세요."
    }

    private func generatePositiveMessage() -> String {
        return positiveMessages.randomElement() ?? "행복한 하루 되세요!"
    }

    private func getLuckyItem(ageGroup: String, gender: String) -> String {
        let baseItems = luckyItems["기본"] ?? []
        let ageItems = luckyItems[ageGroup] ?? []
        let genderItems = luckyItems[gender] ?? []

        let allItems = baseItems + ageItems + genderItems
        return allItems.randomElement() ?? "긍정적인 마음"
    }
}
