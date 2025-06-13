import Foundation

/// LLM 출력 구조 (Claude/Foundational 공통)
public struct LLMOutput: Decodable, Equatable {
    /// 모델이 생성한 텍스트
    public let text: String
    /// 추가 메타데이터(선택)
    public let metadata: [String: String]?
}

/// Foundation Model 실행/캐시/출력 파싱 러너
@available(iOS 17.0, *)
public final class FoundationModelRunner {
    private let modelName: String
    private let adapterURL: URL?
    private var kvCache: [String: Any] = [:] // KV 캐시 (실제 구현 시 MLState 등으로 대체)
    /// 생성자
    /// - Parameters:
    ///   - modelName: Foundation Model 이름
    ///   - adapterURL: LoRA 어댑터 파일 경로(선택)
    public init(modelName: String, adapterURL: URL?) {
        self.modelName = modelName
        self.adapterURL = adapterURL
    }
    /// prompt를 기반으로 Foundation Model 출력 생성
    /// - Parameters:
    ///   - prompt: 사용자 입력
    ///   - useKVCache: KV 캐시 재사용 여부
    /// - Returns: 구조화된 LLMOutput (Decodable)
    public func generateResponse(from prompt: String, useKVCache: Bool) async throws -> LLMOutput {
        // 실제 Foundation Model 호출부는 placeholder/mock
        if useKVCache, let cached = kvCache[prompt] as? LLMOutput {
            return cached
        }
        // (실제 환경: Foundation Model + LoRAAdapter + MLState 활용)
        // 여기서는 mock 응답
        let output = LLMOutput(text: "[FM] \(prompt) 응답", metadata: ["model": modelName])
        if useKVCache { kvCache[prompt] = output }
        return output
    }
} 