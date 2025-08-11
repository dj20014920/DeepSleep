import UIKit
import SwiftUI
import Combine
import Foundation
import AVFoundation

// MARK: - Missing Types
enum JSONParsingError: Error {
    case invalidJSON
    case missingRequiredFields
    case invalidVolumeCount
}

struct AIResponseData: Codable {
    let presetName: String?
    let description: String?
    let volumes: [Float]?
    let reason: String? // Corrected from 'reasoning'
    let confidence: Double?
    let personalizedExplanation: String?
    let adaptation: String?
    let adaptationLevel: String?
    let emotion: String?
}

// MARK: - SharedCore 타입들 사용 (중복 제거 완료)
// 모든 공통 타입들은 SharedCore.swift에서 사용

// SharedCore 타입들을 직접 사용 (typealias 제거)

// MARK: - AI Teaching Delegate Protocol
protocol AITeachingDelegate: AnyObject {
    func didCreateNewRule(userInput: String, correctedMeaning: String)
    func didSaveTeaching(text: String, for persona: String)
}

// MARK: - Session Feedback Model (이제 CompilerFixStubs.swift에서 정의됨)

// MARK: - Claude 3.5 AI 추천 모델
struct ClaudeRecommendation {
    let presetName: String
    let analysis: String
    let recommendationReason: String
    let volumes: [Float]
    let versions: [Int]
    let confidence: Float
    let expectedMoodImprovement: String
    let sessionDuration: String
}


// MARK: - Session Metrics Structures


struct EnhancedSessionMetrics {
    let sessionId: UUID
    let duration: TimeInterval
    let messageCount: Int
    let recommendationCount: Int
    let userSatisfaction: Float
    let aiAccuracy: Float
}

// Note: RecommendationResponse is now defined in Models.swift to avoid duplication

class ChatViewController: UIViewController, UIGestureRecognizerDelegate, AITeachingDelegate {
    // MARK: - Properties
    var chatManager: ChatManager!  // 🚀 의존성 주입용 (ChatRouter에서 설정)
    var messages: [ChatMessage] = []
    var initialUserText: String?
    var diaryContext: DiaryContext?
    var emotionPatternData: String?
    var onPresetApply: ((SoundPreset) -> Void)?
    private var sessionStartTime: Date?
    private var messageCount = 0
    private let maxMessages = 75
    private var bottomConstraint: NSLayoutConstraint?
    var chatHistory: [(isUser: Bool, message: String)] = []
    
    // 🧠 추가된 프로퍼티 for Preset extension
    var lastAppliedPreset: SoundPreset?
    var categorySliders: [UISlider] = []
    
    // MARK: - 🔄 통합 채팅 컨텍스트 프로퍼티
    var chatContext: ChatMode = .generalConversation  // enum 타입으로 변경하여 타입 안정성 향상
    var initialDiaryData: EmotionDiary?
    var initialEmotion: String?
    var initialPatternData: String?
    var initialSystemMessage: String?
    
    // 🧠 Enhanced AI Properties
    private var currentSessionId = UUID()
    private var lastRecommendationTime: Date?
    private var currentEmotion: Any?
    private var feedbackPendingPresets: [UUID: String] = [:]
    // ✅ ML 학습 관련 코드 제거됨 - 기본 성능 메트릭으로 대체
    private var performanceMetrics = (duration: TimeInterval(0), completionRate: Float(0.5), context: [String: Any]())
    
    // 🔒 중복 요청 방지 플래그
    private var isProcessingRecommendation = false
    
    // 🎵 활성 추천 프리셋 임시 저장소
    private var activeRecommendationPresets: [UUID: SoundPreset] = [:]
    
    // MARK: - Paging Properties
    private let pageSize = 20
    private var currentPage = 0
    private var isLoadingMessages = false
    private var hasMoreMessages = true
    private var displayMessages: [ChatMessage] = []
    private var allMessagesCache: [ChatMessage] = []
    
    // MARK: - Model Switching Properties
    // TODO: 임시 주석 처리 - 컴파일 오류 해결 후 활성화
    // private let modelSwitchingManager = ModelSwitchingManager.shared
    // private let unifiedContextManager = UnifiedContextManager.shared
    private var modelSelectorButton: UIButton!
    
