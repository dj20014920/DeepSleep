import UIKit

final class EmotionAnalysisInputView: UIView {
    // MARK: - Properties
    var onSendMessage: ((String) -> Void)?
    var isLoading: Bool = false {
        didSet {
            updateLoadingState()
        }
    }
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.lightGray.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let textField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "감정에 대해 더 궁금한 점이 있나요?"
        textField.borderStyle = .none
        textField.font = .systemFont(ofSize: 16)
        textField.returnKeyType = .send
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("전송", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .systemBackground
        
        addSubview(containerView)
        containerView.addSubview(textField)
        containerView.addSubview(sendButton)
        containerView.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 60),
            
            textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            textField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),
            
            sendButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60),
            sendButton.heightAnchor.constraint(equalToConstant: 36),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: sendButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor)
        ])
        
        // 액션 설정
        textField.delegate = self
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        
        // 키보드 알림 설정
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
    
    // MARK: - Actions
    @objc private func sendTapped() {
        guard let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        
        onSendMessage?(text)
        textField.text = ""
    }
    
    // MARK: - Keyboard Handling
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        
        let transform = CGAffineTransform(translationX: 0, y: -keyboardFrame.height)
        
        UIView.animate(withDuration: duration) {
            self.transform = transform
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        
        UIView.animate(withDuration: duration) {
            self.transform = .identity
        }
    }
    
    // MARK: - Private Methods
    private func updateLoadingState() {
        sendButton.isHidden = isLoading
        isLoading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
        textField.isEnabled = !isLoading
    }
    
    // MARK: - Public Methods
    func clearText() {
        textField.text = ""
    }
    
    func focus() {
        textField.becomeFirstResponder()
    }
    
    func unfocus() {
        textField.resignFirstResponder()
    }
}

// MARK: - UITextFieldDelegate
extension EmotionAnalysisInputView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}

// MARK: - Accessibility
extension EmotionAnalysisInputView {
    private func setupAccessibility() {
        textField.accessibilityLabel = "메시지 입력"
        textField.accessibilityHint = "메시지를 입력하려면 두 번 탭하세요"
        
        sendButton.accessibilityLabel = "메시지 전송"
        sendButton.accessibilityHint = "입력한 메시지를 전송하려면 두 번 탭하세요"
        
        accessibilityElements = [textField, sendButton]
    }
} 