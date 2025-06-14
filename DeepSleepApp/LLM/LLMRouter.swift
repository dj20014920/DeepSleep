import Foundation
import UIKit

/// LLM 입력 구조체
public struct LLMInput {
    public let prompt: String
    /// 토큰 수 추정 (간단히 문자수/4)
    public var estimatedTokenCount: Int { prompt.count / 4 }
    public init(prompt: String) { self.prompt = prompt }
}

/// LLM 출력 구조체 (Claude/Foundational 공통)
public struct LLMOutput: Decodable, Equatable {
    public let text: String
    public let metadata: [String: String]?
    public let soundPreset: SoundPreset?
    public init(text: String, metadata: [String: String]? = nil, soundPreset: SoundPreset? = nil) {
        self.text = text
        self.metadata = metadata
        self.soundPreset = soundPreset
    }
}

/// LLM 라우팅/분기/예외처리 컴포넌트
@available(iOS 16.0, *)
public final class LLMRouter {
    public static let shared = LLMRouter()
    private init() {}

    /// LLM 입력에 대해 적절한 엔진(FM/Claude)으로 분기 실행
    /// - Parameter input: LLMInput (prompt)
    /// - Returns: LLMOutput (텍스트, 사운드 프리셋 등)
    /// - Throws: Claude/Foundational 예측 실패 시 오류
    public func route(input: LLMInput) async throws -> LLMOutput {
        // iOS 17 이상 + FoundationModelRunner 지원
        if #available(iOS 17.0, *) {
            if shouldUseClaude(for: input.prompt) {
                return try await callClaude(input: input)
            }
            do {
                let runner = FoundationModelRunner(modelName: "phi-mini", adapterURL: nil)
                let output = try await runner.generateResponse(from: input.prompt, useKVCache: true)
                return LLMOutput(text: output.text, metadata: output.metadata, soundPreset: nil)
            } catch {
                // FoundationModelRunner 실패 시 Claude fallback
                return try await callClaude(input: input)
            }
        } else {
            // iOS 16 이하: Claude 3.5만 사용
            return try await callClaude(input: input)
        }
    }

    /// Claude 3.5 API 호출 (보안 키 자동 처리)
    private func callClaude(input: LLMInput) async throws -> LLMOutput {
        let apiKey = try fetchAPIToken()
        let result = try await ClaudeService.shared.sendChat(prompt: input.prompt, apiKey: apiKey)
        // ClaudeService는 LLMOutput 또는 String 반환한다고 가정
        if let output = result as? LLMOutput {
            return output
        } else if let text = result as? String {
            return LLMOutput(text: text, metadata: ["engine": "claude-3.5"])
        } else {
            throw NSError(domain: "LLMRouter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Claude 응답 파싱 실패"])
        }
    }

    /// Claude fallback 조건: 장문/코드블록 포함
    private func shouldUseClaude(for prompt: String) -> Bool {
        return prompt.count > 1000 || prompt.contains("```")
    }

    /// Info.plist/Keychain 기반 API 키 보안 처리
    private func fetchAPIToken() throws -> String {
        // 1. Keychain 우선
        if let key = SecureEnclaveKeyStore.shared.get(key: "REPLICATE_API_TOKEN") {
            return key
        }
        // 2. Info.plist fallback
        if let key = Bundle.main.infoDictionary?["REPLICATE_API_TOKEN"] as? String, !key.isEmpty {
            return key
        }
        throw NSError(domain: "LLMRouter", code: 1, userInfo: [NSLocalizedDescriptionKey: "API 토큰이 없습니다."])
    }
} 