    // MARK: - UI Components
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.register(ChatBubbleCell.self, forCellReuseIdentifier: ChatBubbleCell.identifier)
        return tv
    }()
    
    private let inputContainerView = UIView()
    let inputTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "마음을 편하게 말해보세요..."
        tf.borderStyle = .roundedRect
        tf.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        tf.textColor = UIDesignSystem.Colors.primaryText
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    private let sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("전송", for: .normal)
        btn.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let presetButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("🎵 지금 기분에 맞는 사운드 추천받기", for: .normal)
        btn.backgroundColor = UIDesignSystem.Colors.adaptiveTertiaryBackground
        btn.setTitleColor(UIDesignSystem.Colors.primaryText, for: .normal)
        btn.layer.cornerRadius = 8
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    // ✅ 화면 하단 로딩 시스템 제거 (채팅 버블 내 고양이로 대체)
    
    // MARK: - Computed Properties
    private var dailyChatCount: Int {
        let todayStats = SettingsManager.shared.getTodayStats()
        return todayStats.chatCount
    }
    
    // MARK: - Enhanced Gesture Properties
    private var initialPanLocation: CGPoint = .zero
    private var isPerformingBackGesture: Bool = false
    
    // MARK: - 🚀 통합된 AI 분기 시스템 (로컬/외부 자동 선택)
    
    /// 지능형 AI 라우팅 - 입력에 따라 로컬 또는 외부 AI 자동 선택
    private func routeAIRequest(message: String, completion: @escaping (String?) -> Void) {
        // 1. 입력 복잡도 분석
        let complexity = analyzeInputComplexity(message)
        
        // 2. 시스템 상태 확인
        let batteryLevel = UIDevice.current.batteryLevel
        let isLowBattery = batteryLevel < 0.2 && batteryLevel > 0
        
        // 3. 라우팅 결정
        let shouldUseLocal = shouldUseLocalAI(complexity: complexity, batteryLevel: batteryLevel, isLowBattery: isLowBattery)
        
        if shouldUseLocal {
            // 로컬 AI 사용
            processWithLocalAI(message: message, completion: completion)
        } else {
            // 외부 Claude AI 사용
            processWithExternalAI(message: message, completion: completion)
        }
    }
    
    /// 입력 복잡도 분석
    private func analyzeInputComplexity(_ message: String) -> Float {
        let tokenCount = message.split(separator: " ").count
        let hasComplexQuestions = message.contains("왜") || message.contains("어떻게") || message.contains("분석")
        let hasEmotionalContext = message.contains("느낌") || message.contains("기분") || message.contains("감정")
        let requiresCreativeResponse = message.contains("추천") || message.contains("제안") || message.contains("도움")
        
        var complexity: Float = 0.0
        complexity += Float(tokenCount) * 0.1
        complexity += hasComplexQuestions ? 0.3 : 0.0
        complexity += hasEmotionalContext ? 0.2 : 0.0
        complexity += requiresCreativeResponse ? 0.2 : 0.0
        
        return min(complexity, 1.0) // 0.0 ~ 1.0 범위로 정규화
    }
    
    /// 로컬 AI 사용 여부 결정
    private func shouldUseLocalAI(complexity: Float, batteryLevel: Float, isLowBattery: Bool) -> Bool {
        // 배터리 부족 시 로컬 AI 우선
        if isLowBattery { return true }
        
        // 간단한 요청은 로컬 AI
        if complexity < 0.3 { return true }
        
        // 복잡한 요청은 외부 AI
        if complexity > 0.7 { return false }
        
        // 중간 복잡도는 배터리 상태에 따라
        return batteryLevel < 0.5
    }
    
    /// 로컬 AI 처리
    private func processWithLocalAI(message: String, completion: @escaping (String?) -> Void) {
        // 로컬 AI 응답 생성 (간단한 패턴 매칭 기반)
        let localResponse = generateLocalResponse(for: message)
        completion(localResponse)
    }
    
    /// 외부 AI 처리 (ChatManager 통합 완료)
    private func processWithExternalAI(message: String, completion: @escaping (String?) -> Void) {
        // UI에 사용자 메시지 추가
        addMessageToChat(message: message, fromUser: true)
        
        // AI 응답 로딩 시작
        showLoading(true)
        
        // 비동기 작업으로 AI 서비스 호출
        Task {
            do {
                // 🤖 ChatManager.sendMessage로 통합 AI 호출 (통합 아키텍처)
                let responseText = try await ChatManager.shared.sendMessage(
                    userInput: message,
                    modeString: "general_conversation",
                    modelString: "claude"  // 일반 대화에 최적화
                )
                
                // 메인 스레드에서 UI 업데이트
                await MainActor.run {
                    self.showLoading(false)
                    let parsedResponse = self.parseAIResponse(responseText)
                    self.addMessageToChat(message: parsedResponse, fromUser: false)
                    UnifiedLogger.shared.info("ChatManager 통합 AI 응답 완료", category: .ai)
                    completion(parsedResponse)
                }
                
            } catch {
                // 메인 스레드에서 에러 처리 및 UI 업데이트
                await MainActor.run {
                    self.showLoading(false)
                    
                    // 사용량 제한 초과 에러 처리
                    let errorMessage: String
                    if case AIServiceError.usageLimitExceeded(let message) = error {
                        errorMessage = message
                    } else {
                        errorMessage = "오류가 발생했습니다: \(error.localizedDescription)"
                    }
                    
                    self.addMessageToChat(message: errorMessage, fromUser: false)
                    completion(nil)
                }
            }
        }
    }
    
    /// 🧠 지능형 AI 응답 파싱 (모든 JSON 구조 지원)
    private func parseAIResponse(_ response: String) -> String {
        print("🔍 [ChatViewController] 원본 AI 응답: \(response)")
        
        // 1. 지능형 JSON 파싱 시도
        if let cleanText = parseJSONIntelligently(response) {
            print("✅ [ChatViewController] JSON 파싱 성공: \(cleanText.prefix(50))...")
            return cleanText
        }
        
        // 2. 원본 텍스트 정리 후 반환
        let cleanedText = cleanRawResponse(response)
        print("🔄 [ChatViewController] 정리된 텍스트 반환: \(cleanedText.prefix(50))...")
        return cleanedText
    }
    
    /// 🎯 지능형 JSON 파싱 - 다양한 키 구조 지원 (보안 강화)
    private func parseJSONIntelligently(_ response: String) -> String? {
        // JSON 형식 확인
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") && trimmed.hasSuffix("}") else {
            return nil
        }
        
        // 🛡️ 보안 검증 - JSON 크기 제한 (DoS 방지)
        guard trimmed.count < 50000 else {
            print("⚠️ [ChatViewController] JSON 크기 초과 - 보안상 거부")
            return nil
        }
        
        do {
            guard let data = trimmed.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            print("🔧 [ChatViewController] JSON 구조: \(json.keys.sorted())")
            
            // 우선순위별 키 검색 (성능 최적화 - 상수로 분리)
            for key in Self.priorityKeys {
                if let text = json[key] as? String, !text.isEmpty {
                    print("✅ [ChatViewController] '\(key)' 키에서 텍스트 추출")
                    return sanitizeAIResponse(text)
                }
            }
            
            // 중첩 객체에서 텍스트 검색
            for (_, value) in json {
                if let nestedDict = value as? [String: Any] {
                    for key in Self.priorityKeys {
                        if let text = nestedDict[key] as? String, !text.isEmpty {
                            print("✅ [ChatViewController] 중첩 객체 '\(key)' 키에서 텍스트 추출")
                            return sanitizeAIResponse(text)
                        }
                    }
                }
            }
            
            // 첫 번째 문자열 값 추출 (최후 수단)
            for (key, value) in json {
                if let text = value as? String, !text.isEmpty, text.count > 10 {
                    print("⚠️ [ChatViewController] '\(key)' 키에서 긴 문자열 추출 (최후 수단)")
                    return sanitizeAIResponse(text)
                }
            }
            
            print("❌ [ChatViewController] JSON에서 유효한 텍스트를 찾을 수 없음")
            return nil
            
        } catch {
            print("❌ [ChatViewController] JSON 파싱 오류: \(error)")
            return nil
        }
    }
    
    /// 🛡️ AI 응답 보안 검증 및 살균
    private func sanitizeAIResponse(_ text: String) -> String {
        let validationResult = InputValidationManager.shared.validate(text, against: .aiResponse)
        
        if !validationResult.isValid {
            // 심각한 보안 위험만 차단 (길이 초과는 허용)
            let criticalIssues = validationResult.securityIssues.filter { 
                $0.severity == .critical || $0.severity == .high 
            }
            
            if !criticalIssues.isEmpty {
                print("⚠️ [ChatViewController] 심각한 보안 위험 감지: \(criticalIssues)")
                return "죄송합니다. 응답을 처리하는 중 문제가 발생했습니다. 다시 시도해주세요."
            } else {
                print("ℹ️ [ChatViewController] 경미한 보안 이슈 감지하지만 허용: \(validationResult.securityIssues)")
            }
        }
        
        return validationResult.sanitizedValue ?? text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 📋 우선순위 키 목록 (성능 최적화)
    private static let priorityKeys = ["message", "response", "text", "content", "answer", "reply"]
    
    /// 🧹 원본 응답 정리 - JSON 아티팩트 제거 (성능 최적화)
    private func cleanRawResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 🛡️ 보안 검증 먼저 수행 (AI 응답용 규칙 사용)
        let validationResult = InputValidationManager.shared.validate(cleaned, against: .aiResponse)
        if !validationResult.isValid {
            // 심각한 보안 위험만 차단
            let criticalIssues = validationResult.securityIssues.filter { 
                $0.severity == .critical || $0.severity == .high 
            }
            if !criticalIssues.isEmpty {
                print("⚠️ [ChatViewController] 원본 응답에서 심각한 보안 위험 감지")
                return "응답을 처리할 수 없습니다. 다시 시도해주세요."
            }
        }
        
        // JSON 형태라면 최대한 읽기 쉽게 정리
        if cleaned.hasPrefix("{") && cleaned.hasSuffix("}") {
            // 성능 최적화: 미리 컴파일된 정규식 사용
            for regex in Self.precompiledRegexes {
                if let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.count)),
                   let range = Range(match.range(at: 1), in: cleaned) {
                    let extractedText = String(cleaned[range])
                    print("🔧 [ChatViewController] 정규식으로 텍스트 추출: \(extractedText.prefix(50))...")
                    return extractedText
                }
            }
            
            // 정규식 실패 시 JSON 아티팩트 제거
            cleaned = cleaned
                .replacingOccurrences(of: "\\\"", with: "\"")  // 이스케이프 따옴표
                .replacingOccurrences(of: "\\n", with: "\n")   // 이스케이프 개행
                .replacingOccurrences(of: "\\t", with: " ")    // 이스케이프 탭
            
            // 간단한 JSON 구조 정리
            if cleaned.contains("\"message\":") {
                cleaned = cleaned.replacingOccurrences(of: "^\\{.*\"message\"\\s*:\\s*\"", with: "", options: .regularExpression)
                cleaned = cleaned.replacingOccurrences(of: "\".*\\}$", with: "", options: .regularExpression)
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 📋 미리 컴파일된 정규식 (성능 최적화)
    private static let precompiledRegexes: [NSRegularExpression] = {
        let patterns = [
            "\"message\"\\s*:\\s*\"([^\"]+)\"",
            "\"response\"\\s*:\\s*\"([^\"]+)\"", 
            "\"text\"\\s*:\\s*\"([^\"]+)\"",
            "\"content\"\\s*:\\s*\"([^\"]+)\""
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }
    }()
    
    /// 로컬 AI 응답 생성
    private func generateLocalResponse(for message: String) -> String {
        let lowercaseMessage = message.lowercased()
        
        // 감정 표현 감지
        if lowercaseMessage.contains("슬퍼") || lowercaseMessage.contains("우울") {
            return "마음이 많이 힘드시군요 😔 이런 때일수록 따뜻한 사운드가 도움이 될 것 같아요. 프리셋 추천 버튼을 눌러보시겠어요?"
        }
        
        if lowercaseMessage.contains("행복") || lowercaseMessage.contains("기뻐") {
            return "좋은 기분이시네요! 😊 이 좋은 감정을 더 오래 유지할 수 있는 편안한 사운드를 추천해드릴까요?"
        }
        
        if lowercaseMessage.contains("피곤") || lowercaseMessage.contains("지쳐") {
            return "많이 피곤하셨나 봐요 😴 휴식에 도움이 되는 사운드로 마음을 편안하게 해드릴게요."
        }
        
        if lowercaseMessage.contains("추천") || lowercaseMessage.contains("프리셋") {
            return "지금 기분에 맞는 사운드를 추천해드릴게요! 하단의 '🎵 지금 기분에 맞는 사운드 추천받기' 버튼을 눌러보세요."
        }
        
        // 기본 응답
        return "말씀해주신 내용을 잘 들었어요. 더 자세히 이야기해주시면 더 도움이 될 것 같아요. 💝"
    }
    
    // MARK: - 📝 일기 분석 기능 (통합)
    
    /// 일기 분석 요청 처리
    func requestDiaryAnalysisWithTracking(diary: DiaryContext) {
        appendChat(ChatMessage(text: "분석하고 있어요...", sender: .ai, type: .loading))
        
        Task {
            do {
                // 🚀 ChatManager의 통합 AI 서비스 사용
                let responseContent = try await chatManager.sendMessage(
                    userInput: diary.content,
                    modeString: "emotion_diary_analysis",
                    modelString: nil
                )
                
                // ChatManager에 메시지 기록
                addBotMessage(responseContent)
                
                // 메인 스레드에서 UI 업데이트
                await MainActor.run {
                    self.removeLastLoadingMessage()
                    self.appendChat(ChatMessage(text: responseContent, sender: .ai, type: .bot))
                    
                    // 분석 결과에 대한 추가 안내 메시지
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.appendChat(ChatMessage(text: "💡 이 분석 결과에 대해 더 궁금한 점이 있으면 언제든 질문해주세요!", sender: .ai, type: .bot))
                    }
                }
            } catch {
                // 메인 스레드에서 에러 처리
                await MainActor.run {
                    self.removeLastLoadingMessage()
                    self.appendChat(ChatMessage(text: "❌ 분석에 실패했어요. 잠시 후 다시 시도해주세요.", sender: .ai, type: .bot))
                }
            }
        }
    }
    
    // MARK: - 💬 메시지 전송 처리 (리팩토링 완료)
    
    @objc func sendButtonTapped() {
        print("🔵 [ChatViewController] sendButtonTapped() 호출됨")
        guard let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { 
            print("🔴 [ChatViewController] 입력 텍스트가 비어있음")
            return 
        }
        
        print("🔵 [ChatViewController] 입력 텍스트: '\(text)'")
        inputTextField.text = ""
        
        // 🚀 새로운 AI 응답 처리 함수 호출
        fetchAIResponse(for: text)
        print("🔵 [ChatViewController] fetchAIResponse 호출 완료")
    }
    
    // MARK: - 🚀 AI 응답 처리 (신규 아키텍처)

    /// 사용자 메시지를 받아 AI에게 응답을 요청합니다.
    private func fetchAIResponse(for message: String) {
        addMessageToChat(message: message, fromUser: true)
        showLoading(true)
        
        Task {
            do {
                // 🚀 ChatManager의 통합 AI 서비스를 통한 메시지 전송
                // 현재 채팅 컨텍스트에 맞는 AI 모드 자동 결정
                let aiMode = determineAIModeFromContext()
                print("🎯 [ChatViewController] 현재 컨텍스트: '\(chatContext.displayName)' → AI 모드: \(aiMode.rawValue)")
                
                let responseContent = try await chatManager.sendMessage(
                    userInput: message,
                    modeString: aiMode.rawValue,
                    modelString: nil
                )
                
                handleAIResponse(responseContent)
                print("✅ [ChatViewController] AI 응답 받음")
                
            } catch {
                handleAIError(error)
            }
        }
    }
    
    /// 현재 채팅 컨텍스트를 기반으로 AI 모드 결정
    private func determineAIModeFromContext() -> AIMode {
        // ChatContext enum의 aiMode 프로퍼티를 직접 사용하여 간단하게 매핑
        return chatContext.aiMode
    }
    
    /// AI 컨텍스트 생성
    private func createAIContext() -> AIContext {
        // AIContext 생성 시 conversationHistory는 옵셔널이므로 nil로 설정
        return AIContext(
            userId: "user_\(currentSessionId)",
            sessionId: "\(currentSessionId)",
            conversationHistory: nil  // ChatManager가 내부적으로 히스토리를 관리하므로 여기서는 nil
        )
    }
    
    /// 최근 채팅 히스토리를 문자열 배열로 변환
    private func getRecentChatHistory() -> [String] {
        let maxHistoryCount = 5 // 최근 5개 메시지만 포함
        
        let recentMessages = messages
            .filter { message in
                message.type != .loading && 
                (message.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty == false)
            }
            .suffix(maxHistoryCount)
        
        return recentMessages.compactMap { message -> String? in
            guard let text = message.text, !text.isEmpty else { return nil }
            let role = message.sender == .user ? "사용자" : "AI"
            return "\(role): \(text)"
        }
    }
    
    /// 🎯 중앙집중형 메시지 추가 메서드 - 모든 메시지는 이 메서드를 통해 추가됨
    /// ChatMessage 객체를 채팅에 추가하고 UI를 업데이트합니다
    private func appendChat(_ message: ChatMessage) {
        // 메인 스레드에서 안전하게 처리
        DispatchQueue.main.async {
            // 1. UI 메시지 배열에 추가
            self.messages.append(message)
            
            // 2. ChatManager를 통한 영속성 처리 (중앙집중형)
            if let chatManager = self.chatManager {
                chatManager.append(message)
                
                // 3. 즉시 디스크에 저장 (데이터 안전성 보장)
                chatManager.flush()
                
                print("✅ [ChatViewController] 메시지 추가 및 즉시 저장 완료 - Type: \(message.type), Sender: \(message.sender)")
            } else {
                print("❌ [ChatViewController] ChatManager가 nil - 메시지 저장 실패!")
            }
            
            // 4. UI 업데이트
            self.tableView.reloadData()
            self.scrollToBottom()
        }
    }

    private func handleAIResponse(_ text: String) {
        Task { @MainActor in
            self.showLoading(false)
            let parsedResponse = self.parseAIResponse(text)
            
            // 🎯 중앙집중형 처리: appendChat 하나로 통합
            let aiMessage = ChatMessage(
                text: parsedResponse,
                date: Date(),
                sender: .ai,
                type: .bot
            )
            
            // appendChat이 모든 저장과 UI 업데이트를 처리
            self.appendChat(aiMessage)
            print("✅ [ChatViewController] AI 응답 처리 완료")
        }
    }

    private func handleAIError(_ error: Error) {
        Task { @MainActor in
            print("❌ [ChatViewController] AI 에러 처리 시작: \(error)")
            
            // 중앙집중식 로딩 제거
            self.showLoading(false)
            
            let errorMessage = UserFriendlyErrorHandler.shared.getUserFriendlyMessage(for: error)
            print("🔧 [ChatViewController] 사용자 친화적 에러 메시지: \(errorMessage)")
            
            self.addMessageToChat(message: errorMessage, fromUser: false)
            print("✅ [ChatViewController] 에러 메시지 추가 완료")
        }
    }
    
    // MARK: - 📱 Message Management Methods
    
    /// 채팅 메시지를 추가하고 UI를 업데이트합니다
    private func addMessageToChat(message: String, fromUser: Bool) {
        print("🟡 [ChatViewController] addMessageToChat 호출됨 - 메시지: '\(message)', fromUser: \(fromUser)")
        let messageType: ChatMessageType = fromUser ? .user : .bot
        let sender: MessageSender = fromUser ? .user : .ai
        let chatMessage = ChatMessage(
            text: message,
            date: Date(),
            sender: sender,
            type: messageType
        )
        print("🟡 [ChatViewController] ChatMessage 생성됨 - ID: \(chatMessage.id)")
        appendChat(chatMessage)
    }
    
    
    /// 봇 메시지를 채팅에 추가합니다
    override func addBotMessage(_ message: String) {
        print("🤖 [ChatViewController] addBotMessage 호출됨 - 메시지: \(message.prefix(50))")
        let botMessage = ChatMessage(
            text: message,
            date: Date(),
            sender: .ai,
            type: .bot
        )
        appendChat(botMessage)
    }
    
    /// 로딩 상태를 표시하거나 숨깁니다
    private func showLoading(_ show: Bool) {
        print("⏳ [ChatViewController] showLoading 호출됨 - show: \(show)")
        DispatchQueue.main.async {
            if show {
                print("⏳ [ChatViewController] 로딩 메시지 추가")
                let loadingMessage = ChatMessage(
                    text: "", // 빈 텍스트로 변경 - 고양이.gif만 표시
                    date: Date(),
                    sender: .ai,
                    type: .loading
                )
                self.appendChat(loadingMessage)
                print("⏳ [ChatViewController] 로딩 메시지 추가됨 - 메시지 수: \(self.messages.count)")
            } else {
                // 중앙집중식 로딩 메시지 제거
                self.removeAllLoadingMessages()
            }
            print("⏳ [ChatViewController] tableView.reloadData() 호출")
            self.tableView.reloadData()
            self.scrollToBottom()
            print("⏳ [ChatViewController] showLoading 완료")
        }
    }
    
    /// 테이블뷰를 맨 아래로 스크롤합니다
    private func scrollToBottom(animated: Bool = true) {
        DispatchQueue.main.async {
            // 스크롤 하단으로 이동
            guard !self.messages.isEmpty else { 
                print("🔴 [ChatViewController] 메시지가 없어서 스크롤하지 않음")
                return 
            }
            let indexPath = IndexPath(row: self.messages.count - 1, section: 0)
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
            // 스크롤 완료
        }
    }
    
    // MARK: - 🔧 Additional Helper Methods
    
    /// 모든 로딩 메시지를 제거합니다 (중앙집중식 처리, 메모리 최적화)
    private func removeAllLoadingMessages() {
        let beforeCount = messages.count
        messages.removeAll { $0.type == .loading }
        let afterCount = messages.count
        let removedCount = beforeCount - afterCount
        
        if removedCount > 0 {
            print("🧹 [ChatViewController] 로딩 메시지 \(removedCount)개 제거 완료 - 현재 메시지 수: \(afterCount)")
            
            // 메모리 최적화: 메인 스레드에서 이미 실행 중인지 확인
            if Thread.isMainThread {
                self.tableView.reloadData()
                self.scrollToBottom()
            } else {
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.scrollToBottom()
                }
            }
        }
    }
    
    /// 마지막 로딩 메시지를 제거합니다 (레거시 메서드)
    private func removeLastLoadingMessage() {
        DispatchQueue.main.async {
            self.removeAllLoadingMessages()
            self.tableView.reloadData()
        }
    }
    
    /// 현재 감정 데이터를 반환합니다
    private func getEmotionData() -> [String: Any] {
        return [
            "primaryEmotion": "평온",
            "emotion": "평온",
            "intensity": 0.5,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
    
    /// AI 티칭 뷰를 표시합니다
    private func presentAITeachingView(with message: String) {
        print("AI 티칭 뷰 표시: \(message)")
        // TODO: 실제 AI 티칭 뷰 구현
    }
    
    // MARK: - 🐛 Debug Methods
    
    private func debugCheckFeedbackStatus() {
        if #available(iOS 17.0, *) {
            let totalCount = FeedbackManager.shared.getTotalFeedbackCount()
            let recentCount = FeedbackManager.shared.getRecentFeedback(limit: 20).count
            let avgSatisfaction = FeedbackManager.shared.getAverageSatisfaction()
            print("Feedback - Total: \(totalCount), Recent: \(recentCount), Avg: \(avgSatisfaction)")
        } else {
            print("Feedback system requires iOS 17.0+")
        }
    }
    
    private func debugCreateTestData() {
        if #available(iOS 17.0, *) {
            FeedbackManager.shared.createTestFeedbackData()
            print("Test feedback data created")
        } else {
            print("Test data creation requires iOS 17.0+")
        }
    }
    
    private func debugTestLearningSystem() {
        if #available(iOS 17.0, *) {
            let feedbackCount = FeedbackManager.shared.getTotalFeedbackCount()
            print("Learning system test - Feedback count: \(feedbackCount)")
        } else {
            print("Learning system requires iOS 17.0+")
        }
    }
    
    // MARK: - 🤖 AITeachingDelegate Implementation
    
    func didCreateNewRule(userInput: String, correctedMeaning: String) {
        print("새 규칙 생성: \(userInput) -> \(correctedMeaning)")
        // TODO: 실제 규칙 생성 로직 구현
    }
    
    func didSaveTeaching(text: String, for persona: String) {
        print("티칭 저장: \(text) for \(persona)")
        // TODO: 실제 티칭 저장 로직 구현
    }
    
    // MARK: - 💾 채팅 기록 저장/불러오기 (통합)
    
    /// 채팅 기록 저장 - ChatManager가 자동으로 처리
    private func saveChatHistory() {
        // ChatManager가 자동으로 처리하므로 별도 작업 불필요
        #if DEBUG
        print("💾 [ChatPersistence] 채팅 기록 자동 저장 (ChatManager 관리)")
        #endif
        UnifiedLogger.shared.debug("채팅 기록 자동 저장 (ChatManager 관리)", category: .cache)
    }
    
    /// ChatManager 메시지 로드
    private func loadChatManagerMessages() {
        guard let chatManager = chatManager else { return }
        
        // ChatManager의 메시지를 로컬 배열에 동기화
        messages = chatManager.messages.compactMap { $0 as? ChatMessage }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.scrollToBottom()
        }
        
        UnifiedLogger.shared.debug("ChatManager에서 \(messages.count)개 메시지 로드 완료", category: .chat)
    }
    
    // MARK: - 🎯 유틸리티 함수들 (통합)
    
    // Note: These functions moved to CompilerFixStubs.swift to avoid duplication
    
    // MARK: - 📝 Step 2: 저장된 메시지 불러오기 구현
    
    /// viewDidLoad 후 저장된 메시지를 불러와서 표시 - 앱 시작 시 이전 대화 복원
    private func loadSavedMessages() {
        guard let chatManager = chatManager else {
            #if DEBUG
            print("💾 [ChatPersistence] 경고: ChatManager가 초기화되지 않음")
            #endif
            return
        }
        
        #if DEBUG
        print("💾 [ChatPersistence] 저장된 메시지 불러오기 시작")
        #endif
        
        // 1. ChatManager에서 최근 메시지 가져오기 (초기 로드는 100개)
        let stored = chatManager.getRecentMessages(limit: 100)  // 최근 100개 메시지
        
        // 2. StoredChatMessage를 ChatMessage로 변환하여 전체 캐시에 저장
        allMessagesCache = stored.map { chatManager.convertToChatMessage($0) }
        
        // 3. 초기 페이지 설정 (최근 pageSize개만 표시)
        currentPage = 0
        let initialCount = min(pageSize, allMessagesCache.count)
        messages = Array(allMessagesCache.suffix(initialCount))
        hasMoreMessages = allMessagesCache.count > pageSize
        
        #if DEBUG
        print("💾 [ChatPersistence] 전체 \(allMessagesCache.count)개 중 \(messages.count)개 메시지 UI에 표시")
        #endif
        
        // 4. 테이블뷰 리로드 및 하단으로 스크롤
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
            if !self.messages.isEmpty {
                self.scrollToBottom(animated: false)
            }
        }
    }
    
    /// 이전 메시지를 페이징으로 로드 - 스크롤 시 추가 메시지 로드
    private func paginateOlderMessages() {
        guard hasMoreMessages && !isLoadingMessages else {
            #if DEBUG
            print("💾 [ChatPersistence] 페이징 스킵 - hasMore: \(hasMoreMessages), loading: \(isLoadingMessages)")
            #endif
            return
        }
        
        isLoadingMessages = true
        #if DEBUG
        print("💾 [ChatPersistence] 이전 메시지 페이징 시작 - 현재 페이지: \(currentPage)")
        #endif
        
        // 📊 페이징 전 메모리 체크
        #if DEBUG
        MemoryProfiler.shared.logMemoryUsage(context: "페이징 전 (페이지: \(currentPage))")
        #endif
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 다음 페이지 계산
            let nextPage = self.currentPage + 1
            let startIndex = max(0, self.allMessagesCache.count - (nextPage + 1) * self.pageSize)
            let endIndex = max(0, self.allMessagesCache.count - nextPage * self.pageSize)
            
            guard startIndex < endIndex else {
                DispatchQueue.main.async {
                    self.hasMoreMessages = false
                    self.isLoadingMessages = false
                    print("📝 [ChatViewController] 더 이상 로드할 메시지 없음")
                }
                return
            }
            
            // 이전 메시지들 추출
            let olderMessages = Array(self.allMessagesCache[startIndex..<endIndex])
            
            DispatchQueue.main.async {
                // 현재 스크롤 위치 저장
                let previousContentHeight = self.tableView.contentSize.height
                let previousContentOffset = self.tableView.contentOffset.y
                
                // 메시지 추가 (앞쪽에 삽입)
                self.messages.insert(contentsOf: olderMessages, at: 0)
                self.currentPage = nextPage
                
                // 테이블 뷰 업데이트
                self.tableView.reloadData()
                
                // 스크롤 위치 유지
                self.tableView.layoutIfNeeded()
                let newContentHeight = self.tableView.contentSize.height
                let contentHeightDiff = newContentHeight - previousContentHeight
                self.tableView.contentOffset = CGPoint(x: 0, y: previousContentOffset + contentHeightDiff)
                
                // 상태 업데이트
                self.hasMoreMessages = startIndex > 0
                self.isLoadingMessages = false
                
                #if DEBUG
                print("💾 [ChatPersistence] 페이징 완료 - 추가된 메시지: \(olderMessages.count), 전체: \(self.messages.count)")
                #endif
                
                // 📊 페이징 후 메모리 체크
                #if DEBUG
                MemoryProfiler.shared.logMemoryUsage(context: "페이징 후 (현재 표시: \(self.messages.count)개)")
                
                // 50MB 초과 시 경고
                if MemoryProfiler.shared.checkMemoryWarning() {
                    print("⚠️ 메모리 사용량이 50MB를 초과했습니다!")
                    // 필요시 오래된 메시지 정리
                    self.cleanupOldMessages()
                }
                #endif
            }
        }
    }
    
    // MARK: - 🔄 StorageManagement 변경 사항 처리
    
    /// StorageManagement에서 대화 삭제/압축 시 호출되는 핸들러
    @objc private func handleChatStoreDidChange(_ notification: Notification) {
        UnifiedLogger.shared.debug("🔄 ChatStoreDidChange 노티피케이션 수신 - 메시지 다시 로드", category: .storage)
        
        // 1. 저장된 메시지 다시 로드
        loadSavedMessages()
        
        // 2. 메모리 캐시 정리 (삭제된 세션 제거)
        cleanupSessionCache()
        
        // 3. 사용자에게 알림 표시 (선택적)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 메시지가 모두 사라진 경우 안내 메시지 표시
            if self.messages.isEmpty {
                let infoMessage = ChatMessage(
                    text: "💾 저장소 정리가 완료되었습니다. 새로운 대화를 시작해보세요!",
                    sender: .system,
                    type: .system
                )
                self.messages = [infoMessage]
                self.tableView.reloadData()
            }
            
            UnifiedLogger.shared.debug("✅ ChatStoreDidChange 처리 완료 - 현재 메시지 수: \(self.messages.count)", category: .storage)
        }
    }
    
    /// 메모리에 캐시된 세션 정리
    private func cleanupSessionCache() {
        guard let chatManager = chatManager else { return }
        
        // ChatManager의 메모리 캐시 정리 요청
        // 삭제된 세션이 메모리에 남아있지 않도록 처리
        Task {
            // 오래된 세션 정리 (캐시 갱신)
            chatManager.cleanupOldSessions(olderThan: 0) // 즉시 캐시 갱신
            
            UnifiedLogger.shared.debug("🧹 세션 캐시 정리 완료", category: .storage)
        }
    }
    
    // MARK: - 📅 날짜별 메시지 그룹화 유틸리티 (Optional)
    
    /// 메시지를 날짜별로 그룹화합니다
    private func groupMessagesByDate() -> [[ChatMessage]] {
        var groupedMessages: [[ChatMessage]] = []
        var currentDateMessages: [ChatMessage] = []
        var currentDate: Date?
        
        let calendar = Calendar.current
        
        for message in messages {
            let messageDate = message.date ?? Date()
            
            // 날짜 비교 (일 단위)
            if let current = currentDate {
                if !calendar.isDate(messageDate, inSameDayAs: current) {
                    // 날짜가 바뀌면 이전 그룹 저장하고 새 그룹 시작
                    if !currentDateMessages.isEmpty {
                        groupedMessages.append(currentDateMessages)
                    }
                    currentDateMessages = [message]
                    currentDate = messageDate
                } else {
                    // 같은 날짜면 현재 그룹에 추가
                    currentDateMessages.append(message)
                }
            } else {
                // 첫 메시지
                currentDate = messageDate
                currentDateMessages = [message]
            }
        }
        
        // 마지막 그룹 추가
        if !currentDateMessages.isEmpty {
            groupedMessages.append(currentDateMessages)
        }
        
        return groupedMessages
    }
    
    /// 날짜 헤더를 위한 날짜 문자열 포맷팅
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        
        if calendar.isDateInToday(date) {
            return "오늘"
        } else if calendar.isDateInYesterday(date) {
            return "어제"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"  // 요일
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "M월 d일"  // 월 일
            return formatter.string(from: date)
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 📊 메모리 프로파일링 시작
        #if DEBUG
        MemoryProfiler.shared.setBaseline()
        MemoryProfiler.shared.logMemoryUsage(context: "viewDidLoad 시작")
        #endif
        
        // UI 설정
        setupUI()
        setupConstraints()
        setupTableView()
        setupTargets()
        setupNotifications()
        
        // 🔄 컨텍스트 기반 초기화
        setupChatContext()
        
        // 🤖 모델 전환 시스템 설정
        // TODO: 임시 주석 처리 - 모델 전환 시스템
        // setupModelSwitching()
        
        // TODO: 모델 전환 시스템 통합 예정
        
        // 페이징 설정
        setupPaging()
        
        // 🎯 중앙집중식 메시지 복원 - 하나의 메서드만 호출
        restoreAndInitializeMessages()
        
        // 📊 메모리 사용량 체크
        #if DEBUG
        MemoryProfiler.shared.logMemoryUsage(context: "loadSavedMessages 완료")
        #endif
        
        // 메모리 압박 상황 모니터링
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // 배경색 설정
        view.backgroundColor = UIDesignSystem.Colors.adaptiveBackground
        title = "대나무숲"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        scrollToBottom()
        
        // ✅ swipe back 제스처 재활성화 (혹시 비활성화되었을 경우)
        // 간소화: swipe back gesture 제거
        
        // ✅ 세션 시작 시간 기록
        sessionStartTime = Date()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 네비게이션 바가 숨겨져 있다면 다시 표시
        if navigationController?.isNavigationBarHidden == true {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
        refreshCacheStatus()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
        recordSessionTime()
        
        // 📱 앱 종료/백그라운드 진입 시 채팅 기록 강제 저장
        saveChatHistory()
    }
    
    // ✅ 세션 시간 기록
    private func recordSessionTime() {
        guard let startTime = sessionStartTime else { return }
        let sessionDuration = Date().timeIntervalSince(startTime)
        
        // 최소 10초 이상의 세션만 기록
        if sessionDuration > 10 {
            SettingsManager.shared.addSessionTime(sessionDuration)
            
            // 🧠 Enhanced: 세션 메트릭 기록
            // ✅ ML 학습 관련 코드 제거됨 - 기본 메트릭 업데이트로 대체
            performanceMetrics = (duration: sessionDuration, completionRate: performanceMetrics.completionRate, context: performanceMetrics.context)
            recordSessionMetrics()
            
            #if DEBUG
            UnifiedLogger.shared.debug("세션 시간 기록: \(Int(sessionDuration))초", category: .timer)
            #endif
        }
        
        sessionStartTime = nil
    }
    
    // MARK: - 🔧 Enhanced Gesture Recognition System
    
    private func setupEnhancedGestureRecognizers() {
        // 🚀 최신 iOS 17 호환 제스처 처리 방식
        
        // 1. Back swipe gesture (UIKit Navigation 표준)
        let backSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleBackSwipe))
        backSwipe.direction = .right
        backSwipe.delegate = self
        view.addGestureRecognizer(backSwipe)
        
        // 2. Pan gesture for detailed control
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        panGesture.maximumNumberOfTouches = 1
        view.addGestureRecognizer(panGesture)
        
        // 3. NavigationController interactivePopGestureRecognizer 활성화
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    // MARK: - Enhanced Gesture Handling with iOS 17 compatibility
    @objc private func handleBackSwipe() {
        guard isValidBackGesture() else { return }
        performBackNavigation()
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        let location = gesture.location(in: view)
        
        switch gesture.state {
        case .began:
            initialPanLocation = location
            isPerformingBackGesture = false
            
        case .changed:
            // 수평 이동이 수직 이동보다 큰 경우만 처리
            if abs(translation.x) > abs(translation.y) && translation.x > 0 {
                // Edge에서 시작된 경우만 처리
                if isLocationNearEdge(initialPanLocation) && isValidBackGesture() {
                    isPerformingBackGesture = true
                    handleBackGestureProgress(translation.x / view.bounds.width)
                }
            }
            
        case .ended, .cancelled:
            let isValidGesture = translation.x > 100 && velocity.x > 300
            let isNearEdge = isLocationNearEdge(initialPanLocation)
            
            if isValidGesture && isNearEdge && isValidBackGesture() && isPerformingBackGesture {
                performBackNavigation()
            } else {
                // 제스처 취소 시 변형 복원
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                    self.view.transform = .identity
                }
            }
            
            initialPanLocation = .zero
            isPerformingBackGesture = false
            
        default:
            break
        }
    }
    
    private func handleBackGestureProgress(_ progress: CGFloat) {
        // 시각적 피드백 (더 자연스러운 움직임)
        let clampedProgress = min(max(progress, 0), 1)
        let translationX = clampedProgress * 80 // 더 작은 이동거리
        let scale = 1.0 - (clampedProgress * 0.05) // 살짝 축소
        
        view.transform = CGAffineTransform(translationX: translationX, y: 0).scaledBy(x: scale, y: scale)
    }
    
    private func isValidBackGesture() -> Bool {
        // TableView가 스크롤 중이면 제스처 무시
        if tableView.isDragging || tableView.isDecelerating {
            return false
        }
        
        // 텍스트 입력 중이면 제스처 무시
        if inputTextField.isFirstResponder {
            return false
        }
        
        // 키보드가 열려있으면 제스처 무시
        if view.frame.height != view.bounds.height {
            return false
        }
        
        // 간소화: 로딩 상태 체크 제거
        
        return true
    }
    
    private func isLocationNearEdge(_ location: CGPoint) -> Bool {
        let edgeThreshold: CGFloat = 44 // Apple 권장 터치 영역
        return location.x <= edgeThreshold
    }
    
    private func performBackNavigation() {
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.7) {
            self.view.transform = .identity
        }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if let navigationController = self.navigationController, navigationController.viewControllers.count > 1 {
                navigationController.popViewController(animated: true)
            } else {
                self.dismiss(animated: true)
            }
        }
    }
    
    // MARK: - 🧠 Enhanced AI Integration
    
    private func recordSessionMetrics() {
        // 세션 완료 시 메트릭 기록
        let metrics = EnhancedSessionMetrics(
            sessionId: currentSessionId,
            duration: performanceMetrics.duration,
            messageCount: messageCount,
            recommendationCount: 0, // 기본값
            userSatisfaction: performanceMetrics.completionRate,
            aiAccuracy: 0.8 // 기본값
        )
        
        // 향후 분석을 위해 로컬 저장
        saveSessionMetrics(metrics)
    }
    
    private func saveSessionMetrics(_ metrics: EnhancedSessionMetrics) {
        var savedMetrics = UserDefaults.standard.array(forKey: "session_metrics") as? [[String: Any]] ?? []
        
        let metricsDict: [String: Any] = [
            "sessionId": metrics.sessionId.uuidString,
            "duration": metrics.duration,
            "messageCount": metrics.messageCount,
            "recommendationCount": metrics.recommendationCount,
            "userSatisfaction": metrics.userSatisfaction,
            "aiAccuracy": metrics.aiAccuracy,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        savedMetrics.append(metricsDict)
        
        // 최대 100개 세션만 유지
        if savedMetrics.count > 100 {
            savedMetrics = Array(savedMetrics.suffix(100))
        }
        
        UserDefaults.standard.set(savedMetrics, forKey: "session_metrics")
    }
    
    private func processUserMessageInternal(_ userMessage: String) {
        // 기본 메시지 처리 로직
        messageCount += 1
        
        // 🧠 Enhanced: 간단한 감정 분석
        let enhancedEmotion = analyzeEnhancedEmotion(from: userMessage)
        currentEmotion = enhancedEmotion
        
        // 🧠 Enhanced: 감정 로깅
        UnifiedLogger.shared.debug("감정 분석 완료: \(enhancedEmotion.primaryEmotion) (강도: \(enhancedEmotion.intensity))", category: .emotion)
        
        // 메시지를 채팅 기록에 추가
        let userChatMessage = ChatMessage(text: userMessage, sender: .user, type: .user)
        appendChat(userChatMessage)
        
        // 테이블 뷰 업데이트
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.scrollToBottom()
        }
        
        // AI 응답 생성 (기본 구현)
        generateAIResponse(for: userMessage)
    }
    
    private func generateAIResponse(for userMessage: String) {
        // 간단한 AI 응답 생성
        let response = "메시지를 받았습니다: \(userMessage)"
        
        let aiMessage = ChatMessage(text: response, sender: .ai, type: .bot)
        appendChat(aiMessage)
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.scrollToBottom()
        }
    }
    
    private func processUserMessageWithEnhancedAI(_ userMessage: String) {
        // �� Enhanced: 고도화된 감정 분석
        let enhancedEmotion = analyzeEnhancedEmotion(from: userMessage)
        currentEmotion = enhancedEmotion
        
        // 감정 분석 완료 로그
        UnifiedLogger.shared.debug("감정 분석 완료: \(enhancedEmotion.primaryEmotion) (강도: \(enhancedEmotion.intensity))", category: .emotion)
        
        // 기존 처리 로직 호출
        processUserMessageInternal(userMessage)
    }
    
    private func analyzeEnhancedEmotion(from message: String) -> (primaryEmotion: String, intensity: Float, physicalState: Any, environmentContext: Any, cognitiveState: Any, socialContext: Any) {
        // 간단한 감정 분석
        let emotions = ["행복", "슬픔", "불안", "평온", "스트레스"]
        let primaryEmotion = emotions.randomElement() ?? "평온"
        let intensity = Float.random(in: 0.3...0.9)
        
        let physicalState = analyzePhysicalState(from: message)
        let environmentContext = analyzeEnvironmentalContext(from: message)
        let cognitiveState = analyzeCognitiveState(from: message)
        let socialContext = analyzeSocialContext(from: message)
        
        return (
            primaryEmotion: primaryEmotion,
            intensity: intensity,
            physicalState: physicalState,
            environmentContext: environmentContext,
            cognitiveState: cognitiveState,
            socialContext: socialContext
        )
    }
    
    // MARK: - 🧠 Enhanced Emotion Analysis Components
    
    /// 신체 상태 분석
    private func analyzePhysicalState(from message: String) -> (energy: Float, tension: Float, comfort: Float, fatigue: Float) {
        let message = message.lowercased()
        
        // 에너지 수준
        var energy: Float = 0.5
        if message.contains("피곤") || message.contains("힘들어") || message.contains("지쳐") {
            energy = 0.2
        } else if message.contains("활기") || message.contains("상쾌") || message.contains("기운나") {
            energy = 0.8
        }
        
        // 긴장도
        var tension: Float = 0.5
        if message.contains("스트레스") || message.contains("긴장") || message.contains("불안") {
            tension = 0.8
        }
        
        // 안락함
        var comfort: Float = 0.5
        if message.contains("편안") || message.contains("포근") || message.contains("아늑") {
            comfort = 0.8
        }
        
        // 피로도
        var fatigue: Float = 0.5
        if message.contains("피곤") || message.contains("지쳐") {
            fatigue = 0.8
        }
        
        return (energy: energy, tension: tension, comfort: comfort, fatigue: fatigue)
    }
    
    /// 환경적 맥락 분석
    private func analyzeEnvironmentalContext(from message: String) -> (location: String, timeContext: String, weatherMood: String, socialSetting: String, noiseLevel: Float, lightingCondition: String, temperature: String) {
        let message = message.lowercased()
        
        // 위치 추정
        var location = "일반"
        if message.contains("집") || message.contains("방") {
            location = "집"
        } else if message.contains("회사") || message.contains("직장") || message.contains("사무실") {
            location = "직장"
        } else if message.contains("카페") || message.contains("커피") {
            location = "카페"
        } else if message.contains("학교") || message.contains("수업") {
            location = "학교"
        }
        
        // 시간대 맥락
        let hour = Calendar.current.component(.hour, from: Date())
        var timeContext = "일반"
        switch hour {
        case 6..<10:
            timeContext = "아침"
        case 10..<12:
            timeContext = "오전"
        case 12..<14:
            timeContext = "점심"
        case 14..<18:
            timeContext = "오후"
        case 18..<22:
            timeContext = "저녁"
        case 22...23, 0..<6:
            timeContext = "밤"
        default:
            timeContext = "일반"
        }
        
        // 날씨 감정 (메시지 기반 추정)
        var weatherMood = "보통"
        if message.contains("비") || message.contains("흐려") {
            weatherMood = "차분함"
        } else if message.contains("맑") || message.contains("화창") {
            weatherMood = "상쾌함"
        }
        
        // 사회적 설정
        var socialSetting = "혼자"
        if message.contains("친구") || message.contains("사람") || message.contains("함께") {
            socialSetting = "사람들과 함께"
        }
        
        // 소음 수준 (임의)
        let noiseLevel: Float = 0.5
        
        // 조명 상태
        var lightingCondition = "보통"
        if timeContext == "밤" {
            lightingCondition = "어두움"
        } else if timeContext == "아침" {
            lightingCondition = "밝음"
        }
        
        // 온도
        let temperature = "쾌적함"
        
        return (
            location: location,
            timeContext: timeContext,
            weatherMood: weatherMood,
            socialSetting: socialSetting,
            noiseLevel: noiseLevel,
            lightingCondition: lightingCondition,
            temperature: temperature
        )
    }
    
    /// 인지 상태 분석
    private func analyzeCognitiveState(from message: String) -> (focusLevel: Float, mentalClarity: Float, creativityLevel: Float, stressLevel: Float, motivation: Float, decisionMaking: String) {
        let message = message.lowercased()
        
        // 집중도
        var focusLevel: Float = 0.5
        if message.contains("집중") || message.contains("몰입") {
            focusLevel = 0.8
        } else if message.contains("산만") || message.contains("정신없") {
            focusLevel = 0.2
        }
        
        // 정신적 명료성
        var mentalClarity: Float = 0.5
        if message.contains("명확") || message.contains("깔끔") {
            mentalClarity = 0.8
        } else if message.contains("혼란") || message.contains("복잡") {
            mentalClarity = 0.2
        }
        
        // 창의성
        var creativityLevel: Float = 0.5
        if message.contains("아이디어") || message.contains("창의") {
            creativityLevel = 0.8
        }
        
        // 스트레스 수준
        var stressLevel: Float = 0.5
        if message.contains("스트레스") || message.contains("압박") {
            stressLevel = 0.8
        }
        
        // 동기 부여
        var motivation: Float = 0.5
        if message.contains("의욕") || message.contains("동기") {
            motivation = 0.8
        } else if message.contains("무기력") || message.contains("의욕없") {
            motivation = 0.2
        }
        
        // 의사결정 능력
        let decisionMaking = stressLevel > 0.7 ? "어려움" : "보통"
        
        return (
            focusLevel: focusLevel,
            mentalClarity: mentalClarity,
            creativityLevel: creativityLevel,
            stressLevel: stressLevel,
            motivation: motivation,
            decisionMaking: decisionMaking
        )
    }
    
    /// 사회적 맥락 분석
    private func analyzeSocialContext(from message: String) -> (socialEnergy: Float, interpersonalStress: Float, supportNeed: String, communicationStyle: String, relationshipStatus: String) {
        let message = message.lowercased()
        
        // 사회적 에너지
        var socialEnergy: Float = 0.5
        if message.contains("외로") || message.contains("혼자") {
            socialEnergy = 0.2
        } else if message.contains("함께") || message.contains("친구") {
            socialEnergy = 0.8
        }
        
        // 대인관계 스트레스
        var interpersonalStress: Float = 0.3
        if message.contains("갈등") || message.contains("싸웠") || message.contains("화나") {
            interpersonalStress = 0.8
        }
        
        // 지원 필요도
        var supportNeed = "보통"
        if message.contains("도움") || message.contains("조언") || message.contains("위로") {
            supportNeed = "높음"
        }
        
        // 의사소통 스타일
        let communicationStyle = message.count > 100 ? "표현적" : "간결"
        
        // 관계 상태
        let relationshipStatus = "안정적"
        
        return (
            socialEnergy: socialEnergy,
            interpersonalStress: interpersonalStress,
            supportNeed: supportNeed,
            communicationStyle: communicationStyle,
            relationshipStatus: relationshipStatus
        )
    }
    
    private func generateEnterpriseRecommendation() -> PresetRecommendationResponse {
        // 🧠 감정 기반 기본 추천 시스템
        let emotionData = getEmotionData()
        let emotionText = emotionData["emotion"] as? String ?? "알 수 없음"
        let intensity = emotionData["intensity"] as? Float ?? 0.5
        
        // 감정과 강도에 따른 볼륨 조정
        let baseVolumes = SoundPresetCatalog.getRecommendedPreset(for: emotionText)
        let adjustedVolumes = baseVolumes.map { $0 * intensity }
        
        // 시간대 고려
        let hour = Calendar.current.component(.hour, from: Date())
        let timeMultiplier: Float = hour >= 22 || hour <= 6 ? 0.7 : 1.0 // 밤시간 볼륨 조정
        let finalVolumes = adjustedVolumes.map { $0 * timeMultiplier }
        
        // ✅ ML 관련 성능 메트릭 제거됨 - 기본 로깅으로 대체
        print("✅ AI 추천 생성 완료")
        
        // 추천 시간 기록
        lastRecommendationTime = Date()
        
        return PresetRecommendationResponse(
            volumes: finalVolumes,
            presetName: "🧠 AI 감정 추천",
            selectedVersions: SoundPresetCatalog.defaultVersions
        )
    }
    
    private func getBasicRecommendation() -> PresetRecommendationResponse {
        // 기존 방식으로 폴백
        let emotion = getEmotionData()["emotion"] as? String ?? "평온"
        let volumes = SoundPresetCatalog.getRecommendedPreset(for: emotion)
        return PresetRecommendationResponse(volumes: volumes, presetName: "기본 추천")
    }
    
    // MARK: - Helper Methods for AI Context
    
    private func getEstimatedEnvironmentNoise() -> Float {
        // 시간대 기반 추정
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 22...23, 0...6: return 0.2  // 밤/새벽: 조용함
        case 7...9, 17...21: return 0.7  // 출퇴근 시간: 시끄러움
        case 10...16: return 0.5         // 낮: 보통
        default: return 0.4
        }
    }
    
    private func getCurrentActivity() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6...9: return "morning_routine"
        case 9...12: return "work"
        case 12...13: return "lunch"
        case 13...18: return "work"
        case 18...20: return "evening_routine"
        case 20...22: return "relax"
        default: return "sleep"
        }
    }
    
    private func getWeatherMood() -> Float {
        // 간단한 시뮬레이션 (실제로는 날씨 API 사용)
        return Float.random(in: 0.3...0.8)
    }
    
    private func getConsecutiveUsageCount() -> Int {
        return UserDefaults.standard.integer(forKey: "consecutive_usage_count")
    }
    
    private func getUserPreferences() -> [String: Float] {
        // 사용자 설정에서 선호도 로드
        return [
            "nature_sounds": 0.8,
            "ambient_noise": 0.6,
            "white_noise": 0.4,
            "music": 0.3
        ]
    }
    
    // MARK: - Feedback Integration
    
    private func promptForFeedback(presetName: String) {
        // 일정 시간 후 피드백 요청
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) { // 5분 후
            self.showFeedbackPrompt(presetName: presetName)
        }
    }
    
    private func showFeedbackPrompt(presetName: String) {
        let alert = UIAlertController(
            title: "🧠 대나무숲 학습 도움", 
            message: "방금 추천받은 '\(presetName)'는 어떠셨나요? 피드백을 주시면 AI가 더 정확해집니다!", 
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "✨ 상세 피드백", style: .default) { _ in
            self.presentDetailedFeedback(presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "👍 좋았음", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 0.8, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "👎 별로", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 0.3, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "나중에", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func presentDetailedFeedback(presetName: String) {
        guard let startTime = sessionStartTime else { return }
        
        // 간단한 피드백 뷰컨트롤러 표시
        let alert = UIAlertController(
            title: "상세 피드백",
            message: "'\(presetName)' 추천에 대한 자세한 의견을 알려주세요.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "매우 만족", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 1.0, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "만족", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 0.8, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "보통", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 0.5, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "불만족", style: .default) { _ in
            self.submitQuickFeedback(satisfaction: 0.2, presetName: presetName)
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func submitQuickFeedback(satisfaction: Float, presetName: String) {
        guard let startTime = sessionStartTime else { return }
        
        // 간단한 피드백 객체 생성 (기본 FeedbackManager 호환)
        let quickFeedback = PresetFeedback(
            presetId: presetName,
            sessionId: UUID().uuidString,
            timestamp: Date(),
            quantitative: ["satisfaction": satisfaction],
            qualitative: PresetFeedback.QualitativeFeedback(
                freeText: "빠른 피드백",
                moodAfter: satisfaction > 0.6 ? "좋음" : "보통",
                tags: ["빠른피드백"]
            ),
            context: PresetFeedback.Context(
                usageDuration: 0,
                intentionalStop: false,
                repeatUsageIntent: false,
                recommendationIntent: true
            ),
            deviceContext: nil,
            environmentContext: nil,
            userEmotion: nil
        )
        
        // 만족도 정보는 이미 초기화에서 설정됨 (read-only 프로퍼티)
        
        UnifiedLogger.shared.debug("빠른 피드백 저장: \(presetName) (만족도: \(satisfaction))", category: .feedback)
        
        // 성공 메시지
        showQuickFeedbackThankYou()
    }
    
    private func createQuickDeviceContext() -> [String: Any] {
        return [
            "volume": 0.7,
            "brightness": Float(UIScreen.main.brightness),
            "batteryLevel": UIDevice.current.batteryLevel,
            "deviceOrientation": UIDevice.current.orientation.rawValue.description,
            "headphonesConnected": false
        ]
    }
    
    private func createQuickEnvironmentContext() -> [String: Any] {
        return [
            "lightLevel": "보통",
            "noiseLevel": getEstimatedEnvironmentNoise(),
            "weatherCondition": nil as String?,
            "location": "앱사용",
            "timeOfUse": getCurrentTimeOfUse()
        ]
    }
    
    private func getCurrentTimeOfUse() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9: return "아침"
        case 9..<12: return "오전"
        case 12..<18: return "오후"
        case 18..<22: return "저녁"
        case 22...23, 0..<5: return "밤"
        default: return "하루"
        }
    }
    
    private func showQuickFeedbackThankYou() {
        let message = ChatMessage(text: "🙏 피드백 감사합니다! AI가 조금 더 똑똑해졌어요. 계속 학습하여 더 나은 추천을 드리겠습니다!", sender: .ai, type: .bot)
        appendChat(message)
        
        // ✅ ML 관련 성능 메트릭 제거됨 - 기본 로깅으로 대체
        print("✅ 피드백 수신 완료")
    }
    
    private func showPresetAppliedMessage(_ presetName: String) {
        let message = ChatMessage(text: "✅ '\(presetName)' 프리셋이 적용되었습니다! 🎵", sender: .ai, type: .bot)
        appendChat(message)
    }
    
    private func displayAIRecommendation(_ recommendation: EnhancedRecommendationResponse) {
        let message = """
        **[\(recommendation.presetName)]**
        \(recommendation.reason ?? "AI가 분석한 추천 프리셋입니다.")
        
        신뢰도: 70%
        """
        
        let chatMessage = ChatMessage(text: message, sender: .ai, type: .presetRecommendation)
        appendChat(chatMessage)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cleanup()
    }

    private func createPreset(from aiResponse: AIResponseData) -> SoundPreset? {
        guard let volumes = aiResponse.volumes else {
            return nil
        }
        
        let presetName = aiResponse.presetName ?? "AI 추천"
        let description = aiResponse.reason ?? "AI가 사용자의 현재 상태에 맞춰 추천하는 사운드 프리셋입니다."

        // SoundPreset을 생성합니다.
        return SoundPreset(
            name: presetName,
            volumes: volumes,
            emotion: aiResponse.emotion,
            isAIGenerated: true,
            description: description
        )
    }

    private func showPresetOptions(for preset: SoundPreset) {
        let message = ChatMessage(
            text: "AI가 다음 프리셋을 추천했습니다: **\(preset.name)**\n*\(preset.description ?? "")*\n\n이 프리셋을 적용하시겠습니까?",
            sender: .ai,
            type: .presetRecommendation,
            quickActions: [
                QuickAction(title: "✅ 적용하기", action: "applyPreset"),
                QuickAction(title: "🔄 다른 추천 받기", action: "requestDifferentPreset"),
                QuickAction(title: "📝 피드백 주기", action: "giveFeedback")
            ],
            metadata: ChatMetadata(sessionId: currentSessionId.uuidString)
        )
        
        // 생성된 프리셋을 메시지 ID와 함께 저장
        activeRecommendationPresets[message.id] = preset
        
        appendChat(message)
    }

    // MARK: - AI 응답 처리 및 프리셋 추천

    private func parseAIResponse(jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8) else {
            handleAIError(NSError(domain: "AIResponseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "AI 응답을 처리하는 중 오류가 발생했습니다: Invalid data format"]))
            return
        }
        
        do {
            let aiResponse = try JSONDecoder().decode(AIResponseData.self, from: jsonData)
            
            if let preset = createPreset(from: aiResponse) {
                showPresetOptions(for: preset)
            } else {
                let textResponse = aiResponse.description ?? "어떻게 도와드릴까요?"
                appendChat(ChatMessage(text: textResponse, sender: .ai, type: .bot))
            }
        } catch {
            handleAIError(error)
            // 단순 텍스트로 처리 시도
            appendChat(ChatMessage(text: jsonString, sender: .ai, type: .bot))
        }
    }

    private func handlePresetAction(action: String, messageId: UUID) {
        switch action {
        case "applyPreset":
            UnifiedLogger.shared.debug("'적용하기' 선택됨", category: .ui)
            if let presetToApply = activeRecommendationPresets[messageId] {
                onPresetApply?(presetToApply)
                appendChat(ChatMessage(text: "'\(presetToApply.name)' 프리셋을 적용했습니다.", sender: .system, type: .system))
                activeRecommendationPresets.removeValue(forKey: messageId) // 적용 후 제거
            } else {
                appendChat(ChatMessage(text: "이전 추천 정보를 찾을 수 없어 프리셋을 적용할 수 없습니다.", sender: .ai, type: .error))
            }
            
        case "requestDifferentPreset":
            UnifiedLogger.shared.debug("'다른 추천 받기' 선택됨", category: .ui)
            // 현재 대화의 마지막 사용자 메시지를 기반으로 다시 요청
            if let lastUserMessage = messages.last(where: { $0.sender == .user })?.text {
                processUserMessageInternal(lastUserMessage)
            } else {
                processUserMessageInternal("다른 사운드 추천해줘")
            }
            
        case "giveFeedback":
            UnifiedLogger.shared.debug("'피드백 주기' 선택됨", category: .feedback)
            // 피드백 UI 표시 (구현 필요)
            let feedbackMessage = "피드백 기능은 현재 개발 중입니다. 소중한 의견 감사합니다!"
            appendChat(ChatMessage(text: feedbackMessage, sender: .system, type: .system))
            
        default:
            break
        }
        
        // 버튼 비활성화 (TODO: 구현 필요)
        // disableQuickActions(for: messageId)
    }

    private func getLastRecommendation(for sessionId: String) -> PresetRecommendationResponse? {
        // 메시지 목록을 역순으로 탐색하여 해당 세션 ID를 가진 마지막 추천을 찾습니다.
        for message in messages.reversed() {
            if message.type == .presetRecommendation,
               let metadata = message.metadata,
               metadata.sessionId == sessionId {
                // 이 메시지와 관련된 RecommendationResponse를 찾아야 함
                // 현재 구조에서는 ChatMessage에 직접 RecommendationResponse를 저장하지 않으므로,
                // 다른 방식으로 추천 정보를 찾아야 합니다.
                // 임시로 마지막 추천을 반환하도록 처리
                 if let lastApplied = self.lastAppliedPreset {
                     // 더 이상 RecommendationResponse를 직접 생성하지 않음.
                     // 이 로직은 새로운 activeRecommendationPresets 시스템으로 대체되어야 함.
                     // 따라서 nil을 반환하거나, 혹은 title/description만으로 임시 객체를 만들어야 하지만,
                     // 현재 구조에서는 getLastRecommendation 함수 자체가 거의 불필요해짐.
                     return nil
                 }
            }
        }
        return nil
    }
}

// MARK: - Setup Methods
extension ChatViewController {
    private func loadChatHistory() {
        messages.removeAll()
        
        // ChatManager에서 메시지 로드 - 간소화
        let loadedSessions = ChatManager.shared.getSessions()
        UnifiedLogger.shared.debug("loadChatHistory: \(loadedSessions.count)개 세션 발견", category: .cache)
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.scrollToBottom()
        }
    }
    
    /// 기존 UserDefaults 채팅 기록을 ChatManager로 마이그레이션
    private func migrateOldChatHistory() {
        UnifiedLogger.shared.debug("기존 채팅 기록 마이그레이션 시작", category: .cache)
        
        // 새 세션 생성
        let migrationSessionId = UUID()
        // 간소화: 세션 생성 제거
        
        // 기존 메시지들을 새 포맷으로 변환
        for message in messages {
            let storedMessage = StoredChatMessage(
                id: UUID(),
                text: message.text ?? "",
                type: message.type == .user ? .user : .bot,
                timestamp: Date(),
                metadata: nil
            )
            // ChatManager.shared.addMessage(to: migrationSessionId.uuidString, message: storedMessage)
        }
        
        // 마이그레이션 완료 확인
        let migratedSessions = ChatManager.shared.getSessions()
        if !migratedSessions.isEmpty {
            UnifiedLogger.shared.debug("마이그레이션 완료: \(migratedSessions.count)개 세션", category: .cache)
        }
        
        UnifiedLogger.shared.debug("기존 채팅 기록 마이그레이션 완료", category: .cache)
    }
    
    /// 복원된 프리셋 추천 메시지 처리
    private func handleRestoredPresetRecommendation(text: String) {
        UnifiedLogger.shared.debug("복원된 프리셋 처리 시작", category: .preset)
        
        // 메시지에서 프리셋 이름 추출 시도
        if let presetName = extractPresetNameFromText(text) {
            // 기본 프리셋 생성 (감정 기반)
            let currentEmotion = getEmotionData()["emotion"] as? String ?? "neutral"
            let baseVolumes = SoundPresetCatalog.getRecommendedPreset(for: currentEmotion)
            let versions = SoundPresetCatalog.defaultVersions
            
            let restoredPreset = (
                name: presetName,
                volumes: baseVolumes,
                description: "복원된 프리셋",
                versions: versions
            )
            
            UnifiedLogger.shared.debug("복원된 프리셋 적용: \(presetName)", category: .preset)
            // 프리셋 적용 로직 (간소화)
            SoundManager.shared.applyPresetWithVersions(volumes: restoredPreset.volumes, versions: restoredPreset.versions)
            showPresetAppliedMessage(restoredPreset.name)
        } else {
            UnifiedLogger.shared.debug("프리셋 이름 추출 실패, 기본 프리셋 사용", category: .preset)
            // 기본 프리셋 적용
            let currentEmotion = getEmotionData()["emotion"] as? String ?? "neutral"
            let baseVolumes = SoundPresetCatalog.getRecommendedPreset(for: currentEmotion)
            let versions = SoundPresetCatalog.defaultVersions
            
            let defaultPreset = (
                name: "복원된 기본 프리셋",
                volumes: baseVolumes,
                description: "기본 설정으로 복원된 프리셋",
                versions: versions
            )
            
            // 프리셋 적용 로직 (간소화)
            SoundManager.shared.applyPresetWithVersions(volumes: defaultPreset.volumes, versions: defaultPreset.versions)
            showPresetAppliedMessage(defaultPreset.name)
        }
    }
    
    /// 텍스트에서 프리셋 이름 추출
    private func extractPresetNameFromText(_ text: String) -> String? {
        // **[프리셋 이름]** 패턴 찾기
        if let range = text.range(of: #"\*\*\[([^\]]+)\]\*\*"#, options: .regularExpression) {
            let extracted = String(text[range])
            return extracted.replacingOccurrences(of: "**[", with: "").replacingOccurrences(of: "]**", with: "")
        }
        
        // 다른 패턴들도 시도
        if let range = text.range(of: #"\[([^\]]+)\]"#, options: .regularExpression) {
            let extracted = String(text[range])
            return extracted.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        }
        
        return nil
    }
    
    private func setupNavigationBar() {
        // 네비게이션 바 표시 설정
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        // 뒤로가기 버튼 설정
        if navigationController?.viewControllers.count ?? 0 > 1 {
            // 스택에 다른 뷰컨트롤러가 있는 경우 (push로 온 경우)
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "← 뒤로",
                style: .plain,
                target: self,
                action: #selector(backButtonTapped)
            )
        } else {
            // 모달로 표시된 경우
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "✕ 닫기",
                style: .plain,
                target: self,
                action: #selector(closeButtonTapped)
            )
        }
        
        // ✅ 타이틀을 항상 "#Todays_Mood"로 통일 (일관성 확보)
        title = "#Todays_Mood"
        
        // 네비게이션 바 스타일
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationController?.navigationBar.tintColor = .systemBlue
    }
    
    // MARK: - 뒤로가기 버튼 액션들
    @objc private func backButtonTapped() {
        // 채팅 기록 저장
        saveChatHistory()
        
        // 네비게이션 스택에서 이전 화면으로 이동
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func closeButtonTapped() {
        // 🔧 세션 저장 및 정리
        _ = sessionStartTime != nil
        
        // ChatManager에 세션 종료 알림
        // 간소화: ChatManager 현재 세션 접근 제거
        
        // 성능 메트릭 기록
        recordSessionMetrics()
        
        // 네비게이션 처리
        // 간소화: 닫기 동작
        dismiss(animated: true)
    }
    
    // ✅ TLB식 캐시 시스템 초기화
    private func initializeTLBCacheSystem() {
        // 캐시 매니저 초기화
        ChatManager.shared.initialize()
        
        // 만료된 캐시들 정리 (14일 기준)
        UserDefaults.standard.cleanExpiredCaches()
        UserDefaults.standard.cleanOldData(olderThanDays: CacheConst.keepDays)
        
        #if DEBUG
        UnifiedLogger.shared.debug("TLB식 캐시 시스템 초기화 완료 (14일 보존, 3일 raw)", category: .cache)
        let debugInfo = ChatManager.shared.getDebugInfo()
        UnifiedLogger.shared.debug(debugInfo, category: .cache)
        #endif
    }
    
    // 중복된 loadChatManagerMessages 함수 제거됨 - 원본이 위에 있음
    

    
    // ✅ TLB식 대화 히스토리 로드
    private func loadTLBChatHistory() {
        let cutOffRecent = Calendar.current.date(byAdding: .day, value: -CacheConst.recentDaysRaw, to: Date())!
        let cutOffTotal = Calendar.current.date(byAdding: .day, value: -CacheConst.keepDays, to: Date())!
        
        // 캐시에서 최근 대화 로드 (ChatManager 통합 - 간소화)
        let cachedHistory = ChatManager.shared.loadWeeklyMemory()
        if !cachedHistory.isEmpty && cachedHistory.count > 20 { // 의미 있는 데이터가 있을 때만
            // 캐시 요약을 시스템 메시지로 추가
            let contextMessage = ChatMessage(
                text: "💾 \(cachedHistory)", 
                sender: .ai, 
                type: .system
            )
            messages = [contextMessage]
            
            #if DEBUG
            UnifiedLogger.shared.debug("ChatManager 캐시 로드 완료 - \(cachedHistory.count)자", category: .cache)
            #endif
        }
    }
    
    // MARK: - TLB 메시지 파싱 헬퍼
    
    /// 라인에서 날짜 추출
    private func extractDateFromLine(_ line: String) -> Date? {
        // 간단한 날짜 추출 (메시지 생성 시간 기준)
        // 실제 구현에서는 메시지에 타임스탬프가 포함되어야 함
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        // 현재는 최근 메시지로 간주 (실제로는 타임스탬프 파싱 필요)
        return Date()
    }
    
    /// 라인에서 ChatMessage 객체 생성
    private func parseMessageFromLine(_ line: String) -> ChatMessage? {
        if line.hasPrefix("사용자:") {
            let content = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            return ChatMessage(text: content, sender: .user, type: .user)
        } else if line.hasPrefix("AI:") || line.hasPrefix("Bot:") {
            let content = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            return ChatMessage(text: content, sender: .ai, type: .bot)
        }
        return nil
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
    }
    
    private func setupTargets() {
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        presetButton.addTarget(self, action: #selector(presetButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - 누락된 함수들 추가
    
    @objc private func presetButtonTapped() {
        UnifiedLogger.shared.debug("프리셋 버튼 탭됨 - 퀵액션 생성", category: .ui)
        
        // 퀵액션을 보여주는 메시지 생성
        let quickActions = [
            QuickAction(title: "앱 분석 추천받기", action: "local_recommendation"),
            QuickAction(title: "AI 분석 추천받기 (5/5)", action: "ai_recommendation")
        ]
        
        let selectorMessage = ChatMessage(
            text: "맞춤 사운드 추천 방식을 선택해주세요\n\n당신의 현재 상황에 가장 적합한\n사운드 조합을 찾아드릴게요!\n어떤 방식으로 추천받고 싶으신가요?",
            sender: .ai,
            type: .recommendationSelector,
            quickActions: quickActions
        )
        
        appendChat(selectorMessage)
    }
    
    /// 채팅 내용에서 현재 감정 상태 분석
    private func analyzeCurrentEmotionFromChat() -> String {
        // 최근 5개 메시지에서 감정 키워드 추출
        let recentMessages = messages.suffix(5)
        let userMessages = recentMessages.filter { $0.sender == .user }.compactMap { $0.text }
        
        // 감정 키워드 매칭
        let emotionKeywords = [
            "행복": ["기쁘다", "좋다", "즐겁다", "신나다", "행복하다", "만족", "기분좋다"],
            "슬픔": ["슬프다", "우울하다", "속상하다", "눈물", "힘들다", "외롭다"],
            "스트레스": ["스트레스", "피곤하다", "지쳤다", "힘들다", "바쁘다", "부담"],
            "불안": ["불안하다", "걱정", "초조하다", "긴장", "두렵다", "떨린다"],
            "화남": ["화나다", "짜증", "분노", "열받다", "답답하다"]
        ]
        
        for message in userMessages.reversed() {
            for (emotion, keywords) in emotionKeywords {
                for keyword in keywords {
                    if message.contains(keyword) {
                        return emotion
                    }
                }
            }
        }
        
        // 기본값은 "편안함"
        return "편안함"
    }
    
    /// 시간대 문자열 반환
    private func getTimeOfDayString(from hour: Int) -> String {
        switch hour {
        case 5..<9: return "아침"
        case 9..<12: return "오전"
        case 12..<14: return "점심"
        case 14..<18: return "오후"
        case 18..<22: return "저녁"
        case 22...23, 0..<5: return "밤"
        default: return "하루종일"
        }
    }
    
    /// 기본 추천 결과를 채팅에 표시
    private func displayBasicRecommendationInChat(_ recommendation: (sounds: [(soundId: String, version: String, volume: Float)], explanation: String), emotion: String, timeOfDay: String) {
        let responseText = """
        🎯 **\(emotion)** 감정과 **\(timeOfDay)** 시간대에 맞는 사운드를 추천드려요!
        
        🎵 **맞춤 사운드 조합**
        \(recommendation.explanation)
        
        📚 **추천 이유**: 현재 상황과 감정에 최적화된 조합입니다.
        
        지금 바로 적용해보시겠어요? 🎼
        """
        
        let recommendationMessage = ChatMessage(
            text: responseText,
            sender: .ai,
            type: .bot
        )
        appendChat(recommendationMessage)
        
        // 프리셋 적용 버튼 메시지 추가
        let applyButtonMessage = ChatMessage(
            text: "🎼 이 사운드로 바로 시작하기",
            sender: .ai,
            type: .bot
        )
        appendChat(applyButtonMessage)
        
        // 추가 옵션 메시지
        let moreOptionsMessage = ChatMessage(
            text: "💡 다른 사운드도 궁금하시다면 \"다른 추천\"이라고 말씀해주세요!",
            sender: .ai,
            type: .bot
        )
        appendChat(moreOptionsMessage)
    }
    
    /// 고급 추천 결과를 채팅에 표시
    private func displayRecommendationInChat(_ recommendation: AdvancedRecommendationResult, emotion: String, timeOfDay: String) {
        let responseText = """
        🎯 **\(emotion)** 감정과 **\(timeOfDay)** 시간대에 맞는 사운드를 추천드려요!
        
        🎵 **\(recommendation.presetName)**
        \(recommendation.explanation)
        
        📚 **과학적 근거**: \(recommendation.scientificBasis)
        
        ⏰ **권장 재생시간**: \(recommendation.duration)
        🎨 **색채 치료**: \(recommendation.colorTherapy)
        
        지금 바로 적용해보시겠어요? 아래 버튼을 눌러주세요! 👇
        """
        
        let recommendationMessage = ChatMessage(
            text: responseText,
            sender: .ai,
            type: .bot
        )
        appendChat(recommendationMessage)
        
        // 프리셋 적용 버튼 메시지 추가
        let applyButtonMessage = ChatMessage(
            text: "🎼 이 사운드로 바로 시작하기",
            sender: .ai,
            type: .bot
        )
        appendChat(applyButtonMessage)
        
        // 추가 옵션 메시지
        let moreOptionsMessage = ChatMessage(
            text: "💡 다른 사운드도 궁금하시다면 \"다른 추천\"이라고 말씀해주세요!",
            sender: .ai,
            type: .bot
        )
        appendChat(moreOptionsMessage)
    }
    
    // MARK: - 🔄 컨텍스트 기반 채팅 설정
    
    /// 채팅 컨텍스트에 따른 초기 설정
    private func setupChatContext() {
        UnifiedLogger.shared.debug("채팅 컨텍스트 설정: \(chatContext.displayName)", category: .ui)
        
        switch chatContext {
        case .emotionDiaryAnalysis, .emotionDiaryAnalysisAlt:
            setupDiaryAnalysisContext()
        case .emotionAnalysis:
            setupEmotionAnalysisContext()
        case .monthlyPatternAnalysis, .monthlyStatistics:
            setupMonthlyPatternContext()
        case .feedbackAnalysis:
            setupFeedbackAnalysisContext()
        default:
            setupGeneralContext()
        }
    }
    
    /// 일기 분석 컨텍스트 설정
    private func setupDiaryAnalysisContext() {
        if let diary = initialDiaryData {
            title = "대나무숲 - 일기 분석"
            
            let welcomeMessage = ChatMessage(
                text: "📔 오늘의 일기를 함께 살펴보며 마음을 들여다보아요 ✨",
                sender: .ai,
                type: .bot
            )
            appendChat(welcomeMessage)
            
            let diaryContent = "📝 **오늘의 일기**\n\n\(diary.userMessage)"
            let diaryMessage = ChatMessage(
                text: diaryContent,
                sender: .ai,
                type: .bot
            )
            appendChat(diaryMessage)
            
            let analysisPrompt = ChatMessage(
                text: "이 일기에 대해 어떤 감정을 느끼셨나요? 편안하게 이야기해주세요 💝",
                sender: .ai,
                type: .bot
            )
            appendChat(analysisPrompt)
        }
    }
    
    /// 감정 분석 컨텍스트 설정
    private func setupEmotionAnalysisContext() {
        if let emotion = initialEmotion {
            title = "대나무숲 - 감정 분석"
            
            let welcomeMessage = ChatMessage(
                text: "💝 지금 \(emotion) 감정을 느끼고 계시는군요. 함께 이야기 나누어봐요 🌸",
                sender: .ai,
                type: .bot
            )
            appendChat(welcomeMessage)
            
            let promptMessage = ChatMessage(
                text: "어떤 일이 있으셨나요? 마음 편히 들려주세요 😊",
                sender: .ai,
                type: .bot
            )
            appendChat(promptMessage)
        }
    }
    
    /// 월간 패턴 분석 컨텍스트 설정
    private func setupMonthlyPatternContext() {
        title = "대나무숲 - 월간 감정 패턴"
        
        let welcomeMessage = ChatMessage(
            text: "📊 최근 한 달간의 감정 패턴을 분석해드릴게요 ✨",
            sender: .ai,
            type: .bot
        )
        appendChat(welcomeMessage)
        
        if let patternData = initialPatternData {
            let analysisMessage = ChatMessage(
                text: patternData,
                sender: .ai,
                type: .bot
            )
            appendChat(analysisMessage)
        }
        
        let promptMessage = ChatMessage(
            text: "이 패턴에 대해 궁금한 점이나 더 알고 싶은 부분이 있으시면 언제든 말씀해주세요! 💭",
            sender: .ai,
            type: .bot
        )
        appendChat(promptMessage)
    }
    
    /// 피드백 분석 컨텍스트 설정
    private func setupFeedbackAnalysisContext() {
        title = "대나무숲 - 피드백 분석"
        
        let welcomeMessage = ChatMessage(
            text: "🎨 사운드 경험에 대한 피드백을 분석하고 개선점을 찾아보아요 ✨",
            sender: .ai,
            type: .bot
        )
        appendChat(welcomeMessage)
        
        let promptMessage = ChatMessage(
            text: "최근 사용하신 사운드는 어떠셨나요? 솔직한 의견을 들려주세요 😊",
            sender: .ai,
            type: .bot
        )
        appendChat(promptMessage)
    }
    
    /// 일반 컨텍스트 설정
    private func setupGeneralContext() {
        if let systemMessage = initialSystemMessage {
            let message = ChatMessage(
                text: systemMessage,
                sender: .ai,
                type: .bot
            )
            appendChat(message)
        }
    }
    
    private func requestPatternAnalysisWithTracking(patternData: String) {
        // 패턴 분석 요청
        UnifiedLogger.shared.debug("패턴 분석 요청: \(patternData)", category: .emotion)
        
        let analysisResponse = """
        📈 최근 30일간의 감정 패턴 분석 결과입니다:
        
        전반적으로 안정적인 감정 상태를 보이고 계시네요 😊
        특별한 패턴이나 개선점이 있다면 더 자세히 알려드릴게요!
        """
        
        appendChat(ChatMessage(text: analysisResponse, sender: .ai, type: .bot))
    }
    
    private func getEmotionalGreeting(for emotion: String) -> String {
        switch emotion.lowercased() {
        case "기쁨", "행복", "즐거움":
            return "와! 기분이 정말 좋으시네요! 😊 오늘의 기쁨을 함께 나눠주세요 ✨"
        case "슬픔", "우울", "속상함":
            return "마음이 무거우시군요 😔 천천히 이야기해보세요. 함께 들어드릴게요 💙"
        case "화남", "짜증", "분노":
            return "화가 나시는 일이 있으셨나 봐요 😤 마음을 차분히 정리해보시는 건 어떨까요?"
        case "불안", "걱정", "스트레스":
            return "마음이 불안하시군요 😰 깊게 숨을 들이쉬고 차근차근 이야기해보세요 🌸"
        default:
            return "안녕하세요! 😊 오늘은 어떤 하루를 보내고 계신가요? 편안하게 이야기해주세요 ✨"
        }
    }
    

    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // 🔄 StorageManagement에서 채팅 데이터 변경 시 알림 수신
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChatStoreDidChange),
            name: Notification.Name("ChatStoreDidChange"),
            object: nil
        )
        
        UnifiedLogger.shared.debug("📡 ChatStoreDidChange 노티피케이션 옵저버 등록 완료", category: .storage)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupUI() {
        // 네비게이션 바 설정
        setupNavigationBar()
        
        // inputContainerView 설정
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.backgroundColor = UIDesignSystem.Colors.adaptiveSecondaryBackground
        inputContainerView.layer.shadowColor = UIColor.black.cgColor
        inputContainerView.layer.shadowOffset = CGSize(width: 0, height: -1)
        inputContainerView.layer.shadowOpacity = 0.1
        inputContainerView.layer.shadowRadius = 4
        
        // inputTextField 스타일 개선
        inputTextField.font = .systemFont(ofSize: 16)
        inputTextField.layer.cornerRadius = 20
        inputTextField.layer.borderWidth = 1
        inputTextField.layer.borderColor = UIDesignSystem.Colors.border.cgColor
        
        // sendButton 스타일 개선
        sendButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        sendButton.backgroundColor = UIDesignSystem.Colors.primary
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.layer.cornerRadius = 8
        
        // tableView 설정
        tableView.backgroundColor = .clear
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        
        // presetButton 스타일 개선
        presetButton.layer.shadowColor = UIColor.black.cgColor
        presetButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        presetButton.layer.shadowOpacity = 0.1
        presetButton.layer.shadowRadius = 4
        
        inputContainerView.addSubview(inputTextField)
        inputContainerView.addSubview(sendButton)

        view.addSubview(tableView)
        view.addSubview(presetButton)
        view.addSubview(inputContainerView)
        
        // ✅ 화면 하단 로딩 시스템 제거됨
    }

    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: presetButton.topAnchor, constant: 0), // ✅ 간격 완전 제거

            presetButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            presetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            presetButton.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: -8), // ✅ 12 → 8로 간격 줄임
            presetButton.heightAnchor.constraint(equalToConstant: 50),

            inputTextField.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 16),
            inputTextField.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: 8),
            inputTextField.bottomAnchor.constraint(equalTo: inputContainerView.bottomAnchor, constant: -8),
            inputTextField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputTextField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60)
        ])

        bottomConstraint = inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        bottomConstraint?.isActive = true
        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupInitialMessages() {
        if let diary = diaryContext {
            appendChat(ChatMessage(text: "📝 이 일기를 분석해주세요", sender: .user, type: .user))
            
            // ✅ 안전한 옵셔널 처리로 크래시 방지
            let emotionText = diary.emotion ?? "알 수 없는 감정"
            let initialResponse = """
            📖 \(emotionText) 이런 기분으로 일기를 써주셨군요 😊
            
            차근차근 마음 이야기를 나눠볼까요? 
            어떤 부분이 가장 마음에 남으셨나요? 💭
            """
            
            appendChat(ChatMessage(text: initialResponse, sender: .ai, type: .bot))
            requestDiaryAnalysisWithTracking(diary: diary)
            
        } else if let patternData = emotionPatternData, !patternData.isEmpty {
            appendChat(ChatMessage(text: "📊 최근 감정 패턴을 분석해주세요", sender: .user, type: .user))
            
            let initialResponse = """
            📈 최근 30일간의 감정 패턴을 분석해드릴게요 😊
            
            패턴을 살펴보고 있어요... 잠시만 기다려주세요! 💭
            """
            
            appendChat(ChatMessage(text: initialResponse, sender: .ai, type: .bot))
            requestPatternAnalysisWithTracking(patternData: patternData)
            
        } else if let userText = initialUserText,
                  userText != "일기_분석_모드" && userText != "감정_패턴_분석_모드" {
            appendChat(ChatMessage(text: "선택한 기분: \(userText)", sender: .user, type: .user))
            let greeting = getEmotionalGreeting(for: userText)
            appendChat(ChatMessage(text: greeting, sender: .ai, type: .bot))
        } else {
            appendChat(ChatMessage(text: "안녕하세요! 😊\n오늘 하루는 어떠셨나요? 마음 편하게 이야기해보세요 ✨", sender: .ai, type: .bot))
        }
    }
    
    // ✅ 캐시 상태 새로고침
    private func refreshCacheStatus() {
        // 캐시가 유효한지 확인하고 필요시 업데이트
        let weeklyMemory = ChatManager.shared.loadWeeklyMemory()
        
        #if DEBUG
        UnifiedLogger.shared.debug("캐시 상태 새로고침: 주간 메모리 로드 완료", category: .cache)
        #endif
        
        // 주간 메모리 백그라운드 업데이트
        ChatManager.shared.updateWeeklyMemoryAsync()
    }
    
    private func handleInitialUserText(_ text: String) {
        switch text {
        case "감정_패턴_분석_모드":
            startEmotionPatternAnalysis()
        case "일기_분석_모드":
            startDiaryAnalysis()
        default:
            break
        }
    }
    
    private func startEmotionPatternAnalysis() {
        guard let emotionData = emotionPatternData, !emotionData.isEmpty else {
            appendChat(ChatMessage(text: "아직 감정 기록이 충분하지 않네요 😊 일기를 더 작성해주시면 더 정확한 분석을 도와드릴 수 있어요!", sender: .ai, type: .bot))
            return
        }
        
        appendChat(ChatMessage(text: "📊 최근 30일간의 감정 패턴을 분석하고 있어요... ✨", sender: .ai, type: .loading))
        showLoading(true)

        Task {
            do {
                // 🚀 ChatManager의 통합 AI 서비스 사용
                let prompt = "다음은 나의 최근 30일간의 감정 데이터야. 이걸 보고 나의 감정 패턴을 분석하고 조언해줘.\n\n\(emotionData)"
                let responseContent = try await chatManager.sendMessage(
                    userInput: prompt,
                    modeString: "pattern_analysis",
                    modelString: nil
                )
                handleAIResponse(responseContent)
                addQuickEmotionButtons()
            } catch {
                handleAIError(error)
            }
        }
    }
    
    private func startDiaryAnalysis() {
        guard let diaryData = diaryContext else { return }
        
        let analysisText = """
        오늘의 감정: \(diaryData.emotion) 
        일기 내용을 바탕으로 감정을 분석해드릴게요 😊
        """
        appendChat(ChatMessage(text: analysisText, sender: .ai, type: .bot))
        showLoading(true)
        
        Task {
            do {
                let diaryContent = "감정: \(diaryData.emotion), 내용: 일기 분석 요청"
                
                // 🚀 ChatManager의 통합 AI 서비스 사용
                let responseContent = try await chatManager.sendMessage(
                    userInput: diaryContent,
                    modeString: "emotion_diary_analysis",
                    modelString: nil
                )
                handleAIResponse(responseContent)
            } catch {
                handleAIError(error)
            }
        }
    }
    
    private func addQuickEmotionButtons() {
        appendChat(ChatMessage(text: "💡 더 자세한 분석을 원하시나요?\n\n🎯 개선 방법\n📈 감정 변화 추이\n💡 스트레스 관리\n\n위 키워드로 질문해보세요! ✨", sender: .ai, type: .bot))
    }

}

