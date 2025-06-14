import Foundation

// MARK: - 토큰 사용량 추적기
class TokenTracker {
    static let shared = TokenTracker()
    private init() {}
    
    // 일일 토큰 사용량 추적
    private var dailyTokenUsage: [String: Int] = [:]
    private var dailyInputTokens: [String: Int] = [:]
    private var dailyOutputTokens: [String: Int] = [:]
    
    // ✅ 디버그 모드 체크
    private var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    // ✅ 개발자 전용 설정 (콘솔에서만 확인 가능)
    private var isDeveloperMode: Bool {
        // 특정 조건에서만 활성화 (예: 개발자 비밀번호 입력 후)
        return UserDefaults.standard.bool(forKey: "DEVELOPER_MODE_ENABLED")
    }
    
    // ✅ API 요금 (Claude 3.5 Haiku 기준, USD)
    private let inputTokenPrice: Double = 0.25 / 1_000_000  // $0.25 per 1M tokens
    private let outputTokenPrice: Double = 1.25 / 1_000_000 // $1.25 per 1M tokens
    private let usdToKrw: Double = 1350.0 // 환율 (대략적)
    
    // MARK: - 메인 토큰 추적 메소드
    /// 토큰 사용량 로깅 및 추적 (디버그 모드에서만 출력)
    func logAndTrack(prompt: String, intent: String, response: String? = nil) {
        let promptTokens = estimateTokens(for: prompt)
        let responseTokens = response.map { estimateTokens(for: $0) } ?? 0
        let totalTokens = promptTokens + responseTokens
        
        // 일일 사용량 누적 (항상 추적 - 내부 데이터용)
        let today = getTodayKey()
        dailyTokenUsage[today, default: 0] += totalTokens
        dailyInputTokens[today, default: 0] += promptTokens
        dailyOutputTokens[today, default: 0] += responseTokens
        
        // ✅ 디버그 모드에서만 로그 출력
        guard isDebugMode else { return }
        
        // 비용 계산
        let todayInputTokens = dailyInputTokens[today, default: 0]
        let todayOutputTokens = dailyOutputTokens[today, default: 0]
        let todayTotalTokens = dailyTokenUsage[today, default: 0]
        
        let inputCostUSD = Double(todayInputTokens) * inputTokenPrice
        let outputCostUSD = Double(todayOutputTokens) * outputTokenPrice
        let totalCostUSD = inputCostUSD + outputCostUSD
        let totalCostKRW = totalCostUSD * usdToKrw
        
        // ✅ 개선된 디버그 로그 출력 (더 명확한 정보)
        print("""
        
        💰 [DEBUG] 토큰 & 비용 분석 [\(intent)]
        ┌─────────────────────────────────────────────────
        │ 📝 이번 요청:
        │   ├─ 프롬프트 토큰: \(promptTokens)개
        │   ├─ 응답 토큰: \(responseTokens)개
        │   └─ 이번 총합: \(totalTokens)개
        │
        │ 📊 오늘 누적 (개인 사용량):
        │   ├─ 입력 토큰: \(todayInputTokens)개 ($\(String(format: "%.4f", inputCostUSD)))
        │   ├─ 출력 토큰: \(todayOutputTokens)개 ($\(String(format: "%.4f", outputCostUSD)))
        │   ├─ 총 토큰: \(todayTotalTokens)개
        │   └─ 예상 비용: $\(String(format: "%.4f", totalCostUSD)) (₩\(Int(totalCostKRW)))
        │
        │ ℹ️  참고: 이 데이터는 개인 사용량만 추적합니다
        │    (다른 사용자 데이터는 포함되지 않음)
        └─────────────────────────────────────────────────
        """)
        
        // 경고 체크 (디버그 모드에서만)
        checkUsageWarning(totalTokens: todayTotalTokens, totalCost: totalCostKRW)
    }
    
