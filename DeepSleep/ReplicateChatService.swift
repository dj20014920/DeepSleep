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

    // MARK: - sendPrompt 메소드 (모든 intent 지원)
    func sendPrompt(message: String, intent: String, completion: @escaping (String?) -> Void) {
        let contextPrompt: String
        
        if intent == "diary" {
            contextPrompt = """
            당신은 감정을 깊이 이해하고 진심으로 위로해주는 AI 친구입니다.
            사용자가 일기 형태로 하루의 이야기를 들려주고 있습니다.
            
            대화 스타일:
            - 진심어린 공감과 위로
            - 부드럽고 따뜻한 어조  
            - 적절한 이모지 사용 (과하지 않게)
            - 사용자의 감정을 인정하고 수용
            - 실용적이면서도 감정적인 조언
            
            사용자 메시지: \(message)
            
            위 내용을 충분히 들어주고 깊이 공감해주세요.
            """
        } else if intent == "diary_analysis" {
            // ✅ 일기 분석 전용 프롬프트
            contextPrompt = """
            당신은 전문적인 감정 분석가이자 따뜻한 상담사입니다.
            사용자가 작성한 일기를 분석하여 감정적 지지와 위로를 제공해주세요.
            
            분석 방향:
            - 감정 상태에 대한 깊은 공감
            - 긍정적인 요소 발견 및 격려
            - 어려운 감정에 대한 따뜻한 위로
            - 건설적이고 실용적인 조언
            - 희망적인 미래 전망 제시
            
            응답 스타일:
            - 따뜻하고 이해심 많은 어조
            - 적절한 감정 이모지 (1-2개)
            - 3-4문장의 적당한 길이
            - 사용자의 감정을 먼저 인정
            
            분석할 일기 내용: \(message)
            
            위 일기를 분석하여 사용자에게 따뜻한 위로와 격려를 해주세요.
            """
        } else if intent == "pattern_analysis" {
            // ✅ 감정 패턴 분석 전용 프롬프트
            contextPrompt = """
            당신은 감정 패턴 분석 전문가이자 심리 상담사입니다.
            사용자의 장기간 감정 데이터를 분석하여 인사이트를 제공해주세요.
            
            분석 초점:
            - 감정 패턴의 의미와 해석
            - 긍정적인 변화와 성장 포인트
            - 주의깊게 살펴볼 감정 경향
            - 감정 건강 개선을 위한 구체적 조언
            - 개인 맞춤형 감정 관리 전략
            
            응답 스타일:
            - 전문적이지만 따뜻한 어조
            - 데이터 기반의 객관적 분석
            - 실용적이고 실행 가능한 조언
            - 희망적이고 격려적인 메시지
            - 적절한 구조화 (불릿 포인트 등)
            
            분석할 감정 패턴 데이터: \(message)
            
            위 패턴을 전문적으로 분석하여 사용자의 감정 건강 향상을 도와주세요.
            """
        } else {
            contextPrompt = """
            당신은 감정을 이해하고 따뜻하게 위로해주는 AI 친구입니다.
            친구처럼 자연스럽고 다정한 한국어로 대화해주세요.
            
            대화 원칙:
            - 짧고 자연스러운 응답 (2-3문장)
            - 진심어린 공감 표현
            - 적절한 감정 이모지 (1-2개)
            - 부담스럽지 않은 따뜻함
            
            사용자 메시지: \(message)
            """
        }

        let input: [String: Any] = [
            "prompt": contextPrompt,
            "temperature": intent == "diary" || intent == "diary_analysis" ? 0.8 : (intent == "pattern_analysis" ? 0.7 : 0.7),
            "top_p": 0.9,
            "max_tokens": intent == "pattern_analysis" ? 500 : (intent == "diary_analysis" ? 300 : (intent == "diary" ? 400 : 200)),
            "system_prompt": "한국어로 대화하는 친근하고 따뜻한 AI 친구입니다."
        ]

        sendToReplicate(input: input, completion: completion)
    }

    // MARK: - 프리셋 추천용 프롬프트 (기존 유지)
    func recommendPreset(emotion: String, completion: @escaping (String?) -> Void) {
        let prompt = """
        당신은 감정을 이해하고 사운드 테라피를 제공하는 전문가입니다.
        
        사용자 상황: \(emotion)
        
        12가지 사운드로 맞춤 프리셋을 만들어주세요:
        1. Rain (빗소리 - 평온, 집중)
        2. Thunder (천둥 - 강렬함, 드라마틱) 
        3. Ocean (파도 - 자연, 휴식)
        4. Fire (모닥불 - 따뜻함, 포근함)
        5. Steam (증기 - 부드러움)
        6. WindowRain (창가 빗소리 - 아늑함)
        7. Forest (숲새소리 - 자연, 생동감)
        8. Wind (바람 - 시원함, 청량함)
        9. Night (여름밤 - 로맨틱, 평화)
        10. Lullaby (자장가 - 수면, 위로)
        11. Fan (선풍기 - 집중, 백색소음)
        12. WhiteNoise (백색소음 - 집중, 차단)
        
        각 사운드의 볼륨을 0-100으로 설정하여 감정 상태에 최적화된 조합을 만드세요.
        
        **출력 형식 (정확히 따라주세요):**
        [감정에 맞는 프리셋 이름] Rain:80, Thunder:10, Ocean:60, Fire:0, Steam:20, WindowRain:40, Forest:70, Wind:30, Night:50, Lullaby:0, Fan:20, WhiteNoise:30
        
        다른 설명 없이 위 형식만 출력해주세요.
        """

        let input: [String: Any] = [
            "prompt": prompt,
            "temperature": 0.2, // 더 일관된 출력을 위해 낮춤
            "top_p": 0.8,
            "max_tokens": 150,
            "system_prompt": "사운드 테라피 전문가로서 정확한 형식으로 프리셋을 추천합니다."
        ]

        sendToReplicate(input: input, completion: completion)
    }

    // MARK: - Replicate API 요청 (기존 유지)
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

            let url = URL(string: "https://api.replicate.com/v1/models/anthropic/claude-3.5-haiku/predictions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

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

    // MARK: - 결과 폴링 (기존 유지)
    private func pollPredictionResult(id: String, token: String, attempts: Int, completion: @escaping (String?) -> Void) {
        guard attempts < 30 else {
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
