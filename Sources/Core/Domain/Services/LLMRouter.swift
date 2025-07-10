//
//  LLMRouter.swift
//  DeepSleep
//
//  Created by AI on 2025/06/28.
//

import Foundation

/// `LLMRouter`는 모든 AI 관련 요청을 처리하는 중앙 컨트롤 타워입니다.
/// `AITask`를 입력받아, **요청의 의도와 목적**을 분석하여
/// 최적의 `LLMService`로 요청을 지능적으로 라우팅합니다.
public final class LLMRouter: LLMServiceProtocol {
    
    // MARK: - Properties
    public static let shared = LLMRouter()
    private let monitor = LLMMonitor.shared
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 1.0
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    /// 지정된 AI 작업을 가장 적합한 LLM으로 라우팅하여 처리하고 결과를 반환합니다.
    ///
    /// - Parameter task: 처리할 AI 작업 (`AITask`).
    /// - Returns: AI 처리 결과를 담은 `LLMResponse` 객체.
    /// - Throws: `LLMError` 또는 하위 서비스에서 발생하는 오류.
    public func send(task: AITask) async throws -> LLMResponse {
        var lastError: Error?
        
        // 재시도 로직
        for attempt in 1...maxRetryAttempts {
            do {
                let startTime = Date()
                let response = try await processTask(task)
                
                // 성능 메트릭 기록
                monitor.recordSuccess(
                    taskType: task.type,
                    duration: Date().timeIntervalSince(startTime)
                )
                
                // TODO: 대화를 캐시에 저장 (백그라운드에서) - 구현 예정
                // Task {
                //     do {
                //         await saveToCacheIfNeeded(task: task, response: response)
                //     } catch {
                //         monitor.recordWarning(message: "Failed to cache conversation: \(error.localizedDescription)")
                //     }
                // }
                
                return response
            } catch let error as LLMError {
                lastError = error
                
                // 재시도 가능한 에러인지 확인
                guard error.isRetryable && attempt < maxRetryAttempts else {
                    monitor.recordError(taskType: task.type, error: error)
                    throw error
                }
                
                // 재시도 전 대기
                try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                
                // 폴백 서비스로 전환
                if attempt == maxRetryAttempts - 1 {
                    return try await handleFallback(task: task, originalError: error)
                }
            } catch {
                lastError = error
                monitor.recordError(taskType: task.type, error: error)
                throw LLMError.unexpectedError(error)
            }
        }
        
        // 모든 재시도 실패
        throw lastError ?? LLMError.maxRetriesExceeded
    }
    
    // MARK: - Private Methods
    /// 실제 작업 처리를 수행하는 내부 메서드
    private func processTask(_ task: AITask) async throws -> LLMResponse {
        let serviceType = selectService(for: task)
        
        do {
            let service = try await LLMServiceFactory.shared.getService(for: serviceType)
            let enrichedTask = try await enrichTaskWithMemory(task)
            return try await service.send(task: enrichedTask)
        } catch let error as LLMServiceFactory.FactoryError {
            throw LLMError.serviceInitializationError(serviceType, error)
        }
    }
    
    /// 작업에 메모리 컨텍스트를 추가하는 메서드
    private func enrichTaskWithMemory(_ task: AITask) async throws -> AITask {
        guard task.shouldUseMemory else { return task }
        
        do {
            let memory = try await fetchRelevantMemory(for: task)
            return task.with(memory: memory)
        } catch {
            // 메모리 검색 실패는 치명적이지 않음 - 원본 작업 반환
            monitor.recordWarning(message: "Memory enrichment failed: \(error.localizedDescription)")
            return task
        }
    }
    
    /// 관련 메모리를 검색하는 메서드
    private func fetchRelevantMemory(for task: AITask) async throws -> String {
        // TODO: 새로운 대화 캐시 시스템 구현 예정
        // 현재는 기존 방식 사용
        
        // 사용자 구독 상태 확인
        let isSubscribed = await checkUserSubscription()
        guard isSubscribed else {
            // 무료 사용자는 현재 대화만 기억
            return ""
        }
        
        // 과거 대화 검색 시스템 (Vector DB 준비 전까지 임시 구현)
        let memoryManager = LongTermMemoryManager.shared
        let relevantMemories = try await memoryManager.searchRelevantMemories(
            query: task.userPrompt,
            limit: 5
        )
        
        // 검색된 메모리를 컨텍스트로 변환
        if relevantMemories.isEmpty {
            return ""
        }
        
        var memoryContext = "\n\n[이전 대화 기억]\n"
        for memory in relevantMemories {
            memoryContext += "- \(memory.date.formatted()): \(memory.summary)\n"
        }
        
        return memoryContext
    }
    