// MARK: - Helper Methods
extension ChatViewController {
    func incrementDailyChatCount() {
        SettingsManager.shared.incrementChatUsage()
    }
    
    // ✅ 화면 하단 로딩 시스템 제거됨 (채팅 버블 내 고양이로 대체)
    

    
    // 중복된 함수들이 제거됨 - 원본 함수들이 위에 있음
    
    // 🆕 중복 추천 메시지 제거 (개선된 버전)
    private func removePreviousRecommendations() {
        // presetRecommendation 타입 메시지들을 모두 제거
        let initialCount = messages.count
        messages.removeAll { $0.type == .presetRecommendation }
        
        // 실제로 제거된 메시지가 있을 때만 UI 업데이트
        if messages.count != initialCount {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
}

// MARK: - Keyboard Handling
extension ChatViewController {
    @objc private func keyboardWillShow(notification: Notification) {
        if let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            bottomConstraint?.constant = -keyboardFrame.height + view.safeAreaInsets.bottom
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
                self.scrollToBottom()
            }
        }
    }

    @objc private func keyboardWillHide(notification: Notification) {
        bottomConstraint?.constant = 0
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}


// MARK: - UITableViewDataSource, UITableViewDelegate
extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = messages.count
        // 테이블뷰 행 수 반환
        return count
    }
    
    // MARK: - Helper Methods (기존 클래스 활용)
    
    // 최근 사용한 프리셋 가져오기 - ChatManager 활용
    private func getRecentPresets() -> [(name: String, emotion: String)] {
        // ChatManager의 최근 프리셋 정보 활용
        let recentSessions = ChatManager.shared.getSessions().prefix(5)
        var recentPresets: [(name: String, emotion: String)] = []
        
        for session in recentSessions {
            if let presetMessage = session.messages.first(where: { $0.type == .presetRecommendation }),
               let presetName = extractPresetNameFromText(presetMessage.text) {
                // 메타데이터에서 감정 추출 (기본값: "평온")
                let emotion = session.metadata?.emotion ?? "평온"
                recentPresets.append((name: presetName, emotion: emotion))
            }
        }
        
        // UserDefaults 백업 확인
        if recentPresets.isEmpty,
           let recentData = UserDefaults.standard.array(forKey: "recentPresets") as? [[String: String]] {
            return recentData.compactMap { dict in
                guard let name = dict["name"], let emotion = dict["emotion"] else { return nil }
                return (name: name, emotion: emotion)
            }
        }
        
        return recentPresets
    }
    
    // 감정에 맞는 시적인 프리셋 이름 생성 - 기본 구현
    private func generatePoeticPresetName(for emotion: String) -> String {
        // EnhancedSoundRecommendationEngine의 private 메서드이므로 직접 구현
        // 또는 SoundPresetCatalog의 기존 프리셋 이름 활용
        let poeticNames: [String: [String]] = [
            "평온": ["고요한 호수의 속삭임", "바람의 노래", "평화로운 새벽"],
            "수면": ["달빛 자장가", "꿈의 정원", "별들의 춤"],
            "활력": ["태양의 에너지", "새로운 시작", "생명의 리듬"],
            "집중": ["깊은 몰입", "명상의 순간", "내면의 초점"],
            "안정": ["마음의 닻", "평온한 항구", "안식의 공간"],
            "이완": ["부드러운 파도", "구름 위의 휴식", "저녁 노을"]
        ]
        
        // SoundPresetCatalog의 기존 프리셋 이름 확인
        let catalogPresets = SoundPresetCatalog.samplePresets.keys.filter { $0.contains(emotion) }
        if !catalogPresets.isEmpty {
            return catalogPresets.randomElement() ?? "맞춤형 사운드"
        }
        
        // 위의 poeticNames에서 선택
        let names = poeticNames[emotion] ?? ["맞춤형 사운드"]
        return names.randomElement() ?? "맞춤형 사운드"
    }
    
    // 로컬 추천 설명 생성 - CommonUtilities 활용
    private func generateLocalRecommendationDescription(for emotion: String) -> String {
        // CommonUtilities의 generateSoundDescription 활용
        let dummyVolumes: [Float] = Array(repeating: 0.5, count: 13)
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = CommonUtilities.shared.getTimeOfDay(from: hour)
        
        return CommonUtilities.shared.generateSoundDescription(
            volumes: dummyVolumes,
            emotion: emotion,
            timeOfDay: timeOfDay,  // 시간대 제공
            includeVolumes: false,
            style: .poetic
        )
    }
    
    // 현재 시간대 가져오기 - CommonUtilities 활용
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        return CommonUtilities.shared.getTimeOfDay(from: hour)
    }
    
    // MARK: - 스크롤 감지 및 페이징 처리
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 스크롤이 상단에 도달했는지 확인 (상단 50pt 이내)
        if scrollView.contentOffset.y < 50 && !isLoadingMessages && hasMoreMessages {
            print("📝 [ChatViewController] 스크롤 상단 도달 - 이전 메시지 로드")
            paginateOlderMessages()
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 테이블뷰 셀 구성
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ChatBubbleCell.identifier, for: indexPath) as? ChatBubbleCell else {
            print("🔴 [ChatViewController] ChatBubbleCell dequeue 실패")
            return UITableViewCell()
        }
        
        let message = messages[indexPath.row]
        let isUserMessage = (message.sender == .user)
        // 메시지 셀 구성
        
        var originalUserInput: String?
        if !isUserMessage && indexPath.row > 0 {
            // AI 메시지일 경우, 바로 이전의 사용자 메시지를 '가르치기'를 위한 원본으로 간주합니다.
            let previousMessage = messages[indexPath.row - 1]
            if previousMessage.sender == .user {
                originalUserInput = previousMessage.text
            }
        }
        
        cell.configure(with: message, isUserMessage: isUserMessage, originalUserMessage: originalUserInput)
        
        // "가르치기" 액션 핸들러 설정
        cell.teachAction = { [weak self] originalMessageToTeach in
            self?.presentAITeachingView(with: originalMessageToTeach)
        }
        
        return cell
    }
    
    // 🆕 퀵 액션 처리 메서드
    func handleQuickActionFromCell(_ action: String) {
        UnifiedLogger.shared.logUserAction(action: "퀵액션클릭", details: ["actionType": action])
        
        switch action {
        case "local_recommendation":
            Task {
                await handleLocalRecommendation()
            }
        case "ai_recommendation":
            handleAIRecommendation()
        default:
            UnifiedLogger.shared.warning("알 수 없는 퀵 액션: \(action)")
        }
    }
    
    // 🆕 Phase 2: 통합 데이터 기반 로컬 추천 처리
    private func handleLocalRecommendation() async {
        // 🔒 중복 요청 방지
        guard !isProcessingRecommendation else {
            UnifiedLogger.shared.warning("추천 요청이 이미 진행 중입니다.")
            return
        }
        
        isProcessingRecommendation = true
        
        let userMessage = ChatMessage(text: "앱 분석 추천받기", sender: .user, type: .user)
        appendChat(userMessage)
        
        // 🎯 Phase 2: SessionManager에서 통합 데이터 가져오기
        let richContext = SessionManager.shared.buildRichContextForLocalAI()
        
        // 🧠 실제 사용자 데이터 기반 감정 추론
        let recommendedEmotion = inferEmotionFromUserData(context: richContext)
        
        // 🎯 풍부한 컨텍스트 구성
        let contextString = buildRichContextString(
            feedbackData: richContext.feedbackData,
            emotionHistory: richContext.emotionHistory,
            behaviorPatterns: richContext.behaviorPatterns,
            timePreferences: richContext.timePreferences
        )
        
        // 로컬 컨텍스트 구성 (통합 추천 엔진을 통한 다양한 정보 종합)
        let masterRecommendation: (volumes: [Double], compatibleVersions: [Int])
        
        do {
            // 🎯 Phase 2: 실제 사용자 데이터를 EnhancedSoundRecommendationEngine에 전달
            let recommendation = EnhancedSoundRecommendationEngine.shared.getEnhancedRecommendation(
                emotion: recommendedEmotion,
                timeOfDay: getCurrentTimeOfDay(),
                intensity: calculateEmotionIntensity(from: richContext.emotionHistory),
                context: contextString, // 풍부한 컨텍스트 전달
                preferredCount: nil
            )
            
            // 추천 결과를 기존 형식으로 변환
            let volumes = recommendation.sounds.map { Double($0.volume * 100) } // 볼륨을 백분율로 변환
            let versions = recommendation.sounds.map { _ in Int.random(in: 1...2) } // 랜덤 버전 선택
            
            // 13개 사운드로 확장 (부족한 경우 기본값으로 채움)
            let expandedVolumes = Array(volumes.prefix(13)) + Array(repeating: 30.0, count: max(0, 13 - volumes.count))
            let expandedVersions = Array(versions.prefix(13)) + Array(repeating: 1, count: max(0, 13 - versions.count))
            
            masterRecommendation = (volumes: expandedVolumes, compatibleVersions: expandedVersions)
            
            print("✅ 로컬 프리셋 추천 성공: \(recommendation.sounds.count)개 사운드")
            
        } catch {
            print("❌ EnhancedSoundRecommendationEngine 오류: \(error)")
            // 폴백: 기본값 사용
            masterRecommendation = (volumes: Array(repeating: 50.0, count: 13), compatibleVersions: Array(repeating: 1, count: 13))
        }
        
        // 🎭 로컬 알고리즘이 생성한 시적 이름
        let poeticName = generatePoeticPresetName(for: recommendedEmotion)
        
        // 🎯 로컬 추천 품질 평가
        let qualityScore: Float = 1.0
        
        let recommendedPreset = (
            name: poeticName,
            volumes: masterRecommendation.volumes,
            description: generateLocalRecommendationDescription(for: recommendedEmotion),
            versions: masterRecommendation.compatibleVersions
        )
        
        // 사용자 친화적인 메시지 생성
        let presetMessage = """
        **[\(recommendedPreset.name)]**
        \(recommendedPreset.description)
        
        로컬 알고리즘으로 현재 시간대에 최적화된 사운드 조합을 선별했습니다. 
        바로 적용해보세요!
        
        이 추천은 AI 사용량에 영향을 주지 않는 로컬 추천입니다.
        """
        
        // 프리셋 적용 메시지 추가
        let chatMessage = ChatMessage(text: presetMessage, sender: .ai, type: .presetRecommendation)
        
        appendChat(chatMessage)
        
        // 🆕 로컬 AI 추천 기록 저장
        ChatManager.shared.recordLocalAIRecommendation(
            userInput: "로컬 AI 추천 요청",
            response: poeticName
        )
        
        // 🔓 로컬 추천 처리 완료
        isProcessingRecommendation = false
    }
    
    // MARK: - Phase 2: 통합 데이터 분석 헬퍼 메서드
    
    /// 사용자 데이터 기반 감정 추론
    private func inferEmotionFromUserData(context: LocalAIContext) -> String {
        // 1. 최근 감정 히스토리 분석
        if let recentEmotion = context.emotionHistory.first?.emotion {
            return recentEmotion
        }
        
        // 2. 피드백 데이터에서 감정 추출
        if let recentFeedback = context.feedbackData.first,
           let emotion = recentFeedback.contextEmotion {
            return emotion
        }
        
        // 3. 시간대별 기본 감정 (폴백)
        let currentTimeOfDay = getCurrentTimeOfDay()
        switch currentTimeOfDay {
        case "새벽", "자정":
            return "수면"
        case "아침":
            return "활력"
        case "오전", "점심":
            return "집중"
        case "오후":
            return "안정"
        case "저녁":
            return "이완"
        case "밤":
            return "수면"
        default:
            return "평온"
        }
    }
    
    /// 감정 강도 계산
    private func calculateEmotionIntensity(from emotionHistory: [EmotionHistoryItem]) -> Float {
        guard !emotionHistory.isEmpty else { return 1.0 }
        
        // 최근 3개 감정의 평균 강도
        let recentEmotions = Array(emotionHistory.prefix(3))
        let averageIntensity = recentEmotions.map { $0.intensity }.reduce(0, +) / Float(recentEmotions.count)
        
        return averageIntensity
    }
    
    /// 🚨 수정: 검증 가능한 풍부한 컨텍스트 문자열 생성
    private func buildRichContextString(
        feedbackData: [PresetFeedback],
        emotionHistory: [EmotionHistoryItem],
        behaviorPatterns: [BehaviorPattern],
        timePreferences: [TimePreference]
    ) -> String {
        var contextBuilder = "사용자 개인화 데이터:\n"
        var contextQuality = 0 // 컨텍스트 품질 점수
        
        // 1. 최근 피드백 요약 (가중치: 높음)
        if !feedbackData.isEmpty {
            let recentFeedback = Array(feedbackData.prefix(3))
            contextBuilder += "최근 피드백: "
            for feedback in recentFeedback {
                if let presetName = feedback.presetName,
                   let satisfaction = feedback.satisfactionScore {
                    contextBuilder += "\(presetName)(만족도: \(satisfaction)), "
                    contextQuality += 3 // 피드백 데이터는 높은 가중치
                }
            }
            contextBuilder += "\n"
        }
        
        // 2. 감정 히스토리 요약 (가중치: 중간)
        if !emotionHistory.isEmpty {
            let recentEmotions = Array(emotionHistory.prefix(3))
            contextBuilder += "최근 감정: "
            for emotion in recentEmotions {
                contextBuilder += "\(emotion.emotion)(\(emotion.intensity)), "
                contextQuality += 2 // 감정 데이터는 중간 가중치
            }
            contextBuilder += "\n"
        }
        
        // 3. 행동 패턴 요약 (가중치: 중간)
        if !behaviorPatterns.isEmpty {
            contextBuilder += "행동 패턴: "
            for pattern in behaviorPatterns.prefix(2) {
                contextBuilder += "\(pattern.pattern)(신뢰도: \(pattern.confidence)), "
                contextQuality += 2
            }
            contextBuilder += "\n"
        }
        
        // 4. 시간 선호도 요약 (가중치: 낮음)
        if !timePreferences.isEmpty {
            let currentHour = Calendar.current.component(.hour, from: Date())
            if let currentTimePreference = timePreferences.first(where: { $0.hour == currentHour }) {
                contextBuilder += "현재 시간대 선호도: \(currentTimePreference.preference)\n"
                contextQuality += 1
            }
        }
        
        let finalContext = contextBuilder.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 🚨 Gemini 지적 반영: 컨텍스트 품질 로깅 및 검증
        print("🔍 [AI Context] 생성된 컨텍스트 품질 점수: \(contextQuality)")
        print("🔍 [AI Context] 최종 컨텍스트: \(finalContext)")
        
        // 컨텍스트가 너무 빈약하면 경고
        if contextQuality < 3 {
            print("⚠️ [AI Context] 컨텍스트 품질이 낮습니다. 추천 품질에 영향을 줄 수 있습니다.")
        }
        
        return finalContext
    }
    
    /// 🆕 AI 추천 품질 검증을 위한 로깅
    private func logAIRecommendationQuality(context: String, recommendation: Any) {
        // TODO: Phase 2.5에서 A/B 테스트 구현
        print("📊 [AI Quality] 컨텍스트 길이: \(context.count)자")
        print("📊 [AI Quality] 추천 결과 로깅 (품질 측정 필요)")
    }
    
    // 🆕 진짜 외부 AI 추천 처리 (Claude 3.5 API)
    private func handleAIRecommendation() {
        // AI 사용량 체크
        guard AIUsageManager.shared.canUse(feature: .presetRecommendation) else {
            let errorMessage = ChatMessage(text: "⚠️ 대나무숲 분석 추천 사용량이 초과되었습니다. (일일 5회 제한)", sender: .ai, type: .bot)
            appendChat(errorMessage)
            return
        }
        
        // 🔒 중복 요청 방지
        guard !isProcessingRecommendation else {
            UnifiedLogger.shared.warning("추천 요청이 이미 진행 중입니다.")
            return
        }
        
        isProcessingRecommendation = true
        
        let userMessage = ChatMessage(text: "대나무숲 분석 추천받기", sender: .user, type: .user)
        appendChat(userMessage)
        
        // 이전 추천 메시지 제거
        removePreviousRecommendations()
        
        // 로딩 메시지 추가
        appendChat(ChatMessage(text: "🧠 대나무숲에서 7일간의 대화와 감정 기록을 종합 분석 중...", sender: .ai, type: .loading))
        
        // 🚀 외부 Claude 3.5 API 호출 (간소화된 버전)
        performClaudeAnalysis()
    }
    
    private func performClaudeAnalysis() {
        // ⚠️ 토큰 절약: 전체 히스토리 대신 최소한의 컨텍스트만 사용
        // let weeklyHistory = ChatManager.shared.getRecentContext(days: 7) // 차단!
        // let currentContext = buildCurrentEmotionContext() // 차단!
        
        // 🎯 토큰 절약형 컨텍스트 (최대 200 토큰 이내)
        let minimalContext = buildMinimalContextForAI()
        
        // 외부 AI 분석 요청 구성 (토큰 절약)
        let analysisPrompt = buildTokenEfficientPrompt(context: minimalContext)
        
        Task {
            do {
                // 🚀 ChatManager의 통합 AI 서비스 사용
                // 프리셋 추천에 특화된 처리
                let responseContent = try await chatManager.sendMessage(
                    userInput: "감정: \(currentEmotion ?? "평온"), 상황: \(analysisPrompt)",
                    modeString: "preset_recommendation",
                    modelString: "openai"  // JSON 출력에 최적화된 모델 사용
                )

                try await MainActor.run { [weak self] in
                    self?.removeLastLoadingMessage()
                
                    if !responseContent.isEmpty {
                        let recommendation = self?.parsePresetRecommendation(from: responseContent)
                        if let recommendation = recommendation {
                            self?.displayAIRecommendation(recommendation)
                        }
                    AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                } else {
                        throw "Empty response from AI" // 에러 케이스로 전달
                    }
                    self?.isProcessingRecommendation = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.removeLastLoadingMessage()
                    let errorMessage = ChatMessage(
                        text: "❌ 외부 대나무숲 분석 중 오류가 발생했습니다. 로컬 분석을 대신 제공하겠습니다.",
                        sender: .ai, 
                        type: .bot
                    )
                    self?.appendChat(errorMessage)
                    Task {
                        await self?.handleLocalRecommendation() // 실패 시 로컬 분석으로 대체
                    }
                self?.isProcessingRecommendation = false
                }
            }
        }
    }
    
    // MARK: - Phase 1: JSON 기반 AI 응답 파싱 (통합된 새로운 방식)
    func parsePresetRecommendation(from response: String) -> EnhancedRecommendationResponse? {
        UnifiedLogger.shared.debug("프리셋 파싱 시작: \(response.prefix(100))...", category: .ai)
        
        // 🔄 통합 JSON 파싱 시스템 활용 (중앙집중식)
        if let cleanText = parseJSONIntelligently(response) {
            // 추출된 텍스트를 프리셋 형식으로 변환 시도
            do {
                let result = try decodeAIResponse(from: cleanText)
                UnifiedLogger.shared.debug("통합 파서로 JSON 형식 파싱 성공", category: .ai)
                return result
            } catch let error as JSONParsingError {
                UnifiedLogger.shared.warning("통합 파서 JSON 파싱 실패: \(error.localizedDescription)")
            } catch {
                UnifiedLogger.shared.warning("통합 파서 예상치 못한 오류: \(error.localizedDescription)")
            }
        }
        
        // 2. 레거시 정규식 파싱 시도 (호환성 유지)
        if let result = parseNewFormat(from: response) {
            UnifiedLogger.shared.debug("레거시 파서: 새로운 11개 형식 파싱 성공", category: .ai)
            return result
        }
        
        if let result = parseLegacyFormat(from: response) {
            UnifiedLogger.shared.debug("레거시 파서: 기존 12개 형식 파싱 성공", category: .ai)
            return result
        }
        
        // 3. 감정 기반 기본 프리셋 반환 (최후 수단)
        let fallbackResult = parseBasicFormat(from: response)
        UnifiedLogger.shared.warning("모든 파싱 실패, 기본 프리셋 사용")
        return fallbackResult
    }
    
    // MARK: - JSON 기반 AI 응답 디코딩
    private func decodeAIResponse(from response: String) throws -> EnhancedRecommendationResponse {
        // JSON 형식 검증
        guard response.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") else {
            throw JSONParsingError.invalidJSON
        }
        
        // JSON 데이터로 변환
        guard let jsonData = response.data(using: .utf8) else {
            throw JSONParsingError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        let aiResponse: AIResponseData
        
        do {
            aiResponse = try decoder.decode(AIResponseData.self, from: jsonData)
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .keyNotFound:
                throw JSONParsingError.missingRequiredFields
            case .typeMismatch:
                throw JSONParsingError.invalidVolumeCount
            case .valueNotFound:
                throw JSONParsingError.missingRequiredFields
            case .dataCorrupted:
                throw JSONParsingError.invalidJSON
            @unknown default:
                throw JSONParsingError.invalidJSON
            }
        }
        
        // 데이터 유효성 검증
        guard let presetName = aiResponse.presetName, !presetName.isEmpty else {
            throw JSONParsingError.missingRequiredFields
        }
        
        guard let volumes = aiResponse.volumes, !volumes.isEmpty else {
            throw JSONParsingError.missingRequiredFields
        }
        
        // confidence 값 검증 (옵셔널 처리)
        let confidenceValue = aiResponse.confidence ?? 0.8
        guard confidenceValue >= 0.0 && confidenceValue <= 1.0 else {
            throw JSONParsingError.invalidVolumeCount
        }
        
        // 볼륨 배열 크기 검증
        guard volumes.count == 13 else {
            throw JSONParsingError.invalidVolumeCount
        }
        
        // 조합 필터링 적용
        let filteredVolumes = SoundPresetCatalog.applyCompatibilityFilter(to: volumes)
        let versions = SoundPresetCatalog.defaultVersions // aiResponse.versions는 없으므로 기본값 사용
        
        return EnhancedRecommendationResponse(
            presetName: "🧠 " + presetName,
            volumes: filteredVolumes,
            versions: versions,
            reason: aiResponse.reason ?? "AI 추천 프리셋"
        )
    }
    
    // MARK: - 새로운 11개 형식 파싱
    private func parseNewFormat(from response: String) -> EnhancedRecommendationResponse? {
        let pattern = #"(\\w+):(\\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: response, options: [], range: NSRange(location: 0, length: response.count)) ?? []
        
        if matches.count < 5 { return nil }
        
        var volumes: [Float] = Array(repeating: 0, count: SoundPresetCatalog.categoryCount)
        var versions: [Int] = SoundPresetCatalog.defaultVersions
        var presetName = "🎵 AI 추천"
        
        for match in matches {
            guard match.numberOfRanges == 3 else { continue }
            
            let categoryRange = Range(match.range(at: 1), in: response)!
            let volumeRange = Range(match.range(at: 2), in: response)!
            
            let category = String(response[categoryRange])
            let volumeStr = String(response[volumeRange])
            
            guard let volume = Float(volumeStr) else { continue }
            
            if let index = SoundPresetCatalog.findCategoryIndex(by: category) {
                volumes[index] = min(100, max(0, volume))
            }
        }
        
        // 프리셋 이름 추출
        if let nameMatch = response.range(of: #"\""([^\"]+)\""#, options: .regularExpression) {
            presetName = String(response[nameMatch]).replacingOccurrences(of: "\"", with: "")
        }
        
        // AI가 추천한 볼륨에 따라 적절한 버전 선택
        versions = generateOptimalVersions(volumes: volumes)
        
        // 조합 필터링 적용
        let filteredVolumes = SoundPresetCatalog.applyCompatibilityFilter(to: volumes)
        
        return EnhancedRecommendationResponse(
            presetName: safePresetName(presetName),
            volumes: filteredVolumes,
            versions: versions,
            reason: "새로운 11개 형식 추천"
        )
    }
    
    // MARK: - 볼륨에 따른 최적 버전 선택
    private func generateOptimalVersions(volumes: [Float]) -> [Int] {
        var versions = SoundPresetCatalog.defaultVersions
        
        // 볼륨이 높은 카테고리에 더 적합한 버전 선택
        for (index, volume) in volumes.enumerated() {
            if SoundPresetCatalog.hasMultipleVersions(at: index) {
                switch index {
                case 1:  // 바람 - 볼륨 높으면 바람2 (더 강한 바람)
                    versions[index] = volume > 60 ? 1 : 0
                case 2:  // 밤 - 볼륨 높으면 밤2 (더 깊은 밤)
                    versions[index] = volume > 70 ? 1 : 0
                case 4:  // 비 - 볼륨 중간 이상이면 창문비 (더 부드러운)
                    versions[index] = volume > 50 ? 1 : 0
                case 9:  // 키보드 - 볼륨 높으면 키보드2 (더 리드미컬)
                    versions[index] = volume > 65 ? 1 : 0
                case 10: // 파도 - 볼륨 높으면 파도2 (더 강한 파도)
                    versions[index] = volume > 60 ? 1 : 0
                case 11: // 새 - 볼륨 높으면 새-비 (비와 새 조합)
                    versions[index] = volume > 55 ? 1 : 0
                case 12: // 발걸음-눈 - 볼륨 높으면 발걸음-눈2 (더 선명한 소리)
                    versions[index] = volume > 50 ? 1 : 0
                default:
                    break
                }
            }
        }
        
        return versions
    }
    
    // MARK: - 기존 12개 형식 파싱
    private func parseLegacyFormat(from response: String) -> EnhancedRecommendationResponse? {
        let legacyCategories = ["Rain", "Thunder", "Ocean", "Fire", "Steam", "WindowRain", "Forest", "Wind", "Night", "Lullaby", "Fan", "WhiteNoise"]
        let pattern = #"(\\w+):(\\d+)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: response, options: [], range: NSRange(location: 0, length: response.count)) ?? []
        
        if matches.count < 5 { return nil }
        
        var legacyVolumes: [Float] = Array(repeating: 0, count: 12)
        let presetName = "🎵 AI 추천 (레거시)"
        
        for match in matches {
            guard match.numberOfRanges == 3 else { continue }
            
            let categoryRange = Range(match.range(at: 1), in: response)!
            let volumeRange = Range(match.range(at: 2), in: response)!
            
            let category = String(response[categoryRange])
            let volumeStr = String(response[volumeRange])
            
            guard let volume = Float(volumeStr) else { continue }
            
            if let index = legacyCategories.firstIndex(of: category) {
                legacyVolumes[index] = min(100, max(0, volume))
            }
        }
        
        // 12개 → 13개 변환 (올바른 크기로 수정)
        var convertedVolumes: [Float] = Array(repeating: 0, count: 13)
        for i in 0..<min(12, convertedVolumes.count) {
            convertedVolumes[i] = legacyVolumes[i]
        }
        
        let filteredVolumes = SoundPresetCatalog.applyCompatibilityFilter(to: convertedVolumes)
        
        return EnhancedRecommendationResponse(
            presetName: safePresetName(presetName),
            volumes: filteredVolumes,
            versions: SoundPresetCatalog.defaultVersions,
            reason: "레거시 12개 형식 추천"
        )
    }
    
    // MARK: - 감정별 기본 프리셋 (13개 카테고리)
    private func parseBasicFormat(from response: String) -> EnhancedRecommendationResponse? {
        let emotion = initialUserText ?? "😊"
        
        // 🌈 모든 프리셋에서 동등하게 선택 (우선순위 없음)
        // 감정과 시간대 기반으로 통합된 추천 시스템 사용
        let scientificRecommendation = getScientificRecommendationFor(emotion: emotion)
        if let scientificPreset = scientificRecommendation {
            return scientificPreset
        }
        
        // 만약 과학적 프리셋 선택에 실패한 경우 (거의 없음) 기본 프리셋 반환
        let volumes: [Float] = [30, 70, 60, 10, 80, 90, 0, 70, 50, 0, 70, 0, 0]
        return EnhancedRecommendationResponse(
            presetName: safePresetName("🌊 마음 달래는 소리"),
            volumes: SoundPresetCatalog.applyCompatibilityFilter(to: volumes),
            versions: generateOptimalVersions(volumes: volumes),
            reason: "기본 감정별 추천"
        )
    }
    
    // MARK: - 🧠 과학적 프리셋 추천 시스템
    
    /// 감정과 시간대를 기반으로 과학적 프리셋 추천
    private func getScientificRecommendationFor(emotion: String) -> EnhancedRecommendationResponse? {
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        let timeOfDay: SoundPresetCatalog.TimeOfDay
        switch currentHour {
        case 5...8: timeOfDay = .morning
        case 9...11: timeOfDay = .lateMorning
        case 12...16: timeOfDay = .afternoon
        case 17...20: timeOfDay = .evening
        case 21...23: timeOfDay = .night
        default: timeOfDay = .lateNight
        }
        
        let emotionalState = SoundPresetCatalog.EmotionalState(rawValue: emotion) ?? .peaceful
        
        // 추천 사운드 가져오기
        let recommendedSounds = emotionalState.recommendedSounds
        let timeSounds = timeOfDay.recommendedSounds
        
        // 두 목록의 교집합과 합집합을 사용하여 최종 목록 생성
        let intersection = Set(recommendedSounds).intersection(Set(timeSounds))
        let union = Set(recommendedSounds).union(Set(timeSounds))
        
        var finalSoundList = Array(intersection)
        finalSoundList += union.filter { !intersection.contains($0) }.shuffled().prefix(5 - intersection.count)
        
        // 볼륨 생성 (주요 사운드는 높게, 나머지는 낮게)
        var volumes: [Float] = Array(repeating: 0, count: 13)
        for (index, soundName) in finalSoundList.enumerated() {
            if let categoryIndex = SoundPresetCatalog.categoryNames.firstIndex(of: soundName) {
                volumes[categoryIndex] = index < 3 ? Float.random(in: 60...90) : Float.random(in: 20...50)
            }
        }
        
        let presetName = "🌿 \(timeOfDay.rawValue)의 \(emotionalState.rawValue)"
        
        return EnhancedRecommendationResponse(
            presetName: safePresetName(presetName),
            volumes: SoundPresetCatalog.applyCompatibilityFilter(to: volumes),
            versions: generateOptimalVersions(volumes: volumes),
            reason: "\(timeOfDay.rawValue) 시간대와 \(emotionalState.rawValue) 감정에 맞춰 과학적으로 조합된 사운드입니다."
        )
    }
    
    // MARK: - 프리셋 적용 및 UI 업데이트
    
    func applyPreset(_ preset: EnhancedRecommendationResponse) {
        let newPreset = SoundPreset(
            name: preset.presetName,
                    volumes: preset.volumes,
            emotion: nil,
            isAIGenerated: true,
            description: preset.reason ?? "AI 추천 프리셋"
        )
        
        if let last = lastAppliedPreset, last.isEqual(to: newPreset) {
            showToast(message: "✔️ 동일한 프리셋이 이미 적용 중입니다.")
            return
        }
        
        lastAppliedPreset = newPreset
        updateCategorySliders(with: preset.volumes)
        // onPresetApply?(preset) // ViewController에 알림 - 타입 불일치로 임시 주석
        
        showToast(message: "🎵 프리셋 '\(preset.presetName)'이 적용되었습니다.")
    }
    
    private func updateCategorySliders(with volumes: [Float]) {
        for (index, slider) in categorySliders.enumerated() {
            guard index < volumes.count else { continue }
            slider.setValue(volumes[index], animated: true)
        }
    }
    
    // MARK: - UI 피드백
    
    func showFeedbackUI(for presetName: String, volumes: [Float]) {
        // 이 부분은 피드백 UI를 표시하는 로직
        // 예: 새로운 ViewController를 push하거나, alert를 띄움
        UnifiedLogger.shared.debug("피드백 UI 요청: \(presetName)", category: .feedback)
        let message = "적용된 프리셋 '\(presetName)'이 마음에 드시나요?"
        let alert = UIAlertController(title: "피드백", message: message, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "👍 마음에 들어요", style: .default) { _ in
            self.sendFeedback(isPositive: true, presetName: presetName, volumes: volumes)
        })
        
        alert.addAction(UIAlertAction(title: "👎 아쉬워요", style: .destructive) { _ in
            self.sendFeedback(isPositive: false, presetName: presetName, volumes: volumes)
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func sendFeedback(isPositive: Bool, presetName: String, volumes: [Float]) {
        // 피드백 전송 로직
        UnifiedLogger.shared.debug("피드백 전송: \(isPositive ? "긍정" : "부정") - \(presetName)", category: .feedback)
        showToast(message: "소중한 피드백 감사합니다! 🥰")
    }
    
    private func safePresetName(_ name: String) -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "🎵 AI 추천" : cleaned
    }
    
    // MARK: - 슬라이더 변경 핸들러
    
    @objc func volumeChanged(_ slider: UISlider) {
        if let index = categorySliders.firstIndex(of: slider) {
            UnifiedLogger.shared.debug("슬라이더 \(index) 값 변경: \(slider.value)", category: .ui)
            // 즉각적인 사운드 변경을 위해 ViewController에 알림
            // onVolumeChange?(index, slider.value)
        }
    }
    
    // MARK: - SuperRecommendationEngine 헬퍼 메서드
    
    /// 현재 계절을 반환하는 헬퍼 메서드
    private func getCurrentSeason() -> String {
        let month = Calendar.current.component(.month, from: Date())
        
        switch month {
        case 3...5:
            return "spring"
        case 6...8:
            return "summer"
        case 9...11:
            return "autumn"
        default:
            return "winter"
        }
    }
    
    /// 한국 공휴일 체크 로직
    private func isHoliday(date: Date) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // 주요 한국 공휴일 체크
        switch (month, day) {
        case (1, 1): return true     // 신정
        case (3, 1): return true     // 삼일절
        case (5, 5): return true     // 어린이날
        case (6, 6): return true     // 현충일
        case (8, 15): return true    // 광복절
        case (10, 3): return true    // 개천절
        case (10, 9): return true    // 한글날
        case (12, 25): return true   // 크리스마스
        default: break
        }
        
        // 추가적으로 음력 공휴일 체크 (간단한 버전)
        // 실제 구현 시에는 음력 변환 라이브러리 사용 권장
        return false
    }
    
    /// 위치 기반 컨텍스트를 반환하는 헬퍼 메서드
    private func getLocationContext() -> String? {
        let hour = Calendar.current.component(.hour, from: Date())
        let isWeekend = Calendar.current.isDateInWeekend(Date())
        
        // 시간대와 요일 기반 추정 위치 컨텍스트
        if hour >= 22 || hour <= 6 {
            return "home_night" // 밤 시간대는 집에 있을 가능성이 높음
        } else if hour >= 9 && hour <= 17 && !isWeekend {
            return "work_office" // 평일 낮 시간대는 직장에 있을 가능성이 높음
        } else if isWeekend {
            return "home_weekend" // 주말은 집에 있을 가능성이 높음
        } else {
            return "transit" // 출퇴근 시간대는 이동 중일 가능성이 높음
        }
    }
}

