// ChatService.swift
import Foundation

public enum ChatServiceError: Error {
    case network(Error)
    case decoding(String)
 }

// 백엔드 JSON 스키마
struct RecommendationResponse: Codable {
    let empathy: String
    let fortune: String
    let presetName: String
    let volumes: [Float]
    let prompt: String
 }

class ChatService {
    // ▶ 여러분이 배포한 Flask 서버 주소
    private static let endpoint = URL(string: "http://YOUR_SERVER_IP:5000/recommend")!

    /// 사용자가 입력한 텍스트(일기 or 이모지)로 AI 분석 요청
    static func requestRecommendation(
        userText: String,
        completion: @escaping (Result<RecommendationResponse, ChatServiceError>) -> Void
    ) {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["text": userText]
        do {
            req.httpBody = try JSONEncoder().encode(body)
        } catch {
            return completion(.failure(.decoding(error.localizedDescription)))
        }

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                return completion(.failure(.network(err)))
            }
            guard let data = data else {
                return completion(.failure(.decoding("No data")))
            }
            do {
                let rec = try JSONDecoder().decode(RecommendationResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(rec))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.decoding(error.localizedDescription)))
                }
            }
        }.resume()
    }
}
