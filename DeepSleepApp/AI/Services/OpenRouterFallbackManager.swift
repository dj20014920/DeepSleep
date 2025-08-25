//
//  OpenRouterFallbackManager.swift
//  DeepSleep
//
//  Created by Agent on 2025-08-08.
//

import Foundation

/// 🚀 Phase 3: 고도화된 OpenRouter 무료/테스트 모델 폴백 매니저
/// - 지능형 모델 선택: 성공률 기반 동적 순서 조정
/// - 성능 모니터링: 응답 시간 및 성공률 추적
/// - 캐싱 시스템: 동일 요청 응답 캐싱으로 성능 향상
/// - 목표: 한국어 대화, 프리셋 추천 파싱, JSON 생성 안정성
final class OpenRouterFallbackManager {
    static let shared = OpenRouterFallbackManager()
    
    // MARK: - 🚀 Phase 3: 성능 모니터링 시스템
    public struct ModelPerformance {
        var successCount: Int = 0
        var failureCount: Int = 0
        var totalResponseTime: TimeInterval = 0
        var lastUsed: Date = Date.distantPast
        
        var successRate: Double {
            let total = successCount + failureCount
            return total > 0 ? Double(successCount) / Double(total) : 0.0
        }
        
        var averageResponseTime: TimeInterval {
            return successCount > 0 ? totalResponseTime / Double(successCount) : 0.0
        }
    }
    
    private var modelPerformance: [String: ModelPerformance] = [:]
    private let performanceQueue = DispatchQueue(label: "com.deepsleep.openrouter.performance", attributes: .concurrent)
    