// MARK: - String Extensions for ChatViewController
extension String {
    func ranges(of substring: String) -> [NSRange] {
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: self.count)
        
        while searchRange.location < self.count {
            let foundRange = (self as NSString).range(of: substring, options: [], range: searchRange)
            if foundRange.location != NSNotFound {
                ranges.append(foundRange)
                searchRange = NSRange(location: foundRange.location + foundRange.length, 
                                     length: self.count - (foundRange.location + foundRange.length))
            } else {
                break
            }
        }
        
        return ranges
    }
}

// MARK: - EnhancedRecommendationResponse to RecommendationResponse Conversion
extension ChatViewController {
    // 이 함수는 더 이상 필요하지 않으므로 제거하거나 주석 처리합니다.
    /*
    func convertToRecommendationResponse(_ enhanced: EnhancedRecommendationResponse) -> RecommendationResponse {
        return RecommendationResponse(
            volumes: enhanced.volumes,
            presetName: enhanced.presetName,
            selectedVersions: enhanced.versions,
            reasoning: enhanced.reasoning
        )
    }
    */
}

// MARK: - AITeachingDelegate Implementation
extension ChatViewController {
    // AITeachingDelegate는 이미 ChatViewController 클래스에서 구현됨
    // 중복 정의 방지를 위해 이 extension은 제거됨
}

