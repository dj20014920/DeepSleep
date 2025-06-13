import Foundation

/// LoRA Adapter 파일 관리 매니저 (실제 구현)
final class LoRAAdapterManager {
    static let shared = LoRAAdapterManager()
    private let cache = LRUCache<String, Data>(capacity: 3)
    private init() {}
    
    /// adapter 파일 로드
    func loadAdapter(named name: String) -> Data? {
        if let cached = cache.get(name) { return cached }
        let url = Self.adapterURL(for: name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        cache.set(name, value: data)
        return data
    }
    /// adapter 파일 저장
    func saveAdapter(named name: String, data: Data) {
        let url = Self.adapterURL(for: name)
        try? data.write(to: url)
        cache.set(name, value: data)
    }
    /// adapter 파일 삭제
    func deleteAdapter(named name: String) {
        let url = Self.adapterURL(for: name)
        try? FileManager.default.removeItem(at: url)
        cache.remove(name)
    }
    /// adapter 파일 네트워크 다운로드
    func downloadAdapter(from url: URL, named name: String, completion: @escaping (Bool) -> Void) {
        AdapterDownloader.shared.downloadAdapter(from: url) { result in
            switch result {
            case .success(let localURL):
                if let data = try? Data(contentsOf: localURL) {
                    self.saveAdapter(named: name, data: data)
                    completion(true)
                } else {
                    completion(false)
                }
            case .failure:
                completion(false)
            }
        }
    }
    static func adapterURL(for name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("\(name).adapter")
    }
} 