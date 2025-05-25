import Foundation

class ReplicateChatService {
    static let shared = ReplicateChatService()
    private init() {}

    private let versionGUID = "8e6975e5ed6174911a6ff3d60540dfd4844201974602551e10e9e87ab143d81e"

    func sendPrompt(_ prompt: String, completion: @escaping (String?) -> Void) {
        guard let apiToken = Bundle.main.object(forInfoDictionaryKey: "REPLICATE_API_TOKEN") as? String else {
            print("❌ API 토큰을 불러오지 못했습니다.")
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
                print("❌ Error: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }

            if let responseString = String(data: data, encoding: .utf8) {
                print("✅ Response: \(responseString)")
                completion(responseString)
            } else {
                completion(nil)
            }
        }.resume()
    }
}