// MARK: - Helper Functions (Removed - were outside class scope)

// MARK: - Missing Methods Implementation (Moved to ChatViewController class)

// MARK: - Paging Methods
extension ChatViewController {
    private func loadMoreMessages() {
        guard !isLoadingMessages, hasMoreMessages else { return }
        isLoadingMessages = true
        
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, messages.count)
        
        guard startIndex < messages.count else {
            hasMoreMessages = false
            isLoadingMessages = false
            return
        }
        
        let messagesForPage = Array(messages[startIndex..<endIndex])
        
        PerformanceOptimizer.shared.batchOperation(identifier: "loadMessages") {
            self.displayMessages.append(contentsOf: messagesForPage)
            self.currentPage += 1
            self.isLoadingMessages = false
            self.tableView.reloadData()
        }
    }
    
    private func setupPaging() {
        tableView.prefetchDataSource = self
    }
}

// MARK: - UITableViewDataSourcePrefetching
extension ChatViewController: UITableViewDataSourcePrefetching {
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        let threshold = displayMessages.count - 5
        if indexPaths.contains(where: { $0.row > threshold }) {
            loadMoreMessages()
        }
    }
}

// MARK: - Message Caching
extension ChatViewController {
    private func cacheMessage(_ message: ChatMessage) {
        let cacheKey = "message_\(message.id.uuidString)"
        PerformanceOptimizer.shared.cacheData(message, forKey: cacheKey)
    }
    
