import Foundation
import os

/// LLM 라우팅 및 분기 관리 (Foundation ↔ Claude 3.5)
public final class LLMRouter {
    /// LLM 종류
    public enum ModelType {
        case foundation
        case claude
    }
    /// 라우팅 결과
    public struct RoutingResult {
        public let model: ModelType
        public let reason: String
    }
    /// LLM 응답 생성 (iOS 17 이상 Foundation, 미만 Claude)
    /// - Parameters:
    ///   - prompt: 입력 프롬프트
    ///   - outputHint: 예상 출력(길이, 코드블록 등)
    ///   - useKVCache: FoundationModelRunner의 KV 캐시 사용 여부
    /// - Returns: LLMOutput (Claude/Foundational 공통)
    public static func generateResponse(prompt: String, outputHint: String? = nil, useKVCache: Bool = true) async throws -> LLMOutput {
        // Claude fallback 조건: iOS 17 미만 or (iOS 17+에서 fallback 조건)
        let isFallback: Bool = {
            if let hint = outputHint, (hint.count >= 1000 || hint.contains("```")) {
                return true
            }
            return false
        }()
        if #available(iOS 17.0, *) {
            if isFallback == false {
                // FoundationModelRunner 사용
                let runner = FoundationModelRunner(modelName: "foundation-llm", adapterURL: nil)
                return try await runner.generateResponse(from: prompt, useKVCache: useKVCache)
            } else {
                // Claude fallback
                let service = ClaudeService()
                let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<LLMOutput, Error>) in
                    service.sendMessage(prompt) { res in
                        switch res {
                        case .success(let str):
                            cont.resume(returning: LLMOutput(text: str, metadata: ["model": "claude-3.5"]))
                        case .failure(let err):
                            cont.resume(throwing: err)
                        }
                    }
                }
                return result
            }
        } else {
            // iOS 17 미만: Claude 3.5만 사용
            let service = ClaudeService()
            let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<LLMOutput, Error>) in
                service.sendMessage(prompt) { res in
                    switch res {
                    case .success(let str):
                        cont.resume(returning: LLMOutput(text: str, metadata: ["model": "claude-3.5"]))
                    case .failure(let err):
                        cont.resume(throwing: err)
                    }
                }
            }
            return result
        }
    }
} 