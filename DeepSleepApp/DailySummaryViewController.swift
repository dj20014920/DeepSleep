import UIKit

// MARK: - AI 서비스 Import
// UnifiedAIServiceImpl과 관련 타입들을 사용하기 위한 import

/// 🎯 하루 요약 뷰컨트롤러
/// SessionManager.sendMessage를 통한 중앙집중형 AI 호출 사용
/// 선택된 날짜의 일기 + Todo + AI 응답을 통합 표시
class DailySummaryViewController: UIViewController {
    
    // MARK: - Properties
    private var selectedDate: Date = Date()
    private var todos: [TodoItem] = []
    private var diary: EmotionDiary?
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    private let dateLabel = UILabel()
    private let summaryTextView = UITextView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupNavigationBar()
        generateSummary()
    }
    
    // MARK: - Configuration
    func configure(date: Date, todos: [TodoItem], diary: EmotionDiary?) {
        self.selectedDate = date
        self.todos = todos
        self.diary = diary
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "하루 요약"
        
        // Scroll View
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)
        
        // Content View
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Stack View
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // Date Label
        dateLabel.font = .systemFont(ofSize: 24, weight: .bold)
        dateLabel.textColor = UIDesignSystem.Colors.primaryText
        dateLabel.textAlignment = .center
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateLabel.text = dateFormatter.string(from: selectedDate)
        
        stackView.addArrangedSubview(dateLabel)
        
        // Summary Text View
        summaryTextView.font = .systemFont(ofSize: 16)
        summaryTextView.textColor = UIDesignSystem.Colors.primaryText
        summaryTextView.backgroundColor = UIColor.secondarySystemGroupedBackground
        summaryTextView.layer.cornerRadius = 12
        summaryTextView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        summaryTextView.isEditable = false
        summaryTextView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.addArrangedSubview(summaryTextView)
        
        // Loading Indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Stack View
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // Summary Text View Height
            summaryTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
            
            // Loading Indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        let closeButton = UIBarButtonItem(title: "닫기", style: .plain, target: self, action: #selector(closeButtonTapped))
        navigationItem.rightBarButtonItem = closeButton
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Summary Generation
    private func generateSummary() {
        loadingIndicator.startAnimating()
        summaryTextView.text = "하루 요약을 생성하고 있습니다..."
        
        // 기본 데이터 표시
        var summaryContent = buildBasicSummary()
        summaryTextView.text = summaryContent
        
        // AI 분석 요청 (SessionManager.sendMessage 사용)
        requestAISummary { [weak self] aiSummary in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                
                if let aiSummary = aiSummary {
                    summaryContent += "\n\n📊 AI 분석\n\n\(aiSummary)"
                } else {
                    summaryContent += "\n\n📊 AI 분석\n\n분석을 생성할 수 없습니다."
                }
                
                self?.summaryTextView.text = summaryContent
            }
        }
    }
    
    /// 기본 요약 내용 생성 (일기 + Todo)
    private func buildBasicSummary() -> String {
        var content = ""
        
        // 일기 섹션
        if let diary = diary {
            content += "💭 감정 일기\n\n"
            content += "\(diary.userMessage)\n"
            
            // TODO: EmotionDiary 모델의 aiResponse 타입 확인 후 수정 필요
            // if !diary.aiResponse.isEmpty {
            //     content += "\n🤖 AI 분석:\n\(diary.aiResponse)\n"
            // }
        }
        
        // Todo 섹션
        if !todos.isEmpty {
            if !content.isEmpty {
                content += "\n\n"
            }
            
            content += "📌 할 일 목록\n\n"
            
            for (index, todo) in todos.enumerated() {
                let status = todo.isCompleted ? "✅" : "⏳"
                let priority = ["🔵", "🟡", "🔴"][min(todo.priority, 2)]
                
                content += "\(index + 1). \(status) \(priority) \(todo.title)\n"
                
                if let endDate = todo.endDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .short
                    content += "   📅 ~\(dateFormatter.string(from: endDate))\n"
                }
                
                if let notes = todo.notes, !notes.isEmpty {
                    content += "   📝 \(notes)\n"
                }
                
                // AI 조언이 있으면 표시
                if let aiAdvices = todo.aiAdvices, !aiAdvices.isEmpty {
                    content += "   💡 AI 조언: \(aiAdvices.joined(separator: " | "))\n"
                }
                
                content += "\n"
            }
        }
        
        return content
    }
    
    /// UnifiedAIServiceImpl을 통한 중앙집중형 AI 요약 요청
    private func requestAISummary(completion: @escaping (String?) -> Void) {
        // 요약 요청 메시지 구성
        var prompt = "다음은 \(dateLabel.text ?? "특정 날짜")의 활동 요약입니다. 이를 바탕으로 하루를 종합적으로 분석하고 인사이트를 제공해주세요:\n\n"
        
        // 일기 내용 추가
        if let diary = diary {
            prompt += "감정 일기:\n\(diary.userMessage)\n\n"
        }
        
        // Todo 내용 추가
        if !todos.isEmpty {
            prompt += "할 일 목록:\n"
            for todo in todos {
                let status = todo.isCompleted ? "완료" : "미완료"
                prompt += "- [\(status)] \(todo.title)"
                if let notes = todo.notes, !notes.isEmpty {
                    prompt += " (메모: \(notes))"
                }
                prompt += "\n"
            }
            prompt += "\n"
        }
        
        prompt += """
        위 내용을 바탕으로 다음 관점에서 분석해주세요:
        1. 감정 상태와 패턴
        2. 생산성과 목표 달성도
        3. 개선점과 제안사항
        4. 긍정적인 측면과 격려
        
        따뜻하고 공감적인 톤으로 작성해주세요.
        """
        
        // SessionManager를 통한 중앙집중형 AI 호출 (저장 안 함)
        Task {
            do {
                let response = try await SessionManager.shared.sendMessage(
                    content: prompt,
                    model: .claude,
                    mode: .generalConversation,
                    saveMessages: false
                )
                completion(response)
            } catch {
                print("❌ [DailySummaryViewController] AI 요약 생성 실패: \(error)")
                completion(nil)
            }
        }
    }
}