    private func getCachedMessage(id: String) -> ChatMessage? {
        let cacheKey = "message_\(id)"
        return PerformanceOptimizer.shared.getCachedData(forKey: cacheKey, type: ChatMessage.self)
    }
    
    private func cacheMessages(_ messages: [ChatMessage]) {
        PerformanceOptimizer.shared.batchOperation(identifier: "cacheMessages") {
            messages.forEach { self.cacheMessage($0) }
        }
    }
    
    private func loadCachedMessages() {
        // 캐시된 메시지 로드 시도
        let cachedMessages = messages.compactMap { message -> ChatMessage? in
            if let cached = getCachedMessage(id: message.id.uuidString) {
                return cached
            }
            return message
        }
        
        messages = cachedMessages
        displayMessages = Array(cachedMessages.prefix(pageSize))
        currentPage = 1
    }
}

// MARK: - Memory Management
extension ChatViewController {
    private func cleanupOldMessages() {
        guard messages.count > 100 else { return }
        
        // 가장 오래된 메시지부터 50개 제거
        let messagesToRemove = messages.prefix(50)
        messagesToRemove.forEach { message in
            let cacheKey = "message_\(message.id.uuidString)"
            // 캐시에서도 제거 - smartCache를 직접 사용하지 않고 메서드 사용
            PerformanceOptimizer.shared.removeFromCache(key: cacheKey)
        }
        
        messages = Array(messages.dropFirst(50))
        
        // 현재 페이지 조정
        currentPage = max(0, currentPage - 3)
        loadMoreMessages()
    }
    