    // MARK: - 토큰 추정
    /// 한국어 특성을 고려한 토큰 추정
    func estimateTokens(for text: String) -> Int {
        let korean = CharacterSet(charactersIn: "가-힣")
        let english = CharacterSet.letters
        let numbers = CharacterSet.decimalDigits
        
        var koreanCount = 0
        var englishWordCount = 0
        var otherCount = 0
        
        // 한국어 글자 수 계산
        for char in text {
            if char.unicodeScalars.allSatisfy(korean.contains) {
                koreanCount += 1
            }
        }
        
        // 영어 단어 수 계산
        let englishWords = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { word in
                word.unicodeScalars.allSatisfy { english.contains($0) || numbers.contains($0) }
            }
        englishWordCount = englishWords.count
        
        // 기타 문자 (구두점, 숫자 등)
        otherCount = text.count - koreanCount - englishWords.joined().count
        
        // 토큰 추정 공식 (Claude/GPT 기준 근사치)
        let koreanTokens = Int(Double(koreanCount) * 1.5)  // 한글 1글자 ≈ 1.5토큰
        let englishTokens = Int(Double(englishWordCount) * 0.75)  // 영어 1단어 ≈ 0.75토큰
        let otherTokens = Int(Double(otherCount) * 0.5)  // 구두점 등 ≈ 0.5토큰
        
        return koreanTokens + englishTokens + otherTokens
    }
    
    // MARK: - 경고 및 알림
    /// 사용량 및 비용 경고 (디버그 모드에서만)
    private func checkUsageWarning(totalTokens: Int, totalCost: Double) {
        guard isDebugMode else { return }
        
        // 토큰 경고
        switch totalTokens {
        case 10000...:
            print("🚨🚨 [CRITICAL] 오늘 10,000+ 토큰 사용! 즉시 확인 필요!")
        case 5000...:
            print("🚨 [WARNING] 오늘 5,000+ 토큰 사용! 비용 주의")
        case 2000...:
            print("⚠️ [CAUTION] 오늘 2,000+ 토큰 사용 중")
        case 1000...:
            print("📝 [INFO] 오늘 1,000+ 토큰 사용 중")
        default:
            break
        }
        
        // 비용 경고 (원화 기준)
        switch totalCost {
        case 2000...:
            print("💸💸 [CRITICAL] 오늘 비용 2,000원 이상! (₩\(Int(totalCost)))")
        case 1000...:
            print("💸 [WARNING] 오늘 비용 1,000원 이상! (₩\(Int(totalCost)))")
        case 500...:
            print("💰 [CAUTION] 오늘 비용 500원 이상 (₩\(Int(totalCost)))")
        case 100...:
            print("💵 [INFO] 오늘 비용 100원 이상 (₩\(Int(totalCost)))")
        default:
            break
        }
    }
    
    // MARK: - 사용량 조회 메소드
    /// 오늘 날짜 키
    private func getTodayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    /// 일일 사용량 조회
    func getTodayUsage() -> Int {
        return dailyTokenUsage[getTodayKey(), default: 0]
    }
    
    /// ✅ 오늘 비용 조회 (원화) - 디버그 모드에서만 실제 값 반환
    func getTodayCostKRW() -> Int {
        guard isDebugMode else { return 0 }
        
        let today = getTodayKey()
        let inputTokens = dailyInputTokens[today, default: 0]
        let outputTokens = dailyOutputTokens[today, default: 0]
        
        let inputCostUSD = Double(inputTokens) * inputTokenPrice
        let outputCostUSD = Double(outputTokens) * outputTokenPrice
        let totalCostUSD = inputCostUSD + outputCostUSD
        
        return Int(totalCostUSD * usdToKrw)
    }
    
    /// ✅ 오늘 비용 조회 (달러) - 디버그 모드에서만 실제 값 반환
    func getTodayCostUSD() -> Double {
        guard isDebugMode else { return 0.0 }
        
        let today = getTodayKey()
        let inputTokens = dailyInputTokens[today, default: 0]
        let outputTokens = dailyOutputTokens[today, default: 0]
        
        let inputCostUSD = Double(inputTokens) * inputTokenPrice
        let outputCostUSD = Double(outputTokens) * outputTokenPrice
        
        return inputCostUSD + outputCostUSD
    }
    
    /// ✅ 상세 사용량 정보 - 디버그 모드에서만 실제 값 반환
    func getTodayDetailedUsage() -> (tokens: Int, inputTokens: Int, outputTokens: Int, costKRW: Int, costUSD: Double) {
        let today = getTodayKey()
        let totalTokens = dailyTokenUsage[today, default: 0]
        
        if isDebugMode {
            let inputTokens = dailyInputTokens[today, default: 0]
            let outputTokens = dailyOutputTokens[today, default: 0]
            let costKRW = getTodayCostKRW()
            let costUSD = getTodayCostUSD()
            
            return (totalTokens, inputTokens, outputTokens, costKRW, costUSD)
        } else {
            return (totalTokens, 0, 0, 0, 0.0)
        }
    }
    
