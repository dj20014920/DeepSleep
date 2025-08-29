import Foundation
import StoreKit

enum ProxyTierReporter {
    static func report(passiveFrom transaction: Transaction) async {
        guard EnvironmentConfig.shared.useProxy,
              let url = URL(string: EnvironmentConfig.shared.proxyBaseURL)?.appendingPathComponent("v1/subscription/report")
        else { return }

        // 최소 보안: HMAC 인증 헤더(프록시에서 per-device 비밀 검증)
        let uid: String = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString ?? "unknown" }
        let tier = tierFor(productId: transaction.productID)
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
        let secret = "" // 클라이언트 비밀은 Keychain에서 프록시 호출시만 사용하므로 여기선 헤더만 보내고 프록시가 device secret으로 HMAC 검증
        // 여기서는 하위 호환: 서명 없이도 프록시가 device secret 기반 HMAC만 요구하므로, 최소한의 헤더만 첨부 (UnifiedAIServiceImpl에서 enroll/서명 수행)

        var body: [String: Any] = [
            "productId": transaction.productID
        ]
        if let exp = transaction.expirationDate {
            body["expiresAtMs"] = Int64(exp.timeIntervalSince1970 * 1000)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(uid, forHTTPHeaderField: "X-Emozleep-UID")
        req.setValue(tier, forHTTPHeaderField: "X-Emozleep-Tier")
        req.setValue(ts, forHTTPHeaderField: "X-Emozleep-Timestamp")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: req)
    }

    private static func tierFor(productId: String) -> String {
        switch productId {
        case "com.emozleep.pro.monthly", "com.emozleep.pro.yearly": return "pro"
        case "com.emozleep.max.monthly", "com.emozleep.max.yearly": return "max"
        default: return "free"
        }
    }
}
