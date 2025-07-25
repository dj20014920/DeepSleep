import Testing
@testable import Core
@testable import DeepSleep
import Foundation

/// 장기 기억 시스템 테스트
/// DeepSleep의 핵심 기능인 개인화 메모리 관리 테스트
struct LongTermMemoryManagerTests {
    
    // MARK: - 기본 기능 테스트
    
    @Test("LongTermMemoryManager 싱글톤 테스트")
    func singletonInstance() {
        let manager1 = LongTermMemoryManager.shared
        let manager2 = LongTermMemoryManager.shared
        
        #expect(manager1 === manager2, "LongTermMemoryManager는 싱글톤이어야 합니다")
    }
    
    @Test("메모리 저장 기본 기능")
    func basicMemorySaving() async throws {
        let manager = LongTermMemoryManager.shared
        
        // 테스트 전 초기화
        try await manager.clearAllMemories()
        
        // 메모리 저장
        try await manager.saveMemory(
            "오늘 아침에 조깅을 했어요. 정말 상쾌했습니다!",
            summary: "아침 조깅 경험",
            emotion: "상쾌함",
            category: .health
        )
        
        // 저장된 메모리 검색
        let memories = try await manager.searchRelevantMemories(
            query: "운동",
            limit: 5
        )
        
        #expect(memories.count > 0, "저장된 메모리를 찾을 수 있어야 합니다")
        #expect(memories.first?.summary == "아침 조깅 경험", "올바른 요약이 저장되어야 합니다")
        #expect(memories.first?.emotion == "상쾌함", "감정 정보가 저장되어야 합니다")
    }
    
    // MARK: - 검색 기능 테스트
    
    @Test("의미 기반 메모리 검색", arguments: [
        ("운동", "조깅"),
        ("수면", "잠"),
        ("음식", "식사"),
        ("감정", "기분")
    ])
    func semanticMemorySearch(query: String, relatedKeyword: String) async throws {
        let manager = LongTermMemoryManager.shared
        
        // 테스트 데이터 준비
        try await manager.clearAllMemories()
        
        let testMemories = [
            ("매일 아침 조깅을 하고 있어요", "운동 루틴", "활기참"),
            ("어젯밤 잠을 잘 못 잤어요", "수면 문제", "피곤함"),
            ("점심에 맛있는 파스타를 먹었어요", "식사 경험", "만족"),
            ("오늘 기분이 정말 좋아요", "긍정적 감정", "기쁨")
        ]
        
        for (content, summary, emotion) in testMemories {
            try await manager.saveMemory(content, summary: summary, emotion: emotion)
        }
        
        // 검색 테스트
        let results = try await manager.searchRelevantMemories(query: query, limit: 3)
        
        #expect(results.count > 0, "\(query) 관련 메모리를 찾을 수 있어야 합니다")
        
        // 관련성 확인
        let hasRelevantContent = results.contains { memory in
            memory.content.contains(relatedKeyword) || 
            memory.summary.contains(relatedKeyword) ||
            memory.content.contains(query)
        }
        
        #expect(hasRelevantContent, "검색 결과가 쿼리와 관련이 있어야 합니다")
    }
    
