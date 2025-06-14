import UIKit

class LaunchViewController: UIViewController {
    
    private let gradientLayer = CAGradientLayer()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var hasSetupConstraints = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        #if DEBUG
        print("🚀 [LaunchViewController] viewDidLoad 호출됨")
        #endif
        setupGradientBackground()
        setupViews()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
        
        // 제약조건을 한 번만 설정
        if !hasSetupConstraints {
            setupConstraints()
            hasSetupConstraints = true
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        
            setupGradientBackground()
        
    }
    
    private func setupGradientBackground() {
        
            gradientLayer.colors = [
                UIColor.systemPink.withAlphaComponent(0.6).cgColor,
                UIColor.systemPurple.withAlphaComponent(0.5).cgColor,
                UIColor.systemBlue.withAlphaComponent(0.4).cgColor,
                UIColor.systemTeal.withAlphaComponent(0.3).cgColor
            ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        
        // 기존 그라데이션 레이어 제거 후 새로 추가
        gradientLayer.removeFromSuperlayer()
        view.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func setupViews() {
        // 앱 아이콘 이미지뷰 (달을 하얀색으로)
        iconImageView.image = UIImage(named: "AppIcon") ?? UIImage(systemName: "moon.fill")
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.layer.cornerRadius = 20
        iconImageView.layer.shadowColor = UIColor.black.cgColor
        iconImageView.layer.shadowOffset = CGSize(width: 0, height: 4)
        iconImageView.layer.shadowRadius = 8
        iconImageView.layer.shadowOpacity = 0.3
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // 메인 타이틀
        titleLabel.text = "EmoZleep"
        titleLabel.font = UIFont.systemFont(ofSize: 36, weight: .light)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 서브타이틀 추가
        subtitleLabel.text = "AI와 함께하는 감정 기록"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .light)
        subtitleLabel.textColor = .white.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // 초기 투명도 설정 (애니메이션을 위해)
        iconImageView.alpha = 0
        titleLabel.alpha = 0
        subtitleLabel.alpha = 0
        
        view.addSubview(iconImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 아이콘을 화면 중앙보다 약간 위에 배치
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -150),
            iconImageView.widthAnchor.constraint(equalToConstant: 120),
            iconImageView.heightAnchor.constraint(equalToConstant: 120),
            
            // 타이틀을 아이콘 아래에 배치
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            // 서브타이틀을 타이틀 아래에 배치
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if DEBUG
        print("🚀 [LaunchViewController] viewDidAppear 호출됨")
        #endif
        
        // 🚀 백그라운드에서 앱 초기화 시작 (UI 애니메이션과 병렬 실행)
        Task {
            await performBackgroundInitialization()
        }
        
        // 3초 로딩 시간에 맞춘 부드러운 애니메이션
        // 아이콘이 먼저 천천히 나타나고 (0.5초 후, 1초간)
        UIView.animate(withDuration: 1.0, delay: 0.5, options: .curveEaseOut) {
            self.iconImageView.alpha = 1.0
        }
        
        // 타이틀이 자연스럽게 이어서 나타남 (1.2초 후, 0.8초간)
        UIView.animate(withDuration: 0.8, delay: 1.2, options: .curveEaseOut) {
            self.titleLabel.alpha = 1.0
        }
        
        // 서브타이틀이 마지막에 부드럽게 나타남 (1.8초 후, 0.6초간)
        UIView.animate(withDuration: 0.6, delay: 1.8, options: .curveEaseOut) {
            self.subtitleLabel.alpha = 1.0
        }
        
        // 1.3초 후 메인 화면으로 이동 (사용자 경험 개선)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            self.transitionToMainInterface()
        }
    }
    
    // 🚀 백그라운드 초기화 작업
    private func performBackgroundInitialization() async {
        await Task.detached {
            // 데이터 검증 및 마이그레이션 사전 실행
            #if DEBUG
            print("🚀 [Launch] 백그라운드 초기화 시작")
            #endif
            
            // 프리셋 마이그레이션 사전 실행
            PresetManager.shared.migrateLegacyPresetsIfNeeded()
            
            // 사운드 매니저 초기화
            _ = SoundManager.shared
            
            // 설정 매니저 초기화
            _ = SettingsManager.shared
            
            // 온디바이스 학습 모델 사전 로드
            _ = ComprehensiveRecommendationEngine.shared
            
            // 🧹 피드백 데이터 자동 정리 (백그라운드에서 실행)
            await FeedbackManager.shared.performStartupCleanup()
            
            #if DEBUG
            print("✅ [Launch] 백그라운드 초기화 완료")
            #endif
        }.value
    }
    
    // MARK: - 안전한 화면 전환
    private func transitionToMainInterface() {
        // 여러 방법으로 SceneDelegate에 접근 시도 (안정성 향상)
        if let windowScene = view.window?.windowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate {
            sceneDelegate.showMainInterface()
        } else if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            sceneDelegate.showMainInterface()
        } else {
            // 마지막 수단: 직접 화면 전환
            print("⚠️ SceneDelegate를 찾을 수 없어 직접 화면 전환을 시도합니다")
            fallbackTransition()
        }
    }
    
    private func fallbackTransition() {
        guard let window = view.window else { return }
        
        let tabBarController = UITabBarController()
        
        // 1. 메인 사운드 화면 (ViewController)
        let mainVC = ViewController()
        let mainNav = UINavigationController(rootViewController: mainVC)
        mainNav.navigationBar.prefersLargeTitles = true
        mainNav.tabBarItem = UITabBarItem(title: "사운드", image: UIImage(systemName: "speaker.wave.2.fill"), tag: 0)
        
        // 2. 일기 목록 화면 (EmotionDiaryViewController)
        let diaryVC = EmotionDiaryViewController()
        let diaryNav = UINavigationController(rootViewController: diaryVC)
        diaryNav.navigationBar.prefersLargeTitles = true
        diaryNav.tabBarItem = UITabBarItem(title: "일기목록", image: UIImage(systemName: "book.fill"), tag: 1)
        
        // 3. 감정 캘린더 화면 (TodoCalendarViewController)
        let todoCalendarVC = TodoCalendarViewController()
        let todoCalendarNav = UINavigationController(rootViewController: todoCalendarVC)
        todoCalendarNav.navigationBar.prefersLargeTitles = true
        todoCalendarNav.tabBarItem = UITabBarItem(title: "내 일정", image: UIImage(systemName: "calendar.badge.plus"), tag: 2)
        
        // TabBarController에 모든 뷰 컨트롤러들 설정
        tabBarController.viewControllers = [mainNav, diaryNav, todoCalendarNav]
        tabBarController.selectedIndex = 0 // 기본으로 첫 번째 탭 선택
        
        UIView.transition(
            with: window,
            duration: 0.7,
            options: .transitionCrossDissolve,
            animations: {
                window.rootViewController = tabBarController
            }
        )
    }
}
