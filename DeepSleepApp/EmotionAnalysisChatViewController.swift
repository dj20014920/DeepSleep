import UIKit

import Combine

class EmotionAnalysisChatViewController: UIViewController, UIGestureRecognizerDelegate, UITextFieldDelegate {
    private var subscriptionObserver: NSObjectProtocol?
    
    // MARK: - Properties
    private var viewModel: EmotionAnalysisViewModelProtocol!
    private var cancellables = Set<AnyCancellable>()
    
    private var tableView: UITableView!
    private var inputTextField: UITextField!
    private var sendButton: UIButton!
    private var inputContainerView: UIView!
    private var quickActionView: EmotionAnalysisQuickActionView!
    
    // MARK: - Initialization
    init(viewModel: EmotionAnalysisViewModelProtocol) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupInputView()
        setupQuickActions()
        setupNavigationBar()
        setupKeyboardHandling()
        setupSwipeGestures()
        setupBindings()
        
        // 구독 상태 옵저버
        subscriptionObserver = NotificationCenter.default.addObserver(forName: .subscriptionStatusChanged, object: nil, queue: .main) { [weak self] _ in
            self?.updateUIForSubscriptionStatus()
        }
        updateUIForSubscriptionStatus()
        
        // 초기 분석 수행
        Task {
            await viewModel.performInitialAnalysis()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        inputTextField.becomeFirstResponder()
    }
    
    // MARK: - Bindings
    private func setupBindings() {
        // 로딩 상태 바인딩
        viewModel.onLoadingStateChanged = { [weak self] isLoading in
            self?.setLoading(isLoading)
        }
        
        // 새 메시지 바인딩
        viewModel.onNewMessageAdded = { [weak self] isUser, message in
            self?.addMessage(isUser: isUser, content: message)
        }
        
        // 에러 바인딩
        viewModel.onError = { [weak self] error in
            self?.handleError(error)
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        title = "감정 분석 채팅"
    }
    
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
    }
    
    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = UIColor.systemBackground
        tableView.estimatedRowHeight = 80
        tableView.rowHeight = UITableView.automaticDimension
        
