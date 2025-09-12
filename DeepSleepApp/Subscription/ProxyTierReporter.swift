import Foundation
import StoreKit

enum ProxyTierReporter {
    static func report(passiveFrom transaction: Transaction) async {
        guard EnvironmentConfig.shared.useProxy,
              let proxyBase = URL(string: EnvironmentConfig.shared.proxyBaseURL)
        else { return }
        let url = proxyBase.appendingPathComponent("v1/subscription/report")

        // 공통 헤더 값
        let uid: String = await MainActor.run { UIDevice.current.identifierForVendor?.uuidString ?? "unknown" }
        let tier = tierFor(productId: transaction.productID)
        let ts = String(Int64(Date().timeIntervalSince1970 * 1000))
        let useNonce = EnvironmentConfig.shared.proxyAuthUseNonce
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

        // per-device secret 확보(없으면 enroll)
        let secret: String
        do {
            secret = try await ProxyAuthClient.loadSecretOrEnroll(uid: uid, proxyBase: proxyBase)
        } catch {
            #if DEBUG
            let fallback = EnvironmentConfig.shared.clientProxyHmacSecret
            guard !fallback.isEmpty else { return }
            secret = fallback
            #else
            return
            #endif
        }
        let signingMessage = ProxyAuthSigner.composeSigningMessage(ts: ts, uid: uid, tier: tier, nonce: useNonce ? nonce : nil)
        let sig = ProxyAuthSigner.hmacSHA256Hex(message: signingMessage, secret: secret)

        var body: [String: Any] = [
            "productId": transaction.productID
        ]
        let purchaseAt = transaction.purchaseDate
        body["purchaseDateMs"] = Int64(purchaseAt.timeIntervalSince1970 * 1000)
        if let exp = transaction.expirationDate {
            body["expiresAtMs"] = Int64(exp.timeIntervalSince1970 * 1000)
        }
        // 휴리스틱: 구매~만료가 약 7일(5~8일) 범위면 트라이얼로 추정
        if let e = transaction.expirationDate {
            let days = e.timeIntervalSince(purchaseAt) / (24 * 3600)
            let isTrial = (days >= 5.0 && days <= 8.0)
            body["trialHeuristic"] = isTrial
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(ProxyAuthConfig.origin, forHTTPHeaderField: "Origin")
        req.setValue(uid, forHTTPHeaderField: "X-Emozleep-UID")
        req.setValue(tier, forHTTPHeaderField: "X-Emozleep-Tier")
        req.setValue(ts, forHTTPHeaderField: "X-Emozleep-Timestamp")
        if useNonce { req.setValue(nonce, forHTTPHeaderField: "X-Emozleep-Nonce") }
        req.setValue(sig, forHTTPHeaderField: "X-Emozleep-Sig")
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
