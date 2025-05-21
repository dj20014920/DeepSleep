import CoreML
import Foundation

class CoreMLChatEngine {
    private var model: MLModel?

    init() {
        loadModel()
    }

    private func loadModel() {
        let config = MLModelConfiguration()
        config.computeUnits = .all  // Apple Neural Engine + GPU + CPU

        guard let modelURL = Bundle.main.url(forResource: "ko_dialogpt", withExtension: "mlpackage") else {
            print("❌ .mlpackage 파일을 찾을 수 없습니다.")
            return
        }

        do {
            let compiledURL = try MLModel.compileModel(at: modelURL)
            self.model = try MLModel(contentsOf: compiledURL, configuration: config)
            print("✅ CoreML 모델 로드 완료")
        } catch {
            print("❌ 모델 로드 실패: \(error)")
        }
    }

    func predict(inputIds: MLMultiArray, attentionMask: MLMultiArray) -> MLMultiArray? {
        guard let model = self.model else {
            print("❌ 모델이 로드되지 않았습니다.")
            return nil
        }

        let inputs: [String: Any] = [
            "input_ids": inputIds,
            "attention_mask": attentionMask
        ]

        do {
            let inputProvider = try MLDictionaryFeatureProvider(dictionary: inputs)
            let prediction = try model.prediction(from: inputProvider)
            return prediction.featureValue(for: "logits")?.multiArrayValue
        } catch {
            print("❌ 예측 실패: \(error)")
            return nil
        }
    }
}