    // TODO: 새로운 캐시 시스템 구현 예정
    // /// 대화를 캐시에 저장 (필요한 경우에만)
    // private func saveToCacheIfNeeded(task: AITask, response: LLMResponse) async {
    //     // 구현 예정
    // }
    
    /// 사용자 구독 상태 확인
    private func checkUserSubscription() async -> Bool {
        // TODO: 실제 구독 상태 확인 로직 구현
        // 현재는 UserDefaults에서 확인
        return UserDefaults.standard.bool(forKey: "isSubscribedUser")
    }
    
    /// 폴백 처리를 수행하는 메서드
    private func handleFallback(task: AITask, originalError: Error) async throws -> LLMResponse {
        let fallbackService = try await LLMServiceFactory.shared.getFallbackService()
        monitor.recordFallback(taskType: task.type, originalError: originalError)
        return try await fallbackService.send(task: task)
    }
    
    /// `AITask`의 종류에 따라 가장 적합한 `LLMServiceType`을 선택하는 내부 로직입니다.
    /// `DeepSleep_AI_Development_Guide.md`의 모델 포트폴리오 전략을 따릅니다.
    ///
    /// - Parameter task: 분석할 AI 작업.
    /// - Returns: 선택된 `LLMServiceType`.
    private func selectService(for task: AITask) -> LLMServiceType {
        // 부하 분산을 위한 가중치 계산
        let weights = calculateServiceWeights()
        
        // 기본 서비스 선택
        let baseService = selectBaseService(for: task)
        
        // 부하가 높으면 대체 서비스 반환
        if weights[baseService] ?? 0 > 0.8 {
            return selectAlternativeService(for: baseService)
        }
        
        return baseService
    }
    
    /// 서비스별 현재 부하 가중치를 계산
    private func calculateServiceWeights() -> [LLMServiceType: Double] {
        let metrics = monitor.getCurrentMetrics()
        var weights: [LLMServiceType: Double] = [:]
        
        for serviceType in LLMServiceType.allCases {
            let serviceMetrics = metrics[serviceType] ?? LLMMetrics()
            weights[serviceType] = calculateWeight(for: serviceMetrics)
        }
        
        return weights
    }
    
    /// 메트릭을 기반으로 서비스 가중치 계산
    private func calculateWeight(for metrics: LLMMetrics) -> Double {
        let errorWeight = Double(metrics.errorCount) * 0.3
        let latencyWeight = metrics.averageLatency * 0.4
        let costWeight = metrics.totalCost * 0.3
        return errorWeight + latencyWeight + costWeight
    }
    
    /// 작업 유형에 따른 기본 서비스 선택
    private func selectBaseService(for task: AITask) -> LLMServiceType {
        switch task {
        // 감성 대화, 일기 분석 -> The Core Empath
        case .generalChat, .analyzeEmotionDiary, .analyzeEmotion, .summarizeDiary:
            return .claude // Claude 3.5 Haiku
            
        // 지능형 조율, 복잡한 지시 -> The Intelligent Orchestrator
        case .recommendTodo:
            return .openAI // GPT-4o mini
            
        // 빠르고 저렴한 작업 처리 -> The Efficient Worker
        case .recommendSound, .recommendPreset:
            return .gemini // Gemini 2.0 Flash-Lite
            
        // 한국어 뉘앙스, 문화적 맥락 -> The True Korean Friend
        case .generateFortune:
            return .naver // HyperCLOVA X
        }
    }
    
    /// 대체 서비스 선택
    private func selectAlternativeService(for baseService: LLMServiceType) -> LLMServiceType {
        switch baseService {
        case .claude:
            return .openAI
        case .openAI:
            return .claude
        case .gemini:
            return .openAI
        case .naver:
            return .claude
        case .onDevice:
            return .gemini
        }
    }
} 
