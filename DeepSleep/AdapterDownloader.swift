import Foundation

/// LoRA Adapter 파일 다운로드/검증 매니저
final class AdapterDownloader {
    static let shared = AdapterDownloader()
    private init() {}
    
    /// Adapter 파일 다운로드
    func downloadAdapter(from url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, _, error in
            if let error = error {
                completion(.failure(error))
            } else if let localURL = localURL {
                completion(.success(localURL))
            } else {
                completion(.failure(NSError(domain: "AdapterDownloader", code: -1)))
            }
        }
        task.resume()
    }
} 