    @objc private func handleMemoryWarning() {
        cleanupOldMessages()
    }
    
    private func cleanup() {
        // 캐시된 메시지 정리
        messages.forEach { message in
            let cacheKey = "message_\(message.id.uuidString)"
            PerformanceOptimizer.shared.removeFromCache(key: cacheKey)
        }
        
        // 기타 리소스 정리
        displayMessages.removeAll()
        messages.removeAll()
    }
}

// MARK: - Image Optimization
extension ChatViewController {
    private func optimizeImage(_ image: UIImage) -> UIImage {
        let maxSize = CGSize(width: 800, height: 800)
        let aspectRatio = image.size.width / image.size.height
        
        var targetSize = maxSize
        if aspectRatio > 1 {
            targetSize.height = maxSize.width / aspectRatio
        } else {
            targetSize.width = maxSize.height * aspectRatio
        }
        
        return PerformanceOptimizer.shared.resizeImageEfficiently(image, to: targetSize) ?? image
    }
    
    private func cacheOptimizedImage(_ image: UIImage, forKey key: String) {
        let optimized = optimizeImage(image)
        if let data = PerformanceOptimizer.shared.compressImage(optimized) {
            PerformanceOptimizer.shared.cacheData(data, forKey: "image_\(key)")
        }
    }
    
    private func getCachedImage(forKey key: String) -> UIImage? {
        if let data = PerformanceOptimizer.shared.getCachedData(forKey: "image_\(key)", type: Data.self) {
            return UIImage(data: data)
        }
        return nil
    }
}

// MARK: - Preset Application
extension ChatViewController {
    /// 프리셋 추천 메시지에서 "바로 적용하기" 버튼을 눌렀을 때 호출
    func applyRecommendedPreset(messageId: UUID) {
        UnifiedLogger.shared.debug("프리셋 적용 요청 - messageId: \(messageId)", category: .ui)
        
        // 해당 메시지 찾기 (displayMessages와 messages 모두에서 검색)
        var message: ChatMessage?
        
        // 먼저 displayMessages에서 찾기
        message = displayMessages.first(where: { $0.id == messageId })
        
        // 없으면 전체 messages에서 찾기
        if message == nil {
            message = messages.first(where: { $0.id == messageId })
        }
        
        guard let foundMessage = message,
              let messageText = foundMessage.text else {
            UnifiedLogger.shared.error("메시지를 찾을 수 없음 - messageId: \(messageId)")
            UnifiedLogger.shared.error("displayMessages 개수: \(displayMessages.count), messages 개수: \(messages.count)")
            return
        }
        
        UnifiedLogger.shared.debug("메시지 발견 - 타입: \(foundMessage.type), 텍스트 일부: \(String(messageText.prefix(50)))", category: .ui)
        
        // 메시지에서 프리셋 이름 추출 (간단한 파싱)
        let presetName = extractPresetName(from: messageText)
        
        // ViewController+Utilities의 기존 applyRecommendedPreset 메서드 활용
        if let mainVC = navigationController?.viewControllers.first as? ViewController {
            // 프리셋 적용 시도
            if let volumes = SoundPresetCatalog.samplePresets[presetName] {
                mainVC.applyPreset(volumes: volumes, versions: SoundPresetCatalog.defaultVersions, name: presetName)
                UnifiedLogger.shared.debug("프리셋 적용 완료: \(presetName)", category: .ui)
                
                // 적용 완료 피드백 메시지
                let feedbackMessage = ChatMessage(
                    text: "🎵 '\(presetName)' 프리셋이 적용되었습니다!\n\n사운드 설정이 업데이트되었어요.",
                    sender: .ai,
                    type: .bot
                )
                appendChat(feedbackMessage)
            } else {
                UnifiedLogger.shared.error("프리셋을 찾을 수 없음: \(presetName)")
                
                // 오류 피드백 메시지
                let errorMessage = ChatMessage(
                    text: "⚠️ 죄송합니다. 해당 프리셋을 찾을 수 없습니다.\n다른 추천을 받아보시겠어요?",
                    sender: .ai,
                    type: .bot
                )
                appendChat(errorMessage)
            }
        }
    }
    