    // MARK: - 🧠 Phase 3: 지능형 캐싱 시스템
    private struct CacheKey: Hashable {
        let content: String
        let mode: AIMode
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(content.prefix(100)) // 처음 100자만 해시에 사용
            hasher.combine(mode)
        }
    }
    
    private struct CacheEntry {
        let response: String
        let timestamp: Date
        let model: String
    }
    
    private var responseCache: [CacheKey: CacheEntry] = [:]
    private let cacheQueue = DispatchQueue(label: "com.deepsleep.openrouter.cache", attributes: .concurrent)
    private let cacheExpirationTime: TimeInterval = 300 // 5분
    
    private init() {
        // 성능 데이터 로드
        loadPerformanceData()
        
        // 주기적 캐시 정리 (10분마다)
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            self.cleanupExpiredCache()
        }
    }

    // 🎯 통합 무료 모델 리스트 (지능순 + 한국어 대화 + JSON 파싱 최적화)
    // 웹 검색 결과 기반으로 성능 순서 재배치 (2025년 8월 기준)
    private let unifiedFreeModels: [String] = [
        // Tier 1: 최고 성능 추론 모델들 (한국어 + JSON 특화)
        "deepseek/deepseek-r1:free",                    // 🥇 최신 추론 모델, O3급 성능
        "deepseek/deepseek-r1-0528:free",               // 🥈 안정화된 R1, 수학/코딩 우수
        "deepseek/deepseek-r1-0528-qwen3-8b:free",     // 🥉 경량화된 R1, 8B로 235B급 성능
        
        // Tier 2: 대형 고성능 모델들 (한국어 우수)
        "qwen/qwen-2.5-72b-instruct:free",             // 72B 대형, JSON 생성 특화
        "qwen/qwen-2.5-coder-32b-instruct:free",       // 코딩/JSON 특화, 한국어 지원
        "meta-llama/llama-3.3-70b-instruct:free",      // Meta 최신 70B, 범용성 우수
        "shisa-ai/shisa-v2-llama3.3-70b:free",         // 일본어 특화이지만 한국어도 우수
        
        // Tier 3: 중형 안정 모델들 (JSON 파싱 안정)
        "mistralai/mistral-small-3.2-24b-instruct:free", // 최신 Mistral, JSON 안정
        "mistralai/mistral-small-24b-instruct-2501:free", // 2025년 1월 최신
        "google/gemma-3-27b-it:free",                   // Google 대형 Gemma
        "qwen/qwq-32b:free",                           // 추론 능력 우수
        
        // Tier 4: 실험적 고성능 모델들
        "google/gemini-2.0-flash-exp:free",            // 최신 Gemini 실험 모델
        "google/gemini-2.5-pro-exp-03-25",            // Gemini 2.5 Pro 실험
        "nvidia/llama-3.1-nemotron-ultra-253b-v1:free", // NVIDIA 초대형 (제한적)
        "rekaai/reka-flash-3:free",                    // Reka 최신
        
        // Tier 5: 중형 백업 모델들
        "google/gemma-3-12b-it:free",                  // 중형 Gemma
        "mistralai/mistral-small-3.1-24b-instruct:free", // 검증된 안정성
        "mistralai/mistral-nemo:free",                 // 경량 Mistral
        "moonshotai/kimi-dev-72b:free",                // Moonshot 대형
        
        // Tier 6: 경량 백업 모델들
        "qwen/qwen3-30b-a3b:free",                     // Qwen 3세대 30B
        "deepseek/deepseek-chat-v3-0324:free",         // DeepSeek 채팅 특화
        "google/gemma-3-4b-it:free",                   // 경량 Gemma
        "qwen/qwen3-14b:free",                         // 중소형 Qwen
        "mistralai/devstral-small-2505:free",          // 개발 특화
        "qwen/qwen3-8b:free",                          // 경량 Qwen
        "meta-llama/llama-3.2-11b-vision-instruct:free" // 비전 지원 (제외 대상이지만 백업용)
    ]

    /// 모드별 기본 시스템 지침 (간결)
    private func systemPromptPrefix(for mode: AIMode) -> String {
        switch mode {
        case .presetRecommendation:
            return "다음 규칙을 반드시 지키세요. 1) 한국어로 답변. 2) JSON만 출력. 3) 키는 preset, volumes, rationale. 4) 문자열에 줄바꿈/설명 포함 금지."
        case .emotionAnalysis:
            return "한국어로 감정을 분석하세요. JSON만 출력. 키는 primary, intensity(0..1), secondary(사전)."
        default:
            return "한국어로 간결하고 친절하게 답변하세요. 가능하면 JSON 형식으로 응답: {\"message\": \"답변내용\", \"emotion\": \"감정상태\"}"
        }
    }

    // MARK: - OpenRouter Chat Payload Types
    struct ORMessage: Codable { let role: String; let content: String }
    private struct ORRequest: Codable { let model: String; let messages: [ORMessage] }
    private struct ORChoice: Codable { let message: ORMessage }
    private struct ORResponse: Codable { let choices: [ORChoice]? }

    /// 🚀 Phase 3: 고도화된 지능형 OpenRouter 호출 (성능 최적화 + 적응형 타임아웃)
    func sendMessageWithFallback(content: String, mode: AIMode) async throws -> String {
        let cacheKey = CacheKey(content: content, mode: mode)
        
        // 1. 캐시 확인
        if let cachedResponse = getCachedResponse(for: cacheKey) {
            print("⚡ [OpenRouterFallback] 캐시 히트! 모델: \(cachedResponse.model)")
            return cachedResponse.response
        }
        
        // 2. 성능 기반 모델 순서 조정 (상위 5개 모델만 우선 시도)
        let optimizedModels = getOptimizedModelOrder()
        let priorityModels = Array(optimizedModels.prefix(5)) // 상위 5개 우선
        let fallbackModels = Array(optimizedModels.dropFirst(5)) // 나머지는 폴백
        
        var tried: [String] = []
        var lastError: Error?

        print("🚀 [OpenRouterFallback] 고도화된 폴백 시스템 시작")
        print("   우선 모델: \(priorityModels.count)개, 폴백 모델: \(fallbackModels.count)개")
        
        // 3. 우선 모델들 시도 (짧은 타임아웃)
        for (index, model) in priorityModels.enumerated() {
            do {
                let startTime = Date()
                let performance = getModelPerformance(model)
                let adaptiveTimeout = calculateAdaptiveTimeout(for: model, performance: performance, isPriority: true)
                
                print("🎯 [OpenRouterFallback] 우선 모델 #\(index + 1) 시도: \(model)")
                print("   성공률: \(String(format: "%.1f", performance.successRate * 100))%, 평균응답: \(String(format: "%.1f", performance.averageResponseTime))초")
                
                let prefixed = systemPromptPrefix(for: mode) + "\n\n" + content
                let output = try await withTimeout(seconds: adaptiveTimeout) { [self] in
                    try await callOpenRouter(model: model, userContent: prefixed)
                }
                
                let responseTime = Date().timeIntervalSince(startTime)
                
                // 성공 기록
                recordModelSuccess(model: model, responseTime: responseTime)
                
                // 캐시에 저장
                cacheResponse(for: cacheKey, response: output, model: model)
                
                print("✅ [OpenRouterFallback] 우선 모델 성공! \(model) (응답시간: \(String(format: "%.2f", responseTime))초)")
                if tried.count > 0 {
                    print("🔄 [OpenRouterFallback] 폴백 완료 - 실패한 모델: \(tried.count)개")
                }
                return output
                
            } catch {
                tried.append(model)
                lastError = error
                
                // 실패 기록
                recordModelFailure(model: model, error: error)
                
                print("❌ [OpenRouterFallback] 우선 모델 실패: \(model) - \(error.localizedDescription)")
                
                continue
            }
        }
        
        // 4. 우선 모델들이 모두 실패한 경우, 폴백 모델들 시도 (긴 타임아웃)
        if !fallbackModels.isEmpty {
            print("🔄 [OpenRouterFallback] 우선 모델 실패, 폴백 모델들 시도 시작")
            
            for (index, model) in fallbackModels.enumerated() {
                do {
                    let startTime = Date()
                    let performance = getModelPerformance(model)
                    let adaptiveTimeout = calculateAdaptiveTimeout(for: model, performance: performance, isPriority: false)
                    
                    print("🎯 [OpenRouterFallback] 폴백 모델 #\(index + 1) 시도: \(model)")
                    
                    let prefixed = systemPromptPrefix(for: mode) + "\n\n" + content
                    let output = try await withTimeout(seconds: adaptiveTimeout) { [self] in
                        try await callOpenRouter(model: model, userContent: prefixed)
                    }
                    
                    let responseTime = Date().timeIntervalSince(startTime)
                    
                    // 성공 기록
                    recordModelSuccess(model: model, responseTime: responseTime)
                    
                    // 캐시에 저장
                    cacheResponse(for: cacheKey, response: output, model: model)
                    
                    print("✅ [OpenRouterFallback] 폴백 모델 성공! \(model) (응답시간: \(String(format: "%.2f", responseTime))초)")
                    print("🔄 [OpenRouterFallback] 총 실패한 모델: \(tried.count)개")
                    return output
                    
                } catch {
                    tried.append(model)
                    lastError = error
                    
                    // 실패 기록
                    recordModelFailure(model: model, error: error)
                    
                    print("❌ [OpenRouterFallback] 폴백 모델 실패: \(model) - \(error.localizedDescription)")
                    
                    continue
                }
            }
        }
        
        print("💥 [OpenRouterFallback] 모든 \(tried.count)개 모델 실패")
        print("🔍 [OpenRouterFallback] 시도한 모델들: \(tried.joined(separator: ", "))")
        throw AIServiceError.allModelsFailed(tried)
    }

    /// 멀티-메시지 버전: 역할 분리된 메시지 배열을 입력으로 받아 폴백 수행
    func sendMessageWithFallback(messages: [ORMessage], mode: AIMode) async throws -> String {
        // 시스템 프롬프트 프리픽스 주입(없으면 추가, 있으면 결합)
        var finalMessages = messages
        if let sysIdx = finalMessages.firstIndex(where: { $0.role.lowercased() == "system" }) {
            let prefix = systemPromptPrefix(for: mode)
            let merged = ORMessage(role: "system", content: prefix + "\n\n" + finalMessages[sysIdx].content)
            finalMessages[sysIdx] = merged
        } else {
            finalMessages.insert(ORMessage(role: "system", content: systemPromptPrefix(for: mode)), at: 0)
        }

        // 캐시 키 구성: 역할:내용을 합쳐서 생성 (길이 제한 적용)
        let keyString = finalMessages.map { "\($0.role):\($0.content)" }.joined(separator: "\n")
        let cacheKey = CacheKey(content: String(keyString.prefix(800)), mode: mode)

        if let cachedResponse = getCachedResponse(for: cacheKey) {
            print("⚡ [OpenRouterFallback] 캐시 히트! 모델: \(cachedResponse.model)")
            return cachedResponse.response
        }

        // 모델 순서 계산
        let optimizedModels = getOptimizedModelOrder()
        let priorityModels = Array(optimizedModels.prefix(5))
        let fallbackModels = Array(optimizedModels.dropFirst(5))
        var tried: [String] = []
        var lastError: Error?

        print("🚀 [OpenRouterFallback] (멀티) 폴백 시스템 시작")
        print("   우선 모델: \(priorityModels.count)개, 폴백 모델: \(fallbackModels.count)개")

        // 우선 모델 시도
        for (index, model) in priorityModels.enumerated() {
            do {
                let startTime = Date()
                let performance = getModelPerformance(model)
                let adaptiveTimeout = calculateAdaptiveTimeout(for: model, performance: performance, isPriority: true)

                print("🎯 [OpenRouterFallback] (멀티) 우선 모델 #\(index + 1) 시도: \(model)")
                let output = try await withTimeout(seconds: adaptiveTimeout) { [self] in
                    try await callOpenRouter(model: model, messages: finalMessages)
                }
                let responseTime = Date().timeIntervalSince(startTime)
                recordModelSuccess(model: model, responseTime: responseTime)
                cacheResponse(for: cacheKey, response: output, model: model)
                print("✅ [OpenRouterFallback] (멀티) 우선 모델 성공! \(model) (\(String(format: "%.2f", responseTime))초)")
                return output
            } catch {
                tried.append(model)
                lastError = error
                recordModelFailure(model: model, error: error)
                print("❌ [OpenRouterFallback] (멀티) 우선 모델 실패: \(model) - \(error.localizedDescription)")
                continue
            }
        }

        // 폴백 모델 시도
        for (index, model) in fallbackModels.enumerated() {
            do {
                let startTime = Date()
                let performance = getModelPerformance(model)
                let adaptiveTimeout = calculateAdaptiveTimeout(for: model, performance: performance, isPriority: false)

                print("🎯 [OpenRouterFallback] (멀티) 폴백 모델 #\(index + 1) 시도: \(model)")
                let output = try await withTimeout(seconds: adaptiveTimeout) { [self] in
                    try await callOpenRouter(model: model, messages: finalMessages)
                }
                let responseTime = Date().timeIntervalSince(startTime)
                recordModelSuccess(model: model, responseTime: responseTime)
                cacheResponse(for: cacheKey, response: output, model: model)
                print("✅ [OpenRouterFallback] (멀티) 폴백 모델 성공! \(model) (\(String(format: "%.2f", responseTime))초)")
                return output
            } catch {
                tried.append(model)
                lastError = error
                recordModelFailure(model: model, error: error)
                print("❌ [OpenRouterFallback] (멀티) 폴백 모델 실패: \(model) - \(error.localizedDescription)")
                continue
            }
        }

        print("💥 [OpenRouterFallback] (멀티) 모든 \(tried.count)개 모델 실패")
        print("🔍 [OpenRouterFallback] 시도한 모델들: \(tried.joined(separator: ", "))")
        throw AIServiceError.allModelsFailed(tried)
    }

    private func callOpenRouter(model: String, userContent: String) async throws -> String {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw AIServiceError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 환경에서 안전하게 API 키 로드 (Info.plist에 OPENROUTER_API_KEY 존재 가정)
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String, !apiKey.isEmpty else {
            throw AIServiceError.configurationError("OPENROUTER_API_KEY 누락")
        }
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let referer = Bundle.main.bundleIdentifier {
            req.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
            req.setValue("DeepSleep", forHTTPHeaderField: "X-Title")
        }

        let body = ORRequest(model: model, messages: [
            ORMessage(role: "user", content: userContent)
        ])
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let text = String(data: data, encoding: .utf8) {
                throw AIServiceError.apiError(http.statusCode, text)
            } else {
                throw AIServiceError.httpError(http.statusCode)
            }
        }
        let decoded = try JSONDecoder().decode(ORResponse.self, from: data)
        guard let content = decoded.choices?.first?.message.content, !content.isEmpty else {
            throw AIServiceError.invalidResponse
        }
        return content
    }

    /// OpenRouter 호출 (멀티-메시지)
    private func callOpenRouter(model: String, messages: [ORMessage]) async throws -> String {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else {
            throw AIServiceError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OPENROUTER_API_KEY") as? String, !apiKey.isEmpty else {
            throw AIServiceError.configurationError("OPENROUTER_API_KEY 누락")
        }
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let referer = Bundle.main.bundleIdentifier {
            req.setValue(referer, forHTTPHeaderField: "HTTP-Referer")
            req.setValue("DeepSleep", forHTTPHeaderField: "X-Title")
        }

        let body = ORRequest(model: model, messages: messages)
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let text = String(data: data, encoding: .utf8) {
                throw AIServiceError.apiError(http.statusCode, text)
            } else {
                throw AIServiceError.httpError(http.statusCode)
            }
        }
        let decoded = try JSONDecoder().decode(ORResponse.self, from: data)
        guard let content = decoded.choices?.first?.message.content, !content.isEmpty else {
            throw AIServiceError.invalidResponse
        }
        return content
    }
    
    // MARK: - 🚀 Phase 3: 성능 모니터링 및 최적화 메서드
    
    /// 성능 기반 모델 순서 최적화
    private func getOptimizedModelOrder() -> [String] {
        return performanceQueue.sync {
            return unifiedFreeModels.sorted { model1, model2 in
                let perf1 = modelPerformance[model1] ?? ModelPerformance()
                let perf2 = modelPerformance[model2] ?? ModelPerformance()
                
                // 1차: 성공률 (높은 순)
                if abs(perf1.successRate - perf2.successRate) > 0.1 {
                    return perf1.successRate > perf2.successRate
                }
                
                // 2차: 평균 응답 시간 (빠른 순)
                if abs(perf1.averageResponseTime - perf2.averageResponseTime) > 1.0 {
                    return perf1.averageResponseTime < perf2.averageResponseTime
                }
                
                // 3차: 최근 사용 시간 (최근 순)
                return perf1.lastUsed > perf2.lastUsed
            }
        }
    }
    
    /// 모델 성공 기록
    private func recordModelSuccess(model: String, responseTime: TimeInterval) {
        performanceQueue.async(flags: .barrier) {
            var performance = self.modelPerformance[model] ?? ModelPerformance()
            performance.successCount += 1
            performance.totalResponseTime += responseTime
            performance.lastUsed = Date()
            self.modelPerformance[model] = performance
            
            // 성능 데이터 저장
            self.savePerformanceData()
        }
    }
    
    /// 모델 실패 기록
    private func recordModelFailure(model: String, error: Error) {
        performanceQueue.async(flags: .barrier) {
            var performance = self.modelPerformance[model] ?? ModelPerformance()
            performance.failureCount += 1
            performance.lastUsed = Date()
            self.modelPerformance[model] = performance
            
            // 성능 데이터 저장
            self.savePerformanceData()
        }
    }
    
    /// 모델 성능 조회
    private func getModelPerformance(_ model: String) -> ModelPerformance {
        return performanceQueue.sync {
            return modelPerformance[model] ?? ModelPerformance()
        }
    }
    
    // MARK: - 🧠 Phase 3: 캐싱 시스템
    
    /// 캐시된 응답 조회
    private func getCachedResponse(for key: CacheKey) -> CacheEntry? {
        return cacheQueue.sync {
            guard let entry = responseCache[key] else { return nil }
            
            // 만료 확인
            if Date().timeIntervalSince(entry.timestamp) > cacheExpirationTime {
                responseCache.removeValue(forKey: key)
                return nil
            }
            
            return entry
        }
    }
    
    /// 응답 캐싱
    private func cacheResponse(for key: CacheKey, response: String, model: String) {
        cacheQueue.async(flags: .barrier) {
            let entry = CacheEntry(response: response, timestamp: Date(), model: model)
            self.responseCache[key] = entry
        }
    }
    
    /// 만료된 캐시 정리
    private func cleanupExpiredCache() {
        cacheQueue.async(flags: .barrier) {
            let now = Date()
            self.responseCache = self.responseCache.filter { _, entry in
                now.timeIntervalSince(entry.timestamp) <= self.cacheExpirationTime
            }
            print("🧹 [OpenRouterFallback] 캐시 정리 완료 - 현재 캐시 항목: \(self.responseCache.count)개")
        }
    }
    
    // MARK: - 💾 Phase 3: 성능 데이터 영속화
    
    /// 성능 데이터 저장
    private func savePerformanceData() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let performanceFile = documentsPath.appendingPathComponent("openrouter_performance.json")
        
        do {
            let data = try JSONEncoder().encode(modelPerformance)
            try data.write(to: performanceFile)
        } catch {
            print("❌ [OpenRouterFallback] 성능 데이터 저장 실패: \(error)")
        }
    }
    
    /// 성능 데이터 로드
    private func loadPerformanceData() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let performanceFile = documentsPath.appendingPathComponent("openrouter_performance.json")
        
        do {
            let data = try Data(contentsOf: performanceFile)
            modelPerformance = try JSONDecoder().decode([String: ModelPerformance].self, from: data)
            print("✅ [OpenRouterFallback] 성능 데이터 로드 완료 - \(modelPerformance.count)개 모델")
        } catch {
            print("ℹ️ [OpenRouterFallback] 성능 데이터 로드 실패 (첫 실행일 수 있음): \(error)")
            modelPerformance = [:]
        }
    }
    
    // MARK: - 📊 Phase 3: 성능 통계 조회 (디버깅용)
    
    /// 성능 통계 출력
    func printPerformanceStats() {
        performanceQueue.sync {
            print("\n📊 [OpenRouterFallback] 모델 성능 통계:")
            print(String(repeating: "=", count: 60))
            
            let sortedModels = modelPerformance.sorted { $0.value.successRate > $1.value.successRate }
            
            for (model, performance) in sortedModels.prefix(10) {
                let successRate = String(format: "%.1f%%", performance.successRate * 100)
                let avgTime = String(format: "%.2fs", performance.averageResponseTime)
                let total = performance.successCount + performance.failureCount
                
                print("🎯 \(model)")
                print("   성공률: \(successRate) (\(performance.successCount)/\(total))")
                print("   평균 응답시간: \(avgTime)")
                print("   마지막 사용: \(performance.lastUsed)")
                print("")
            }
            
            print("💾 캐시 항목: \(responseCache.count)개")
            print(String(repeating: "=", count: 60))
        }
    }
    
    // MARK: - 🚀 Phase 3: 성능 최적화 추가 메서드들
    
    /// 적응형 타임아웃 계산
    private func calculateAdaptiveTimeout(for model: String, performance: ModelPerformance, isPriority: Bool) -> TimeInterval {
        let baseTimeout: TimeInterval = isPriority ? 15.0 : 30.0 // 우선 모델은 짧은 타임아웃
        
        // 성능 기반 조정
        if performance.successCount > 0 {
            let avgResponseTime = performance.averageResponseTime
            let adjustedTimeout = max(baseTimeout, avgResponseTime * 2.0) // 평균 응답시간의 2배
            return min(adjustedTimeout, isPriority ? 20.0 : 45.0) // 최대 제한
        }
        
        return baseTimeout
    }
    
    /// 타임아웃 래퍼 함수
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AIServiceError.timeoutError
            }
            
            guard let result = try await group.next() else {
                throw AIServiceError.timeoutError
            }
            
            group.cancelAll()
            return result
        }
    }
}

// MARK: - 🚀 Phase 3: ModelPerformance Codable 지원
extension OpenRouterFallbackManager.ModelPerformance: Codable {}

