import AVFoundation
import Combine
import Foundation
import SwiftUI
import UIKit

// MARK: - Missing Types
enum JSONParsingError: Error {
    case invalidJSON
    case missingRequiredFields
    case invalidVolumeCount
}

// MARK: - SharedCore 타입들 사용 (중복 제거 완료)
// 모든 공통 타입들은 SharedCore.swift에서 사용

// SharedCore 타입들을 직접 사용 (typealias 제거)

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

class ChatViewController: UIViewController, UIGestureRecognizerDelegate {
    // 중복 분석 트리거 방지
    private var didStartDiaryAnalysis: Bool = false
    // MARK: - Properties
    private let sessionManager = SessionManager.shared  // 🎯 통합 세션 관리자
    // (정리) 과거 'UsageGate 제거' 주석 제거. SSOT: UsageGate를 통해서만 사용량 확인/증가.
    var messages: [ChatMessage] = []
    /// displayMessages 호환용 (기존 코드 참조 유지) - 실제 저장은 messages 단일화
    private var displayMessages: [ChatMessage] {
        get { messages }
        set { messages = newValue }
    }

    /// 특정 세션을 불러와 이어서 대화하기 위한 ID (옵션)
    var resumeSessionId: String?
    // 에페메랄 세션 여부(과거 대화 복원/재개/오버라이드 비활성)
    var isEphemeralSession: Bool = false
    var initialUserText: String?
    var diaryContext: DiaryContext?

    // Resume/Override session handling state
    private var hasShownResumeAlert = false
    private var didAdoptSessionOverride = false
    private var overrideHintLabel: UILabel?
    private var currentLoadedSessionId: String?
    var emotionPatternData: String?
    var onPresetApply: ((SoundPreset) -> Void)?
    private var sessionStartTime: Date?
    private var messageCount = 0
    private let maxMessages = 150  // ✅ 사용자 요구 반영: 한 화면 유지 최대 150개 (동적 윈도우)
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
    // 일기 분석 사전 소비 여부(버튼 즉시 반영용)
    var diaryAnalysisPreConsumed: Bool = false

    // 🧠 Enhanced AI Properties
    private var currentSessionId = UUID()
    private var lastRecommendationTime: Date?
    private var currentEmotion: Any?
    private var feedbackPendingPresets: [UUID: String] = [:]
    // ✅ ML 학습 관련 코드 제거됨 - 기본 성능 메트릭으로 대체
    private var performanceMetrics = (
        duration: TimeInterval(0), completionRate: Float(0.5), context: [String: Any]()
    )

    // 🔒 중복 요청 방지 플래그
    private var isProcessingRecommendation = false
    // 추천 메시지와 페이로드 연결(바로 적용하기용)
    private var presetPayloads: [UUID: EnhancedRecommendationResponse] = [:]

    // 🎵 활성 추천 프리셋 임시 저장소
    private var activeRecommendationPresets: [UUID: SoundPreset] = [:]

    // MARK: - Paging Properties
    private let pageSize = 20
    private var currentPage = 0
    private var isLoadingMessages = false
    private var hasMoreMessages = true

    // 동적 페이징 상태
    private var lastPaginationTime: Date?
    private var consecutiveFastPaginations: Int = 0

    // UI/메인스레드 디바운스(100ms 내 합치기)
    private var reloadDebounceWorkItem: DispatchWorkItem?
    private var showLoadingDebounceWorkItem: DispatchWorkItem?
    private let uiDebounceInterval: TimeInterval = 0.1
    private var memoryLogWorkItem: DispatchWorkItem? // throttled post-runloop memory logging

    // 구독 상태에 따른 UI 갱신
    private func updateUIForSubscriptionStatus() {
        // 중앙 UsageGate 경유 (SSOT)
        let status = UsageGate.shared.checkUsage(for: .generalConversation)
        let canAccess = status.canUse
        sendButton.isEnabled = canAccess
        inputTextField.isEnabled = canAccess
    }
    // displayMessages 제거 - messages 배열로 통합 (DRY 원칙)

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
    // MARK: - 입력 길이 제한 및 1일 1회 예외(400토큰) 처리
    private func effectiveMaxPromptLength() -> Int {
        // 기본은 Security/AppConfig 경유. 누락 시 합리적 기본값 1000자
        let configured = AppConfig.Security.maxPromptLength
        return configured > 0 ? configured : 1000
    }

    private func hasUsedDailyOnceExtension() -> Bool {
        let key = "prompt_len_once_extension_used_" + todayKey()
        return UserDefaults.standard.bool(forKey: key)
    }

    private func markDailyOnceExtensionUsed() {
        let key = "prompt_len_once_extension_used_" + todayKey()
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - 메모리 관리 최적화

    /// 메모리 정리: 오래된 메시지 제거 및 가비지 컬렉션
    private func performMemoryCleanup() {
        #if DEBUG
            print("🧹 [ChatViewController] 메모리 정리 시작")
        #endif

        // 1. 메시지 수가 maxMessages를 초과하면 오래된 메시지 제거
        if messages.count > maxMessages {
            let excessCount = messages.count - maxMessages
            let removedMessages = Array(messages.prefix(excessCount))
            messages.removeFirst(excessCount)

            #if DEBUG
                print("🧹 [ChatViewController] \(excessCount)개 오래된 메시지 제거됨")
            #endif
        }

        // 2. 프리셋 페이로드 정리 (1시간 이상 된 것)
        let oneHourAgo = Date().addingTimeInterval(-3600)
        presetPayloads = presetPayloads.filter { _, payload in
            // EnhancedRecommendationResponse에 timestamp가 없으므로 전체 정리
            false  // 모든 오래된 페이로드 제거
        }

        // 3. 활성 추천 프리셋 정리
        activeRecommendationPresets.removeAll()

        // 4. 피드백 대기 프리셋 정리
        feedbackPendingPresets.removeAll()

        #if DEBUG
            print("🧹 [ChatViewController] 메모리 정리 완료 - 현재 메시지 수: \(messages.count)")
        #endif
    }

    /// 페이징 로드 시 메모리 정리
    private func performPagingMemoryCleanup() {
        // 페이징으로 새 메시지가 추가된 후 메모리 정리
        performMemoryCleanup()

        // 테이블뷰 셀 재사용을 위한 명시적 리로드
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }

    private func todayKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private func handleOverMaxLengthInput(_ text: String) {
        let maxLen = effectiveMaxPromptLength()
        let alert = UIAlertController(
            title: "입력이 너무 길어요",
            message: "최대 \(maxLen)자까지만 입력할 수 있어요.",
            preferredStyle: .alert
        )

        if !hasUsedDailyOnceExtension() {
            alert.addAction(
                UIAlertAction(title: "이번에만 봐줄까요? (400토큰)", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    self.markDailyOnceExtensionUsed()
                    let trimmed = String(text.prefix(maxLen))
                    self.requestWithTokenOverride(originalText: trimmed, overrideMaxTokens: 400)
                })
        } else {
            // 이미 1일 1회 예외를 사용한 경우 안내만
            alert.message = "오늘은 이미 1회 예외를 사용했어요. 이게 최대입니다!"
        }

        alert.addAction(UIAlertAction(title: "확인", style: .cancel))
        present(alert, animated: true)
    }

    private func requestWithTokenOverride(originalText text: String, overrideMaxTokens: Int) {
        // 토큰 상한(출력)을 일시적으로 400으로 상향하여 한 번만 허용
        addMessageToChat(message: text, fromUser: true)
        showLoading(true)

        Task {
            do {
                let aiMode = determineAIModeFromContext()
                let selectedModel = mapAIModelTypeToAIModel(SettingsManager.shared.selectedLLM)
                let baseCfg = aiMode.recommendedTokenConfig
                let overrideCfg = TokenConfiguration(
                    maxTokens: overrideMaxTokens,
                    temperature: baseCfg.temperature,
                    topP: baseCfg.topP,
                    frequencyPenalty: baseCfg.frequencyPenalty,
                    presencePenalty: baseCfg.presencePenalty,
                    responseFormat: baseCfg.responseFormat
                )

                let response = try await SessionManager.shared.sendMessage(
                    content: text,
                    mode: aiMode,
                    saveMessages: true,
                    sessionId: nil,
                    policyMeta: ["onceTokenExtension": "1", "date": todayKey()],
                    tokenConfigOverride: overrideCfg
                )
                await MainActor.run {
                    self.handleAIResponse(response.content)
                }
            } catch {
                await MainActor.run {
                    self.handleAIError(error)
                }
            }
        }
    }

    private func routeAIRequest(message: String, completion: @escaping (String?) -> Void) {
        // 1. 입력 복잡도 분석
        let complexity = analyzeInputComplexity(message)

        // 2. 시스템 상태 확인
        let batteryLevel = UIDevice.current.batteryLevel
        let isLowBattery = batteryLevel < 0.2 && batteryLevel > 0

        // 3. 라우팅 결정
        let shouldUseLocal = shouldUseLocalAI(
            complexity: complexity, batteryLevel: batteryLevel, isLowBattery: isLowBattery)

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
        let hasComplexQuestions =
            message.contains("왜") || message.contains("어떻게") || message.contains("분석")
        let hasEmotionalContext =
            message.contains("느낌") || message.contains("기분") || message.contains("감정")
        let requiresCreativeResponse =
            message.contains("추천") || message.contains("제안") || message.contains("도움")

        var complexity: Float = 0.0
        complexity += Float(tokenCount) * 0.1
        complexity += hasComplexQuestions ? 0.3 : 0.0
        complexity += hasEmotionalContext ? 0.2 : 0.0
        complexity += requiresCreativeResponse ? 0.2 : 0.0

        return min(complexity, 1.0)  // 0.0 ~ 1.0 범위로 정규화
    }

    /// 로컬 AI 사용 여부 결정
    private func shouldUseLocalAI(complexity: Float, batteryLevel: Float, isLowBattery: Bool)
        -> Bool
    {
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
                let selectedModel = mapAIModelTypeToAIModel(SettingsManager.shared.selectedLLM)
                let aiMode = self.determineAIModeFromContext()
                let response = try await SessionManager.shared.sendMessage(
                    content: message,
                    model: selectedModel,
                    mode: aiMode,
                    saveMessages: true
                )

                // 메인 스레드에서 UI 업데이트
                await MainActor.run {
                    self.showLoading(false)
                    let parsedResponse = self.parseAIResponse(response)
                    // ✅ 저장과 UI 갱신은 여기서만 수행
                    self.appendChat(
                        ChatMessage(text: parsedResponse, date: Date(), sender: .ai, type: .bot))
                    UnifiedLogger.shared.info("SessionManager 통합 AI 응답 완료", category: .ai)
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
        // 중앙 파서로 일원화 (DRY)
        let provider: AIProvider = .openrouter  // 통합 free_model 경로 포함, 기본값을 openrouter로 취급
        let parsed = AIResponseParser.shared.parse(response, from: provider)
        return parsed
    }

    /// 🎯 지능형 JSON 파싱 - (Deprecated) 개별 파서
    @available(*, deprecated, message: "Use AIResponseParser.shared.parse instead")
    private func parseJSONIntelligently(_ response: String) -> String? {
        var trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // ```json 블록 처리
        if trimmed.hasPrefix("```json") && trimmed.hasSuffix("```") {
            trimmed =
                trimmed
                .replacingOccurrences(of: "```json\n", with: "")
                .replacingOccurrences(of: "\n```", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if trimmed.hasPrefix("```") && trimmed.hasSuffix("```") {
            // 일반 코드 블록 처리
            trimmed =
                trimmed
                .replacingOccurrences(of: "```\n", with: "")
                .replacingOccurrences(of: "\n```", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // JSON 형식 확인
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
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
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
                print(
                    "ℹ️ [ChatViewController] 경미한 보안 이슈 감지하지만 허용: \(validationResult.securityIssues)")
            }
        }

        return validationResult.sanitizedValue
            ?? text.trimmingCharacters(in: .whitespacesAndNewlines)
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
                if let match = regex.firstMatch(
                    in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.count)),
                    let range = Range(match.range(at: 1), in: cleaned)
                {
                    let extractedText = String(cleaned[range])
                    print("🔧 [ChatViewController] 정규식으로 텍스트 추출: \(extractedText.prefix(50))...")
                    return extractedText
                }
            }

            // 정규식 실패 시 JSON 아티팩트 제거
            cleaned =
                cleaned
                .replacingOccurrences(of: "\\\"", with: "\"")  // 이스케이프 따옴표
                .replacingOccurrences(of: "\\n", with: "\n")  // 이스케이프 개행
                .replacingOccurrences(of: "\\t", with: " ")  // 이스케이프 탭

            // 간단한 JSON 구조 정리
            if cleaned.contains("\"message\":") {
                cleaned = cleaned.replacingOccurrences(
                    of: "^\\{.*\"message\"\\s*:\\s*\"", with: "", options: .regularExpression)
                cleaned = cleaned.replacingOccurrences(
                    of: "\".*\\}$", with: "", options: .regularExpression)
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
            "\"content\"\\s*:\\s*\"([^\"]+)\"",
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
        // 0) 사전 소비 플래그가 없는 경우에만 게이트 검사(지문/총 한도)
        if !diaryAnalysisPreConsumed {
            if DiaryUsagePolicy.hasUsedToday(diary) {
                appendChat(ChatMessage(text: "✅ 오늘 이 일기에 대한 분석은 이미 진행했어요. 다른 일기를 선택해 보세요.", sender: .ai, type: .bot))
                return
            }
            guard AIUsageManager.shared.canUse(feature: .diaryAnalysis) else {
                let total = AIUsageManager.shared.getTotalLimit(for: .diaryAnalysis)
                appendChat(ChatMessage(text: "⛔️ 오늘 일기 분석 한도(총 \(total)회)를 모두 사용했어요. 내일 다시 시도해 주세요.", sender: .ai, type: .bot))
                return
            }
        }
        // 최근 3일 이내 일기만 분석 허용
        if let d = diary.date {
            let cal = Calendar.current
            if let threeDaysAgo = cal.date(byAdding: .day, value: -3, to: Date()) {
                if d < threeDaysAgo {
                    appendChat(
                        ChatMessage(
                            text: "⏳ 최근 3일 이내의 일기만 분석할 수 있어요. 더 최근 일기를 선택해 주세요.", sender: .ai,
                            type: .bot))
                    return
                }
            }
        }

        appendChat(ChatMessage(text: "분석하고 있어요...", sender: .ai, type: .loading))

        Task {
            do {
                // 정책 고정: 일기 분석은 Gemini로 호출(사용자 모델 설정과 무관)
                let response = try await SessionManager.shared.sendMessage(
                    content: diary.content,
                    model: .gemini,
                    mode: .emotionDiaryAnalysis,
                    saveMessages: true
                )

                // SessionManager 저장은 비활성화했으므로, 여기서만 UI/저장 처리
                await MainActor.run {
                    self.removeLastLoadingMessage()
                    self.handleAIResponse(response)

                    // ✅ 오늘의 일기 분석 기록 저장 (캘린더 ‘대나무숲 친구 답변’에서 사용)
                    let parsed = self.parseAIResponse(response)
                    SettingsManager.shared.appendDiaryAnalysis(parsed, for: Date())
                    // ✅ 사용량/지문 반영
                    if !self.diaryAnalysisPreConsumed {
                        DiaryUsagePolicy.markUsedToday(diary)
                        _ = AIUsageManager.shared.recordUsage(for: .diaryAnalysis)
                    }

                    // 분석 결과에 대한 추가 안내 메시지
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.appendChat(
                            ChatMessage(
                                text: "💡 이 분석 결과에 대해 더 궁금한 점이 있으면 언제든 질문해주세요!", sender: .ai,
                                type: .bot))
                    }
                }
            } catch {
                // 메인 스레드에서 에러 처리
                await MainActor.run {
                    self.removeLastLoadingMessage()
                    self.appendChat(
                        ChatMessage(text: "❌ 분석에 실패했어요. 잠시 후 다시 시도해주세요.", sender: .ai, type: .bot))
                }
            }
        }
    }

    // MARK: - 💬 메시지 전송 처리 (리팩토링 완료)

    @objc func sendButtonTapped() {
        print("🔵 [ChatViewController] sendButtonTapped() 호출됨")
        guard let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            print("🔴 [ChatViewController] 입력 텍스트가 비어있음")
            return
        }

        // 중앙 게이트로 무료/유료 분기 (무료 한도 초과 시 페이월 표시)
        let (canChat, reason) = EntitlementGate.canAccess(.chat)
        if !canChat {
            print("🛑 [ChatViewController] Chat 게이트 차단 - reason: \(reason)")
            EntitlementUI.require(.chat, from: self)
            return
        }

        // 입력 길이 제한 검사 및 1일 1회 예외 처리(400 토큰 확장)
        let maxLen = effectiveMaxPromptLength()
        if text.count > maxLen {
            handleOverMaxLengthInput(text)
            return
        }

        // 사용자가 실제로 입력을 시작한 순간, resumeSessionId 또는 SettingsManager override를 적용
        adoptOverrideSessionIfNeeded()

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
                print(
                    "🎯 [ChatViewController] 현재 컨텍스트: '\(chatContext.displayName)' → AI 모드: \(aiMode.rawValue)"
                )

                let selectedModel = mapAIModelTypeToAIModel(SettingsManager.shared.selectedLLM)
                let response = try await SessionManager.shared.sendMessage(
                    content: message,
                    model: selectedModel,
                    mode: aiMode,
                    saveMessages: true
                )

                handleAIResponse(response)
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
        let maxHistoryCount = 5  // 최근 5개 메시지만 포함

        let recentMessages =
            messages
            .filter { message in
                message.type != .loading
                    && (message.text?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        .isEmpty == false)
            }
            .suffix(maxHistoryCount)

        return recentMessages.compactMap { message -> String? in
            guard let text = message.text, !text.isEmpty else { return nil }
            let role = message.sender == .user ? "사용자" : "AI"
            return "\(role): \(text)"
        }
    }

    /// 🎯 중앙집중형 메시지 추가 메서드 (단일) - 통합 appendBatch(allowLoading/scroll 옵션) 사용
    private func appendChat(_ message: ChatMessage) {
        appendBatch([message], allowLoading: true, scrollToBottom: true)
    }

    /* DEPRECATED (Merged into unified enforceMemoryWindow below)
     기존 1차 enforceMemoryWindow 구현 제거됨. 새 구현은 파일 하단(두 번째 정의 위치)에 통합.
     - 기능: 메시지 개수 상한 + 메모리 경고 + runloop 지연 측정
     */

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
        // Centralized wrapper → always routes through appendBatch for DRY
        print("🟡 [ChatViewController] addMessageToChat 호출됨 - fromUser=\(fromUser) len=\(message.count)")
        let msg = ChatMessage(
            text: message,
            date: Date(),
            sender: fromUser ? .user : .ai,
            type: fromUser ? .user : .bot
        )
        appendBatch([msg], allowLoading: false, scrollToBottom: true)
    }

