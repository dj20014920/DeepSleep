import UIKit

// MARK: - 조언 표시를 위한 간단한 커스텀 뷰 컨트롤러 (글자 수 제한 없음)
class SimpleAdviceViewController: UIViewController {
    private let titleText: String
    private let adviceText: String

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let adviceTextView = UITextView()
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
        view.backgroundColor = UIColor.black.withAlphaComponent(0.35)

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

        // 조언 텍스트뷰 설정(스크롤/선택/링크 자동 탐지)
        adviceTextView.translatesAutoresizingMaskIntoConstraints = false
        adviceTextView.font = .systemFont(ofSize: 16)
        adviceTextView.textColor = .label
        adviceTextView.backgroundColor = .clear
        adviceTextView.isEditable = false
        adviceTextView.isSelectable = true
        adviceTextView.dataDetectorTypes = [.link, .phoneNumber]
        adviceTextView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        adviceTextView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        containerView.addSubview(adviceTextView)

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

        // 제약 조건 설정
        NSLayoutConstraint.activate([
            // 컨테이너 뷰
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            // 화면 80% 이내로 제한
            containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            containerView.heightAnchor.constraint(greaterThanOrEqualTo: view.heightAnchor, multiplier: 0.6),
            containerView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.8),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            // 제목 라벨
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

            // 텍스트뷰(자동 스크롤)
            adviceTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            adviceTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            adviceTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            // 텍스트뷰는 버튼 위까지 확장
            adviceTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),

            // 버튼 스택뷰
            buttonStackView.topAnchor.constraint(equalTo: adviceTextView.bottomAnchor, constant: 20),
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            buttonStackView.heightAnchor.constraint(equalToConstant: 44)
        ])

        // 텍스트뷰가 컨테이너 최대 높이 내에서 스크롤되도록 설정
        adviceTextView.isScrollEnabled = true
        adviceTextView.setContentCompressionResistancePriority(.required, for: .vertical)
        adviceTextView.setContentHuggingPriority(.defaultLow, for: .vertical)
    }

    private func configureContent() {
        titleLabel.text = titleText
        let trimmed = adviceText.trimmingCharacters(in: .whitespacesAndNewlines)
        adviceTextView.text = trimmed.isEmpty ? "내용이 비어 있습니다." : adviceText
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
