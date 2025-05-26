
import Foundation

class ReplicateChatService {
    static let shared = ReplicateChatService()
    private init() {}

    private let versionGUID = "8e6975e5ed6174911a6ff3d60540dfd4844201974602551e10e9e87ab143d81e"

    func sendPrompt(_ prompt: String, completion: @escaping (String?) -> Void) {
        guard let apiToken = Bundle.main.object(forInfoDictionaryKey: "REPLICATE_API_TOKEN") as? String else {
            print("❌ API 토큰 불러오기 실패")
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

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ 에러: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let output = json["output"] as? [String],
                   let finalMessage = output.first {
                    print("✅ 파싱된 응답: \(finalMessage)")
                    completion(finalMessage)
                } else {
                    print("❌ 응답 파싱 실패")
                    completion(nil)
                }
            } catch {
                print("❌ JSON 파싱 오류: \(error)")
                completion(nil)
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