    /// 봇 메시지를 채팅에 추가합니다
    override func addBotMessage(_ message: String) {
        print("🤖 [ChatViewController] addBotMessage 호출됨 - len=\(message.count)")
        let botMessage = ChatMessage(
            text: message,
            date: Date(),
            sender: .ai,
            type: .bot
        )
        appendBatch([botMessage], allowLoading: false, scrollToBottom: true)
    }

    /// 로딩 상태를 표시하거나 숨깁니다
    private func showLoading(_ show: Bool) {
        print("⏳ [ChatViewController] showLoading 호출됨 - show: \(show)")
        DispatchQueue.main.async {
            if show {
                print("⏳ [ChatViewController] 로딩 메시지 추가")
                let loadingMessage = ChatMessage(
                    text: "",
                    date: Date(),
                    sender: .ai,
                    type: .loading
                )
                self.appendBatch([loadingMessage], allowLoading: true, scrollToBottom: false)
                print("⏳ [ChatViewController] 로딩 메시지 추가됨 - 메시지 수: \(self.messages.count)")
            } else {
                // 중앙집중식 로딩 메시지 제거
                self.removeAllLoadingMessages()
            }
            print("⏳ [ChatViewController] tableView.reloadData() 호출")
            self.debouncedReload()
            print("⏳ [ChatViewController] showLoading 완료")
        }
    }

