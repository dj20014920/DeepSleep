//
//  LongTermMemoryManager.swift
//  DeepSleep
//
//  Created by AI on 2025/07/04.
//

import Foundation

/// 장기 기억 관리자 - 사용자의 과거 대화와 감정을 벡터화하여 저장하고 검색
/// Claude의 Projects, GPT의 Memory, Gemini의 Context Caching 기법을 참고한 고도화된 구현
public final class LongTermMemoryManager {
    
    // MARK: - Properties
    
    public static let shared = LongTermMemoryManager()
    private let fileManager = FileManager.default
    private let memoryQueue = DispatchQueue(label: "com.deepsleep.memory", attributes: .concurrent)
    
    // 메모리 저장 경로
    private var memoryStorageURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("DeepSleepMemories")
    }
    
    // 메모리 카테고리 (Claude Projects처럼 구조화)
    private var categoryStorageURL: URL {
        memoryStorageURL.appendingPathComponent("categories")
    }
    
    // 메모리 인덱스 (빠른 검색을 위한 인덱싱)
    private var memoryIndex = MemoryIndex()
    
    // 메모리 압축 전략 (GPT처럼 중요한 정보만 장기 저장)
    private let compressionStrategy = MemoryCompressionStrategy()
    
    // 컨텍스트 우선순위 큐 (Gemini처럼 관련성 높은 순으로 정렬)
    private var contextPriorityQueue = PriorityQueue<MemoryItem>()
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryStorage()
    }
    
    // MARK: - Public Methods
    
    /// 관련 메모리 검색 - 다층 검색 전략 (Multi-tier Search Strategy)
    public func searchRelevantMemories(query: String, limit: Int = 5) async throws -> [MemoryItem] {
        return try await withCheckedThrowingContinuation { continuation in
            memoryQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LLMError.unexpectedError(NSError(domain: "LongTermMemoryManager", code: -1)))
                    return
                }
                
                do {
                    // 1단계: 인덱스 기반 빠른 검색
                    let indexResults = self.memoryIndex.search(query: query, limit: limit * 3)
                    
                    // 2단계: 시맨틱 검색 (의미 기반)
                    let semanticResults = try self.performSemanticSearch(query: query, candidates: indexResults)
                    
                    // 3단계: 시간적 관련성 고려
                    let temporallyWeightedResults = self.applyTemporalWeighting(memories: semanticResults)
                    
                    // 4단계: 감정적 공명도 계산
                    let emotionallyRelevant = self.calculateEmotionalResonance(query: query, memories: temporallyWeightedResults)
                    
                    // 5단계: 최종 랭킹 및 압축
                    let finalResults = Array(emotionallyRelevant.prefix(limit))
                    
                    continuation.resume(returning: finalResults)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Advanced Search Methods
    
    private func performSemanticSearch(query: String, candidates: [String]) throws -> [MemoryItem] {
        let memories = try loadMemoriesByIds(candidates)
        
        // 의미 유사도 계산 (간단한 구현, 실제로는 임베딩 사용)
        return memories.sorted { mem1, mem2 in
            let sim1 = calculateSemanticSimilarity(query, mem1.content)
            let sim2 = calculateSemanticSimilarity(query, mem2.content)
            return sim1 > sim2
        }
    }
    
    private func applyTemporalWeighting(memories: [MemoryItem]) -> [(memory: MemoryItem, score: Double)] {
        let now = Date()
        return memories.map { memory in
            let daysSince = Calendar.current.dateComponents([.day], from: memory.date, to: now).day ?? 0
            
            // 최근 기억일수록 가중치 증가 (지수 감쇠)
            let temporalWeight = exp(-Double(daysSince) / 30.0)
            let adjustedScore = memory.relevanceScore * temporalWeight
            
            return (memory: memory, score: adjustedScore)
        }
    }
    
    private func calculateEmotionalResonance(query: String, memories: [(memory: MemoryItem, score: Double)]) -> [MemoryItem] {
        // 쿼리의 감정 톤 분석
        let queryEmotion = analyzeEmotionTone(query)
        
        let scoredMemories = memories.map { item -> (memory: MemoryItem, score: Double) in
            var score = item.score
            if let memoryEmotion = item.memory.emotion {
                // 감정 유사도에 따른 가중치
                let emotionSimilarity = calculateEmotionSimilarity(queryEmotion, memoryEmotion)
                score *= (1.0 + emotionSimilarity * 0.5)
            }
            return (memory: item.memory, score: score)
        }
        
        return scoredMemories
            .sorted { $0.score > $1.score }
            .map { $0.memory }
    }
    
    /// 새로운 메모리 저장 - 지능형 압축 및 카테고리화
    public func saveMemory(_ content: String, summary: String, emotion: String? = nil, category: MemoryCategory? = nil) async throws {
        // 1. 중요도 평가
        let importance = evaluateMemoryImportance(content: content, emotion: emotion)
        
        // 2. 압축 수행 (GPT Memory처럼)
        let compressedContent = importance < 0.3 ? compressionStrategy.compress(content) : content
        
        // 3. 자동 카테고리 분류
        let finalCategory = category ?? categorizeMemory(content: content, emotion: emotion)
        
        // 4. 임베딩 생성 (간단한 해시 기반, 실제로는 ML 모델 사용)
        let embedding = generateEmbedding(text: compressedContent)
        
        let memory = MemoryItem(
            id: UUID().uuidString,
            date: Date(),
            content: compressedContent,
            summary: summary,
            emotion: emotion,
            embedding: embedding,
            category: finalCategory,
            importance: importance,
            compressionRatio: Double(compressedContent.count) / Double(content.count),
            accessCount: 0,
            lastAccessDate: Date(),
            metadata: MemoryMetadata(
                source: .aiGenerated,
                context: [:],
                tags: [],
                linkedMemories: [],
                sentiment: 0.0,
                confidence: importance
            )
        )
        
        // 5. 인덱스 업데이트
        memoryIndex.add(memory)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            memoryQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LLMError.unexpectedError(NSError(domain: "LongTermMemoryManager", code: -1)))
                    return
                }
                
                do {
                    var memories = try self.loadAllMemories()
                    memories.append(memory)
                    
                    // 메모리 관리 전략 (Claude의 프로젝트처럼 카테고리별 제한)
                    memories = self.applyMemoryManagementStrategy(memories)
                    
                    try self.saveMemories(memories)
                    
                    // 카테고리별 저장
                    if let category = memory.category {
                        self.saveToCategoryIndex(memory, category: category)
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Memory Management Strategy
    
    private func applyMemoryManagementStrategy(_ memories: [MemoryItem]) -> [MemoryItem] {
        // GPT Memory처럼 중요도가 낮고 오래된 메모리는 압축 또는 삭제
        let maxMemories = 5000 // 최대 메모리 수
        
        if memories.count <= maxMemories {
            return memories
        }
        
        // 중요도와 최근성 기반 정렬
        let sortedMemories = memories.sorted { mem1, mem2 in
            // 중요도가 높을수록, 최근일수록 우선
            if mem1.importance != mem2.importance {
                return mem1.importance > mem2.importance
            }
            return mem1.date > mem2.date
        }
        
        // 카테고리별 균형 유지
        var categoryQuotas: [MemoryCategory: Int] = [:]
        for category in MemoryCategory.allCases {
            categoryQuotas[category] = maxMemories / MemoryCategory.allCases.count
        }
        
        var finalMemories: [MemoryItem] = []
        var categoryCounts: [MemoryCategory: Int] = [:]
        
        for memory in sortedMemories {
            let category = memory.category ?? .conversation
            let currentCount = categoryCounts[category] ?? 0
            let quota = categoryQuotas[category] ?? 0
            
            if currentCount < quota || memory.importance > 0.8 {
                finalMemories.append(memory)
                categoryCounts[category] = currentCount + 1
            }
            
            if finalMemories.count >= maxMemories {
                break
            }
        }
        
        return finalMemories
    }
    
    // MARK: - Helper Methods
    
    private func evaluateMemoryImportance(content: String, emotion: String?) -> Double {
        var importance = 0.5 // 기본값
        
        // 감정 강도에 따른 중요도
        if let emotion = emotion {
            let strongEmotions = ["매우 행복", "매우 슬픔", "분노", "공포", "사랑"]
            if strongEmotions.contains(emotion) {
                importance += 0.3
            }
        }
        
        // 내용 길이와 복잡도
        let wordCount = content.components(separatedBy: .whitespaces).count
        if wordCount > 50 {
            importance += 0.1
        }
        
        // 특별한 키워드 포함 여부
        let importantKeywords = ["중요", "절대", "반드시", "기억", "특별", "처음", "마지막"]
        for keyword in importantKeywords {
            if content.contains(keyword) {
                importance += 0.1
                break
            }
        }
        
        return min(importance, 1.0)
    }
    
    private func categorizeMemory(content: String, emotion: String?) -> MemoryCategory {
        // 키워드 기반 자동 분류
        let content = content.lowercased()
        
        if content.contains("수면") || content.contains("잠") || content.contains("꿈") {
            return .sleep
        } else if content.contains("운동") || content.contains("건강") || content.contains("활동") {
            return .health
        } else if emotion != nil {
            return .emotion
        } else if content.contains("성공") || content.contains("달성") || content.contains("완료") {
            return .achievement
        } else if content.contains("깨달음") || content.contains("알게") || content.contains("발견") {
            return .insight
        } else if content.contains("매일") || content.contains("일상") || content.contains("습관") {
            return .routine
        } else {
            return .conversation
        }
    }
    
    private func generateEmbedding(text: String) -> [Float] {
        // 간단한 해시 기반 임베딩 (실제로는 BERT 등 사용)
        let hash = text.hashValue
        var embedding: [Float] = []
        
        for i in 0..<128 { // 128차원 벡터
            let value = Float((hash &>> i) & 1) * 2.0 - 1.0
            embedding.append(value + Float.random(in: -0.1...0.1))
        }
        
        return embedding
    }
    
    private func calculateSemanticSimilarity(_ text1: String, _ text2: String) -> Double {
        // 간단한 자카드 유사도 (실제로는 코사인 유사도 사용)
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespaces))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespaces))
        
        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }
    
    private func analyzeEmotionTone(_ text: String) -> String {
        // 간단한 감정 분석 (실제로는 ML 모델 사용)
        let positiveWords = ["행복", "기쁨", "좋", "사랑", "감사"]
        let negativeWords = ["슬픔", "우울", "화", "스트레스", "불안"]
        
        var positiveScore = 0
        var negativeScore = 0
        
        for word in positiveWords {
            if text.contains(word) { positiveScore += 1 }
        }
        
        for word in negativeWords {
            if text.contains(word) { negativeScore += 1 }
        }
        
        if positiveScore > negativeScore {
            return "긍정"
        } else if negativeScore > positiveScore {
            return "부정"
        } else {
            return "중립"
        }
    }
    
    private func calculateEmotionSimilarity(_ emotion1: String, _ emotion2: String) -> Double {
        // 감정 유사도 매트릭스
        let emotionMap: [String: [String: Double]] = [
            "긍정": ["긍정": 1.0, "중립": 0.3, "부정": 0.0],
            "중립": ["긍정": 0.3, "중립": 1.0, "부정": 0.3],
            "부정": ["긍정": 0.0, "중립": 0.3, "부정": 1.0]
        ]
        
        return emotionMap[emotion1]?[emotion2] ?? 0.5
    }
    
    private func loadMemoriesByIds(_ ids: [String]) throws -> [MemoryItem] {
        let allMemories = try loadAllMemories()
        let idSet = Set(ids)
        return allMemories.filter { idSet.contains($0.id) }
    }
    
    private func saveToCategoryIndex(_ memory: MemoryItem, category: MemoryCategory) {
        let categoryURL = categoryStorageURL.appendingPathComponent("\(category.rawValue).json")
        
        do {
            var categoryMemories: [String] = []
            
            if fileManager.fileExists(atPath: categoryURL.path) {
                let data = try Data(contentsOf: categoryURL)
                categoryMemories = try JSONDecoder().decode([String].self, from: data)
            }
            
            categoryMemories.append(memory.id)
            
            // 카테고리별 최대 1000개 유지
            if categoryMemories.count > 1000 {
                categoryMemories = Array(categoryMemories.suffix(1000))
            }
            
            let data = try JSONEncoder().encode(categoryMemories)
            try data.write(to: categoryURL)
        } catch {
            print("Failed to save category index: \(error)")
        }
    }
    
    /// 메모리 초기화
    public func clearAllMemories() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            memoryQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: LLMError.unexpectedError(NSError(domain: "LongTermMemoryManager", code: -1)))
                    return
                }
                
                do {
                    try self.fileManager.removeItem(at: self.memoryStorageURL)
                    self.setupMemoryStorage()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryStorage() {
        if !fileManager.fileExists(atPath: memoryStorageURL.path) {
            try? fileManager.createDirectory(at: memoryStorageURL, withIntermediateDirectories: true)
        }
    }
    
    private func loadAllMemories() throws -> [MemoryItem] {
        let memoriesFileURL = memoryStorageURL.appendingPathComponent("memories.json")
        
        guard fileManager.fileExists(atPath: memoriesFileURL.path) else {
            return []
        }
        
        let data = try Data(contentsOf: memoriesFileURL)
        let memories = try JSONDecoder().decode([MemoryItem].self, from: data)
        return memories
    }
    
    private func saveMemories(_ memories: [MemoryItem]) throws {
        let memoriesFileURL = memoryStorageURL.appendingPathComponent("memories.json")
        let data = try JSONEncoder().encode(memories)
        try data.write(to: memoriesFileURL)
    }
}

// MARK: - Vector Database Protocol (추후 구현)

protocol VectorDatabase {
    func search(query: [Float], topK: Int) async throws -> [(id: String, score: Float)]
    func insert(id: String, vector: [Float]) async throws
    func delete(id: String) async throws
    func update(id: String, vector: [Float]) async throws
}

// MARK: - Local Vector Database Implementation (추후 구현)

class LocalVectorDatabase: VectorDatabase {
    func search(query: [Float], topK: Int) async throws -> [(id: String, score: Float)] {
        // TODO: 코사인 유사도 기반 검색 구현
        return []
    }
    
    func insert(id: String, vector: [Float]) async throws {
        // TODO: 벡터 저장 구현
    }
    
    func delete(id: String) async throws {
        // TODO: 벡터 삭제 구현
    }
    
    func update(id: String, vector: [Float]) async throws {
        // TODO: 벡터 업데이트 구현
    }
}
