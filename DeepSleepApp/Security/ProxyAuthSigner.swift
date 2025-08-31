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
        // 서버 로직과 정확히 일치: nonce가 nil이 아니면 포함
        if let n = nonce {
            return "\(ts):\(uid):\(tier):\(n)"
        }
        return "\(ts):\(uid):\(tier)"
    }
}

/// 프록시 장치 등록(enroll) 및 시크릿 로딩
enum ProxyAuthClient {
    /// 키체인에서 시크릿을 로드하거나, 없으면 enroll 후 저장
    static func loadSecretOrEnroll(uid: String, proxyBase: URL) async throws -> String {
        print("🔍 [ProxyAuthClient] 시크릿 로드 시도 (uid: \(uid))")
        
        #if DEBUG
        // DEBUG 모드: 강제 재발급 테스트 (401 인증 실패 해결용)
        let forceReEnroll = true
        if forceReEnroll {
            print("🔧 [ProxyAuthClient] DEBUG: 강제 재발급 모드 활성화")
            // 기존 시크릿 삭제
            ProxySecretStore.delete(for: uid)
            print("🗑️ [ProxyAuthClient] DEBUG: 기존 시크릿 삭제 완료")
        }
        #endif
        
        // 기본 정책: 키체인에 있으면 재사용, 없으면 enroll
        if let s = ProxySecretStore.load(for: uid) {
            print("✅ [ProxyAuthClient] 키체인에서 시크릿 로드 성공")
            return s
        }
        
        print("⚠️ [ProxyAuthClient] 키체인에 시크릿 없음, 새로 발급 시도...")
        let secret = try await enrollSecret(uid: uid, proxyBase: proxyBase)
        
        ProxySecretStore.save(secret, for: uid)
        print("✅ [ProxyAuthClient] 새 시크릿 발급 및 저장 완료")
        
        return secret
    }

    /// /v1/enroll 호출로 장치 시크릿 발급
    private static func enrollSecret(uid: String, proxyBase: URL) async throws -> String {
        print("🚀 [ProxyAuthClient] Enroll 요청 시작: \(proxyBase.absoluteString)/v1/enroll")
        
        var req = URLRequest(url: proxyBase.appendingPathComponent("v1/enroll"))
        req.httpMethod = "POST"
        // 네이티브 앱에서도 일관되게 동일 Origin 사용
        req.setValue(ProxyAuthConfig.origin, forHTTPHeaderField: "Origin")
        req.setValue(uid, forHTTPHeaderField: "X-Emozleep-UID")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        
        guard let http = resp as? HTTPURLResponse else {
            print("❌ [ProxyAuthClient] Enroll 실패: 응답이 HTTP가 아님")
            throw NSError(domain: "ProxyAuthClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard (200...299).contains(http.statusCode) else {
            print("❌ [ProxyAuthClient] Enroll 실패: HTTP \(http.statusCode)")
            throw NSError(domain: "ProxyAuthClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Enroll failed with status: \(http.statusCode)"])
        }
        
        struct EnrollResp: Decodable { let secret: String }
        let obj = try JSONDecoder().decode(EnrollResp.self, from: data)
        print("✅ [ProxyAuthClient] Enroll 성공, 시크릿 수신")
        return obj.secret
    }
}

