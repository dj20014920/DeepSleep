//
//  MemoryStructures.swift
//  DeepSleep
//
//  Created by AI on 2025/07/04.
//

import Foundation

// MARK: - Enhanced Memory Item

public struct MemoryItem: Codable {
    public let id: String
    public let date: Date
    public let content: String
    public let summary: String
    public let emotion: String?
    public let embedding: [Float]?
    
    // 고도화된 필드들
    public let category: MemoryCategory?
    public let importance: Double
    public let compressionRatio: Double
    public var accessCount: Int
    public var lastAccessDate: Date
    
    // 메타데이터
    public let metadata: MemoryMetadata?
    
    /// 관련성 점수 계산 (고도화된 버전)
    public var relevanceScore: Double {
        // 기본 점수
        var score = importance
        
        // 최근성 가중치
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        let recencyWeight = exp(-Double(daysSinceCreation) / 60.0) // 60일 기준 지수 감쇠
        score *= recencyWeight
        
        // 접근 빈도 가중치
        let accessWeight = min(Double(accessCount) / 10.0, 1.0)
        score *= (1.0 + accessWeight * 0.3)
        
        // 최근 접근 가중치
        let daysSinceAccess = Calendar.current.dateComponents([.day], from: lastAccessDate, to: Date()).day ?? 0
        let accessRecency = exp(-Double(daysSinceAccess) / 30.0)
        score *= (1.0 + accessRecency * 0.2)
        
        return min(score, 1.0)
    }
}

// MARK: - Memory Category

public enum MemoryCategory: String, Codable, CaseIterable {
    case emotion = "emotion"
    case conversation = "conversation"
    case health = "health"
    case sleep = "sleep"
    case achievement = "achievement"
    case insight = "insight"
    case routine = "routine"
    case special = "special"
    
    public var icon: String {
        switch self {
        case .emotion: return "❤️"
        case .conversation: return "💬"
        case .health: return "🏃"
        case .sleep: return "😴"
        case .achievement: return "🏆"
        case .insight: return "💡"
        case .routine: return "📅"
        case .special: return "⭐"
        }
    }
    
    public var priority: Int {
        switch self {
        case .special: return 10
        case .emotion: return 8
        case .achievement: return 7
        case .insight: return 6
        case .health: return 5
        case .conversation: return 4
        case .sleep: return 3
        case .routine: return 2
        }
    }
}

// MARK: - Memory Metadata

public struct MemoryMetadata: Codable {
    public let source: MemorySource
    public let context: [String: String]
    public let tags: [String]
    public let linkedMemories: [String]
    public let sentiment: Double // -1.0 ~ 1.0
    public let confidence: Double // 0.0 ~ 1.0
}

public enum MemorySource: String, Codable {
    case userInput = "user_input"
    case aiGenerated = "ai_generated"
    case healthData = "health_data"
    case systemEvent = "system_event"
    case mixedSource = "mixed_source"
}

// MARK: - Memory Index

public class MemoryIndex {
    private var invertedIndex: [String: Set<String>] = [:]
    private var categoryIndex: [MemoryCategory: Set<String>] = [:]
    private var emotionIndex: [String: Set<String>] = [:]
    private var dateIndex: [String: Set<String>] = [:] // YYYY-MM-DD format
    
    public init() {}
    
    public func add(_ memory: MemoryItem) {
        // 키워드 인덱싱
        let keywords = extractKeywords(from: memory.content + " " + memory.summary)
        for keyword in keywords {
            invertedIndex[keyword, default: Set()].insert(memory.id)
        }
        
        // 카테고리 인덱싱
        if let category = memory.category {
            categoryIndex[category, default: Set()].insert(memory.id)
        }
        
        // 감정 인덱싱
        if let emotion = memory.emotion {
            emotionIndex[emotion.lowercased(), default: Set()].insert(memory.id)
        }
        
        // 날짜 인덱싱
        let dateKey = formatDateKey(memory.date)
        dateIndex[dateKey, default: Set()].insert(memory.id)
    }
    
    public func search(query: String, limit: Int) -> [String] {
        let keywords = extractKeywords(from: query)
        var resultIds = Set<String>()
        
        // 키워드 매칭
        for keyword in keywords {
            if let ids = invertedIndex[keyword] {
                resultIds.formUnion(ids)
            }
        }
        
        // 점수 기반 정렬 (간단한 TF 기반)
        let scoredResults = resultIds.map { id -> (String, Int) in
            let score = keywords.reduce(0) { count, keyword in
                return count + (invertedIndex[keyword]?.contains(id) == true ? 1 : 0)
            }
            return (id, score)
        }
        
        return scoredResults
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }
    