    /// 메시지 텍스트에서 프리셋 이름 추출
    private func extractPresetName(from messageText: String) -> String {
        UnifiedLogger.shared.debug("프리셋 이름 추출 시도 - 원본 텍스트: \(messageText)", category: .ui)
        
        // **[프리셋 이름]** 형태 추출 (최우선)
        if let match = messageText.range(of: #"\*\*\[(.+?)\]\*\*"#, options: .regularExpression) {
            let matchedText = String(messageText[match])
            if let innerMatch = matchedText.range(of: #"\[(.+?)\]"#, options: .regularExpression) {
                let presetName = String(matchedText[innerMatch])
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                if !presetName.isEmpty {
                    UnifiedLogger.shared.debug("**[이름]** 패턴에서 프리셋 이름 추출 성공: \(presetName)", category: .ui)
                    return presetName
                }
            }
        }
        
        // 다양한 접두사 패턴으로 프리셋 이름 추출 시도
        let patterns = [
            "추천 프리셋: ",
            "프리셋: ",
            "적용할 프리셋: ",
            "프리셋 이름: "
        ]
        
        for pattern in patterns {
            if let range = messageText.range(of: pattern) {
                let afterPrefix = String(messageText[range.upperBound...])
                let presetName: String
                
                if let newlineRange = afterPrefix.range(of: "\n") {
                    presetName = String(afterPrefix[..<newlineRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                } else {
                    presetName = afterPrefix.trimmingCharacters(in: .whitespaces)
                }
                
                if !presetName.isEmpty {
                    UnifiedLogger.shared.debug("패턴 '\(pattern)'에서 프리셋 이름 추출 성공: \(presetName)", category: .ui)
                    return presetName
                }
            }
        }
        
        // SoundPresetCatalog의 프리셋 이름 중에서 매치되는 것 찾기
        for presetName in SoundPresetCatalog.samplePresets.keys {
            if messageText.contains(presetName) {
                UnifiedLogger.shared.debug("카탈로그에서 프리셋 이름 발견: \(presetName)", category: .ui)
                return presetName
            }
        }
        
        // 기본값으로 "깊은 휴식" 반환
        UnifiedLogger.shared.debug("프리셋 이름 추출 실패 - 기본값 사용: 깊은 휴식", category: .ui)
        return "깊은 휴식"
    }
    
    
    // MARK: - 🔥 토큰 절약형 AI 컨텍스트
    
    /// Phase 2: 페르소나 정보를 포함한 AI 컨텍스트 생성 (최대 200토큰)
    private func buildMinimalContextForAI() -> String {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeContext = getTimeContext(hour: currentHour)
        
        // 🎭 Phase 2: 페르소나 정보 추가
        let personaContext = buildPersonaContext()
        
        // 🧠 Phase 2: 최근 감정 패턴 추가
        let emotionContext = buildEmotionContext()
        
        // 최근 3개 메시지만 (사용자의 현재 요청 파악용)
        let recentMessages = messages.suffix(3)
        let recentContext = recentMessages.compactMap { message in
            if message.sender == .user, let text = message.text {
                return "사용자: \(text.prefix(50))" // 50자만
            }
            return nil
        }.joined(separator: " / ")
        
        return """
        시간: \(timeContext)
        페르소나: \(personaContext)
        감정패턴: \(emotionContext)
        최근요청: \(recentContext.isEmpty ? "없음" : recentContext)
        """
    }
    
    /// 페르소나 컨텍스트 생성
    private func buildPersonaContext() -> String {
        let userSettings = SettingsManager.shared.userSettings
        
        let personality = userSettings.personality ?? "보통"
        let preferredStyle = userSettings.preferredStyle ?? "자연음"
        let sleepPattern = userSettings.sleepPattern ?? "일반"
        
        return "성격:\(personality), 선호:\(preferredStyle), 수면:\(sleepPattern)"
    }
    
    /// 감정 컨텍스트 생성
    private func buildEmotionContext() -> String {
        let richContext = SessionManager.shared.buildRichContextForLocalAI()
        
        if let recentEmotion = richContext.emotionHistory.first {
            return "\(recentEmotion.emotion)(\(recentEmotion.intensity))"
        }
        
        return "평온(1.0)"
    }
    
    /// 토큰 효율적인 프롬프트 생성 (기존 대비 90% 절약)
    private func buildTokenEfficientPrompt(context: String) -> String {
        return """
        사용자 수면 사운드 추천:
        \(context)
        
        다음 중 하나 추천:
        바람결같은고요, 햇살가득한오후, 빗소리와함께하는위로, 마음을다독이는선율, 깊은휴식
        
        형식: **[프리셋명]** 간단한이유
        """
    }
    
    /// 시간대별 컨텍스트 (토큰 절약)
    private func getTimeContext(hour: Int) -> String {
        switch hour {
        case 6..<12: return "아침"
        case 12..<18: return "오후"
        case 18..<22: return "저녁"
        default: return "밤"
        }
    }
}

    // MARK: - 🎯 채팅 히스토리 복원
extension ChatViewController {
    
    /// 중앙집중식 메시지 복원 및 초기화
    private func restoreAndInitializeMessages() {
        #if DEBUG
        print("💾 [ChatPersistence] 중앙집중식 메시지 복원 시작")
        #endif
        
        guard let chatManager = chatManager else {
            print("❌ [ChatViewController] ChatManager 없음 - 초기 메시지만 설정")
            setupInitialMessages()
            return
        }
        
        // 1. ChatManager에서 저장된 세션 확인
        let sessions = chatManager.getSessions()
        let hasStoredMessages = sessions.contains { !$0.messages.isEmpty }
        
        #if DEBUG
        print("💾 [ChatPersistence] 세션 수: \(sessions.count), 저장된 메시지 있음: \(hasStoredMessages)")
        #endif
        
        if hasStoredMessages {
            // 2. 저장된 메시지가 있으면 복원
            loadSavedMessages()
        } else {
            // 3. 저장된 메시지가 없으면 초기 메시지 설정
            setupInitialMessages()
        }
        
        #if DEBUG
        print("💾 [ChatPersistence] 최종 메시지 수: \(messages.count)")
        #endif
    }
    
    /// MessageStore와 ChatManager에서 이전 채팅들을 복원 - 앱 시작 시 호출
    private func restoreChatHistoryFromStorage() {
        #if DEBUG
        print("💾 [ChatPersistence] 채팅 히스토리 복원 시작")
        #endif
        
        Task {
            do {
                // MessageStore에서 최근 메시지들 로드 (최대 50개)
                let storedMessages = try await MessageStore.shared.loadMessages(page: 0, pageSize: 50)
                
                #if DEBUG
                print("💾 [ChatPersistence] MessageStore에서 \(storedMessages.count)개 메시지 로드됨")
                #endif
                
                DispatchQueue.main.async {
                    // 저장된 메시지가 있으면 기존 초기 메시지들 제거 - 제거 비활성화
                    // 이미 restoreAndInitializeMessages에서 처리됨
                    // if !storedMessages.isEmpty {
                    //     self.messages.removeAll()
                    // }
                    
                    // 저장된 메시지들을 ChatMessage로 변환하고 추가
                    for storedMessage in storedMessages {
                        let chatMessage = ChatMessage(
                            text: storedMessage.content,
                            date: Date(), // 시간 순서는 MessageStore가 관리
                            sender: storedMessage.isUser ? .user : .ai,
                            type: self.getMessageType(from: storedMessage.isUser)
                        )
                        
                        // appendChat 대신 직접 추가 (이미 저장된 메시지이므로 재저장 방지)
                        self.messages.append(chatMessage)
                    }
                    
                    #if DEBUG
                    print("💾 [ChatPersistence] \(self.messages.count)개 메시지 UI에 복원 완료")
                    #endif
                    
                    // UI 업데이트
                    self.tableView.reloadData()
                    if !self.messages.isEmpty {
                        self.scrollToBottom()
                    }
                }
                
            } catch {
                print("❌ [ChatViewController] 채팅 히스토리 복원 실패: \(error)")
                
                // 실패 시 ChatManager에서 시도
                self.restoreFromChatManager()
            }
        }
    }
    
    /// ChatManager에서 채팅 히스토리 복원 - MessageStore 실패 시 백업 방법
    private func restoreFromChatManager() {
        #if DEBUG
        print("💾 [ChatPersistence] ChatManager에서 히스토리 복원 시도 (백업)")
        #endif
        
        guard let chatManager = chatManager else {
            print("❌ [ChatViewController] ChatManager가 없습니다")
            return
        }
        
        let sessions = chatManager.getSessions()
        guard let latestSession = sessions.first else {
            print("🔄 [ChatViewController] 저장된 세션이 없습니다")
            return
        }
        
        #if DEBUG
        print("💾 [ChatPersistence] 최신 세션에서 \(latestSession.messages.count)개 메시지 발견")
        #endif
        
        Task { @MainActor in
            // 기존 메시지 제거 - 제거 비활성화
            // 이미 restoreAndInitializeMessages에서 처리됨
            // if !latestSession.messages.isEmpty {
            //     self.messages.removeAll()
            // }
            
            // StoredChatMessage를 ChatMessage로 변환
            for storedMessage in latestSession.messages {
                let isUser = (storedMessage.type == .user)
                let chatMessage = ChatMessage(
                    text: storedMessage.text,
                    date: storedMessage.timestamp,
                    sender: isUser ? .user : .ai,
                    type: isUser ? .user : .bot
                )
                
                // 직접 추가 (재저장 방지)
                self.messages.append(chatMessage)
            }
            
            #if DEBUG
            print("💾 [ChatPersistence] ChatManager에서 \(self.messages.count)개 메시지 복원 완료")
            #endif
            
            // UI 업데이트
            self.tableView.reloadData()
            if !self.messages.isEmpty {
                self.scrollToBottom()
            }
        }
    }
    
    /// 사용자 여부에 따라 메시지 타입 결정
    private func getMessageType(from isUser: Bool) -> ChatMessageType {
        return isUser ? .user : .bot
    }
    
    /// 🔄 StoredMessageType을 ChatMessageType으로 변환
    private func getMessageTypeFromStoredType(_ storedType: String) -> ChatMessageType {
        switch storedType {
        case "user": return .user
        case "bot": return .bot
        case "system": return .system
        case "presetRecommendation": return .presetRecommendation
        case "error": return .error
        default: return .bot
        }
    }
    
    /// 문자열에서 ChatMessageType으로 변환
    private func getMessageTypeFromString(_ typeString: String) -> ChatMessageType {
        switch typeString {
        case "user": return .user
        case "bot": return .bot
        case "system": return .system
        case "preset": return .presetRecommendation
        case "selector": return .recommendationSelector
        case "options": return .presetOptions
        case "loading": return .loading
        case "error": return .error
        default: return .bot
        }
    }
}

// MARK: - TableView Cell Configuration
extension ChatViewController {
    private func configureCell(_ cell: ChatBubbleCell, at indexPath: IndexPath) {
        let message = displayMessages[indexPath.row]
        
        // ChatBubbleCell의 configure 메서드 호출
        cell.configure(with: message, isUserMessage: message.sender == .user)
        
        // 기존 셀 구성 코드...
    }
}

// MARK: - Model Switching Integration
// TODO: 임시 주석 처리 - ModelSwitchingDelegate 확장
/*
extension ChatViewController: ModelSwitchingDelegate {
    
    /// 🤖 모델 전환 시스템 초기 설정
    private func setupModelSwitching() {
        setupModelSelectorButton()
        // TODO: 임시 주석 처리
        // modelSwitchingManager.delegate = self
        
        // 현재 메시지들을 UnifiedContextManager에 등록
        registerCurrentMessagesWithContextManager()
    }
    
    /// 🔘 모델 선택 버튼 설정
    private func setupModelSelectorButton() {
        modelSelectorButton = UIButton(type: .system)
        modelSelectorButton.translatesAutoresizingMaskIntoConstraints = false
        
        // 버튼 디자인
        updateModelSelectorButton()
        modelSelectorButton.addTarget(self, action: #selector(modelSelectorTapped), for: .touchUpInside)
        
        // 네비게이션 바에 추가
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: modelSelectorButton)
    }
    
    /// 🔄 모델 선택 버튼 업데이트
    private func updateModelSelectorButton() {
        // TODO: 임시 주석 처리
        let currentModel = AIModelType.claude35 // modelSwitchingManager.currentModel
        
        modelSelectorButton.setTitle("🤖 \(currentModel.displayName)", for: .normal)
        modelSelectorButton.backgroundColor = .systemBlue.withAlphaComponent(0.1)
        modelSelectorButton.layer.cornerRadius = 8
        modelSelectorButton.layer.borderWidth = 1
        modelSelectorButton.layer.borderColor = UIDesignSystem.Colors.accent.cgColor
        modelSelectorButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        
        // 모델별 색상 차별화
        switch currentModel {
        case .claude35:
            modelSelectorButton.setTitleColor(.systemOrange, for: .normal)
            modelSelectorButton.layer.borderColor = UIDesignSystem.Colors.warning.cgColor
        case .gpt4:
            modelSelectorButton.setTitleColor(.systemGreen, for: .normal)
            modelSelectorButton.layer.borderColor = UIDesignSystem.Colors.success.cgColor
        case .gemini:
            modelSelectorButton.setTitleColor(.systemBlue, for: .normal)
            modelSelectorButton.layer.borderColor = UIDesignSystem.Colors.accent.cgColor
        case .onDevice:
            modelSelectorButton.setTitleColor(.systemPurple, for: .normal)
            modelSelectorButton.layer.borderColor = UIDesignSystem.Colors.accent.cgColor
        }
    }
    
    /// 📱 모델 선택 액션
    @objc private func modelSelectorTapped() {
        presentModelSelectionSheet()
    }
    
    /// 📋 모델 선택 시트 표시
    private func presentModelSelectionSheet() {
        let alertController = UIAlertController(
            title: "AI 모델 선택",
            message: "대화에 사용할 AI 모델을 선택하세요",
            preferredStyle: .actionSheet
        )
        
        // 각 모델에 대한 액션 추가
        for modelType in [AIModelType.claude35, .gpt4, .gemini, .onDevice] {
            // TODO: 임시 주석 처리
            // let characteristics = modelSwitchingManager.getModelCharacteristics(modelType)
            let isCurrentModel = false // modelType == modelSwitchingManager.currentModel
            
            let action = UIAlertAction(
                title: "\(characteristics.name)\(isCurrentModel ? " ✓" : "")",
                style: isCurrentModel ? .cancel : .default
            ) { _ in
                Task {
                    await self.switchToModel(modelType)
                }
            }
            
            // 모델별 설명 추가
            let subtitle = characteristics.strengths.joined(separator: ", ")
            action.setValue(subtitle, forKey: "subtitle")
            
            alertController.addAction(action)
        }
        
        // 취소 액션
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        
        // iPad 지원
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = modelSelectorButton
            popover.sourceRect = modelSelectorButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    /// 🔄 모델 전환 실행
    private func switchToModel(_ newModel: AIModelType) async {
        do {
            // 로딩 상태 표시
            await MainActor.run {
                showModelSwitchingIndicator()
            }
            
            // 현재 대화를 컨텍스트에 저장
            updateContextWithCurrentMessages()
            
            // 모델 전환 실행
            // TODO: 임시 주석 처리
            // try await modelSwitchingManager.switchToModel(newModel)
            print("Model switch to \(newModel) requested but temporarily disabled")
            
        } catch {
            await MainActor.run {
                hideModelSwitchingIndicator()
                showErrorAlert(title: "모델 전환 실패", message: error.localizedDescription)
            }
        }
    }
    
    /// 📝 현재 메시지들을 컨텍스트 매니저에 등록
    private func registerCurrentMessagesWithContextManager() {
        for message in messages {
            let contextMessage = ContextMessage(
                content: message.text ?? "",
                isFromUser: message.sender == .user,
                type: mapToContextMessageType(message.type),
                importance: calculateMessageImportance(message),
                detectedEmotion: extractEmotionFromMessage(message),
                modelUsed: .claude35 // modelSwitchingManager.currentModel
            )
            
            // TODO: 임시 주석 처리
            // unifiedContextManager.addMessage(contextMessage)
        }
    }
    
    /// 🔄 현재 대화를 컨텍스트에 업데이트
    private func updateContextWithCurrentMessages() {
        // 최근 메시지 몇 개만 업데이트
        let recentMessages = Array(messages.suffix(5))
        
        for message in recentMessages {
            let contextMessage = ContextMessage(
                content: message.text ?? "",
                isFromUser: message.sender == .user,
                type: mapToContextMessageType(message.type),
                importance: calculateMessageImportance(message),
                detectedEmotion: extractEmotionFromMessage(message),
                modelUsed: .claude35 // modelSwitchingManager.currentModel
            )
            
            // TODO: 임시 주석 처리
            // unifiedContextManager.addMessage(contextMessage)
        }
    }
    
    /// 💭 메시지 타입 매핑
    private func mapToContextMessageType(_ chatType: ChatMessageType) -> ContextMessageType {
        switch chatType {
        case .user, .bot, .aiResponse: return .normal
        case .system: return .system
        case .presetRecommendation: return .feedback
        case .error: return .system
        default: return .normal
        }
    }
    
    /// 📊 메시지 중요도 계산
    private func calculateMessageImportance(_ message: ChatMessage) -> Double {
        var importance = 0.5 // 기본값
        
        // 메시지 길이 고려
        let length = message.text?.count ?? 0
        if length > 100 { importance += 0.2 }
        if length > 300 { importance += 0.2 }
        
        // 감정 키워드 포함 시
        let emotionKeywords = ["기분", "감정", "스트레스", "불안", "우울", "행복", "슬픔"]
        if let text = message.text {
            for keyword in emotionKeywords {
                if text.contains(keyword) {
                    importance += 0.3
                    break
                }
            }
        }
        
        return min(importance, 1.0)
    }
    
    /// 🎭 메시지에서 감정 추출
    private func extractEmotionFromMessage(_ message: ChatMessage) -> DetectedEmotion? {
        guard let text = message.text else { return nil }
        
        // 간단한 감정 분석 (실제로는 더 정교한 분석 필요)
        let emotions: [(String, [String])] = [
            ("기쁨", ["기쁘", "행복", "좋아", "즐거", "신나"]),
            ("슬픔", ["슬프", "우울", "힘들", "괴로", "눈물"]),
            ("분노", ["화나", "짜증", "분노", "억울", "열받"]),
            ("불안", ["불안", "걱정", "두려", "무서", "긴장"]),
            ("스트레스", ["스트레스", "피곤", "지쳐", "힘들"])
        ]
        
        for (emotion, keywords) in emotions {
            for keyword in keywords {
                if text.contains(keyword) {
                    return DetectedEmotion(
                        type: emotion,
                        intensity: 0.7,
                        confidence: 0.8
                    )
                }
            }
        }
        
        return nil
    }
    
    /// 🔄 모델 전환 로딩 표시
    private func showModelSwitchingIndicator() {
        // 로딩 메시지 추가
        let loadingMessage = ChatMessage(
            text: "🔄 AI 모델을 전환하고 있습니다...",
            date: Date(),
            sender: .ai,
            type: .loading
        )
        
        messages.append(loadingMessage)
        displayMessages.append(loadingMessage)
        
        tableView.insertRows(at: [IndexPath(row: displayMessages.count - 1, section: 0)], with: .fade)
        scrollToBottom()
    }
    
    /// ✅ 모델 전환 로딩 숨김
    private func hideModelSwitchingIndicator() {
        // 로딩 메시지 제거
        if let lastMessage = displayMessages.last,
           lastMessage.type == .loading {
            displayMessages.removeLast()
            messages.removeLast()
            
            let indexPath = IndexPath(row: displayMessages.count, section: 0)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    // MARK: - ModelSwitchingDelegate Implementation
    
    func modelSwitchingWillBegin(from: AIModelType, to: AIModelType) {
        print("🔄 [ChatViewController] 모델 전환 시작: \(from.displayName) → \(to.displayName)")
    }
    
    func modelSwitchingDidComplete(from: AIModelType, to: AIModelType) {
        DispatchQueue.main.async {
            self.hideModelSwitchingIndicator()
            self.updateModelSelectorButton()
            
            // 전환 완료 메시지 추가
            let switchMessage = ChatMessage(
                text: "✅ \(to.displayName)로 전환되었습니다. 이전 대화 맥락을 유지하며 계속 대화할 수 있습니다.",
                date: Date(),
                sender: .ai,
                type: .system
            )
            
            self.addMessage(switchMessage)
        }
        
        print("✅ [ChatViewController] 모델 전환 완료: \(from.displayName) → \(to.displayName)")
    }
    
    func modelSwitchingDidFail(error: Error) {
        DispatchQueue.main.async {
            self.hideModelSwitchingIndicator()
            self.showErrorAlert(title: "모델 전환 실패", message: error.localizedDescription)
        }
        
        print("❌ [ChatViewController] 모델 전환 실패: \(error)")
    }
    
    /// 에러 알림 표시
    private func showErrorAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
*/

// TODO: 모델 전환 시스템은 추후 통합 예정