        // ChatBubbleCell 등록
        tableView.register(ChatBubbleCell.self, forCellReuseIdentifier: "ChatBubbleCell")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupInputView() {
        inputContainerView = UIView()
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.backgroundColor = UIColor.systemBackground
        inputContainerView.layer.borderWidth = 0.5
        inputContainerView.layer.borderColor = UIColor.separator.cgColor
        
        inputTextField = UITextField()
        inputTextField.translatesAutoresizingMaskIntoConstraints = false
        inputTextField.placeholder = "감정을 입력해보세요..."
        inputTextField.borderStyle = .roundedRect
        inputTextField.delegate = self
        inputTextField.returnKeyType = .send
        
        sendButton = UIButton(type: .system)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        sendButton.setTitle("전송", for: .normal)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    
        inputContainerView.addSubview(inputTextField)
        inputContainerView.addSubview(sendButton)
        view.addSubview(inputContainerView)
        
        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            inputContainerView.heightAnchor.constraint(equalToConstant: 60),
            
            inputTextField.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -12),
            inputTextField.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            inputTextField.heightAnchor.constraint(equalToConstant: 36),
            
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60)
        ])
        
        // TableView bottom constraint 업데이트
        tableView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor).isActive = true
    }
    
    private func setupQuickActions() {
        quickActionView = EmotionAnalysisQuickActionView()
        quickActionView.translatesAutoresizingMaskIntoConstraints = false
        quickActionView.delegate = self
        
        view.addSubview(quickActionView)
        
        NSLayoutConstraint.activate([
            quickActionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            quickActionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            quickActionView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: -8),
            quickActionView.heightAnchor.constraint(equalToConstant: 50)
        ])
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
    }
    
    // MARK: - Message Handling
    private func addMessage(isUser: Bool, content: String) {
        // 메인 스레드에서 UI 업데이트 보장
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 데이터 개수 확인
            let messageCount = self.viewModel.chatHistory.count
            guard messageCount > 0 else { return }
            
            // 새로운 메시지의 인덱스 계산
            let indexPath = IndexPath(row: messageCount - 1, section: 0)
            
            // 테이블뷰 업데이트
            self.tableView.insertRows(at: [indexPath], with: .automatic)
            self.scrollToBottom()
        }
    }
    
    private func setLoading(_ isLoading: Bool) {
        let (canUse, _) = EntitlementGate.canAccess(.diaryAnalysis)
        sendButton.isEnabled = !isLoading && canUse
        inputTextField.isEnabled = canUse
    }
    
    private func handleError(_ error: Error) {
        UserFriendlyErrorHandler.shared.showError(error, in: self)
    }
    
    // MARK: - Actions
    @objc private func sendTapped() {
        guard let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        
        inputTextField.text = ""
        
        Task {
            await viewModel.sendUserMessage(text)
    }
    }
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        UIView.animate(withDuration: 0.3) {
            self.view.transform = CGAffineTransform(translationX: 0, y: -keyboardHeight + self.view.safeAreaInsets.bottom)
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        UIView.animate(withDuration: 0.3) {
            self.view.transform = .identity
        }
    }
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
    
    private func updateUIForSubscriptionStatus() {
        let (can, _) = EntitlementGate.canAccess(.diaryAnalysis)
        sendButton?.isEnabled = can
        inputTextField?.isEnabled = can
    }
    
    deinit {
        if let token = subscriptionObserver { NotificationCenter.default.removeObserver(token) }
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITableViewDataSource
extension EmotionAnalysisChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.chatHistory.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatBubbleCell", for: indexPath) as! ChatBubbleCell
        let message = viewModel.chatHistory[indexPath.row]
        
        // ChatMessage 객체 생성
        let chatMessage = ChatMessage(
            text: message.message,
            sender: message.isUser ? MessageSender.user : MessageSender.ai,
            type: message.isUser ? ChatMessageType.user : ChatMessageType.bot
        )
        
        cell.configure(with: chatMessage, isUserMessage: message.isUser)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension EmotionAnalysisChatViewController: UITableViewDelegate {
    private func scrollToBottom() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.viewModel.chatHistory.count > 0 else { return }
            let indexPath = IndexPath(row: self.viewModel.chatHistory.count - 1, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
}

// MARK: - EmotionAnalysisQuickActionViewDelegate
extension EmotionAnalysisChatViewController: EmotionAnalysisQuickActionViewDelegate {
    func quickActionView(_ view: EmotionAnalysisQuickActionView, didSelectEmotion emotion: String) {
        Task {
            await viewModel.handleQuickAction(title: emotion, intent: emotion)
        }
    }
}

// MARK: - Swipe Gestures
extension EmotionAnalysisChatViewController {
    
    private func setupSwipeGestures() {
        // 오른쪽으로 스와이프 - 채팅창 나가기
        let rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeGesture(_:)))
        rightSwipeGesture.direction = .right
        rightSwipeGesture.delegate = self
        view.addGestureRecognizer(rightSwipeGesture)
        
        // 왼쪽 가장자리에서 스와이프 - iOS 기본 뒤로가기와 유사
        let edgeSwipeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgeSwipeGesture(_:)))
        edgeSwipeGesture.edges = .left
        edgeSwipeGesture.delegate = self
        view.addGestureRecognizer(edgeSwipeGesture)
    }
    
    @objc private func handleSwipeGesture(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.direction == .right else { return }
        
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 애니메이션과 함께 채팅창 나가기
        exitChatWithAnimation()
    }
    
    @objc private func handleEdgeSwipeGesture(_ gesture: UIScreenEdgePanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            // 드래그 중일 때 뷰를 약간 이동시켜 피드백 제공
            let progress = min(translation.x / view.bounds.width, 1.0)
            if progress > 0 {
                view.transform = CGAffineTransform(translationX: progress * 20, y: 0)
            }
            
        case .ended, .cancelled:
            // 충분히 스와이프했거나 빠르게 스와이프한 경우 나가기
            let shouldDismiss = translation.x > 100 || velocity.x > 500
            
            if shouldDismiss {
                // 햅틱 피드백
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                exitChatWithAnimation()
            } else {
                // 원래 위치로 되돌리기
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
                    self.view.transform = .identity
                }
            }
            
        default:
            break
        }
    }
    
    private func exitChatWithAnimation() {
        // 키보드 숨기기
        inputTextField.resignFirstResponder()
        
        // 슬라이드 아웃 애니메이션
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.view.transform = CGAffineTransform(translationX: self.view.bounds.width, y: 0)
            self.view.alpha = 0.7
        } completion: { _ in
            // 메인 화면으로 돌아가기
            if let navigationController = self.navigationController {
                navigationController.popViewController(animated: false)
            } else {
                self.dismiss(animated: false)
            }
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 텍스트 입력 중일 때는 스와이프 제스처 비활성화
        if inputTextField.isFirstResponder && inputTextField.text?.isEmpty == false {
            return false
        }
        return true
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 테이블뷰 스크롤과 충돌 방지
        if gestureRecognizer is UISwipeGestureRecognizer {
            // 텍스트 입력 중이 아닐 때만 스와이프 허용
            return !inputTextField.isFirstResponder || inputTextField.text?.isEmpty == true
        }
        return true
    }
}
