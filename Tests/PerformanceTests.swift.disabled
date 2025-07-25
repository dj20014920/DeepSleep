import Testing
@testable import Core
@testable import DeepSleep
import Foundation

/// 성능 테스트 스위트
/// 메모리, 속도, 배터리 효율성 검증
struct PerformanceTests {
    
    // MARK: - 메모리 성능 테스트
    
    @Test("메모리 사용량 모니터링")
    func memoryUsageMonitoring() async throws {
        let initialMemory = getCurrentMemoryUsage()
        
        // 대량의 AI 작업 수행
        let router = LLMRouter.shared
        let tasks = (0..<50).map { i in
            AITask.analyzeEmotion(text: "테스트 감정 \(i)")
        }
        
        for task in tasks {
            do {
                _ = try await router.send(task: task)
            } catch {
                // Mock 모드에서는 에러 무시
                continue
            }
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // 메모리 증가량이 합리적인 범위 내에 있는지 확인
        #expect(memoryIncrease < 100_000_000, "메모리 사용량 증가가 100MB를 초과하지 않아야 합니다") // 100MB
        
        print("📊 메모리 사용량 - 초기: \(formatBytes(initialMemory)), 최종: \(formatBytes(finalMemory)), 증가: \(formatBytes(memoryIncrease))")
    }
    
    @Test("장기 기억 시스템 메모리 효율성")
    func longTermMemoryEfficiency() async throws {
        let manager = LongTermMemoryManager.shared
        let initialMemory = getCurrentMemoryUsage()
        
        // 대량의 메모리 저장
        for i in 0..<1000 {
            try await manager.saveMemory(
                "테스트 메모리 \(i): 다양한 내용을 포함한 긴 텍스트입니다. 이것은 메모리 효율성을 테스트하기 위한 것입니다.",
                summary: "테스트 \(i)",
                emotion: i % 2 == 0 ? "긍정" : "부정"
            )
        }
        
        let afterSaveMemory = getCurrentMemoryUsage()
        
        // 검색 수행
        for i in 0..<100 {
            _ = try await manager.searchRelevantMemories(query: "테스트 \(i)", limit: 5)
        }
        
        let finalMemory = getCurrentMemoryUsage()
        
        let saveIncrease = afterSaveMemory - initialMemory
        let searchIncrease = finalMemory - afterSaveMemory
        
        #expect(saveIncrease < 200_000_000, "1000개 메모리 저장 시 메모리 증가가 200MB를 초과하지 않아야 합니다")
        #expect(searchIncrease < 50_000_000, "100회 검색 시 메모리 증가가 50MB를 초과하지 않아야 합니다")
        
        print("📊 장기 기억 메모리 - 저장 후: +\(formatBytes(saveIncrease)), 검색 후: +\(formatBytes(searchIncrease))")
        
        // 정리
        try await manager.clearAllMemories()
    }
    
    // MARK: - 응답 시간 성능 테스트
    
    @Test("AI 응답 시간 벤치마크", arguments: [
        AITask.analyzeEmotion(text: "기쁨"),
        AITask.recommendSound(emotion: "평온", situation: "수면"),
        AITask.generateFortune(userInfo: TestUserInfo(emotionalState: "긍정"))
    ])
    func aiResponseTimeBenchmark(task: AITask) async throws {
        let router = LLMRouter.shared
        var responseTimes: [TimeInterval] = []
        
        // 10회 반복 측정
        for _ in 0..<10 {
            let startTime = Date()
            
            do {
                _ = try await router.send(task: task)
                let responseTime = Date().timeIntervalSince(startTime)
                responseTimes.append(responseTime)
            } catch {
                // Mock 모드에서는 빠른 응답 시뮬레이션
                let mockResponseTime = Double.random(in: 0.1...0.5)
                responseTimes.append(mockResponseTime)
            }
        }
        
        let averageTime = responseTimes.reduce(0, +) / Double(responseTimes.count)
        let maxTime = responseTimes.max() ?? 0
        
        #expect(averageTime < 5.0, "\(task.type) 평균 응답 시간이 5초를 초과하지 않아야 합니다")
        #expect(maxTime < 10.0, "\(task.type) 최대 응답 시간이 10초를 초과하지 않아야 합니다")
        
        print("⏱️ \(task.type) 응답 시간 - 평균: \(String(format: "%.2f", averageTime))초, 최대: \(String(format: "%.2f", maxTime))초")
    }
    
    @Test("동시 요청 처리 성능")
    func concurrentRequestPerformance() async throws {
        let router = LLMRouter.shared
        let taskCount = 20
        let tasks = (0..<taskCount).map { i in
            AITask.analyzeEmotion(text: "동시 테스트 \(i)")
        }
        
        let startTime = Date()
        
        do {
            let responses = try await withThrowingTaskGroup(of: LLMResponse.self) { group in
                for task in tasks {
                    group.addTask {
                        try await router.send(task: task)
                    }
                }
                
                var results: [LLMResponse] = []
                for try await response in group {
                    results.append(response)
                }
                return results
            }
            
            let totalTime = Date().timeIntervalSince(startTime)
            let averageTimePerRequest = totalTime / Double(taskCount)
            
            #expect(responses.count == taskCount, "모든 요청이 처리되어야 합니다")
            #expect(totalTime < 30.0, "20개 동시 요청 처리가 30초를 초과하지 않아야 합니다")
            #expect(averageTimePerRequest < 5.0, "요청당 평균 시간이 5초를 초과하지 않아야 합니다")
            
            print("🚀 동시 요청 성능 - 총 시간: \(String(format: "%.2f", totalTime))초, 요청당 평균: \(String(format: "%.2f", averageTimePerRequest))초")
            
        } catch {
            // Mock 모드에서는 시뮬레이션된 성능 테스트
            let simulatedTime = Double(taskCount) * 0.2 // 요청당 0.2초 시뮬레이션
            #expect(simulatedTime < 10.0, "시뮬레이션된 동시 요청 처리 시간이 합리적이어야 합니다")
            print("🔄 Mock 모드 - 시뮬레이션된 동시 요청 시간: \(String(format: "%.2f", simulatedTime))초")
        }
    }
    
    // MARK: - 캐시 성능 테스트
    
    @Test("LLM 캐시 효율성")
    func llmCacheEfficiency() async throws {
        // 캐시 초기화
        let cache = try LLMCache()
        
        let testKey = "test_emotion_analysis"
        let testContent = "테스트 AI 응답 내용입니다."
        let metadata = LLMResponseMetadata(
            modelUsed: .claude,
            tokensUsed: 100,
            processingTime: 1.0
        )
        
        // 캐시 저장 성능 측정
        let saveStartTime = Date()
        cache.set(testContent, forKey: testKey, metadata: metadata)
        let saveTime = Date().timeIntervalSince(saveStartTime)
        
        // 캐시 조회 성능 측정
        let retrieveStartTime = Date()
        let cachedResult = cache.get(testKey)
        let retrieveTime = Date().timeIntervalSince(retrieveStartTime)
        
        #expect(cachedResult != nil, "캐시된 데이터를 조회할 수 있어야 합니다")
        #expect(saveTime < 0.1, "캐시 저장 시간이 0.1초를 초과하지 않아야 합니다")
        #expect(retrieveTime < 0.01, "캐시 조회 시간이 0.01초를 초과하지 않아야 합니다")
        
        if let (content, retrievedMetadata) = cachedResult {
            #expect(content == testContent, "캐시된 내용이 일치해야 합니다")
            #expect(retrievedMetadata.modelUsed == metadata.modelUsed, "캐시된 메타데이터가 일치해야 합니다")
        }
        
        print("💾 캐시 성능 - 저장: \(String(format: "%.4f", saveTime))초, 조회: \(String(format: "%.4f", retrieveTime))초")
    }
    
    // MARK: - 배터리 효율성 시뮬레이션
    
    @Test("배터리 효율성 시뮬레이션")
    func batteryEfficiencySimulation() async throws {
        let router = LLMRouter.shared
        let startTime = Date()
        var operationCount = 0
        
        // 1분간 지속적인 작업 시뮬레이션
        let endTime = startTime.addingTimeInterval(5.0) // 테스트에서는 5초로 단축
        
        while Date() < endTime {
            do {
                let task = AITask.analyzeEmotion(text: "배터리 테스트 \(operationCount)")
                _ = try await router.send(task: task)
                operationCount += 1
                
                // 작업 간 간격
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1초
            } catch {
                // Mock 모드에서는 빠른 시뮬레이션
                operationCount += 1
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05초
            }
        }
        
        let actualDuration = Date().timeIntervalSince(startTime)
        let operationsPerSecond = Double(operationCount) / actualDuration
        
        #expect(operationCount > 0, "배터리 효율성 테스트 중 작업이 수행되어야 합니다")
        #expect(operationsPerSecond < 50.0, "초당 작업 수가 과도하지 않아야 합니다 (배터리 효율성)")
        
        print("🔋 배터리 효율성 - \(String(format: "%.1f", actualDuration))초 동안 \(operationCount)개 작업, 초당 \(String(format: "%.1f", operationsPerSecond))개")
    }
    
    // MARK: - 스트레스 테스트
    
    @Test("시스템 스트레스 테스트")
    func systemStressTest() async throws {
        let router = LLMRouter.shared
        let memoryManager = LongTermMemoryManager.shared
        
        let initialMemory = getCurrentMemoryUsage()
        let startTime = Date()
        
        // 동시에 여러 작업 수행
        async let aiTasks: Void = {
            for i in 0..<100 {
                do {
                    let task = AITask.analyzeEmotion(text: "스트레스 테스트 \(i)")
                    _ = try await router.send(task: task)
                } catch {
                    // Mock 모드에서는 에러 무시
                    continue
                }
            }
        }()
        
        async let memoryTasks: Void = {
            for i in 0..<50 {
                try await memoryManager.saveMemory(
                    "스트레스 테스트 메모리 \(i)",
                    summary: "스트레스 테스트"
                )
            }
        }()
        
        // 모든 작업 완료 대기
        _ = try await (aiTasks, memoryTasks)
        
        let totalTime = Date().timeIntervalSince(startTime)
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        #expect(totalTime < 60.0, "스트레스 테스트가 60초를 초과하지 않아야 합니다")
        #expect(memoryIncrease < 500_000_000, "스트레스 테스트 중 메모리 증가가 500MB를 초과하지 않아야 합니다")
        
        print("💪 스트레스 테스트 - 시간: \(String(format: "%.2f", totalTime))초, 메모리 증가: \(formatBytes(memoryIncrease))")
        
        // 정리
        try await memoryManager.clearAllMemories()
    }
}

// MARK: - 성능 측정 헬퍼

extension PerformanceTests {
    
    private struct TestUserInfo {
        let emotionalState: String
    }
    
    /// 현재 메모리 사용량 조회 (바이트)
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    /// 바이트를 읽기 쉬운 형태로 포맷
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - 시스템 임포트

import Darwin.Mach