    @Test("시간 기반 메모리 가중치 테스트")
    func temporalWeighting() async throws {
        let manager = LongTermMemoryManager.shared
        try await manager.clearAllMemories()
        
        // 오래된 메모리 저장 (시뮬레이션)
        try await manager.saveMemory(
            "한 달 전에 운동을 시작했어요",
            summary: "운동 시작",
            emotion: "결심"
        )
        
        // 최근 메모리 저장
        try await manager.saveMemory(
            "어제 운동을 했어요. 정말 힘들었지만 뿌듯했어요",
            summary: "최근 운동",
            emotion: "뿌듯함"
        )
        
        let results = try await manager.searchRelevantMemories(query: "운동", limit: 5)
        
        #expect(results.count >= 2, "두 개의 운동 관련 메모리가 있어야 합니다")
        
        // 최근 메모리가 더 높은 우선순위를 가져야 함
        if results.count >= 2 {
            let firstResult = results[0]
            #expect(firstResult.summary.contains("최근") || firstResult.date > results[1].date,
                   "최근 메모리가 더 높은 우선순위를 가져야 합니다")
        }
    }
    
    // MARK: - 카테고리 분류 테스트
    
    @Test("자동 카테고리 분류", arguments: [
        ("잠을 잘 못 잤어요", MemoryCategory.sleep),
        ("운동을 했어요", MemoryCategory.health),
        ("기분이 좋아요", MemoryCategory.emotion),
        ("목표를 달성했어요", MemoryCategory.achievement),
        ("새로운 것을 배웠어요", MemoryCategory.insight)
    ])
    func automaticCategorization(content: String, expectedCategory: MemoryCategory) async throws {
        let manager = LongTermMemoryManager.shared
        try await manager.clearAllMemories()
        
        try await manager.saveMemory(content, summary: "테스트")
        
        let memories = try await manager.searchRelevantMemories(query: content, limit: 1)
        
        #expect(memories.count > 0, "메모리가 저장되어야 합니다")
        #expect(memories.first?.category == expectedCategory, 
               "\(content)는 \(expectedCategory) 카테고리로 분류되어야 합니다")
    }
    
    // MARK: - 메모리 관리 테스트
    
    @Test("메모리 중요도 평가")
    func memoryImportanceEvaluation() async throws {
        let manager = LongTermMemoryManager.shared
        try await manager.clearAllMemories()
        
        // 중요도가 높은 메모리
        try await manager.saveMemory(
            "정말 중요한 깨달음을 얻었어요. 절대 잊지 말아야겠어요!",
            summary: "중요한 깨달음",
            emotion: "감동"
        )
        
        // 중요도가 낮은 메모리
        try await manager.saveMemory(
            "그냥 평범한 하루였어요",
            summary: "평범한 일상",
            emotion: "평온"
        )
        
        let memories = try await manager.searchRelevantMemories(query: "깨달음", limit: 5)
        
        #expect(memories.count > 0, "중요한 메모리를 찾을 수 있어야 합니다")
        
        if let importantMemory = memories.first {
            #expect(importantMemory.importance > 0.5, "중요한 메모리는 높은 중요도를 가져야 합니다")
        }
    }
    
    @Test("메모리 압축 기능")
    func memoryCompression() async throws {
        let manager = LongTermMemoryManager.shared
        try await manager.clearAllMemories()
        
        // 긴 내용의 메모리 저장
        let longContent = String(repeating: "이것은 매우 긴 메모리 내용입니다. ", count: 100)
        
        try await manager.saveMemory(
            longContent,
            summary: "긴 내용 테스트",
            emotion: "테스트"
        )
        
        let memories = try await manager.searchRelevantMemories(query: "긴 내용", limit: 1)
        
        #expect(memories.count > 0, "압축된 메모리가 저장되어야 합니다")
        
        if let compressedMemory = memories.first {
            #expect(compressedMemory.compressionRatio < 1.0, "메모리가 압축되어야 합니다")
            #expect(compressedMemory.content.count < longContent.count, "압축된 내용이 원본보다 짧아야 합니다")
        }
    }
    
    // MARK: - 성능 테스트
    
    @Test("대용량 메모리 검색 성능")
    func largeScaleMemorySearch() async throws {
        let manager = LongTermMemoryManager.shared
        try await manager.clearAllMemories()
        
        // 100개의 테스트 메모리 생성
        for i in 0..<100 {
            try await manager.saveMemory(
                "테스트 메모리 \(i): 다양한 내용과 감정을 포함합니다",
                summary: "테스트 \(i)",
                emotion: i % 2 == 0 ? "긍정" : "중립"
            )
        }
        
        let startTime = Date()
        let results = try await manager.searchRelevantMemories(query: "테스트", limit: 10)
        let searchTime = Date().timeIntervalSince(startTime)
        
        #expect(results.count > 0, "검색 결과가 있어야 합니다")
        #expect(searchTime < 2.0, "검색 시간이 2초를 초과하지 않아야 합니다")
        #expect(results.count <= 10, "제한된 수의 결과만 반환되어야 합니다")
    }
    
    @Test("메모리 초기화 기능")
    func memoryClearFunction() async throws {
        let manager = LongTermMemoryManager.shared
        
        // 테스트 메모리 저장
        try await manager.saveMemory("테스트 메모리", summary: "테스트")
        
        // 메모리 존재 확인
        let beforeClear = try await manager.searchRelevantMemories(query: "테스트", limit: 5)
        #expect(beforeClear.count > 0, "초기화 전에는 메모리가 있어야 합니다")
        
        // 메모리 초기화
        try await manager.clearAllMemories()
        
        // 메모리 삭제 확인
        let afterClear = try await manager.searchRelevantMemories(query: "테스트", limit: 5)
        #expect(afterClear.count == 0, "초기화 후에는 메모리가 없어야 합니다")
    }
}

// MARK: - 테스트 헬퍼

extension LongTermMemoryManagerTests {
    
    /// 테스트용 메모리 카테고리 확장
    private func createTestMemory(content: String, category: MemoryCategory) async throws {
        try await LongTermMemoryManager.shared.saveMemory(
            content,
            summary: "테스트 요약",
            emotion: "테스트 감정",
            category: category
        )
    }
}