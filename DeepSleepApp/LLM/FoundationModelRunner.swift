import Foundation
import CoreML

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
    private var model: MLModel?
    private let modelRemoteURL: URL = URL(string: "https://your-model-server.com/phi-mini.mlmodelc")! // 실제 서버 URL로 교체

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
    /// - Throws: 모델 로딩/예측 실패 시 오류
    public func generateResponse(from prompt: String, useKVCache: Bool) async throws -> LLMOutput {
        if useKVCache, let cached = kvCache[prompt] as? LLMOutput {
            return cached
        }
        // 1. 모델 로딩 (없으면 MLAssetManager로 다운로드)
        if model == nil {
            let modelURL = try await ensureModelLoaded()
            let config = MLModelConfiguration()
            self.model = try MLModel(contentsOf: modelURL, configuration: config)
        }
        guard let model = self.model else {
            throw NSError(domain: "FoundationModelRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "모델 로딩 실패"])
        }
        // 2. 입력/예측 (실제 입력/출력 구조는 모델에 맞게 수정)
        let inputFeatures = try prepareInput(prompt: prompt)
        let prediction = try await model.prediction(from: inputFeatures)
        let outputText = parseOutput(prediction)
        let output = LLMOutput(text: outputText, metadata: ["model": modelName])
        if useKVCache { kvCache[prompt] = output }
        return output
    }

    /// 모델 파일이 존재하지 않으면 MLAssetManager로 다운로드 후 경로 반환
    private func ensureModelLoaded() async throws -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let modelDir = caches.appendingPathComponent("Models", isDirectory: true)
        let modelURL = modelDir.appendingPathComponent("phi-mini.mlmodelc", isDirectory: true)
        if FileManager.default.fileExists(atPath: modelURL.path) {
            return modelURL
        }
        // MLAssetManager로 다운로드
        #if os(iOS)
        let downloaded = try await MLAssetManager.shared.downloadModelIfNeeded(from: modelRemoteURL, to: "phi-mini")
        #else
        let downloaded = try await MLAssetManager.shared.downloadModelIfNeeded(from: modelRemoteURL, to: "phi-mini")
        #endif
        guard FileManager.default.fileExists(atPath: downloaded.path) else {
            throw NSError(domain: "FoundationModelRunner", code: 2, userInfo: [NSLocalizedDescriptionKey: "모델 다운로드 실패"])
        }
        return downloaded
    }

    /// 입력 텍스트를 CoreML 모델 입력으로 변환 (실제 모델 구조에 맞게 구현 필요)
    private func prepareInput(prompt: String) throws -> MLFeatureProvider {
        // TODO: 실제 모델 입력 구조에 맞게 구현
        // 예시: 텍스트를 벡터로 변환 등
        throw NSError(domain: "FoundationModelRunner", code: 3, userInfo: [NSLocalizedDescriptionKey: "입력 변환 미구현"])
    }

    /// CoreML 예측 결과에서 텍스트 추출 (실제 모델 구조에 맞게 구현 필요)
    private func parseOutput(_ prediction: MLFeatureProvider) -> String {
        // TODO: 실제 모델 출력 구조에 맞게 구현
        // 예시: prediction.featureValue(for: "output")?.stringValue ?? ""
        return "[FM] 예측 결과(placeholder)"
    }
} 