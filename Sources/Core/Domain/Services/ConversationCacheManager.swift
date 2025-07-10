//
//  ConversationCacheManager.swift
//  DeepSleep
//
//  Created by AI on 2025/07/10.
//

import Foundation

/// 대화 저장 계층 타입
public enum ConversationLayer: String, Codable {
    case recent = "recent"         // 최근 1일: 전체 대화
    case important = "important"   // 2-3일: 중요도 높은 것만 전체
    case summary = "summary"       // 2-3일: 나머지는 요약
    case keywords = "keywords"     // 4-7일: 핵심 키워드만
    
    var tokenBudget: Int {
        switch self {
        case .recent: return 300      // 전체 대화
        case .important: return 200   // 전체 대화 (약간 압축)
        case .summary: return 60      // 요약된 대화
        case .keywords: return 30     // 핵심 키워드만
        }
    }
    
    var maxCount: Int {
        switch self {
        case .recent: return 3        // 최근 3개
        case .important: return 7     // 중요한 7개
        case .summary: return 15      // 요약 15개
        case .keywords: return 25     // 키워드 25개
        }
    }
}

/// 캐시된 대화 데이터
public struct CachedConversation: Codable, Identifiable {
    public let id: String
    public let date: Date
    public let userMessage: String
    public let aiResponse: String
    public let layer: ConversationLayer
    public let importance: Float // 0.0-1.0
    public let summary: String?
    public let keywords: [String]
    public let emotionTone: String?
    public let estimatedTokens: Int
    
    public init(
        id: String = UUID().uuidString,
        date: Date,
        userMessage: String,
        aiResponse: String,
        layer: ConversationLayer = .recent,
        importance: Float = 0.5,
        summary: String? = nil,
        keywords: [String] = [],
        emotionTone: String? = nil,
        estimatedTokens: Int = 0
    ) {
        self.id = id
        self.date = date
        self.userMessage = userMessage
        self.aiResponse = aiResponse
        self.layer = layer
        self.importance = importance
        self.summary = summary
        self.keywords = keywords
        self.emotionTone = emotionTone
        self.estimatedTokens = estimatedTokens
    }
}

/// 지능형 대화 캐시 관리자
public final class ConversationCacheManager {
    
    // MARK: - Properties
    
    public static let shared = ConversationCacheManager()
    private let fileManager = FileManager.default
    private let cacheQueue = DispatchQueue(label: "com.deepsleep.cache", attributes: .concurrent)
    
    // 설정값
    private let maxDays = 7
    private let maxTokenBudget = 4000
    
