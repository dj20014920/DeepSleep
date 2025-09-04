import UIKit

// MARK: - 조언 표시를 위한 간단한 커스텀 뷰 컨트롤러 (글자 수 제한 없음)
class SimpleAdviceViewController: UIViewController {
    private let titleText: String
    private let adviceText: String
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let scrollView = UIScrollView()
    private let adviceLabel = UILabel()
    private let buttonStackView = UIStackView()
    private let copyButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    
    init(titleText: String, adviceText: String) {
        self.titleText = titleText
        self.adviceText = adviceText
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureContent()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        // 컨테이너 뷰 설정
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowOpacity = 0.3
        containerView.layer.shadowRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // 제목 라벨 설정
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // 스크롤뷰 설정
        scrollView.showsVerticalScrollIndicator = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(scrollView)
        
        // 조언 라벨 설정
        adviceLabel.font = .systemFont(ofSize: 16)
        adviceLabel.textColor = .label
        adviceLabel.numberOfLines = 0
        adviceLabel.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(adviceLabel)
        
        // 버튼 스택뷰 설정
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .fillEqually
        buttonStackView.spacing = 12
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(buttonStackView)
        
        // 복사 버튼 설정
        copyButton.setTitle("📋 복사하기", for: .normal)
        copyButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        copyButton.backgroundColor = .systemBlue
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.layer.cornerRadius = 8
        copyButton.addTarget(self, action: #selector(copyAdvice), for: .touchUpInside)
        
        // 닫기 버튼 설정
        closeButton.setTitle("닫기", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        closeButton.backgroundColor = .systemGray
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.layer.cornerRadius = 8
        closeButton.addTarget(self, action: #selector(closeAdvice), for: .touchUpInside)
        
        buttonStackView.addArrangedSubview(copyButton)
        buttonStackView.addArrangedSubview(closeButton)
        
        // 제약 조건 설정 (UIScrollView 올바른 오토레이아웃: contentLayoutGuide/frameLayoutGuide 사용)
        NSLayoutConstraint.activate([
            // 컨테이너 뷰
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            containerView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            containerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                         containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
            
            // 제목 라벨
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
             // 스크롤뷰
             scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
             scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
             scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
             scrollView.heightAnchor.constraint(lessThanOrEqualToConstant: 400), // 최대 높이 제한
             
             // 조언 라벨 (contentLayoutGuide에 맞춤)
             adviceLabel.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
             adviceLabel.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
             adviceLabel.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
             adviceLabel.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
             adviceLabel.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
             
            // 버튼 스택뷰
            buttonStackView.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 20),
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            buttonStackView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func configureContent() {
        titleLabel.text = titleText
        adviceLabel.text = adviceText
    }
    
    @objc private func copyAdvice() {
        UIPasteboard.general.string = adviceText
        
        // 복사 완료 피드백
        copyButton.setTitle("✅ 복사됨!", for: .normal)
        copyButton.backgroundColor = .systemGreen
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.copyButton.setTitle("📋 복사하기", for: .normal)
            self?.copyButton.backgroundColor = .systemBlue
        }
    }
    
    @objc private func closeAdvice() {
        dismiss(animated: true)
    }
    
    // 배경 터치로 닫기
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: view)
            if !containerView.frame.contains(location) {
                dismiss(animated: true)
            }
        }
    }
}
