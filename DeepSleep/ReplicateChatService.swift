
import Foundation

class ReplicateChatService {
    static let shared = ReplicateChatService()
    private init() {}

    private let versionGUID = "8e6975e5ed6174911a6ff3d60540dfd4844201974602551e10e9e87ab143d81e"

    func sendPrompt(_ prompt: String, completion: @escaping (String?) -> Void) {
        guard let apiToken = Bundle.main.object(forInfoDictionaryKey: "REPLICATE_API_TOKEN") as? String else {
            print("❌ API 토큰 누락")
            completion(nil)
            return
        }

        let url = URL(string: "https://api.replicate.com/v1/predictions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let parameters: [String: Any] = [
            "version": versionGUID,
            "input": [
                "prompt": prompt,
                "temperature": 0.75,
                "top_p": 1,
                "max_new_tokens": 800
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

        // 1차 요청 (prediction 생성)
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let predictionID = json["id"] as? String else {
                print("❌ Prediction 생성 실패")
                completion(nil)
                return
            }

            print("🧪 Prediction ID: \(predictionID)")

            // 2차 요청 (polling)
            self.pollPredictionResult(id: predictionID, token: apiToken, attempts: 0, completion: completion)

        }.resume()
    }

    private func pollPredictionResult(id: String, token: String, attempts: Int, completion: @escaping (String?) -> Void) {
        guard attempts < 30 else {
            print("❌ 결과 polling 실패: 시도 횟수 초과")
            completion(nil)
            return
        }

        let getURL = URL(string: "https://api.replicate.com/v1/predictions/\(id)")!
        var getRequest = URLRequest(url: getURL)
        getRequest.httpMethod = "GET"
        getRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: getRequest) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else {
                print("❌ polling 응답 파싱 실패")
                completion(nil)
                return
            }

            if status == "succeeded", let output = json["output"] as? [String], let result = output.first {
                print("✅ 결과 수신 완료: \(result)")
                completion(result)
            } else if status == "failed" {
                print("❌ 모델 실행 실패")
                completion(nil)
            } else {
                print("⏳ 결과 대기 중... (\(attempts + 1))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.pollPredictionResult(id: id, token: token, attempts: attempts + 1, completion: completion)
                }
            }
        }.resume()
    }
    
    func recommendPreset(emotion: String, completion: @escaping (String?) -> Void) {
        let presetFormat = SoundPresetCatalog.labels.prefix(12).joined(separator: ", ")
        let prompt = """
        감정: \(emotion)
        프리셋 요소: \(presetFormat)
        응답 형식 예시: [프리셋 이름] Rain:80, Wind:60, Fan:40 ...
        설명 없이 이 형식만 출력해줘.
        """
        sendPrompt(prompt, completion: completion)
    }
}
