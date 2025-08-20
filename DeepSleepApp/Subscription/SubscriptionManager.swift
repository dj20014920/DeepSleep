#if DEBUG
import Foundation

/// 구독 관리자 (Mock)
/// 실제 IAP 구현 전까지 사용할 테스트용 구독 관리자
/// TODO: 실제 StoreKit2 구현으로 교체 필요(Release에서는 제외)
public final class SubscriptionManager {
    
    // MARK: - Singleton
    
    public static let shared = SubscriptionManager()
    
    // MARK: - Properties
    
    /// 구독 상태 (테스트를 위해 UserDefaults에 저장)
    private var _isSubscribed: Bool {
        get {
            UserDefaults.standard.bool(forKey: "mock_subscription_status")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "mock_subscription_status")
            updateMemoryManagerTier()
            NotificationCenter.default.post(
                name: .subscriptionStatusChanged,
                object: nil,
                userInfo: ["isSubscribed": newValue]
            )
        }
    }
    
    /// 현재 구독 상태
    public var isSubscribed: Bool {
        return _isSubscribed
    }
    
    /// 구독 티어
    public var currentTier: MemoryTier {
        return isSubscribed ? .premium : .free
    }
    
    /// 구독 만료일 (Mock)
    public var expirationDate: Date? {
        guard isSubscribed else { return nil }
        // 테스트를 위해 30일 후로 설정
        return Calendar.current.date(byAdding: .day, value: 30, to: Date())
    }
    
    /// 무료 체험 사용 가능 여부
    public var canStartFreeTrial: Bool {
        // 테스트를 위해 구독하지 않은 경우에만 가능
        return !isSubscribed && !hasUsedFreeTrial
    }
    
    /// 무료 체험 사용 이력
    private var hasUsedFreeTrial: Bool {
        get {
            UserDefaults.standard.bool(forKey: "has_used_free_trial")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "has_used_free_trial")
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // 앱 시작 시 구독 상태 확인 및 MemoryManager 티어 설정
        updateMemoryManagerTier()
    }
    
    // MARK: - Public Methods
    
    /// 구독 상태 확인 (실제 구현에서는 StoreKit 호출)
    public func checkSubscriptionStatus(completion: @escaping (Bool) -> Void) {
        // Mock: 비동기 시뮬레이션
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            completion(self.isSubscribed)
        }
    }
    
    /// 구독 구매 (Mock)
    public func purchaseSubscription(completion: @escaping (Result<Bool, Error>) -> Void) {
        // Mock: 구매 시뮬레이션
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // 테스트를 위해 80% 확률로 성공
            let success = Int.random(in: 1...10) <= 8
            
            if success {
                self._isSubscribed = true
                print("✅ [SubscriptionManager] 구독 구매 성공 (Mock)")
                completion(.success(true))
            } else {
                let error = NSError(
                    domain: "SubscriptionManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "구매 실패 (Mock)"]
                )
                print("❌ [SubscriptionManager] 구독 구매 실패 (Mock)")
                completion(.failure(error))
            }
        }
    }
    
    /// 구독 복원 (Mock)
    public func restoreSubscription(completion: @escaping (Result<Bool, Error>) -> Void) {
        // Mock: 복원 시뮬레이션
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // 테스트를 위해 이전에 구독했었다고 가정
            let hadSubscription = UserDefaults.standard.bool(forKey: "had_subscription_before")
            
            if hadSubscription {
                self._isSubscribed = true
                print("✅ [SubscriptionManager] 구독 복원 성공 (Mock)")
                completion(.success(true))
            } else {
                print("ℹ️ [SubscriptionManager] 복원할 구독 없음 (Mock)")
                completion(.success(false))
            }
        }
    }
    
    /// 무료 체험 시작 (Mock)
    public func startFreeTrial(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard canStartFreeTrial else {
            let error = NSError(
                domain: "SubscriptionManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "무료 체험을 사용할 수 없습니다"]
            )
            completion(.failure(error))
            return
        }
        
        // Mock: 무료 체험 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            self._isSubscribed = true
            self.hasUsedFreeTrial = true
            print("✅ [SubscriptionManager] 무료 체험 시작 (Mock)")
            completion(.success(true))
        }
    }
    
    /// 구독 취소 (Mock)
    public func cancelSubscription(completion: @escaping (Result<Bool, Error>) -> Void) {
        // Mock: 취소 시뮬레이션
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            self._isSubscribed = false
            print("✅ [SubscriptionManager] 구독 취소 (Mock)")
            completion(.success(true))
        }
    }
    
    // MARK: - Test Methods (개발용)
    
    #if DEBUG
    /// 테스트용: 구독 상태 직접 설정
    public func setSubscriptionStatus(_ isSubscribed: Bool) {
        self._isSubscribed = isSubscribed
        print("🔧 [SubscriptionManager] 구독 상태 수동 설정: \(isSubscribed)")
    }
    
    /// 테스트용: 모든 구독 데이터 초기화
    public func resetAllData() {
        UserDefaults.standard.removeObject(forKey: "mock_subscription_status")
        UserDefaults.standard.removeObject(forKey: "has_used_free_trial")
        UserDefaults.standard.removeObject(forKey: "had_subscription_before")
        updateMemoryManagerTier()
        print("🔧 [SubscriptionManager] 모든 구독 데이터 초기화")
    }
    #endif
    
    // MARK: - Private Methods
    
    /// MemoryManager 티어 업데이트
    private func updateMemoryManagerTier() {
        let tier: MemoryTier = isSubscribed ? .premium : .free
        MemoryManager.shared.setTier(tier)
        print("📝 [SubscriptionManager] MemoryManager 티어 설정: \(tier)")
    }
}

// MARK: - Notifications

#endif
