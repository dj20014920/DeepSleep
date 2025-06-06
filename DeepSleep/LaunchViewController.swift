import UIKit

class LaunchViewController: UIViewController {
    
    private let gradientLayer = CAGradientLayer()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var hasSetupConstraints = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        
        // 3초 후 메인 화면으로 이동
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                sceneDelegate.showMainInterface()
            }
        }
    }
}
