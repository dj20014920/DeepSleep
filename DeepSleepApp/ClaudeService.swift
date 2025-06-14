import Foundation

/// Claude API 통신 서비스 (Keychain 연동)
final class ClaudeService {
    private let session: URLSession
    init(session: URLSession = .shared) {
        self.session = session
    }
    /// Keychain에서 API 키 로드
    func getAPIKey() -> String? {
        SecureEnclaveKeyStore.shared.loadAPIKey()
    }
    /// 채팅 메시지 전송 (실제 API 연동)
    func sendMessage(_ message: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = getAPIKey() else {
            completion(.failure(NSError(domain: "ClaudeService", code: 401, userInfo: [NSLocalizedDescriptionKey: "API 키 없음"])))
            return
        }
        // 실제 API 호출 예시 (여기선 dummy endpoint)
        let url = URL(string: "https://api.claude.ai/v1/message")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["message": message]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = session.dataTask(with: req) { data, resp, err in
            if let err = err {
                completion(.failure(err))
            } else if let data = data, let str = String(data: data, encoding: .utf8) {
                completion(.success(str))
            } else {
                completion(.failure(NSError(domain: "ClaudeService", code: -1)))
            }
        }
        task.resume()
    }
} 