    private func extractKeywords(from text: String) -> Set<String> {
        // 간단한 키워드 추출 (실제로는 형태소 분석 사용)
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .flatMap { $0.components(separatedBy: .punctuationCharacters) }
            .filter { $0.count > 2 } // 2글자 이상만
        
        return Set(words)
    }
    
    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Memory Compression Strategy

public class MemoryCompressionStrategy {
    
    public init() {}
    
    public func compress(_ content: String) -> String {
        // 간단한 압축 전략 (실제로는 더 정교한 알고리즘 사용)
        
        // 1. 중복 제거
        let sentences = content.components(separatedBy: ".")
        let uniqueSentences = Array(Set(sentences))
        
        // 2. 핵심 문장만 추출 (길이 기반)
        let importantSentences = uniqueSentences
            .filter { $0.count > 10 && $0.count < 200 }
            .sorted { $0.count > $1.count }
            .prefix(3)
        
        // 3. 요약
        let compressed = importantSentences.joined(separator: ". ")
        
        return compressed.isEmpty ? content : compressed + "."
    }
    
    public func decompress(_ compressed: String, originalHint: String? = nil) -> String {
        // 압축 해제 (컨텍스트 복원)
        // 실제로는 AI를 사용하여 원본 컨텍스트 복원
        return compressed
    }
}

// MARK: - Priority Queue

public struct PriorityQueue<T> {
    private var heap: [(element: T, priority: Double)] = []
    
    public init() {}
    
    public mutating func enqueue(_ element: T, priority: Double) {
        heap.append((element, priority))
        heap.sort { $0.priority > $1.priority }
    }
    
    public mutating func dequeue() -> T? {
        return heap.isEmpty ? nil : heap.removeFirst().element
    }
    
    public var isEmpty: Bool {
        return heap.isEmpty
    }
    
    public var count: Int {
        return heap.count
    }
}

// MARK: - Neural Network Processor

public class NeuralNetworkProcessor {
    public static let shared = NeuralNetworkProcessor()
    
    private init() {}
    
    public func processHealthData(_ data: [String: Double]) -> NeuralNetworkAnalysis {
        // 간단한 신경망 시뮬레이션
        let inputLayer = Array(data.values)
        let hiddenLayer1 = applyLayer(input: inputLayer, weights: generateRandomWeights(data.count, 10))
        let hiddenLayer2 = applyLayer(input: hiddenLayer1, weights: generateRandomWeights(10, 5))
        let outputLayer = applyLayer(input: hiddenLayer2, weights: generateRandomWeights(5, 3))
        
        return NeuralNetworkAnalysis(
            primaryPattern: interpretPattern(outputLayer),
            confidence: outputLayer.max() ?? 0.5,
            recommendations: generateRecommendations(outputLayer)
        )
    }
    
    private func applyLayer(input: [Double], weights: [[Double]]) -> [Double] {
        return weights.map { row in
            let sum = zip(input, row).map { $0 * $1 }.reduce(0, +)
            return tanh(sum) // Activation function
        }
    }
    
    private func generateRandomWeights(_ input: Int, _ output: Int) -> [[Double]] {
        return (0..<output).map { _ in
            (0..<input).map { _ in Double.random(in: -1...1) }
        }
    }
    
    private func interpretPattern(_ output: [Double]) -> String {
        let patterns = ["스트레스 패턴", "회복 필요", "활동 권장"]
        let maxIndex = output.enumerated().max { $0.element < $1.element }?.offset ?? 0
        return patterns[min(maxIndex, patterns.count - 1)]
    }
    
    private func generateRecommendations(_ output: [Double]) -> [String] {
        var recommendations: [String] = []
        
        if output[0] > 0.7 {
            recommendations.append("명상이나 휴식이 필요합니다")
        }
        if output[1] > 0.7 {
            recommendations.append("수면 시간을 늘리세요")
        }
        if output[2] > 0.7 {
            recommendations.append("가벼운 운동을 시작하세요")
        }
        
        return recommendations
    }
}

public struct NeuralNetworkAnalysis {
    public let primaryPattern: String
    public let confidence: Double
    public let recommendations: [String]
}
