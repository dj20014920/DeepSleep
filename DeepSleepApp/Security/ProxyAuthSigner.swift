import Foundation
import CryptoKit

/// 프록시 인증/등록 공통 유틸(SSoT)
/// - DRY: UnifiedAIServiceImpl, ProxyTierReporter 등에서 공통 사용
enum ProxyAuthSigner {
    /// HMAC-SHA256 hex 서명
    static func hmacSHA256Hex(message: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    /// 서명 원문 구성
    /// - Parameters:
    ///   - ts: epoch milliseconds 문자열
    ///   - uid: 기기 식별자
    ///   - tier: free|pro|max
    ///   - nonce: Nonce 사용 시 포함(소문자 hex)
    static func composeSigningMessage(ts: String, uid: String, tier: String, nonce: String?) -> String {
        if let n = nonce, !n.isEmpty { return "\(ts):\(uid):\(tier):\(n)" }
        return "\(ts):\(uid):\(tier)"
    }
}

/// 프록시 장치 등록(enroll) 및 시크릿 로딩
enum ProxyAuthClient {
    /// 키체인에서 시크릿을 로드하거나, 없으면 enroll 후 저장
    static func loadSecretOrEnroll(uid: String, proxyBase: URL) async throws -> String {
        if let s = ProxySecretStore.load(for: uid) { return s }
        let secret = try await enrollSecret(uid: uid, proxyBase: proxyBase)
        ProxySecretStore.save(secret, for: uid)
        return secret
    }

    /// /v1/enroll 호출로 장치 시크릿 발급
    private static func enrollSecret(uid: String, proxyBase: URL) async throws -> String {
        var req = URLRequest(url: proxyBase.appendingPathComponent("v1/enroll"))
        req.httpMethod = "POST"
        // 네이티브 앱에서도 일관되게 동일 Origin 사용
        req.setValue("https://emozleep.app", forHTTPHeaderField: "Origin")
        req.setValue(uid, forHTTPHeaderField: "X-Emozleep-UID")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "ProxyAuthClient", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Enroll failed"])
        }
        struct EnrollResp: Decodable { let secret: String }
        let obj = try JSONDecoder().decode(EnrollResp.self, from: data)
        return obj.secret
    }
}