    /// ✅ 월간 예상 비용 (현재 사용 패턴 기준) - 디버그 모드에서만
    func getMonthlyProjectedCost() -> (krw: Int, usd: Double) {
        guard isDebugMode else { return (0, 0.0) }
        
        let todayCostKRW = getTodayCostKRW()
        let todayCostUSD = getTodayCostUSD()
        
        // 30일 기준 예상
        let monthlyKRW = todayCostKRW * 30
        let monthlyUSD = todayCostUSD * 30
        
        return (monthlyKRW, monthlyUSD)
    }
    
    // MARK: - 개발자 전용 메소드
    /// ✅ 개발자 모드 토글 (특별한 키 조합으로만 활성화)
    func enableDeveloperMode(password: String) {
        // 실제 앱에서는 더 안전한 방법 사용
        if password == "DEV_MODE_2024" {
            UserDefaults.standard.set(true, forKey: "DEVELOPER_MODE_ENABLED")
            print("🔓 개발자 모드 활성화됨")
        }
    }
    
    func disableDeveloperMode() {
        UserDefaults.standard.set(false, forKey: "DEVELOPER_MODE_ENABLED")
        print("🔒 개발자 모드 비활성화됨")
    }
    
    /// ✅ 강제 로그 출력 (개발자 모드에서만)
    func forceLogCurrentStats() {
        guard isDeveloperMode || isDebugMode else {
            print("❌ 권한 없음: 개발자 모드가 필요합니다")
            return
        }
        
        let today = getTodayKey()
        let stats = getTodayDetailedUsage()
        
        print("""
        
        🔍 [개인 토큰 사용량] 상세 정보
        ┌─────────────────────────────────────────────────
        │ 📅 오늘 날짜: \(today)
        │ 👤 사용자: 개인 (로컬 추적)
        │
        │ 📊 토큰 사용량:
        │   ├─ 총 토큰: \(stats.tokens)개
        │   ├─ 입력 토큰: \(stats.inputTokens)개
        │   └─ 출력 토큰: \(stats.outputTokens)개
        │
        │ 💰 예상 비용:
        │   ├─ 오늘: ₩\(stats.costKRW) ($\(String(format: "%.4f", stats.costUSD)))
        │   └─ 월간 예상: ₩\(getMonthlyProjectedCost().krw) ($\(String(format: "%.2f", getMonthlyProjectedCost().usd)))
        │
        │ ℹ️  참고사항:
        │   • 이 데이터는 현재 기기의 개인 사용량만 포함
        │   • 다른 사용자나 기기의 데이터는 별도 추적
        │   • 실제 API 비용과 다를 수 있음 (추정치)
        └─────────────────────────────────────────────────
        """)
    }
    
    // MARK: - 데이터 관리
    /// 사용량 리셋 (새날)
    func resetIfNewDay() {
        let today = getTodayKey()
        let savedKeys = Array(dailyTokenUsage.keys)
        
        // 7일 이전 데이터 정리
        for key in savedKeys {
            if key != today && shouldDeleteOldData(dateKey: key) {
                dailyTokenUsage.removeValue(forKey: key)
                dailyInputTokens.removeValue(forKey: key)
                dailyOutputTokens.removeValue(forKey: key)
            }
        }
        
        if isDebugMode {
            print("🔄 [DEBUG] 토큰 추적기 새 날 리셋 완료: \(today)")
        }
    }
    
    private func shouldDeleteOldData(dateKey: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateKey) else { return true }
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        
        return daysSince > 7  // 7일 이전 데이터 삭제
    }
    
    /// ✅ 전체 데이터 초기화 (개발자 모드에서만)
    func clearAllData() {
        guard isDeveloperMode || isDebugMode else {
            print("❌ 권한 없음: 개발자 모드가 필요합니다")
            return
        }
        
        dailyTokenUsage.removeAll()
        dailyInputTokens.removeAll()
        dailyOutputTokens.removeAll()
        
        print("🗑️ [DEBUG] 모든 토큰 데이터가 초기화되었습니다")
    }
}