    // 캐시 저장 경로
    private var cacheStorageURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("ConversationCache")
    }
    
    // MARK: - Initialization
    
    private init() {
        setupCacheStorage()
    }
    
    // MARK: - Public Methods
    
    /// 새로운 대화를 캐시에 추가
    public func addConversation(
        userMessage: String,
        aiResponse: String,
        emotionTone: String? = nil
    ) async throws {
        let conversation = CachedConversation(
            date: Date(),
            userMessage: userMessage,
            aiResponse: aiResponse,
            importance: calculateImportance(userMessage: userMessage, aiResponse: aiResponse),
            keywords: extractKeywords(from: userMessage + " " + aiResponse),
            emotionTone: emotionTone,
            estimatedTokens: estimateTokens(userMessage + aiResponse)
        )
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            cacheQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LLMError.unexpectedError(NSError(domain: "ConversationCacheManager", code: -1)))
                    return
                }
                
                do {
                    var conversations = try self.loadAllConversations()
                    conversations.append(conversation)
                    
                    // 지능형 압축 및 정리
                    conversations = self.optimizeCache(conversations)
                    
                    try self.saveConversations(conversations)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// AI 요청을 위한 컨텍스트 생성
    public func getContextForAI() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LLMError.unexpectedError(NSError(domain: "ConversationCacheManager", code: -1)))
                    return
                }
                
                do {
                    let conversations = try self.loadAllConversations()
                    let context = self.formatConversationsForAI(conversations)
                    continuation.resume(returning: context)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 캐시 통계 정보
    public func getCacheStats() async throws -> (count: Int, tokens: Int, oldestDate: Date?) {
        return try await withCheckedThrowingContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LLMError.unexpectedError(NSError(domain: "ConversationCacheManager", code: -1)))
                    return
                }
                
                do {
                    let conversations = try self.loadAllConversations()
                    let totalTokens = conversations.reduce(0) { $0 + $1.estimatedTokens }
                    let oldestDate = conversations.map(\.date).min()
                    
                    continuation.resume(returning: (
                        count: conversations.count,
                        tokens: totalTokens,
                        oldestDate: oldestDate
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 캐시 초기화
    public func clearCache() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            cacheQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LLMError.unexpectedError(NSError(domain: "ConversationCacheManager", code: -1)))
                    return
                }
                
                do {
                    try self.fileManager.removeItem(at: self.cacheStorageURL)
                    self.setupCacheStorage()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 캐시 최적화 및 계층 분배
    private func optimizeCache(_ conversations: [CachedConversation]) -> [CachedConversation] {
        let cutoffDate = Date().addingTimeInterval(-Double(maxDays) * 24 * 60 * 60)
        let recentConversations = conversations
            .filter { $0.date >= cutoffDate }
            .sorted { $0.date > $1.date }
        
        var optimizedConversations: [CachedConversation] = []
        var currentTokens = 0
        
        let now = Date()
        
        for conversation in recentConversations {
            let daysSince = Calendar.current.dateComponents([.day], from: conversation.date, to: now).day ?? 0
            
            // 계층 결정
            let newLayer: ConversationLayer
            if daysSince == 0 {
                newLayer = .recent
            } else if daysSince <= 3 && conversation.importance >= 0.7 {
                newLayer = .important
            } else if daysSince <= 3 {
                newLayer = .summary
            } else {
                newLayer = .keywords
            }
            
            // 계층별 최대 개수 확인
            let currentLayerCount = optimizedConversations.filter { $0.layer == newLayer }.count
            if currentLayerCount >= newLayer.maxCount {
                continue
            }
            
            // 토큰 예산 확인
            let estimatedTokens = newLayer.tokenBudget
            if currentTokens + estimatedTokens > maxTokenBudget {
                break
            }
            
            // 계층에 맞게 대화 압축
            let optimizedConversation = compressConversation(conversation, to: newLayer)
            optimizedConversations.append(optimizedConversation)
            currentTokens += estimatedTokens
        }
        
        return optimizedConversations
    }
    
    /// 대화를 지정된 계층으로 압축
    private func compressConversation(_ conversation: CachedConversation, to layer: ConversationLayer) -> CachedConversation {
        switch layer {
        case .recent, .important:
            // 전체 대화 유지 (약간의 압축만)
            return CachedConversation(
                id: conversation.id,
                date: conversation.date,
                userMessage: conversation.userMessage,
                aiResponse: conversation.aiResponse,
                layer: layer,
                importance: conversation.importance,
                summary: conversation.summary,
                keywords: conversation.keywords,
                emotionTone: conversation.emotionTone,
                estimatedTokens: layer.tokenBudget
            )
            
        case .summary:
            // 요약된 형태로 변환
            let summary = conversation.summary ?? generateSummary(
                userMessage: conversation.userMessage,
                aiResponse: conversation.aiResponse
            )
            
            return CachedConversation(
                id: conversation.id,
                date: conversation.date,
                userMessage: truncateText(conversation.userMessage, maxTokens: 30),
                aiResponse: truncateText(summary, maxTokens: 30),
                layer: layer,
                importance: conversation.importance,
                summary: summary,
                keywords: conversation.keywords,
                emotionTone: conversation.emotionTone,
                estimatedTokens: layer.tokenBudget
            )
            
        case .keywords:
            // 키워드만 보존
            let keywordSummary = conversation.keywords.joined(separator: ", ")
            
            return CachedConversation(
                id: conversation.id,
                date: conversation.date,
                userMessage: keywordSummary,
                aiResponse: conversation.emotionTone ?? "중립",
                layer: layer,
                importance: conversation.importance,
                summary: conversation.summary,
                keywords: conversation.keywords,
                emotionTone: conversation.emotionTone,
                estimatedTokens: layer.tokenBudget
            )
        }
    }
    
    /// 대화 중요도 계산
    private func calculateImportance(userMessage: String, aiResponse: String) -> Float {
        var importance: Float = 0.5
        
        let text = (userMessage + " " + aiResponse).lowercased()
        
        // 수면 관련 키워드
        let sleepKeywords = ["잠", "수면", "불면", "꿈", "새벽", "밤"]
        for keyword in sleepKeywords {
            if text.contains(keyword) {
                importance += 0.1
            }
        }
        
        // 감정 키워드
        let emotionKeywords = ["스트레스", "우울", "불안", "행복", "슬픔", "화"]
        for keyword in emotionKeywords {
            if text.contains(keyword) {
                importance += 0.15
            }
        }
        
        // 해결책/조언 키워드
        let solutionKeywords = ["어떻게", "방법", "도움", "추천", "조언"]
        for keyword in solutionKeywords {
            if text.contains(keyword) {
                importance += 0.1
            }
        }
        
        // 개인적 정보
        let personalKeywords = ["처음", "항상", "매일", "보통", "평소"]
        for keyword in personalKeywords {
            if text.contains(keyword) {
                importance += 0.05
            }
        }
        
        return min(importance, 1.0)
    }
    
    /// 키워드 추출
    private func extractKeywords(from text: String) -> [String] {
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 1 }
        
        let sleepKeywords = ["잠", "수면", "불면", "꿈", "새벽", "밤", "졸음", "피곤"]
        let emotionKeywords = ["스트레스", "우울", "불안", "행복", "슬픔", "화남", "기쁨"]
        let importantWords = sleepKeywords + emotionKeywords
        
        return words.filter { word in
            importantWords.contains { $0.contains(word) || word.contains($0) }
        }.prefix(5).map { String($0) }
    }
    
    /// 토큰 수 추정
    private func estimateTokens(_ text: String) -> Int {
        // 한국어 기준 대략적인 토큰 계산 (단어 수 × 1.3)
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).count
        return Int(Float(wordCount) * 1.3)
    }
    
    /// 간단한 요약 생성
    private func generateSummary(userMessage: String, aiResponse: String) -> String {
        let userPart = truncateText(userMessage, maxTokens: 15)
        let aiPart = truncateText(aiResponse, maxTokens: 15)
        return "사용자: \(userPart) → AI: \(aiPart)"
    }
    
    /// 텍스트 길이 제한
    private func truncateText(_ text: String, maxTokens: Int) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let maxWords = maxTokens * 3 / 4 // 토큰 대비 단어 수 추정
        
        if words.count <= maxWords {
            return text
        }
        
        return words.prefix(maxWords).joined(separator: " ") + "..."
    }
    
    /// AI용 컨텍스트 포맷팅
    private func formatConversationsForAI(_ conversations: [CachedConversation]) -> String {
        if conversations.isEmpty {
            return ""
        }
        
        var context = "\n\n[대화 기록]\n"
        
        // 계층별로 그룹화
        let groupedByLayer = Dictionary(grouping: conversations) { $0.layer }
        
        // 최근 대화부터 표시
        for layer in [ConversationLayer.recent, .important, .summary, .keywords] {
            guard let layerConversations = groupedByLayer[layer], !layerConversations.isEmpty else { continue }
            
            let sortedConversations = layerConversations.sorted { $0.date > $1.date }
            
            for conversation in sortedConversations {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MM/dd HH:mm"
                let dateStr = dateFormatter.string(from: conversation.date)
                
                switch layer {
                case .recent, .important:
                    context += "[\(dateStr)] 사용자: \(conversation.userMessage)\n"
                    context += "AI: \(conversation.aiResponse)\n\n"
                    
                case .summary:
                    context += "[\(dateStr)] 요약: \(conversation.summary ?? conversation.userMessage)\n"
                    
                case .keywords:
                    if !conversation.keywords.isEmpty {
                        context += "[\(dateStr)] 키워드: \(conversation.keywords.joined(separator: ", "))\n"
                    }
                }
            }
        }
        
        return context
    }
    
    /// 캐시 저장소 설정
    private func setupCacheStorage() {
        if !fileManager.fileExists(atPath: cacheStorageURL.path) {
            try? fileManager.createDirectory(at: cacheStorageURL, withIntermediateDirectories: true)
        }
    }
    
    /// 모든 대화 로드
    private func loadAllConversations() throws -> [CachedConversation] {
        let conversationsFileURL = cacheStorageURL.appendingPathComponent("conversations.json")
        
        guard fileManager.fileExists(atPath: conversationsFileURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: conversationsFileURL)
        let conversations = try JSONDecoder().decode([CachedConversation].self, from: data)
        return conversations
    }
    
    /// 대화 저장
    private func saveConversations(_ conversations: [CachedConversation]) throws {
        let conversationsFileURL = cacheStorageURL.appendingPathComponent("conversations.json")
        let data = try JSONEncoder().encode(conversations)
        try data.write(to: conversationsFileURL)
    }
}
