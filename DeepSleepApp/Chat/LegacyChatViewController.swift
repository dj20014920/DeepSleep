import UIKit
import SwiftUI

// MARK: - Legacy Chat View Controller Wrapper
// 기존 ChatViewController의 핵심 기능을 보존하면서 새로운 아키텍처로 점진적 전환

class LegacyChatViewController: UIViewController {
    
    // MARK: - Properties
    private var hostingController: UIHostingController<AnyView>?
    private var chatView: ModernChatViewWrapper?
    
    // Legacy compatibility properties
    var onPresetApply: ((RecommendationResponse) -> Void)?
    var initialUserText: String?
    var diaryContext: DiaryContext?
    var emotionPatternData: String?
    
    // MARK: - Initialization
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUIIntegration()
        handleLegacyInitialization()
    }
    
    // MARK: - SwiftUI Integration
    private func setupSwiftUIIntegration() {
        let modernChatView = AnyView(ModernChatViewWrapper())
        let hostingController = UIHostingController(rootView: modernChatView)
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        self.hostingController = hostingController
    }
    
    // MARK: - Legacy Compatibility
    private func handleLegacyInitialization() {
        // Handle initial user text from legacy integration
        if let initialText = initialUserText {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.sendMessage(initialText)
            }
        }
        
        // Setup diary context if available
        if let diaryContext = diaryContext {
            setupDiaryContext(diaryContext)
        }
        
        // Handle emotion pattern data if available
        if let emotionData = emotionPatternData {
            handleEmotionPatternData(emotionData)
        }
    }
    
    private func setupDiaryContext(_ context: DiaryContext) {
        // Process diary context for enhanced AI recommendations
        #if DEBUG
        print("📔 Diary context received: \(context)")
        #endif
    }
    
    private func handleEmotionPatternData(_ data: String) {
        // Process emotion pattern data for better recommendations
        #if DEBUG
        print("💭 Emotion pattern data: \(data)")
        #endif
    }
    
    // MARK: - Public API for Legacy Compatibility
    
    /// Send a message programmatically (for legacy integration)
    func sendMessage(_ message: String) {
        // For now, just log the message
        // This will be connected to the actual ViewModel in Phase 3
        #if DEBUG
        print("💬 Sending message: \(message)")
        #endif
    }
    
    /// Request recommendation programmatically
    func requestRecommendation() {
        #if DEBUG
        print("🎵 Requesting recommendation")
        #endif
    }
    
    /// Clear chat session
    func clearSession() {
        #if DEBUG
        print("🧹 Clearing chat session")
        #endif
    }
    
    /// Get current messages count
    var messageCount: Int {
        return 0 // Placeholder
    }
    
    /// Check if AI is currently processing
    var isProcessing: Bool {
        return false // Placeholder
    }
}

// MARK: - Modern Chat View Wrapper
struct ModernChatViewWrapper: View {
    var body: some View {
        VStack {
            Text("Modern Chat Interface")
                .font(.title)
                .padding()
            
            Text("새로운 SwiftUI 기반 채팅 인터페이스로 업그레이드되었습니다.")
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
            
            Text("개발 중...")
                .foregroundColor(.secondary)
                .padding()
        }
        .navigationTitle("AI 채팅")
    }
}

// MARK: - Migration Helper

class ChatMigrationHelper {
    
    /// Create a new LegacyChatViewController with legacy parameters
    static func createLegacyChatViewController(
        initialUserText: String? = nil,
        diaryContext: DiaryContext? = nil,
        emotionPatternData: String? = nil,
        onPresetApply: ((RecommendationResponse) -> Void)? = nil
    ) -> LegacyChatViewController {
        
        let viewController = LegacyChatViewController()
        viewController.initialUserText = initialUserText
        viewController.diaryContext = diaryContext
        viewController.emotionPatternData = emotionPatternData
        viewController.onPresetApply = onPresetApply
        
        return viewController
    }
    
    /// Migrate existing ChatViewController usage to new architecture
    static func migrateFromLegacy(
        chatManager: ChatManager? = nil,
        messages: [(isUser: Bool, message: String)] = []
    ) -> LegacyChatViewController {
        
        let viewController = LegacyChatViewController()
        
        // Process legacy messages
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            for message in messages where message.isUser {
                viewController.sendMessage(message.message)
            }
        }
        
        return viewController
    }
} 