import UIKit

class LaunchViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        let titleLabel = UILabel()
        titleLabel.text = "EmoZleep"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 32)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            // TabBarController 생성
            let tabBarController = UITabBarController()

            // 1. 메인 사운드 화면 (ViewController)
            let mainVC = ViewController()
            let mainNav = UINavigationController(rootViewController: mainVC)
            mainNav.navigationBar.prefersLargeTitles = true
            mainNav.tabBarItem = UITabBarItem(title: "사운드", image: UIImage(systemName: "speaker.wave.2.fill"), tag: 0)

            // 2. 일기 목록 화면 (EmotionDiaryViewController) - 예시
            let diaryVC = EmotionDiaryViewController() // Storyboard나 XIB를 사용한다면 해당 방식으로 초기화
            let diaryNav = UINavigationController(rootViewController: diaryVC)
            diaryNav.navigationBar.prefersLargeTitles = true
            diaryNav.tabBarItem = UITabBarItem(title: "일기목록", image: UIImage(systemName: "book.fill"), tag: 1)
            
            // 3. 감정 캘린더 화면 (EmotionCalendarViewController) - 예시
            let todoCalendarVC = TodoCalendarViewController() // 새로운 뷰 컨트롤러로 변경
            let todoCalendarNav = UINavigationController(rootViewController: todoCalendarVC)
            todoCalendarNav.navigationBar.prefersLargeTitles = true
            todoCalendarNav.tabBarItem = UITabBarItem(title: "내 일정", image: UIImage(systemName: "calendar.badge.plus"), tag: 2) // 이름과 아이콘 변경
            
            // TabBarController에 뷰 컨트롤러들 설정
            tabBarController.viewControllers = [mainNav, diaryNav, todoCalendarNav] // 수정된 네비게이션 컨트롤러로 변경
            tabBarController.selectedIndex = 0 // 기본으로 첫 번째 탭 선택

            // 현재 윈도우 참조
            guard let window = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first?.windows.first else { return }
            
            // CrossDissolve 전환
            UIView.transition(
                with: window,
                duration: 0.5,
                options: .transitionCrossDissolve,
                animations: {
                    window.rootViewController = tabBarController // TabBarController를 루트로 설정
                }
            )
        }
    }
}
