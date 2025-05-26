import Foundation
import Network

class ReplicateChatService {
    static let shared = ReplicateChatService()
    private init() {}

    // MARK: - 네트워크 체크
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

    // MARK: - 일반 메시지용 프롬프트
    func sendPrompt(message: String, intent: String, completion: @escaping (String?) -> Void) {
        let contextPrompt = """
        너는 감정을 공감하고 위로해주는 따뜻한 한국어 대화 AI야. 친구처럼 자연스럽고 다정한 말투로 이야기해줘.
        User: \(message)
        Assistant:
        """

        let input: [String: Any] = [
            "prompt": contextPrompt,
            "temperature": 0.7,
            "top_p": 0.9,
            "max_tokens": 300,
            "system_prompt": "한국어로 대화하는 친근한 AI 어시스턴트입니다."
        ]

        sendToReplicate(input: input, completion: completion)
    }

    // MARK: - 프리셋 추천용 프롬프트
    func recommendPreset(emotion: String, completion: @escaping (String?) -> Void) {
        let presetFormat = SoundPresetCatalog.labels.prefix(12).joined(separator: ", ")
        let prompt = """
        감정: \(emotion)
        프리셋 요소: \(presetFormat)
        출력 예시: [추천 프리셋] Rain:80, Wind:60, ...
        설명 없이 이 형식만 출력해줘.
        """

        let input: [String: Any] = [
            "prompt": prompt,
            "temperature": 0.3,
            "top_p": 0.8,
            "max_tokens": 100,
            "system_prompt": "음향 프리셋 추천 전문가"
        ]

        sendToReplicate(input: input, completion: completion)
    }

    // MARK: - Replicate API 요청 (수정됨)
    private func sendToReplicate(input: [String: Any], completion: @escaping (String?) -> Void) {
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

            // 직접 모델 엔드포인트 사용
            let url = URL(string: "https://api.replicate.com/v1/models/anthropic/claude-3.5-haiku/predictions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            // 요청 바디 - input만 전송
            let body: [String: Any] = [
                "input": input
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                print("📤 Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "")")
            } catch {
                print("❌ JSON 직렬화 실패: \(error)")
                completion(nil)
                return
            }

            let session = URLSession(configuration: .default)

            func tryCreatePrediction(retriesLeft: Int) {
                session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("❌ 네트워크 오류: \(error)")
                        if retriesLeft > 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                tryCreatePrediction(retriesLeft: retriesLeft - 1)
                            }
                        } else {
                            DispatchQueue.main.async { completion(nil) }
                        }
                        return
                    }
                    
                    // HTTP 응답 상태 확인
                    if let httpResponse = response as? HTTPURLResponse {
                        print("📡 HTTP Status: \(httpResponse.statusCode)")
                        if httpResponse.statusCode != 201 && httpResponse.statusCode != 200 {
                            if let data = data, let errorString = String(data: data, encoding: .utf8) {
                                print("❌ API 오류 응답: \(errorString)")
                            }
                        }
                    }
                    
                    guard let data = data else {
                        print("❌ 데이터 없음")
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("📥 Response: \(json)")
                            
                            if let predictionID = json["id"] as? String {
                                print("✅ Prediction ID: \(predictionID)")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    self.pollPredictionResult(id: predictionID, token: apiToken, attempts: 0, completion: completion)
                                }
                            } else if let error = json["error"] as? String {
                                print("❌ API 에러: \(error)")
                                if retriesLeft > 0 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        tryCreatePrediction(retriesLeft: retriesLeft - 1)
                                    }
                                } else {
                                    DispatchQueue.main.async { completion(nil) }
                                }
                            }
                        }
                    } catch {
                        print("❌ JSON 파싱 실패: \(error)")
                        if retriesLeft > 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                tryCreatePrediction(retriesLeft: retriesLeft - 1)
                            }
                        } else {
                            DispatchQueue.main.async { completion(nil) }
                        }
                    }
                }.resume()
            }

            tryCreatePrediction(retriesLeft: 3)
        }
    }

    // MARK: - 결과 폴링 (수정됨)
    private func pollPredictionResult(id: String, token: String, attempts: Int, completion: @escaping (String?) -> Void) {
        guard attempts < 30 else { // 시도 횟수 감소
            print("❌ 결과 polling 실패: 시도 횟수 초과 (\(attempts)회)")
            DispatchQueue.main.async { completion(nil) }
            return
        }

        let getURL = URL(string: "https://api.replicate.com/v1/predictions/\(id)")!
        var request = URLRequest(url: getURL)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Polling 오류: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.pollPredictionResult(id: id, token: token, attempts: attempts + 1, completion: completion)
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let status = json["status"] as? String ?? "unknown"
                    print("📊 Status: \(status) (attempt: \(attempts))")
                    
                    switch status {
                    case "succeeded":
                        // output 처리 방식 개선
                        var result: String?
                        if let outputArray = json["output"] as? [String] {
                            result = outputArray.joined()
                        } else if let outputString = json["output"] as? String {
                            result = outputString
                        }
                        
                        print("✅ 결과: \(result ?? "없음")")
                        DispatchQueue.main.async {
                            completion(result)
                        }
                        
                    case "failed", "canceled":
                        if let error = json["error"] as? String {
                            print("❌ 실패 사유: \(error)")
                        }
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                        
                    case "starting", "processing":
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.pollPredictionResult(id: id, token: token, attempts: attempts + 1, completion: completion)
                        }
                        
                    default:
                        print("⚠️ 알 수 없는 상태: \(status)")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.pollPredictionResult(id: id, token: token, attempts: attempts + 1, completion: completion)
                        }
                    }
                }
            } catch {
                print("❌ Polling JSON 파싱 실패: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
}
