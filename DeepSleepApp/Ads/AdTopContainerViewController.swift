import UIKit

/// 상단 배너 컨테이너 뷰컨트롤러
/// - 목적: 화면 최상단(네비게이션 바 위, 안전영역 하단)에 광고 배너를 배치하고,
///         그 아래에 네비게이션 컨트롤러 + 콘텐츠(예: 일기쓰기 카드)를 배치하기 위한 컨테이너
/// - 특징:
///   • 배너는 view.safeAreaLayoutGuide.topAnchor에 고정(상단바/Status Bar와 겹치지 않음)
///   • 배너 바로 아래에 UINavigationController를 자식으로 넣어 콘텐츠가 배너와 정확히 맞닿도록 배치
///   • 배너 높이 변화는 내부적으로 BannerAdContainerView가 관리(동적 높이 반영)
final class AdTopContainerViewController: UIViewController {

    // MARK: - Public

    /// 내장된 내비게이션 컨트롤러 (필요하면 외부에서 접근 가능)
    public private(set) var embeddedNavigationController: UINavigationController

    /// 배너 호스트 뷰(광고 컨테이너)
    public private(set) var topBannerView: BannerAdContainerView = BannerAdContainerView()

    // MARK: - Private

    private let autoLoadBanner: Bool

    // MARK: - Init

    /// - Parameters:
    ///   - rootViewController: 배너 아래에 표시할 루트 콘텐츠(예: 일기쓰기 VC)
    ///   - prefersLargeTitles: 네비게이션 바 Large Title 사용 여부
    ///   - autoLoadBanner: viewDidAppear 시 배너 자동 로드 여부
    init(
        rootViewController: UIViewController,
        prefersLargeTitles: Bool = true,
        autoLoadBanner: Bool = true
    ) {
        self.embeddedNavigationController = UINavigationController(
            rootViewController: rootViewController)
        self.autoLoadBanner = autoLoadBanner
        super.init(nibName: nil, bundle: nil)

        if #available(iOS 11.0, *) {
            embeddedNavigationController.navigationBar.prefersLargeTitles = prefersLargeTitles
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        setupTopBanner()
        setupEmbeddedNavigation()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if autoLoadBanner {
            // 컨테이너(self)를 배너의 rootViewController로 사용 (GMA 정책 상 컨텐츠 표시 주체가 자신이면 안전)
            topBannerView.loadBanner(in: self)
        }
    }

    // MARK: - Setup

    private func setupTopBanner() {
        topBannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBannerView)

        // 상단 안전영역에 배너 고정(네비게이션 바 "위에" 해당)
        NSLayoutConstraint.activate([
            topBannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBannerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            topBannerView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor),
        ])

        // 배너 높이 변경 시 레이아웃을 재평가하여 네비게이션/콘텐츠가 바로 아래에 붙도록 유지
        topBannerView.onHeightChange = { [weak self] _ in
            guard let self = self else { return }
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    private func setupEmbeddedNavigation() {
        let navView = embeddedNavigationController.view!
        embeddedNavigationController.view.translatesAutoresizingMaskIntoConstraints = false

        // 자식으로 추가
        addChild(embeddedNavigationController)
        view.addSubview(navView)

        NSLayoutConstraint.activate([
            // 네비게이션 컨트롤러의 상단을 배너 하단에 맞춤 → 배너 바로 아래에서 시작
            navView.topAnchor.constraint(equalTo: topBannerView.bottomAnchor),
            navView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        embeddedNavigationController.didMove(toParent: self)
    }
}
