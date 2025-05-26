import Foundation
import Network

class ReplicateChatService {
    static let shared = ReplicateChatService()
    private init() {}

    private let versionGUID = "40c8f5c03ce250441855e776528bafd11cdb302c6677613acc0942c58dbd0afa"
    private var systemPrompt: String = ""

    func setSystemPrompt(_ prompt: String) {
        self.systemPrompt = prompt
    }

    func isNetworkAvailable(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.pathUpdateHandler = { path in
            monitor.cancel()
            DispatchQueue.main.async {
                completion(path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    func sendPrompt(_ prompt: String, completion: @escaping (String?) -> Void) {
        isNetworkAvailable { isConnected in
            guard isConnected else {
                print("❌ 네트워크 연결 안 됨")
                completion(nil)
                return
            }

            guard let apiToken = Bundle.main.object(forInfoDictionaryKey: "REPLICATE_API_TOKEN") as? String else {
                print("❌ API 토큰 누락")
                completion(nil)
                return
            }

            let fullPrompt = """
            너는 감정을 공감하고 위로해주는 따뜻한 한국어 대화 AI야. 수면, 힐링, 감정 표현 등 다양한 주제에 대해 이야기하고 공감해줄 수 있어
            항상 자연스럽고 공감 가는 말투로, 2~3문장으로 대답해줘 도우미처럼 말하지 말고, 친구처럼 대화해줘\(prompt)
            """

            let url = URL(string: "https://api.replicate.com/v1/predictions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let parameters: [String: Any] = [
                "version": self.versionGUID,
                "input": [
                    "text": fullPrompt,
                    "temperature": 0.7,
                    "top_p": 0.8,
                    "max_new_tokens": 600,
                    "do_sample": true
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)

            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 20
            config.timeoutIntervalForResource = 30
            let session = URLSession(configuration: config)

            func tryCreatePrediction(retriesLeft: Int) {
                session.dataTask(with: request) { data, _, error in
                    guard let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let predictionID = json["id"] as? String else {
                        if retriesLeft > 0 {
                            print("⚠️ Prediction 생성 실패 → 재시도 (\(retriesLeft))")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                tryCreatePrediction(retriesLeft: retriesLeft - 1)
                            }
                        } else {
                            print("❌ Prediction 생성 실패 (최대 재시도 초과)")
                            completion(nil)
                        }
                        return
                    }

                    print("🧪 Prediction ID: \(predictionID)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.pollPredictionResult(id: predictionID, token: apiToken, attempts: 0, completion: completion)
                    }

                }.resume()
            }

            tryCreatePrediction(retriesLeft: 3)
        }
    }
    
    func sendPrompt(message: String, intent: String, completion: @escaping (String?) -> Void) {
        let baseInstruction = """
        너는 감정을 공감하고 위로해주는 따뜻한 한국어 대화 AI야. 수면, 힐링, 감정 표현 등 다양한 주제에 대해 이야기하고 공감해줄 수 있어.
        항상 자연스럽고 공감 가는 말투로, 2~3문장으로 대답해줘. 도우미처럼 말하지 말고 친구처럼 대화해줘.
        """

        let appendedInstruction: String
        if intent == "diary" {
            appendedInstruction = "이 메시지는 사용자의 감정 일기야. 진심 어린 위로를 2~3문장으로 자연스럽게 건네줘."
        } else {
            appendedInstruction = "친근하고 따뜻하게 2~3문장으로 자연스럽게 반응해줘."
        }

        let fullPrompt = """
        \(baseInstruction)
        메시지: \(message)
        \(appendedInstruction)
        """

        // 기존 sendPrompt(String, completion:) 호출
        self.sendPrompt(fullPrompt, completion: completion)
    }
    
    private func pollPredictionResult(id: String, token: String, attempts: Int, completion: @escaping (String?) -> Void) {
        // 💡 평균 응답 55~60초 고려 → 최소 70회까지 허용
        guard attempts < 70 else {
            print("❌ 결과 polling 실패: 시도 횟수 초과 (\(attempts)회)")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        let getURL = URL(string: "https://api.replicate.com/v1/predictions/\(id)")!
        var getRequest = URLRequest(url: getURL)
        getRequest.httpMethod = "GET"
        getRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // 커스텀 세션 설정 (느린 네트워크 고려)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)

        session.dataTask(with: getRequest) { data, response, error in
            if let error = error {
                print("❌ Polling 중 네트워크 오류: \(error.localizedDescription)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.pollPredictionResult(id: id, token: token, attempts: attempts + 1, completion: completion)
                }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else {
                print("❌ polling 응답 파싱 실패 또는 데이터 없음")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.pollPredictionResult(id: id, token: token, attempts: attempts + 1, completion: completion)
                }
                return
            }

            if status == "succeeded" {
                print("🧾 전체 응답 json: \(json)")
                if let outputArray = json["output"] as? [String] {
                    let result = outputArray.joined()
                    print("✅ 결과 수신 완료 (배열): \(result)")
                    DispatchQueue.main.async {
                        completion(result)
                    }
                } else if let result = json["output"] as? String {
                    print("✅ 결과 수신 완료 (문자열): \(result)")
                    DispatchQueue.main.async {
                        completion(result)
                    }
                } else {
                    // 🔁 output 이 아직 준비되지 않았을 경우 → 재시도
                    print("⏳ succeeded지만 output 없음 → 재시도 (\(attempts + 1))")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.pollPredictionResult(id: id, token: token, attempts: attempts + 1, completion: completion)
                    }
                }

            } else if status == "failed" || status == "canceled" {
                print("❌ 모델 처리 실패 또는 취소됨. Status: \(status), Error: \(json["error"] ?? "N/A")")
                DispatchQueue.main.async {
                    completion(nil)
                }

            } else {
                // status == "starting", "processing" 등
                print("⏳ 결과 대기 중 (\(status))... (\(attempts + 1))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