    /// 테이블뷰를 맨 아래로 스크롤합니다
    private func scrollToBottom(animated: Bool = true) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 최신 테이블 데이터 소스 기준(이미 reload 이전이면 rows는 이전 상태)
            let rows = self.tableView.numberOfRows(inSection: 0)
            guard rows > 0 else {
                print("🔴 [ChatViewController] (scrollToBottom) 행이 없어 스크롤 생략")
                return
            }
            let lastRow = rows - 1
            // 방어: out-of-bounds 예방 (메시지 추가 직후 trim/삭제 경쟁 상황 대비)
            if lastRow < 0 { return }
            let indexPath = IndexPath(row: lastRow, section: 0)
            // 추가 방어: indexPath 검증
            if lastRow >= self.tableView.numberOfRows(inSection: 0) {
                print("⚠️ [ChatViewController] 스크롤 시도 시 행 개수 변동 감지 → 재시도 예약")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.scrollToBottom(animated: animated)
                }
                return
            }
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
        }
    }

    // UI 디바운스: 100ms 내 reload/로딩 토글 합치기
    private func debouncedReload() {
        DispatchQueue.main.async {
            self.reloadDebounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.tableView.reloadData()
                // reload 직후 실제 표시 row 수 기반으로 안전 스크롤
                self.scrollToBottom()
            }
            self.reloadDebounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + self.uiDebounceInterval, execute: work)
        }
    }
    private func scheduleShowLoading(_ show: Bool) {
        DispatchQueue.main.async {
            self.showLoadingDebounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if show {
                    // 중복 로딩 방지: 기존 로딩 제거 후 1개만 추가
                    self.removeAllLoadingMessages()
                    let loadingMessage = ChatMessage(
                        text: "",
                        date: Date(),
                        sender: .ai,
                        type: .loading
                    )
                    self.appendBatch([loadingMessage], allowLoading: true, scrollToBottom: false)
                } else {
                    self.removeAllLoadingMessages()
                }
                self.debouncedReload()
            }
            self.showLoadingDebounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + self.uiDebounceInterval, execute: work)
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
                self.debouncedReload()
            } else {
                DispatchQueue.main.async {
                    self.debouncedReload()
                }
            }
        }
    }

    /// 마지막 로딩 메시지를 제거합니다 (레거시 메서드)
    private func removeLastLoadingMessage() {
        DispatchQueue.main.async {
            self.removeAllLoadingMessages()
            self.debouncedReload()
        }
    }

    /// 현재 감정 데이터를 반환합니다
    private func getEmotionData() -> [String: Any] {
        return [
            "primaryEmotion": "평온",
            "emotion": "평온",
            "intensity": 0.5,
            "timestamp": Date().timeIntervalSince1970,
        ]
    }

    // MARK: - 🐛 Debug Methods

    private func debugCheckFeedbackStatus() {
        if #available(iOS 17.0, *) {
            let recentFeedback = SessionManager.shared.getRecentFeedback(limit: 20)
            let totalCount = recentFeedback.count
            let recentCount = recentFeedback.count
            let avgSatisfaction =
                recentFeedback.isEmpty
                ? 0.0
                : recentFeedback.map { $0.satisfactionScore }.reduce(0, +)
                    / Float(recentFeedback.count)
            print(
                "Feedback - Total: \(totalCount), Recent: \(recentCount), Avg: \(avgSatisfaction)")
        } else {
            print("Feedback system requires iOS 17.0+")
        }
    }

    private func debugCreateTestData() {
        if #available(iOS 17.0, *) {
            // Test feedback data creation not available in SessionManager
            print("Test feedback data created")
        } else {
            print("Test data creation requires iOS 17.0+")
        }
    }

    private func debugTestLearningSystem() {
        if #available(iOS 17.0, *) {
            let feedbackCount = SessionManager.shared.getRecentFeedback(limit: 100).count
            print("Learning system test - Feedback count: \(feedbackCount)")
        } else {
            print("Learning system requires iOS 17.0+")
        }
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

    /// SessionManager 메시지 로드
    private func loadSessionManagerMessages() {
        // SessionManager의 메시지를 로컬 배열에 동기화
        let storedMessages = sessionManager.getRecentChatMessages(limit: 100)
        var mapped = storedMessages.map { storedMessage in
            // role 변환: "assistant" → .ai, "user" → .user
            let sender: MessageSender = {
                switch storedMessage.role {
                case "assistant": return .ai
                case "user": return .user
                case "system": return .system
                default: return .user
                }
            }()
            // 타입 보정: .text → 역할 기반으로 매핑
            let fixedType: ChatMessageType = {
                if storedMessage.type == .text {
                    switch sender {
                    case .user: return .user
                    case .ai: return .bot
                    case .system: return .system
                    }
                }
                return storedMessage.type
            }()
            // AI 응답은 재진입 시 JSON 원문이 남아있을 수 있으므로 정제
            let finalText: String =
                (sender == .ai)
                ? self.parseAIResponse(storedMessage.content) : storedMessage.content
            return ChatMessage(
                text: finalText, date: storedMessage.timestamp, sender: sender, type: fixedType)
        }
        // 과거 이중 저장으로 인한 인접 중복 제거
        mapped = deduplicateMessages(mapped)
        messages = mapped
        DispatchQueue.main.async {
            self.debouncedReload()
        }
        UnifiedLogger.shared.debug("SessionManager에서 \(messages.count)개 메시지 로드 완료", category: .chat)
    }

    // MARK: - 🎯 유틸리티 함수들 (통합)

    /// AIModelType을 AIModel로 변환
    private func mapAIModelTypeToAIModel(_ modelType: AIModelType) -> AIModel {
        switch modelType {
        case .claude35:
            return .claude
        case .gpt4:
            return .openAI
        case .gemini:
            return .gemini
        case .naver:
            return .naver
        case .onDevice:
            return .freeModel
        case .freeModel:
            return .freeModel
        case .testModel:
            return .freeModel
        }
    }

    // Note: These functions moved to CompilerFixStubs.swift to avoid duplication

    // MARK: - 📝 Step 2: 저장된 메시지 불러오기 구현

    /// viewDidLoad 후 저장된 메시지를 불러와서 표시 - 앱 시작 시 이전 대화 복원
    private func loadSavedMessages() {
        #if DEBUG
            print("💾 [ChatPersistence] 저장된 메시지 불러오기 시작")
        #endif

        // 1. SessionManager에서 최근 메시지 가져오기 (초기 로드는 100개)
        let stored = sessionManager.getRecentChatMessages(limit: 100)

        // 2. StoredChatMessage → ChatMessage 매핑 (역할/타입 보정 + AI 텍스트 정제)
        var mapped = stored.map { storedMessage in
            let sender: MessageSender = {
                switch storedMessage.role {
                case "assistant": return .ai
                case "user": return .user
                case "system": return .system
                default: return .user
                }
            }()
            let fixedType: ChatMessageType = {
                if storedMessage.type == .text {
                    switch sender {
                    case .user: return .user
                    case .ai: return .bot
                    case .system: return .system
                    }
                }
                return storedMessage.type
            }()
            let finalText =
                (sender == .ai)
                ? self.parseAIResponse(storedMessage.content) : storedMessage.content
            return ChatMessage(
                text: finalText, date: storedMessage.timestamp, sender: sender, type: fixedType)
        }
        mapped = deduplicateMessages(mapped)

        // 4. 메모리 최적화: 직접 messages 배열 사용 (allMessagesCache 제거)
        currentPage = 0
        let totalCount = mapped.count
        let initialCount = min(pageSize, totalCount)
        messages = Array(mapped.suffix(initialCount))
        hasMoreMessages = totalCount > pageSize

        // 5. 메모리 정리 수행
        if totalCount > maxMessages {
            performMemoryCleanup()
        }

        #if DEBUG
            print("💾 [ChatPersistence] loadSavedMessages 완료:")
            print("   - 로드된 메시지 수: \(messages.count)")
            print("   - 더 많은 메시지 있음: \(hasMoreMessages)")
            MemoryProfiler.shared.logMemoryUsage(context: "loadSavedMessages 완료")
        #endif

        // 6. 테이블뷰 리로드 및 하단으로 스크롤 + 초기 세션 정리(비동기)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.debouncedReload()
            if !self.messages.isEmpty { self.scrollToBottom(animated: false) }
            // 🔄 Persistent retention: in-memory window != persistent pruning
            DispatchQueue.global(qos: .utility).async {
                let removed = SessionManager.shared.cleanupOldSessions()
                #if DEBUG
                print("🧹 [ChatInit] 초기 세션 정리 수행 removed=\(removed)")
                #endif
            }
        }
    }

    /// 이전 메시지를 페이징으로 로드 - 동적 페이지 크기 + 배치 append + 메모리 가드
    private func paginateOlderMessages() {
        guard hasMoreMessages && !isLoadingMessages else {
            #if DEBUG
                print(
                    "💾 [ChatPersistence] 페이징 스킵 - hasMore: \\(hasMoreMessages), loading: \\(isLoadingMessages)"
                )
            #endif
            return
        }

        isLoadingMessages = true

        // 동적 페이지 크기: 빠른 연속 상단 스크롤 시 40, 기본 20
        let now = Date()
        if let last = lastPaginationTime, now.timeIntervalSince(last) < 1.0 {
            consecutiveFastPaginations += 1
        } else {
            consecutiveFastPaginations = 0
        }
        lastPaginationTime = now
        let baseSize = pageSize
        let dynamicPageSize = (consecutiveFastPaginations >= 1) ? min(baseSize * 2, 40) : baseSize

        #if DEBUG
            print(
                "💾 [ChatPersistence] 이전 메시지 페이징 시작 - 현재 페이지: \\(currentPage) dynSize=\\(dynamicPageSize) fastCount=\\(consecutiveFastPaginations)"
            )
            MemoryProfiler.shared.logMemoryUsage(context: "페이징 전 (페이지: \\(currentPage))")
        #endif

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let currentCount = self.messages.count
            let totalRequestSize = currentCount + dynamicPageSize
            let allMessages = self.sessionManager.getRecentChatMessages(limit: totalRequestSize)

            let mappedMessages = allMessages.map { storedMessage in
                let sender: MessageSender = {
                    switch storedMessage.role {
                    case "assistant": return .ai
                    case "user": return .user
                    case "system": return .system
                    default: return .user
                    }
                }()
                let fixedType: ChatMessageType = {
                    if storedMessage.type == .text {
                        switch sender {
                        case .user: return .user
                        case .ai: return .bot
                        case .system: return .system
                        }
                    }
                    return storedMessage.type
                }()
                let finalText =
                    (sender == .ai)
                    ? self.parseAIResponse(storedMessage.content) : storedMessage.content
                return ChatMessage(
                    text: finalText, date: storedMessage.timestamp, sender: sender, type: fixedType)
            }

            let dedup = self.deduplicateMessages(mappedMessages)
            guard dedup.count > currentCount else {
                DispatchQueue.main.async {
                    self.hasMoreMessages = false
                    self.isLoadingMessages = false
                    print("📝 [ChatViewController] 더 이상 로드할 메시지 없음")
                }
                return
            }

            let totalAvailable = dedup.count
            let newDisplayCount = min(currentCount + dynamicPageSize, totalAvailable)
            let newMessagesSlice = Array(dedup.suffix(newDisplayCount))
            let deltaMessages = Array(
                newMessagesSlice.prefix(newMessagesSlice.count - currentCount))

            DispatchQueue.main.async {
                // 스크롤 위치 유지 위한 이전 height
                let prevHeight = self.tableView.contentSize.height
                let prevOffsetY = self.tableView.contentOffset.y

                // 배치 append (기존 메시지 앞에 과거 메시지가 추가되는 형태 → 여기선 전체 교체 대신 diff append)
                self.messages = newMessagesSlice
                self.currentPage += 1

                // 메모리 가드 & trim
                self.enforceMemoryWindow(reason: "pagination")

                self.tableView.layoutIfNeeded()
                let newHeight = self.tableView.contentSize.height
                let diff = newHeight - prevHeight
                self.tableView.contentOffset = CGPoint(x: 0, y: prevOffsetY + diff)

                self.hasMoreMessages = totalAvailable > newDisplayCount
                self.isLoadingMessages = false

                #if DEBUG
                    print(
                        "💾 [ChatPersistence] 페이징 완료: now=\\(self.messages.count) added=\\(deltaMessages.count) totalAvail=\\(totalAvailable) more=\\(self.hasMoreMessages)"
                    )
                    MemoryProfiler.shared.logMemoryUsage(
                        context: "페이징 후 (현재 표시: \\(self.messages.count)개)")

                    if MemoryProfiler.shared.checkMemoryWarning() {
                        print("⚠️ 메모리 사용량 경고(threshold over) → 소프트 경고만 출력 (자동 강제 trim 없음)")
                    }
                #endif
            }
        }
    }

    // MARK: - 📦 Message Batch & Memory Window (Added)

    /// 배치로 메시지를 추가하고 (옵션) 로딩 메시지 중복을 정리한 뒤 메모리 윈도우(150) 적용
    /// - Parameters:
    ///   - newMessages: 추가할 메시지 배열 (이미 정렬: 과거→현재 가정)
    ///   - allowLoading: .loading 타입을 그대로 허용할지
    ///   - scrollToBottom: 추가 후 하단 스크롤 여부 (사용자 메시지/AI 응답 시 true, 과거 페이징은 false)
    private func appendBatch(
        _ newMessages: [ChatMessage],
        allowLoading: Bool = true,
        scrollToBottom: Bool = true
    ) {
        guard !newMessages.isEmpty else { return }

        // 1) .loading 중복 제거 (allowLoading=false 이면 완전히 제거)
        var filtered = newMessages
        if !allowLoading {
            filtered.removeAll { $0.type == .loading }
        } else {
            // allowLoading = true 인 경우: 기존에 남아있는 과거 loading 메시지 모두 제거 후 맨 끝 1개만 허용
            // (중복 로딩 버블 누적 방지)
            if filtered.contains(where: { $0.type == .loading }) {
                messages.removeAll { $0.type == .loading }
            }
        }

        // 2) 실제 추가
        messages.append(contentsOf: filtered)

        // 3) 메모리 윈도우/사용량 가드
        enforceMemoryWindow(reason: "appendBatch")

        // 4) UI 갱신
        debouncedReload()
        if scrollToBottom {
            self.scrollToBottom(animated: true) // self. 명시로 메서드 참조 (파라미터 이름과 충돌 방지)
        }
    }

    /// Unified Memory Window Enforcement
    /// - Maintains a max in-memory chat window (policy: 150 messages) separate from persistence retention (30일 세션 보존 정책)
    /// - Provides layered memory warnings (usageMB thresholds + MemoryProfiler.checkMemoryWarning())
    /// - Throttles a post-runloop memory log (0.4s) to distinguish transient spikes vs steady-state
    /// - reason: call path identifier (appendBatch / pagination / manual)
    private func enforceMemoryWindow(reason: String) {
        let cap = maxMessages // Single source of truth
        if messages.count > cap {
            let overflow = messages.count - cap
            if overflow > 0 {
                messages.removeFirst(overflow)
                #if DEBUG
                    UnifiedLogger.shared.info("[ChatViewController] 윈도우 초과 제거 \(overflow)개 (cap=\(cap)) reason=\(reason)", category: .memory)
                #endif
            }
        }

        #if DEBUG
        // Direct usage inspection (immediate)
        let usage = MemoryProfiler.shared.getCurrentMemoryUsage()
        // 사용자의 '강제 종료·메모리 제한' 불원 정책 반영: 경고 레벨 완화 (로그 레벨=debug) / 강제 trim 없음
        if usage > 190 {
            UnifiedLogger.shared.warning("[MemoryGuard] usage=\(String(format: "%.2f", usage))MB (HIGH segment, no enforce, reason=\(reason), count=\(messages.count))", category: .memory)
        } else if usage > 180 {
            UnifiedLogger.shared.info("[MemoryGuard] usage=\(String(format: "%.2f", usage))MB (SOFT segment, no enforce, reason=\(reason), count=\(messages.count))", category: .memory)
        }
        if MemoryProfiler.shared.checkMemoryWarning() {
            UnifiedLogger.shared.warning("[MemoryGuard] threshold segment (warn-only, no action) reason=\(reason) count=\(messages.count)", category: .memory)
        }
        #endif

        // Post-runloop throttled measurement
        #if DEBUG
        memoryLogWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            MemoryProfiler.shared.logMemoryUsage(context: "post-runloop \(reason)")
        }
        memoryLogWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
        #endif
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
                self.debouncedReload()
            }

            UnifiedLogger.shared.debug(
                "✅ ChatStoreDidChange 처리 완료 - 현재 메시지 수: \(self.messages.count)", category: .storage)
        }
    }

    /// 메모리에 캐시된 세션 정리
    private func cleanupSessionCache() {
        // SessionManager를 통한 세션 정리

        // ChatManager의 메모리 캐시 정리 요청
        // 삭제된 세션이 메모리에 남아있지 않도록 처리
        Task {
            // 오래된 세션 정리 (캐시 갱신)
            SessionManager.shared.cleanupOldSessions(olderThanDays: 0)  // 즉시 캐시 갱신

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

        // 🎯 중앙집중식 메시지 복원 - 컨텍스트에 따라 수행
        if !(chatContext == .emotionDiaryAnalysis || chatContext == .emotionDiaryAnalysisAlt
            || isEphemeralSession)
        {
            restoreMessagesFromStorage()
        }

        // 튜토리얼 표시 (초기화 완료 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showTutorialIfNeeded()
        }

        // 이어서 대화하기: 특정 세션 메시지로 교체 로드 (에페메랄 세션에서는 비활성)
        if !isEphemeralSession {
            if let sessionId = resumeSessionId {
                loadMessagesForSession(sessionId: sessionId)
                // 재개 안내 알림
                presentResumeInfoAlertIfNeeded()
            } else if let overrideId = SettingsManager.shared.activeChatSessionOverrideId {
                // 해시태그 진입 등에서 설정 레벨의 오버라이드가 지정된 경우에도 동일 처리
                loadMessagesForSession(sessionId: overrideId)
                resumeSessionId = overrideId
                presentResumeInfoAlertIfNeeded()
            }
        }

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

        // 구독 상태 바인딩 (중앙형 패턴)
        _ = SubscriptionUIBinder.attach(to: self) { [weak self] _ in
            self?.updateUIForSubscriptionStatus()
        }
        updateUIForSubscriptionStatus()

        // 💡 일반 채팅 사용량 80% 경고/100% 도달 알림 Observe
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleAIUsageThreshold(_:)), name: .aiUsageLimitWarning,
            object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleAIUsageThreshold(_:)), name: .aiUsageLimitReached,
            object: nil)

        // AI 사용량 업데이트 수신 → 퀵액션 라벨을 실시간 갱신
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleAIUsageUpdated(_:)), name: .aiUsageUpdated, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        // 대나무숯(채팅창): 상단바 바로 아래 배너 부착
        AdsBannerCoordinator.shared.attachExclusiveTopBannerUnderNavBar(to: self, autoLoad: true)
        scrollToBottom()

        // ✅ swipe back 제스처 재활성화 (혹시 비활성화되었을 경우)
        // 간소화: swipe back gesture 제거

        // ✅ 세션 시작 시간 기록
        sessionStartTime = Date()

        // 🎯 기능 온보딩 Alert (최초 1회)
        showOnboardingAlertIfNeeded()

        // 📝 #Todays_Mood로 진입한 일반 채팅에서 일기 분석을 바로 시작하도록 안내
        // 에페메랄 세션(일기 전용)에서는 기존 플로우(setupInitialMessages)에서 이미 처리되므로 제외
        handlePendingDiaryAnalysisIfNeeded()
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
        AdsBannerCoordinator.shared.refreshLayoutIfNeeded(for: self)
        recordSessionTime()

        // 📱 앱 종료/백그라운드 진입 시 채팅 기록 강제 저장
        saveChatHistory()
    }

    // MARK: - 초기 데이터 복원/튜토리얼
    private func restoreMessagesFromStorage() {
        // 중앙 저장소(SessionManager)에서 최근 메시지 로드 후 UI 모델로 매핑
        let stored = SessionManager.shared.getRecentChatMessages(limit: 100)
        var mapped = stored.map { storedMessage in
            let sender: MessageSender = {
                switch storedMessage.role {
                case "assistant": return .ai
                case "user": return .user
                case "system": return .system
                default: return .user
                }
            }()
            let fixedType: ChatMessageType = {
                if storedMessage.type == .text {
                    switch sender {
                    case .user: return .user
                    case .ai: return .bot
                    case .system: return .system
                    }
                }
                return storedMessage.type
            }()
            let finalText =
                (sender == .ai)
                ? self.parseAIResponse(storedMessage.content) : storedMessage.content
            return ChatMessage(
                text: finalText, date: storedMessage.timestamp, sender: sender, type: fixedType)
        }
        mapped = deduplicateMessages(mapped)
        self.messages = mapped
        self.debouncedReload()
    }

    private func showTutorialIfNeeded() {
        // ChatViewController 전용 간단 튜토리얼 (최초 1회)
        let key = "HasShownChatTutorial"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let alert = UIAlertController(
            title: "🌟 대화 시작 가이드",
            message: "하단의 '🎵 지금 기분에 맞는 사운드 추천받기' 버튼을 눌러보세요!\n또는 마음속 이야기를 자유롭게 적어보셔도 좋아요.",
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: "확인", style: .default) { _ in
                UserDefaults.standard.set(true, forKey: key)
            })
        present(alert, animated: true)
    }

    @objc private func handleAIUsageThreshold(_ note: Notification) {
        guard let mode = note.userInfo?["mode"] as? String,
            mode == AIMode.generalConversation.rawValue
        else { return }

        let status = UsageGate.shared.checkUsage(for: .generalConversation)
        let remaining = status.remaining
        let resetAt = status.resetTime
        let df = DateFormatter()
        df.locale = Locale(identifier: "ko_KR")
        df.dateFormat = "M월 d일 a h시 m분"
        let resetStr = df.string(from: resetAt)

        let isWarning = note.name == .aiUsageLimitWarning
        let title = isWarning ? "⚠️ 채팅 사용량 80% 도달" : "⛔️ 오늘 채팅 한도 도달"
        let message =
            isWarning
            ? "오늘 남은 채팅 횟수: \(remaining)회\n\n리셋 시각: \(resetStr)\n더 많은 대화를 위해 상위 티어 구독을 이용해보시겠어요?"
            : "오늘 채팅 한도(\(status.dailyLimit)회)를 모두 사용했습니다.\n\n리셋 시각: \(resetStr)\n상위 티어 구독으로 여유롭게 이용해보세요."

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel))
        alert.addAction(
            UIAlertAction(
                title: "업그레이드", style: .default,
                handler: { [weak self] _ in
                    guard let self = self else { return }
                    let vc = PaywallViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .formSheet
                    self.present(nav, animated: true)
                }))
        present(alert, animated: true)
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
            performanceMetrics = (
                duration: sessionDuration, completionRate: performanceMetrics.completionRate,
                context: performanceMetrics.context
            )
            recordSessionMetrics()

            #if DEBUG
                UnifiedLogger.shared.debug("세션 시간 기록: \(Int(sessionDuration))초", category: .timer)
            #endif
        }

        sessionStartTime = nil
    }

    // MARK: - 🎯 기능 온보딩 Alert

    private func showOnboardingAlertIfNeeded() {
        // UserDefaults에서 온보딩 표시 여부 확인
        let hasShownOnboarding = UserDefaults.standard.bool(forKey: "HasShownChatOnboarding")

        guard !hasShownOnboarding else { return }

        // 온보딩 Alert 생성
        let alert = UIAlertController(
            title: "🌟 대나무숲에 오신 것을 환영합니다!",
            message: """
                대나무숲은 당신의 마음을 이해하고 공감하는 친구입니다.

                ✨ 주요 기능:

                1️⃣ 페르소나 설정
                나만의 대나무숲 친구를 만들어보세요! 설정 > 대나무숲 친구 페르소나에서 성격과 대화 스타일을 선택할 수 있습니다.

                2️⃣ 핵심 기억 관리
                중요한 대화는 길게 눌러 '핵심 기억'으로 저장하세요. 대나무숲 친구가 당신을 더 잘 기억하고 이해할 수 있게 됩니다.

                3️⃣ 맞춤형 사운드 추천
                현재 감정과 상황에 맞는 수면 사운드를 대나무숲 친구가 추천해드립니다.

                💡 Tip: 대화를 나눌수록 대나무숲 친구가 당신을 더 잘 이해하게 됩니다!
                """,
            preferredStyle: .alert
        )

        // 페르소나 설정하러 가기 버튼
        alert.addAction(
            UIAlertAction(title: "페르소나 설정하기", style: .default) { _ in
                // 설정 화면으로 이동
                self.navigateToPersonaSettings()
                // 온보딩 표시 완료 플래그 설정
                UserDefaults.standard.set(true, forKey: "HasShownChatOnboarding")
            })

        // 나중에 하기 버튼
        alert.addAction(
            UIAlertAction(title: "나중에 설정하기", style: .cancel) { _ in
                // 온보딩 표시 완료 플래그 설정
                UserDefaults.standard.set(true, forKey: "HasShownChatOnboarding")

                // 안내 메시지 추가
                let guideMessage = ChatMessage(
                    text: "💡 언제든지 설정 > 대나무숲 친구 페르소나에서 나만의 대나무숲 친구를 만들 수 있어요!",
                    sender: .ai,
                    type: .system
                )
                self.appendChat(guideMessage)
            })

        // Alert 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.present(alert, animated: true)
        }
    }

    /// 페르소나 설정 화면으로 이동
    private func navigateToPersonaSettings() {
        // SettingsViewController 생성 (Storyboard 확인 후 직접 생성)
        let settingsVC = SettingsViewController()

        // 설정 화면으로 이동
        navigationController?.pushViewController(settingsVC, animated: true)

        // 이동 후 안내 메시지 표시를 위한 딜레이
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // 설정 화면에 진입 후 AI 페르소나 설정 안내
            let guideMessage = ChatMessage(
                text: "💡 설정 화면에서 '🌳 대나무숲 친구 설정' 섹션을 눌러 AI 페르소나를 설정할 수 있어요!",
                sender: .ai,
                type: .system
            )
            self?.appendChat(guideMessage)
        }
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
        let panGesture = UIPanGestureRecognizer(
            target: self, action: #selector(handlePanGesture(_:)))
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
                UIView.animate(
                    withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8,
                    initialSpringVelocity: 0.5
                ) {
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
        let translationX = clampedProgress * 80  // 더 작은 이동거리
        let scale = 1.0 - (clampedProgress * 0.05)  // 살짝 축소

        view.transform = CGAffineTransform(translationX: translationX, y: 0).scaledBy(
            x: scale, y: scale)
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
        let edgeThreshold: CGFloat = 44  // Apple 권장 터치 영역
        return location.x <= edgeThreshold
    }

    private func performBackNavigation() {
        UIView.animate(
            withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.7
        ) {
            self.view.transform = .identity
        }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if let navigationController = self.navigationController,
                navigationController.viewControllers.count > 1
            {
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
            recommendationCount: 0,  // 기본값
            userSatisfaction: performanceMetrics.completionRate,
            aiAccuracy: 0.8  // 기본값
        )

        // 향후 분석을 위해 로컬 저장
        saveSessionMetrics(metrics)
    }

    private func saveSessionMetrics(_ metrics: EnhancedSessionMetrics) {
        var savedMetrics =
            UserDefaults.standard.array(forKey: "session_metrics") as? [[String: Any]] ?? []

        let metricsDict: [String: Any] = [
            "sessionId": metrics.sessionId.uuidString,
            "duration": metrics.duration,
            "messageCount": metrics.messageCount,
            "recommendationCount": metrics.recommendationCount,
            "userSatisfaction": metrics.userSatisfaction,
            "aiAccuracy": metrics.aiAccuracy,
            "timestamp": Date().timeIntervalSince1970,
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
        UnifiedLogger.shared.debug(
            "감정 분석 완료: \(enhancedEmotion.primaryEmotion) (강도: \(enhancedEmotion.intensity))",
            category: .emotion)

        // 메시지를 채팅 기록에 추가
        let userChatMessage = ChatMessage(text: userMessage, sender: .user, type: .user)
        appendChat(userChatMessage)

        // 테이블 뷰 업데이트
        DispatchQueue.main.async {
            self.debouncedReload()
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
            self.debouncedReload()
        }
    }

    private func processUserMessageWithEnhancedAI(_ userMessage: String) {
        // �� Enhanced: 고도화된 감정 분석
        let enhancedEmotion = analyzeEnhancedEmotion(from: userMessage)
        currentEmotion = enhancedEmotion

        // 감정 분석 완료 로그
        UnifiedLogger.shared.debug(
            "감정 분석 완료: \(enhancedEmotion.primaryEmotion) (강도: \(enhancedEmotion.intensity))",
            category: .emotion)

        // 기존 처리 로직 호출
        processUserMessageInternal(userMessage)
    }

    private func analyzeEnhancedEmotion(from message: String) -> (
        primaryEmotion: String, intensity: Float, physicalState: Any, environmentContext: Any,
        cognitiveState: Any, socialContext: Any
    ) {
        // 간단한 감정 분석
        let primaryEmotion = EmotionAnalyzer().extractBasicEmotion(from: message)
        // 결정적 강도 규칙: 텍스트 길이 기반 간단 휴리스틱 (랜덤 금지)
        let clampedLength = min(max(message.count, 0), 400)
        let intensity = Float(0.3 + (Double(clampedLength) / 400.0) * 0.6) // 0.3...0.9

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
    private func analyzePhysicalState(from message: String) -> (
        energy: Float, tension: Float, comfort: Float, fatigue: Float
    ) {
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
    private func analyzeEnvironmentalContext(from message: String) -> (
        location: String, timeContext: String, weatherMood: String, socialSetting: String,
        noiseLevel: Float, lightingCondition: String, temperature: String
    ) {
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
    private func analyzeCognitiveState(from message: String) -> (
        focusLevel: Float, mentalClarity: Float, creativityLevel: Float, stressLevel: Float,
        motivation: Float, decisionMaking: String
    ) {
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
    private func analyzeSocialContext(from message: String) -> (
        socialEnergy: Float, interpersonalStress: Float, supportNeed: String,
        communicationStyle: String, relationshipStatus: String
    ) {
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
        let timeMultiplier: Float = hour >= 22 || hour <= 6 ? 0.7 : 1.0  // 밤시간 볼륨 조정
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
        case 10...16: return 0.5  // 낮: 보통
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
        // 결정적 날씨 점수 근사(위치/시간 부재 시): 시간대 기반 고정값
        // 밤(22-6): 0.4, 아침(6-10): 0.7, 낮(10-18): 0.6, 저녁(18-22): 0.5
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 22...23, 0...5: return 0.4
        case 6...9: return 0.7
        case 10...17: return 0.6
        default: return 0.5
        }
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
            "music": 0.3,
        ]
    }

    // MARK: - Feedback Integration

    private func promptForFeedback(presetName: String) {
        // 일정 시간 후 피드백 요청
        DispatchQueue.main.asyncAfter(deadline: .now() + 300) {  // 5분 후
            self.showFeedbackPrompt(presetName: presetName)
        }
    }

    private func showFeedbackPrompt(presetName: String) {
        let alert = UIAlertController(
            title: "🧠 대나무숲 학습 도움",
            message: "방금 추천받은 '\(presetName)'는 어떠셨나요? 피드백을 주시면 대나무숲 친구가 더 정확해집니다!",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "✨ 상세 피드백", style: .default) { _ in
                self.presentDetailedFeedback(presetName: presetName)
            })

        alert.addAction(
            UIAlertAction(title: "👍 좋았음", style: .default) { _ in
                self.submitQuickFeedback(satisfaction: 0.8, presetName: presetName)
            })

        alert.addAction(
            UIAlertAction(title: "👎 별로", style: .default) { _ in
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

        alert.addAction(
            UIAlertAction(title: "매우 만족", style: .default) { _ in
                self.submitQuickFeedback(satisfaction: 1.0, presetName: presetName)
            })

        alert.addAction(
            UIAlertAction(title: "만족", style: .default) { _ in
                self.submitQuickFeedback(satisfaction: 0.8, presetName: presetName)
            })

        alert.addAction(
            UIAlertAction(title: "보통", style: .default) { _ in
                self.submitQuickFeedback(satisfaction: 0.5, presetName: presetName)
            })

        alert.addAction(
            UIAlertAction(title: "불만족", style: .default) { _ in
                self.submitQuickFeedback(satisfaction: 0.2, presetName: presetName)
            })

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))

        present(alert, animated: true)
    }

    private func submitQuickFeedback(satisfaction: Float, presetName: String) {
        guard let startTime = sessionStartTime else { return }

        // 간단한 피드백 객체 생성 (기본 FeedbackManager 호환)
        let quickFeedback = PresetFeedback(
            id: UUID(),
            timestamp: Date(),
            presetName: presetName,
            contextEmotion: "평온",
            contextTime: Int16(Date().timeIntervalSince1970),
            recommendedVolumes: [],
            recommendedVersions: [],
            finalVolumes: [],
            listeningDuration: 0,
            wasSkipped: false,
            wasSaved: false,
            userSatisfaction: Int(satisfaction * 10),
            comment: "빠른 피드백",
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

        UnifiedLogger.shared.debug(
            "빠른 피드백 저장: \(presetName) (만족도: \(satisfaction))", category: .feedback)

        // 성공 메시지
        showQuickFeedbackThankYou()
    }

    private func createQuickDeviceContext() -> [String: Any] {
        return [
            "volume": 0.7,
            "brightness": Float(UIScreen.main.brightness),
            "batteryLevel": UIDevice.current.batteryLevel,
            "deviceOrientation": UIDevice.current.orientation.rawValue.description,
            "headphonesConnected": false,
        ]
    }

    private func createQuickEnvironmentContext() -> [String: Any] {
        return [
            "lightLevel": "보통",
            "noiseLevel": getEstimatedEnvironmentNoise(),
            "weatherCondition": nil as String?,
            "location": "앱사용",
            "timeOfUse": getCurrentTimeOfUse(),
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
        let message = ChatMessage(
            text: "🙏 피드백 감사합니다! 대나무숲 친구가 조금 더 똑똑해졌어요. 계속 학습하여 더 나은 추천을 드리겠습니다!", sender: .ai,
            type: .bot)
        appendChat(message)

        // ✅ ML 관련 성능 메트릭 제거됨 - 기본 로깅으로 대체
        print("✅ 피드백 수신 완료")
    }

    private func showPresetAppliedMessage(_ presetName: String) {
        let message = ChatMessage(
            text: "✅ '\(presetName)' 프리셋이 적용되었습니다! 🎵", sender: .ai, type: .bot)
        appendChat(message)
    }

    private func displayAIRecommendation(_ recommendation: EnhancedRecommendationResponse) {
        let message = """
            **[\(recommendation.presetName)]**
            \(recommendation.reason ?? "대나무숲 친구가 분석한 추천 프리셋입니다.")
            """

        let chatMessage = ChatMessage(text: message, sender: .ai, type: .presetRecommendation)
        appendChat(chatMessage)

        // 메시지와 추천 페이로드를 연결하여 '바로 적용하기'에서 정확히 적용 가능
        presetPayloads[chatMessage.id] = recommendation
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        cleanup()
    }

    @objc private func handleAIUsageUpdated(_ note: Notification) {
        guard let feature = note.userInfo?["feature"] as? String,
            feature == AIFeatureType.presetRecommendation.rawValue
        else { return }
        // 현재 표시 중인 메시지 중 추천 선택(.recommendationSelector) 버블이 있으면 제목 갱신
        let remaining = AIUsageManager.shared.getRemainingCount(for: .presetRecommendation)
        let total = AIUsageManager.shared.getTotalLimit(for: .presetRecommendation)
        let aiTitle: String = {
            if DebugFlags.unlimitedPresetRecommendation || total > 1_000_000_000 {
                return "대나무숲 분석 추천받기 (무제한)"
            } else {
                return "대나무숲 분석 추천받기 (\(remaining)/\(total))"
            }
        }()

        // 최신 recommendationSelector 메시지를 찾아 quickActions 업데이트
        if let idx = displayMessages.lastIndex(where: {
            $0.type == ChatMessageType.recommendationSelector
        }) {
            // 안전 경로: 부분 reload 대신 전체 디바운스 리로드(행 수 변동 경쟁 상태 회피)
            var msg = displayMessages[idx]
            if let qas = msg.quickActions {
                let newQAs = qas.map { qa in
                    qa.action == "ai_recommendation" ? QuickAction(title: aiTitle, action: qa.action) : qa
                }
                msg.quickActions = newQAs
                displayMessages[idx] = msg
                debouncedReload()
            }
        }
    }

    // MARK: - AI 응답 처리 및 프리셋 추천

    private func getLastRecommendation(for sessionId: String) -> PresetRecommendationResponse? {
        // 메시지 목록을 역순으로 탐색하여 해당 세션 ID를 가진 마지막 추천을 찾습니다.
        for message in messages.reversed() {
            if message.type == .presetRecommendation,
                let metadata = message.metadata,
                metadata.sessionId == sessionId
            {
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
        let loadedSessions = SessionManager.shared.getAllSessions()
        UnifiedLogger.shared.debug(
            "loadChatHistory: \(loadedSessions.count)개 세션 발견", category: .cache)

        DispatchQueue.main.async {
            self.debouncedReload()
        }
    }

    /// 특정 세션의 메시지를 불러와 UI에 표시
    private func loadMessagesForSession(sessionId: String) {
        currentLoadedSessionId = sessionId
        let stored = sessionManager.getChatMessages(forSessionId: sessionId)
        var mapped = stored.map { storedMessage in
            let sender: MessageSender = {
                switch storedMessage.role {
                case "assistant": return .ai
                case "user": return .user
                case "system": return .system
                default: return .user
                }
            }()
            let fixedType: ChatMessageType = {
                if storedMessage.type == .text {
                    switch sender {
                    case .user: return .user
                    case .ai: return .bot
                    case .system: return .system
                    }
                }
                return storedMessage.type
            }()
            let finalText =
                (sender == .ai)
                ? self.parseAIResponse(storedMessage.content) : storedMessage.content
            return ChatMessage(
                text: finalText, date: storedMessage.timestamp, sender: sender, type: fixedType)
        }
        mapped = deduplicateMessages(mapped)
        messages = mapped
        DispatchQueue.main.async {
            self.debouncedReload()
        }
        UnifiedLogger.shared.debug(
            "특정 세션(\(sessionId))에서 \(messages.count)개 메시지 로드", category: .chat)
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
                id: UUID().uuidString,
                timestamp: Date(),
                role: message.type == .user ? "user" : "assistant",
                content: message.text ?? "",
                type: message.type == .user ? .text : .text
            )
            // ChatManager.shared.addMessage(to: migrationSessionId.uuidString, message: storedMessage)
        }

        // 마이그레이션 완료 확인
        let migratedSessions = SessionManager.shared.getAllSessions()
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
            SoundManager.shared.applyPresetWithVersions(
                volumes: restoredPreset.volumes, versions: restoredPreset.versions)
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
            SoundManager.shared.applyPresetWithVersions(
                volumes: defaultPreset.volumes, versions: defaultPreset.versions)
            showPresetAppliedMessage(defaultPreset.name)
        }
    }

    /// 텍스트에서 프리셋 이름 추출
    private func extractPresetNameFromText(_ text: String) -> String? {
        // **[프리셋 이름]** 패턴 찾기
        if let range = text.range(of: #"\*\*\[([^\]]+)\]\*\*"#, options: .regularExpression) {
            let extracted = String(text[range])
            return extracted.replacingOccurrences(of: "**[", with: "").replacingOccurrences(
                of: "]**", with: "")
        }

        // 다른 패턴들도 시도
        if let range = text.range(of: #"\[([^\]]+)\]"#, options: .regularExpression) {
            let extracted = String(text[range])
            return extracted.replacingOccurrences(of: "[", with: "").replacingOccurrences(
                of: "]", with: "")
        }

        return nil
    }

    private func setupNavigationBar() {
        // 네비게이션 바 표시 설정
        navigationController?.setNavigationBarHidden(false, animated: false)

        // 공유/내보내기 버튼 추가
        let exportItem = UIBarButtonItem(
            title: "내보내기", style: .plain, target: self, action: #selector(exportChatTapped))
        navigationItem.rightBarButtonItem = exportItem

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
        // SessionManager initializes automatically

        // 만료된 캐시들 정리 (14일 기준)
        UserDefaults.standard.cleanExpiredCaches()
        UserDefaults.standard.cleanOldData(olderThanDays: CacheConst.keepDays)

        #if DEBUG
            UnifiedLogger.shared.debug("TLB식 캐시 시스템 초기화 완료 (14일 보존, 3일 raw)", category: .cache)
            let debugInfo =
                "SessionManager active with \(SessionManager.shared.getAllSessions().count) sessions"
            UnifiedLogger.shared.debug(debugInfo, category: .cache)
        #endif
    }

    // 중복된 loadChatManagerMessages 함수 제거됨 - 원본이 위에 있음

    // ✅ TLB식 대화 히스토리 로드
    private func loadTLBChatHistory() {
        let cutOffRecent = Calendar.current.date(
            byAdding: .day, value: -CacheConst.recentDaysRaw, to: Date())!
        let cutOffTotal = Calendar.current.date(
            byAdding: .day, value: -CacheConst.keepDays, to: Date())!

        // 캐시에서 최근 대화 로드 (ChatManager 통합 - 간소화)
        let cachedHistory = SessionManager.shared.getRecentChatMessages(limit: 50)
        if !cachedHistory.isEmpty && cachedHistory.count > 20 {  // 의미 있는 데이터가 있을 때만
            // 캐시 요약을 시스템 메시지로 추가
            let contextMessage = ChatMessage(
                text: "💾 \(cachedHistory)",
                sender: .ai,
                type: .system
            )
            messages = [contextMessage]

            #if DEBUG
                UnifiedLogger.shared.debug(
                    "ChatManager 캐시 로드 완료 - \(cachedHistory.count)자", category: .cache)
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
        // 입력창 포커스 시 퀵액션이 뜨지 않도록 편집 시작 이벤트 연결 제거
    }

    // MARK: - Resume/Override Handling
    private func presentResumeInfoAlertIfNeeded() {
        guard !isEphemeralSession else { return }
        guard !hasShownResumeAlert else { return }
        guard resumeSessionId != nil || SettingsManager.shared.activeChatSessionOverrideId != nil
        else { return }
        hasShownResumeAlert = true

        let message = """
            이 날짜의 대화 내용을 읽어볼 수 있어요.
            이어서 대화를 시작하려면 메시지를 입력해 주세요.

            주의: 채팅을 시작하면 현재 채팅창의 기존 대화는 선택한 날짜의 대화로 완전히 덮어쓰기 됩니다.
            """
        let alert = UIAlertController(title: "읽기 전용 미리보기", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func adoptOverrideSessionIfNeeded() {
        guard !isEphemeralSession else { return }
        guard !didAdoptSessionOverride else { return }
        let targetId = resumeSessionId ?? SettingsManager.shared.activeChatSessionOverrideId
        guard let sessionId = targetId else { return }

        // 세션 존재 검증 후 오버라이드 적용
        let exists = SessionManager.shared.getAllSessions().contains { $0.id == sessionId }
        guard exists else { return }

        SettingsManager.shared.activeChatSessionOverrideId = sessionId
        didAdoptSessionOverride = true

        // 기존 대화 내용을 선택된 세션의 메시지로 완전히 교체
        if currentLoadedSessionId != sessionId {
            loadMessagesForSession(sessionId: sessionId)
        }

        // 힌트 라벨은 더 이상 필요하지 않으므로 숨김
        if let hint = overrideHintLabel {
            UIView.animate(withDuration: 0.25) {
                hint.alpha = 0
            } completion: { _ in
                hint.removeFromSuperview()
            }
        }
    }

    @objc private func handleUserTyping() {
        adoptOverrideSessionIfNeeded()
        // 남은 횟수/총 한도를 실시간 반영 (무료 3회/유료 7회)
        let remaining = AIUsageManager.shared.getRemainingCount(for: .presetRecommendation)
        let total = AIUsageManager.shared.getTotalLimit(for: .presetRecommendation)
        let aiTitle: String = {
            if DebugFlags.unlimitedPresetRecommendation || total > 1_000_000_000 {
                return "대나무숲 분석 추천받기 (무제한)"
            } else {
                return "대나무숲 분석 추천받기 (\(remaining)/\(total))"
            }
        }()

        // 퀵액션을 보여주는 메시지 생성
        let quickActions = [
            QuickAction(title: "앱 분석 추천받기", action: "local_recommendation"),
            QuickAction(title: aiTitle, action: "ai_recommendation"),
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
    @objc private func presetButtonTapped() {
        // 추천 선택 UI를 동일하게 띄운다
        handleUserTyping()
    }

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
            "화남": ["화나다", "짜증", "분노", "열받다", "답답하다"],
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
    private func displayBasicRecommendationInChat(
        _ recommendation: (
            sounds: [(soundId: String, version: String, volume: Float)], explanation: String
        ), emotion: String, timeOfDay: String
    ) {
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
    private func displayRecommendationInChat(
        _ recommendation: AdvancedRecommendationResult, emotion: String, timeOfDay: String
    ) {
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
            // 원래 플로우: setupInitialMessages()가 diaryContext를 기반으로 requestDiaryAnalysisWithTracking을 트리거
            setupInitialMessages()
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

            // Fallback: 과거 경로 호환. diaryContext가 미설정된 경우 단일 경로로 통일하여 즉시 분석 트리거
            if self.diaryContext == nil {
                self.diaryContext = DiaryContext(from: diary)
                if !self.didStartDiaryAnalysis {
                    self.didStartDiaryAnalysis = true
                    self.requestDiaryAnalysisWithTracking(diary: self.diaryContext!)
                }
            }
        }
    }

    /// 감정 분석 컨텍스트 설정
    private func setupEmotionAnalysisContext() {
        if let emotion = initialEmotion {
            title = "대나무숲 - 감정 분석"

            // 상위 두 개 안내 버블을 하나로 통합
            let combinedText = """
                💝 지금 \(emotion) 감정을 느끼고 계시는군요. 함께 이야기 나누어봐요 🌸

                어떤 일이 있으셨나요? 마음 편히 들려주세요 😊
                """
            let combinedMessage = ChatMessage(
                text: combinedText,
                sender: .ai,
                type: .bot
            )
            appendChat(combinedMessage)
        }
    }

    /// 월간 패턴 분석 컨텍스트 설정
    private func setupMonthlyPatternContext() {
        title = "대나무숲 - 월간 감정 패턴"

        // 안내와 프롬프트를 하나의 버블로 통합
        let combinedIntro = """
            📊 최근 한 달간의 감정 패턴을 분석해드릴게요 ✨

            이 패턴에 대해 궁금한 점이나 더 알고 싶은 부분이 있으시면 언제든 말씀해주세요! 💭
            """
        appendChat(ChatMessage(text: combinedIntro, sender: .ai, type: .bot))

        if let patternData = initialPatternData {
            let analysisMessage = ChatMessage(
                text: patternData,
                sender: .ai,
                type: .bot
            )
            appendChat(analysisMessage)
        }
    }

    /// 피드백 분석 컨텍스트 설정
    private func setupFeedbackAnalysisContext() {
        title = "대나무숲 - 피드백 분석"

        // 상위 두 개 안내 버블을 하나로 통합
        let combinedText = """
            🎨 사운드 경험에 대한 피드백을 분석하고 개선점을 찾아보아요 ✨

            최근 사용하신 사운드는 어떠셨나요? 솔직한 의견을 들려주세요 😊
            """
        let combinedMessage = ChatMessage(
            text: combinedText,
            sender: .ai,
            type: .bot
        )
        appendChat(combinedMessage)
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
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification, object: nil)

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

        // 덮어쓰기 안내 라벨 (재개 세션이 있을 때만 표시)
        if resumeSessionId != nil || SettingsManager.shared.activeChatSessionOverrideId != nil {
            let hint = UILabel()
            hint.numberOfLines = 0
            hint.textAlignment = .center
            hint.font = .systemFont(ofSize: 12)
            hint.textColor = .secondaryLabel
            hint.translatesAutoresizingMaskIntoConstraints = false
            hint.text = "채팅을 시작하면 현재 채팅창은 선택한 날짜의 대화로 완전히 덮어쓰기 됩니다."
            self.overrideHintLabel = hint
            view.addSubview(hint)
            NSLayoutConstraint.activate([
                hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                hint.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: -4),
            ])
        }

        // ✅ 화면 하단 로딩 시스템 제거됨
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: presetButton.topAnchor, constant: 0),  // ✅ 간격 완전 제거

            presetButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            presetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            presetButton.bottomAnchor.constraint(
                equalTo: inputContainerView.topAnchor, constant: -8),  // ✅ 12 → 8로 간격 줄임
            presetButton.heightAnchor.constraint(equalToConstant: 50),

            inputTextField.leadingAnchor.constraint(
                equalTo: inputContainerView.leadingAnchor, constant: 16),
            inputTextField.topAnchor.constraint(equalTo: inputContainerView.topAnchor, constant: 8),
            inputTextField.bottomAnchor.constraint(
                equalTo: inputContainerView.bottomAnchor, constant: -8),
            inputTextField.trailingAnchor.constraint(
                equalTo: sendButton.leadingAnchor, constant: -8),

            sendButton.trailingAnchor.constraint(
                equalTo: inputContainerView.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputTextField.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 60),
        ])

        bottomConstraint = inputContainerView.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        bottomConstraint?.isActive = true
        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    @objc private func exportChatTapped() {
        // 현재 화면의 메시지 배열을 기반으로 텍스트-only 내보내기 (PII 마스킹 적용)
        var lines: [String] = []
        for m in messages {
            guard m.type != .loading else { continue }
            guard let text = m.text, !text.isEmpty else { continue }
            switch m.sender {
            case .user:
                lines.append("나: " + SettingsManager.shared.maskPIIForExport(text))
            case .ai:
                lines.append("모델: " + SettingsManager.shared.maskPIIForExport(text))
            case .system:
                continue  // 시스템/컨텍스트 정보는 포함하지 않음
            }
        }
        let exportText = lines.joined(separator: "\n")
        let vc = UIActivityViewController(activityItems: [exportText], applicationActivities: nil)
        vc.excludedActivityTypes = [
            .assignToContact, .saveToCameraRoll, .postToFacebook, .postToTwitter,
        ]
        present(vc, animated: true)
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
            userText != "일기_분석_모드" && userText != "감정_패턴_분석_모드"
        {
            appendChat(ChatMessage(text: "선택한 기분: \(userText)", sender: .user, type: .user))
            let greeting = getEmotionalGreeting(for: userText)
            appendChat(ChatMessage(text: greeting, sender: .ai, type: .bot))
        } else {
            appendChat(
                ChatMessage(
                    text: "안녕하세요! 😊\n오늘 하루는 어떠셨나요? 마음 편하게 이야기해보세요 ✨", sender: .ai, type: .bot))
        }
    }

    // ✅ 캐시 상태 새로고침
    private func refreshCacheStatus() {
        // 캐시가 유효한지 확인하고 필요시 업데이트
        let weeklyMemory = SessionManager.shared.getRecentChatMessages(limit: 50)

        #if DEBUG
            UnifiedLogger.shared.debug("캐시 상태 새로고침: 주간 메모리 로드 완료", category: .cache)
        #endif

        // 주간 메모리 백그라운드 업데이트
        // Weekly memory update not available in SessionManager
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
            appendChat(
                ChatMessage(
                    text: "아직 감정 기록이 충분하지 않네요 😊 일기를 더 작성해주시면 더 정확한 분석을 도와드릴 수 있어요!", sender: .ai,
                    type: .bot))
            return
        }

        appendChat(
            ChatMessage(text: "📊 최근 30일간의 감정 패턴을 분석하고 있어요... ✨", sender: .ai, type: .loading))
        showLoading(true)

        Task {
            do {
                // 🚀 SessionManager의 통합 AI 서비스 사용
                let prompt = "다음은 나의 최근 30일간의 감정 데이터야. 이걸 보고 나의 감정 패턴을 분석하고 조언해줘.\n\n\(emotionData)"
                let selectedModel = mapAIModelTypeToAIModel(SettingsManager.shared.selectedLLM)
                let responseContent = try await SessionManager.shared.sendMessage(
                    content: prompt,
                    model: selectedModel,
                    mode: .monthlyStatistics,
                    saveMessages: true
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

        let introText = """
            오늘의 감정: \(diaryData.emotion ?? "알 수 없음")
            일기 내용을 바탕으로 감정을 분석해드릴게요 😊
            """
        appendChat(ChatMessage(text: introText, sender: .ai, type: .bot))

        // SSoT: 통합 경로로 분석 요청
        requestDiaryAnalysisWithTracking(diary: diaryData)
    }

    private func addQuickEmotionButtons() {
        appendChat(
            ChatMessage(
                text: "💡 더 자세한 분석을 원하시나요?\n\n🎯 개선 방법\n📈 감정 변화 추이\n💡 스트레스 관리\n\n위 키워드로 질문해보세요! ✨",
                sender: .ai, type: .bot))
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
                self?.debouncedReload()
            }
        }
    }

    /// 인접한 동일 텍스트/보낸이 메시지를 제거하여 과거 이중 저장으로 인한 중복 표시를 방지
    private func deduplicateMessages(_ list: [ChatMessage]) -> [ChatMessage] {
        var result: [ChatMessage] = []
        for msg in list {
            if let last = result.last,
                last.sender == msg.sender,
                (last.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    == (msg.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            {
                // 타임스탬프가 매우 근접(5초 이내)이면 중복으로 간주
                if abs(last.date.timeIntervalSince1970 - msg.date.timeIntervalSince1970) <= 5 {
                    continue
                }
            }
            result.append(msg)
        }
        return result
    }

    /// #Todays_Mood 경로 등에서 일반 채팅으로 진입했을 때, 전달된 일기 분석을 안전하게 시작
    private func handlePendingDiaryAnalysisIfNeeded() {
        // 에페메랄 세션(일기 전용)에서는 기존 초기화 경로가 처리하므로 제외
        guard !isEphemeralSession else { return }
        guard let text = initialUserText, text == "일기_분석_모드" else { return }
        guard let diary = diaryContext, !didStartDiaryAnalysis else { return }

        // 한 번만 처리하도록 플래그 설정(중복 방지)
        didStartDiaryAnalysis = true
        // 초기 사용자 텍스트는 소진 처리
        initialUserText = nil

        // 개인정보 안내 후 진행 여부 확인
        let emotionLabel = diary.emotion ?? "알 수 없음"
        let alert = UIAlertController(
            title: "🔒 개인정보 보호 안내",
            message: """
                대나무숲에서 이야기하기 위해 다음 정보가 전송됩니다:

                • 선택한 감정: \(emotionLabel)
                • 작성한 일기 내용

                ⚠️ 주의사항:
                • 개인 식별 정보(이름, 전화번호 등)가 포함된 경우 전송하지 않는 것을 권장합니다
                • 대화 종료 후 데이터는 즉시 삭제됩니다
                • 민감한 개인정보는 삭제 후 진행하시기 바랍니다

                계속하시겠습니까?
                """,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: "취소", style: .cancel,
                handler: { [weak self] _ in
                    // 취소 시 안내만 남김
                    self?.appendChat(
                        ChatMessage(text: "원하실 때 언제든 일기 분석을 요청하실 수 있어요. 😊", sender: .ai, type: .bot)
                    )
                }))
        alert.addAction(
            UIAlertAction(
                title: "대나무숲에서 이야기하기", style: .default,
                handler: { [weak self] _ in
                    guard let self = self else { return }
                    self.startDiaryAnalysis()
                }))
        present(alert, animated: true)
    }
}

// MARK: - Keyboard Handling
extension ChatViewController {
    @objc private func keyboardWillShow(notification: Notification) {
        if let keyboardFrame =
            (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
            .cgRectValue
        {
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
        let recentSessions = SessionManager.shared.getRecentSessions(limit: 5)
        var recentPresets: [(name: String, emotion: String)] = []

        for session in recentSessions {
            if let presetMessage = session.chatMessages.first(where: {
                $0.type == .presetRecommendation
            }),
                let presetName = extractPresetNameFromText(presetMessage.content)
            {
                // 메타데이터에서 감정 추출 (기본값: "평온")
                let emotion = session.metadata.primaryEmotion ?? "평온"
                recentPresets.append((name: presetName, emotion: emotion))
            }
        }

        // UserDefaults 백업 확인
        if recentPresets.isEmpty,
            let recentData = UserDefaults.standard.array(forKey: "recentPresets")
                as? [[String: String]]
        {
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
            "이완": ["부드러운 파도", "구름 위의 휴식", "저녁 노을"],
        ]

        // SoundPresetCatalog의 기존 프리셋 이름 확인
        let catalogPresets = SoundPresetCatalog.samplePresets.keys.filter { $0.contains(emotion) }
        if !catalogPresets.isEmpty {
            return catalogPresets.sorted().first ?? "맞춤형 사운드"
        }

        // 위의 poeticNames에서 선택
        let names = poeticNames[emotion] ?? ["맞춤형 사운드"]
        return names.sorted().first ?? "맞춤형 사운드"
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
        guard
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ChatBubbleCell.identifier, for: indexPath) as? ChatBubbleCell
        else {
            print("🔴 [ChatViewController] ChatBubbleCell dequeue 실패")
            return UITableViewCell()
        }

        let message = messages[indexPath.row]
        let isUserMessage = (message.sender == .user)
        // 메시지 셀 구성

        // 길게 누르기 메뉴(기억/복사/공유)는 셀 내부에서 처리하므로 별도 설정 불필요
        cell.configure(with: message, isUserMessage: isUserMessage)

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
                context: contextString,  // 풍부한 컨텍스트 전달
                preferredCount: nil
            )

            // 추천 결과를 기존 형식으로 변환
            let volumes = recommendation.sounds.map { Double($0.volume * 100) }  // 볼륨을 백분율로 변환
            let versions = recommendation.sounds.map { _ in Int.random(in: 1...2) }  // 랜덤 버전 선택

            // 13개 사운드로 확장 (부족한 경우 기본값으로 채움)
            let expandedVolumes =
                Array(volumes.prefix(13))
                + Array(repeating: 30.0, count: max(0, 13 - volumes.count))
            let expandedVersions =
                Array(versions.prefix(13)) + Array(repeating: 1, count: max(0, 13 - versions.count))

            masterRecommendation = (volumes: expandedVolumes, compatibleVersions: expandedVersions)

            if recommendation.sounds.isEmpty,
                let scientific = getScientificRecommendationFor(emotion: recommendedEmotion)
            {
                // 과학 프리셋으로 폴백
                let presetMessage = """
                    **[\(scientific.presetName)]**
                    \(scientific.reason ?? "대나무숲 친구가 분석한 추천 프리셋입니다.")

                    로컬 알고리즘(과학 프리셋)으로 현재 시간대에 최적화된 사운드 조합을 선별했습니다.
                    """
                let chatMessage = ChatMessage(
                    text: presetMessage, sender: .ai, type: .presetRecommendation)
                appendChat(chatMessage)
                presetPayloads[chatMessage.id] = scientific
                isProcessingRecommendation = false
                return
            }
            print("✅ 로컬 프리셋 추천 성공: \(recommendation.sounds.count)개 사운드")

        } catch {
            print("❌ EnhancedSoundRecommendationEngine 오류: \(error)")
            // 폴백: 기본값 사용
            masterRecommendation = (
                volumes: Array(repeating: 50.0, count: 13),
                compatibleVersions: Array(repeating: 1, count: 13)
            )
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
        // 로컬 추천도 페이로드를 연결해 '바로 적용하기'가 정확히 동작하도록 함
        let payload = EnhancedRecommendationResponse(
            presetName: recommendedPreset.name,
            volumes: SoundPresetCatalog.applyCompatibilityFilter(
                to: recommendedPreset.volumes.map { Float($0) }),
            versions: recommendedPreset.versions,
            reason: recommendedPreset.description
        )
        presetPayloads[chatMessage.id] = payload

        // 🆕 로컬 AI 추천 기록 저장
        // Local AI recommendation recording not available in SessionManager

        // 🔓 로컬 추천 처리 완료
        isProcessingRecommendation = false
    }

    // MARK: - Phase 2: 통합 데이터 분석 헬퍼 메서드

    /// 사용자 데이터 기반 감정 추론
    private func inferEmotionFromUserData(context: LocalAIContext) -> String {
        let timeOfDay = getCurrentTimeOfDay()
        // 최근 사용자 텍스트(마지막 5개)
        let recentUserTexts = messages.suffix(5).compactMap { msg in
            (msg.sender == .user) ? msg.text : nil
        }
        // 1) 최근 감정 히스토리
        let recentEmotion = context.emotionHistory.first?.emotion
        // 2) 피드백 데이터 감정
        let feedbackEmotion = context.feedbackData.first?.contextEmotion
        // 우선순위: 히스토리 → 피드백 → 사용자 텍스트 → 시간대
        let primary = recentEmotion ?? feedbackEmotion
        let normalized = EmotionNormalizer.normalizeFromSignals(
            emotion: primary, recentUserTexts: recentUserTexts, timeOfDay: timeOfDay)
        return normalized
    }

    /// 감정 강도 계산
    private func calculateEmotionIntensity(from emotionHistory: [EmotionHistoryItem]) -> Float {
        guard !emotionHistory.isEmpty else { return 1.0 }

        // 최근 3개 감정의 평균 강도
        let recentEmotions = Array(emotionHistory.prefix(3))
        let averageIntensity =
            recentEmotions.map { $0.intensity }.reduce(0, +) / Float(recentEmotions.count)

        return averageIntensity
    }

    /// 🚀 Phase 3: 고도화된 풍부한 컨텍스트 문자열 생성 (품질 검증 강화)
    private func buildRichContextString(
        feedbackData: [PresetFeedback],
        emotionHistory: [EmotionHistoryItem],
        behaviorPatterns: [BehaviorPattern],
        timePreferences: [TimePreference]
    ) -> String {
        let startTime = Date()
        var contextBuilder = "사용자 개인화 데이터:\n"
        var contextQuality = ContextQuality()

        // 1. 최근 피드백 요약 (가중치: 높음)
        if !feedbackData.isEmpty {
            let recentFeedback = Array(feedbackData.prefix(3))
            contextBuilder += "최근 피드백: "
            for feedback in recentFeedback {
                if let presetName = feedback.presetName {
                    let satisfaction = feedback.satisfactionScore
                    contextBuilder += "\(presetName)(만족도: \(satisfaction)), "
                    contextQuality.addFeedbackData(quality: satisfaction > 3 ? .high : .medium)
                }
            }
            contextBuilder += "\n"
        }

        // 2. 감정 히스토리 요약 (가중치: 중간)
        if !emotionHistory.isEmpty {
            let recentEmotions = Array(emotionHistory.prefix(3))
            contextBuilder += "최근 감정: "
            for emotion in recentEmotions {
                contextBuilder +=
                    "\(emotion.emotion)(\(String(format: "%.1f", emotion.intensity))), "
                contextQuality.addEmotionData(intensity: Double(emotion.intensity))
            }
            contextBuilder += "\n"
        }

        // 3. 행동 패턴 요약 (가중치: 중간)
        if !behaviorPatterns.isEmpty {
            contextBuilder += "행동 패턴: "
            for pattern in behaviorPatterns.prefix(2) {
                contextBuilder +=
                    "\(pattern.pattern)(신뢰도: \(String(format: "%.1f", pattern.confidence))), "
                contextQuality.addBehaviorPattern(confidence: Double(pattern.confidence))
            }
            contextBuilder += "\n"
        }

        // 4. 시간 선호도 요약 (가중치: 낮음)
        if !timePreferences.isEmpty {
            let currentHour = Calendar.current.component(.hour, from: Date())
            if let currentTimePreference = timePreferences.first(where: { $0.hour == currentHour })
            {
                contextBuilder += "현재 시간대 선호도: \(currentTimePreference.preference)\n"
                contextQuality.addTimePreference()
            }
        }

        let finalContext = contextBuilder.trimmingCharacters(in: .whitespacesAndNewlines)
        let processingTime = Date().timeIntervalSince(startTime)

        // 🚀 Phase 3: 고도화된 컨텍스트 품질 분석
        let qualityScore = contextQuality.calculateScore()
        let qualityLevel = contextQuality.getQualityLevel()

        // 상세 로깅
        UnifiedLogger.shared.info("🔍 [AI Context] 컨텍스트 생성 완료", category: .ai)
        UnifiedLogger.shared.info("   품질 점수: \(qualityScore)/100", category: .ai)
        UnifiedLogger.shared.info("   품질 등급: \(qualityLevel)", category: .ai)
        UnifiedLogger.shared.info(
            "   처리 시간: \(String(format: "%.3f", processingTime))초", category: .ai)
        UnifiedLogger.shared.info(
            "   데이터 구성: 피드백 \(feedbackData.count)개, 감정 \(emotionHistory.count)개, 패턴 \(behaviorPatterns.count)개",
            category: .ai)

        // 품질 경고 및 개선 제안
        if qualityLevel == .poor {
            UnifiedLogger.shared.warning(
                "⚠️ [AI Context] 컨텍스트 품질이 낮습니다. 추천 품질에 영향을 줄 수 있습니다.", category: .ai)
            suggestContextImprovement(feedbackData: feedbackData, emotionHistory: emotionHistory)
        }

        // 성능 메트릭 기록
        recordContextGenerationMetrics(
            qualityScore: qualityScore,
            processingTime: processingTime,
            dataSize: finalContext.count
        )

        return finalContext
    }

    // MARK: - 🚀 Phase 3: 컨텍스트 품질 관리 시스템

    /// 컨텍스트 품질 계산기
    private struct ContextQuality {
        private var feedbackScore: Int = 0
        private var emotionScore: Int = 0
        private var behaviorScore: Int = 0
        private var timeScore: Int = 0

        mutating func addFeedbackData(quality: DataQuality) {
            feedbackScore += quality.rawValue * 3  // 피드백은 가중치 3
        }

        mutating func addEmotionData(intensity: Double) {
            let qualityLevel: DataQuality =
                intensity > 0.7 ? .high : intensity > 0.3 ? .medium : .low
            emotionScore += qualityLevel.rawValue * 2  // 감정은 가중치 2
        }

        mutating func addBehaviorPattern(confidence: Double) {
            let qualityLevel: DataQuality =
                confidence > 0.8 ? .high : confidence > 0.5 ? .medium : .low
            behaviorScore += qualityLevel.rawValue * 2  // 행동 패턴은 가중치 2
        }

        mutating func addTimePreference() {
            timeScore += 1  // 시간 선호도는 가중치 1
        }

        func calculateScore() -> Int {
            let totalScore = feedbackScore + emotionScore + behaviorScore + timeScore
            return min(100, totalScore)  // 최대 100점
        }

        func getQualityLevel() -> QualityLevel {
            let score = calculateScore()
            switch score {
            case 80...100: return .excellent
            case 60...79: return .good
            case 40...59: return .fair
            case 20...39: return .poor
            default: return .critical
            }
        }
    }

    private enum DataQuality: Int {
        case low = 1
        case medium = 2
        case high = 3
    }

    private enum QualityLevel: String {
        case excellent = "우수"
        case good = "양호"
        case fair = "보통"
        case poor = "부족"
        case critical = "심각"
    }

    /// 컨텍스트 개선 제안
    private func suggestContextImprovement(
        feedbackData: [PresetFeedback], emotionHistory: [EmotionHistoryItem]
    ) {
        var suggestions: [String] = []

        if feedbackData.isEmpty {
            suggestions.append("프리셋 사용 후 피드백 제공")
        }

        if emotionHistory.isEmpty {
            suggestions.append("감정 일기 작성")
        }

        if !suggestions.isEmpty {
            UnifiedLogger.shared.info(
                "💡 [AI Context] 개선 제안: \(suggestions.joined(separator: ", "))", category: .ai)
        }
    }

    /// 컨텍스트 생성 메트릭 기록
    private func recordContextGenerationMetrics(
        qualityScore: Int, processingTime: TimeInterval, dataSize: Int
    ) {
        // SessionManager를 통해 메트릭 저장
        let behaviorEvent = BehaviorEvent(
            type: .sessionStart,
            timestamp: Date(),
            data: [
                "qualityScore": String(qualityScore),
                "processingTime": String(processingTime),
                "dataSize": String(dataSize),
            ]
        )

        let currentSession = SessionManager.shared.getCurrentOrCreateSession()
        SessionManager.shared.addBehaviorEvent(to: currentSession.id, event: behaviorEvent)
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
            let total = AIUsageManager.shared.getTotalLimit(for: .presetRecommendation)
            let errorMessage = ChatMessage(
                text: "⚠️ 대나무숲 분석 추천 사용량이 초과되었습니다. (일일 \(total)회 제한)", sender: .ai, type: .bot)
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
        appendChat(
            ChatMessage(text: "🧠 대나무숲에서 7일간의 대화와 감정 기록을 종합 분석 중...", sender: .ai, type: .loading))

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
                // 🚀 SessionManager의 통합 AI 서비스 사용
                // 프리셋 추천에 특화된 처리
                let responseContent = try await SessionManager.shared.sendMessage(
                    content: "감정: \(currentEmotion ?? "평온"), 상황: \(analysisPrompt)",
                    model: .openAI,
                    mode: .presetRecommendation,
                    saveMessages: true
                )

                try await MainActor.run { [weak self] in
                    self?.removeLastLoadingMessage()

                    if !responseContent.isEmpty {
                        let recommendation = self?.parsePresetRecommendation(from: responseContent)
                        if let recommendation = recommendation {
                            self?.displayAIRecommendation(recommendation)
                            // 성공적으로 프리셋을 파싱·표시한 경우에만 사용량을 증가시킵니다.
                            AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                        } else {
                            UnifiedLogger.shared.warning("프리셋 파싱 실패 → OpenAI로 2차 시도")
                            Task {
                                do {
                                    let sid = self?.currentSessionId.uuidString ?? UUID().uuidString
                                    let uid = "user_\(sid)"
                                    let aiContext = AIContext(
                                        userId: uid,
                                        sessionId: sid,
                                        conversationHistory: [],
                                        userPreferences: nil,
                                        environmentContext: nil
                                    )
                                    let response2 = try await UnifiedAIServiceImpl.shared
                                        .sendMessageForceProvider(
                                            content:
                                                "감정: \(self?.currentEmotion ?? "평온"), 상황: \(analysisPrompt)",
                                            model: .openAI,
                                            mode: .presetRecommendation,
                                            context: aiContext,
                                            tokenConfig: nil,
                                            assembledPrompt: nil
                                        )
                                    if let second = self?.parsePresetRecommendation(
                                        from: response2.content)
                                    {
                                        self?.displayAIRecommendation(second)
                                        AIUsageManager.shared.recordUsage(
                                            for: .presetRecommendation)
                                    } else {
                                        UnifiedLogger.shared.error("OpenAI 2차 시도도 파싱 실패")
                                    }
                                } catch {
                                    UnifiedLogger.shared.error(
                                        "OpenAI 2차 시도 오류: \(error.localizedDescription)")
                                }
                            }
                        }
                    } else {
                        throw JSONParsingError.invalidJSON  // 에러 케이스로 전달
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
                        await self?.handleLocalRecommendation()  // 실패 시 로컬 분석으로 대체
                    }
                    self?.isProcessingRecommendation = false
                }
            }
        }
    }

    // MARK: - Phase 1: JSON 기반 AI 응답 파싱 (통합된 새로운 방식)
    func parsePresetRecommendation(from response: String) -> EnhancedRecommendationResponse? {
        UnifiedLogger.shared.debug("프리셋 파싱 시작: \\(response.prefix(100))...", category: .ai)
        let result = AIResponseParser.shared.parsePresetRecommendation(response)
        if result == nil {
            UnifiedLogger.shared.warning("모든 파싱 실패, 기본/레거시 포함")
        }
        return result
    }

    // 프리셋 내부 선택된 버전 계산(간단 규칙)
    private func generateOptimalVersions(volumes: [Float]) -> [Int] {
        // DRY 준수: 공통 유틸 호출로 대체
        return SoundPresetUtilities.generateOptimalVersions(volumes: volumes)
    }

    // MARK: - 🧠 과학적 프리셋 추천 시스템

    /// 감정과 시간대를 기반으로 과학적 프리셋 추천
    private func getScientificRecommendationFor(emotion: String) -> EnhancedRecommendationResponse?
    {
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
        // 결정적 정렬로 랜덤 제거: 사운드명 사전순으로 정렬 후 부족분 보충
        let deterministicRemainder = union.filter { !intersection.contains($0) }.sorted()
        finalSoundList += deterministicRemainder.prefix(max(0, 5 - intersection.count))

        // 볼륨 생성 (주요 사운드는 높게, 나머지는 낮게)
        var volumes: [Float] = Array(repeating: 0, count: 13)
        for (index, soundName) in finalSoundList.enumerated() {
            if let categoryIndex = SoundPresetCatalog.findCategoryIndex(by: soundName) {
                // 결정적 볼륨 규칙: 상위 3개는 높은 고정값, 나머지는 낮은 고정값
                volumes[categoryIndex] = index < 3 ? 80 : 35
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
        // 메인 화면 컨트롤러에도 적용(재생/저장 포함)
        if let mainVC = navigationController?.viewControllers.first as? ViewController {
            mainVC.applyPreset(
                volumes: preset.volumes, versions: preset.versions, name: preset.presetName)
        }
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

        alert.addAction(
            UIAlertAction(title: "👍 마음에 들어요", style: .default) { _ in
                self.sendFeedback(isPositive: true, presetName: presetName, volumes: volumes)
            })

        alert.addAction(
            UIAlertAction(title: "👎 아쉬워요", style: .destructive) { _ in
                self.sendFeedback(isPositive: false, presetName: presetName, volumes: volumes)
            })

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))

        present(alert, animated: true)
    }

    private func sendFeedback(isPositive: Bool, presetName: String, volumes: [Float]) {
        // 피드백 전송 로직
        UnifiedLogger.shared.debug(
            "피드백 전송: \(isPositive ? "긍정" : "부정") - \(presetName)", category: .feedback)
        showToast(message: "소중한 피드백 감사합니다! 🥰")
    }

    private func safePresetName(_ name: String) -> String {
        // DRY 준수: 공통 유틸 사용
        return SoundPresetUtilities.safePresetName(name)
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
        case (1, 1): return true  // 신정
        case (3, 1): return true  // 삼일절
        case (5, 5): return true  // 어린이날
        case (6, 6): return true  // 현충일
        case (8, 15): return true  // 광복절
        case (10, 3): return true  // 개천절
        case (10, 9): return true  // 한글날
        case (12, 25): return true  // 크리스마스
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
            return "home_night"  // 밤 시간대는 집에 있을 가능성이 높음
        } else if hour >= 9 && hour <= 17 && !isWeekend {
            return "work_office"  // 평일 낮 시간대는 직장에 있을 가능성이 높음
        } else if isWeekend {
            return "home_weekend"  // 주말은 집에 있을 가능성이 높음
        } else {
            return "transit"  // 출퇴근 시간대는 이동 중일 가능성이 높음
        }
    }
}

// MARK: - String Extensions for ChatViewController
extension String {
    func ranges(of substring: String) -> [NSRange] {
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: self.count)

        while searchRange.location < self.count {
            let foundRange = (self as NSString).range(
                of: substring, options: [], range: searchRange)
            if foundRange.location != NSNotFound {
                ranges.append(foundRange)
                searchRange = NSRange(
                    location: foundRange.location + foundRange.length,
                    length: self.count - (foundRange.location + foundRange.length))
            } else {
                break
            }
        }

        return ranges
    }
}

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
            self.debouncedReload()
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
        if let data = PerformanceOptimizer.shared.getCachedData(
            forKey: "image_\(key)", type: Data.self)
        {
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
            let messageText = foundMessage.text
        else {
            UnifiedLogger.shared.error("메시지를 찾을 수 없음 - messageId: \(messageId)")
            UnifiedLogger.shared.error(
                "displayMessages 개수: \(displayMessages.count), messages 개수: \(messages.count)")
            return
        }

        UnifiedLogger.shared.debug(
            "메시지 발견 - 타입: \(foundMessage.type), 텍스트 일부: \(String(messageText.prefix(50)))",
            category: .ui)

        // 1) 추천 페이로드가 연결되어 있으면 그 값을 적용 (정확)
        if let payload = presetPayloads[messageId] {
            applyPreset(payload)
            return
        }
        // 2) 연결이 없으면 메시지 텍스트에서 JSON/키 기반으로 복구 시도
        if let recovered = parsePresetRecommendation(from: messageText) {
            applyPreset(recovered)
            return
        }
        // 3) 마지막으로, 메시지에서 프리셋 이름을 추출해 카탈로그에서 찾기 (강화된 매핑)
        let extractedName = extractPresetName(from: messageText)
        if let resolved = resolvePresetVolumes(byName: extractedName) {
            if let mainVC = navigationController?.viewControllers.first as? ViewController {
                mainVC.applyPreset(
                    volumes: resolved.volumes, versions: SoundPresetCatalog.defaultVersions,
                    name: resolved.name)
            }
            return
        }
        UnifiedLogger.shared.error("프리셋을 찾을 수 없음: \(extractedName)")
        let errorMessage = ChatMessage(
            text: "⚠️ 죄송합니다. 해당 프리셋을 찾을 수 없습니다.\n다른 추천을 받아보시겠어요?",
            sender: .ai,
            type: .bot
        )
        appendChat(errorMessage)
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
                    UnifiedLogger.shared.debug(
                        "**[이름]** 패턴에서 프리셋 이름 추출 성공: \(presetName)", category: .ui)
                    return presetName
                }
            }
        }

        // 다양한 접두사 패턴으로 프리셋 이름 추출 시도
        let patterns = [
            "추천 프리셋: ",
            "프리셋: ",
            "적용할 프리셋: ",
            "프리셋 이름: ",
        ]

        for pattern in patterns {
            if let range = messageText.range(of: pattern) {
                let afterPrefix = String(messageText[range.upperBound...])
                let presetName: String

                if let newlineRange = afterPrefix.range(of: "\n") {
                    presetName = String(afterPrefix[..<newlineRange.lowerBound]).trimmingCharacters(
                        in: .whitespaces)
                } else {
                    presetName = afterPrefix.trimmingCharacters(in: .whitespaces)
                }

                if !presetName.isEmpty {
                    UnifiedLogger.shared.debug(
                        "패턴 '\(pattern)'에서 프리셋 이름 추출 성공: \(presetName)", category: .ui)
                    return presetName
                }
            }
        }

        // 카탈로그 이름 스캔 (샘플 + 과학 프리셋)
        for presetName in SoundPresetCatalog.samplePresets.keys {
            if messageText.contains(presetName) { return presetName }
        }
        for presetName in SoundPresetCatalog.scientificPresets.keys {
            if messageText.contains(presetName) { return presetName }
        }

        // 기본값으로 "깊은 휴식" 반환
        UnifiedLogger.shared.debug("프리셋 이름 추출 실패 - 기본값 사용: 깊은 휴식", category: .ui)
        return "깊은 휴식"
    }

    // MARK: - 이름 정규화 및 매핑 보조
    private func normalizePresetName(_ name: String) -> String {
        // 특수문자/이모지(대부분의 기호 포함)를 제거하고 한글/영문/숫자/공백만 유지
        // 그리고 공백/대소문자/슬래시 표준화
        let lowered = name.lowercased()
        var cleaned =
            lowered
            .replacingOccurrences(of: "[\n\r\t]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[()\[\]\{\}]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "[|]", with: " ", options: .regularExpression)
        // 허용: 한글/영문/숫자/공백, 나머지는 제거
        cleaned = cleaned.replacingOccurrences(
            of: "[^0-9a-z가-힣 ]", with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        // 다중 공백 축약
        return cleaned.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
    }

    private func resolvePresetVolumes(byName name: String) -> (name: String, volumes: [Float])? {
        let norm = normalizePresetName(name)

        // 1) 정확/유사 매칭: 과학 프리셋
        if let match = SoundPresetCatalog.scientificPresets.first(where: {
            normalizePresetName($0.key) == norm
        }) {
            return (name: match.key, volumes: match.value)
        }
        // 부분 포함 매칭
        if let match = SoundPresetCatalog.scientificPresets.first(where: {
            normalizePresetName($0.key).contains(norm) || norm.contains(normalizePresetName($0.key))
        }) {
            return (name: match.key, volumes: match.value)
        }

        // 2) 샘플 프리셋 매칭
        if let match = SoundPresetCatalog.samplePresets.first(where: {
            normalizePresetName($0.key) == norm
        }) {
            return (name: match.key, volumes: match.value)
        }
        if let match = SoundPresetCatalog.samplePresets.first(where: {
            normalizePresetName($0.key).contains(norm) || norm.contains(normalizePresetName($0.key))
        }) {
            return (name: match.key, volumes: match.value)
        }

        // 3) 의미 기반 간단 매핑 (한국어 키워드 → 대표 과학 프리셋)
        let keywordToKey: [(pattern: String, key: String)] = [
            ("수면|잠|밤|저녁", "Deep Sleep Maintenance"),
            ("평온|안정|이완|휴식", "Zen Garden Flow"),
            ("집중|몰입|학습|코딩", "Deep Work Flow"),
            ("활력|에너지|기상|아침", "Morning Energy Boost"),
            ("명상|마음챙김|명상", "Walking Meditation"),
            ("불안|초조|긴장|코르티솔", "Nature Stress Detox"),
        ]
        for map in keywordToKey {
            if norm.range(of: map.pattern, options: .regularExpression) != nil,
                let vols = SoundPresetCatalog.scientificPresets[map.key]
            {
                return (name: map.key, volumes: vols)
            }
        }

        return nil
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
                return "사용자: \(text.prefix(50))"  // 50자만
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
        let userSettings = SettingsManager.shared.settings

        let personality = "보통"  // userSettings.personality ?? "보통"
        let preferredStyle = "자연음"  // userSettings.preferredStyle ?? "자연음"
        let sleepPattern = "일반"  // userSettings.sleepPattern ?? "일반"

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

        // SessionManager를 통한 초기화
        setupInitialMessages()

        // 1. SessionManager에서 저장된 세션 확인
        let sessions = SessionManager.shared.getAllSessions()
        let hasStoredMessages = sessions.contains { !$0.chatMessages.isEmpty }

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

    /// ChatManager에서 채팅 히스토리 복원 - MessageStore 실패 시 백업 방법
    private func restoreFromChatManager() {
        #if DEBUG
            print("💾 [ChatPersistence] ChatManager에서 히스토리 복원 시도 (백업)")
        #endif

        // SessionManager를 통한 처리

        let sessions = SessionManager.shared.getAllSessions()
        guard let latestSession = sessions.first else {
            print("🔄 [ChatViewController] 저장된 세션이 없습니다")
            return
        }

        #if DEBUG
            print("💾 [ChatPersistence] 최신 세션에서 \(latestSession.chatMessages.count)개 메시지 발견")
        #endif

        Task { @MainActor in
            // 기존 메시지 제거 - 제거 비활성화
            // 이미 restoreAndInitializeMessages에서 처리됨
            // if !latestSession.messages.isEmpty {
            //     self.messages.removeAll()
            // }

            // StoredChatMessage를 ChatMessage로 변환
            for storedMessage in latestSession.chatMessages {
                let isUser = (storedMessage.type == .user)
                let chatMessage = ChatMessage(
                    text: storedMessage.content,
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
            self.debouncedReload()
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
