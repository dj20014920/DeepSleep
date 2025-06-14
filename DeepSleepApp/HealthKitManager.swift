/*
 ⚠️ APPLE DEVELOPER 계정 권한 부족으로 인한 임시 비활성화
 
 HealthKit 기능을 사용하려면 다음이 필요합니다:
 1. Apple Developer Program 가입 ($99/년)
 2. Provisioning Profile에 HealthKit capability 추가
 3. com.apple.developer.healthkit entitlement 권한
 
 현재 학술용 시뮬레이터 테스트를 위해 주석처리됨.
 실제 배포시에는 주석 해제 후 Apple Developer 계정으로 빌드 필요.
 
 기능 설명:
 - 애플워치/아이폰 건강 데이터 연동
 - 심박수, 걸음수, 수면 분석 기반 AI 프리셋 추천
 - 스트레스 레벨 분석을 통한 개인 맞춤 사운드 제안
*/

import Foundation
// import HealthKit  // ⚠️ Apple Developer 계정 필요로 임시 비활성화

/// 간단한 애플워치 건강 데이터 기반 AI 추천 시스템
/// ⚠️ Apple Developer 계정 권한 부족으로 임시 비활성화
/// 복잡한 실시간 연동 대신 하루 데이터를 읽어와서 프리셋 추천
class HealthKitManager: NSObject {
    static let shared = HealthKitManager()
    
    // ⚠️ Apple Developer 계정 필요로 임시 비활성화
    // private let healthStore = HKHealthStore()
    private var isAuthorized = false
    
    // MARK: - 권한 요청 (필수 데이터만) - ⚠️ 임시 비활성화
    
    /*
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]
    */
    
    /// 권한 요청 (간단한 버전) - ⚠️ Apple Developer 계정 필요로 임시 비활성화
    func requestPermission(completion: @escaping (Bool) -> Void) {
        // ⚠️ Apple Developer 계정 권한 부족으로 임시 비활성화
        print("⚠️ [HealthKit] Apple Developer 계정 권한 부족으로 비활성화됨")
        print("📚 학술용 시뮬레이터 데모에서는 가상 데이터로 대체됩니다.")
        completion(false)
        
        /* 원본 코드 - Apple Developer 계정 필요
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ [HealthKit] HealthKit 사용 불가")
            completion(false)
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [HealthKit] 권한 요청 실패: \(error.localizedDescription)")
                } else {
                    print("✅ [HealthKit] 권한 요청 \(success ? "성공" : "실패")")
                }
                self?.isAuthorized = success
                completion(success)
            }
        }
        */
    }
    
    // MARK: - 간단한 스트레스 분석 모델 (Apple Developer 계정 무관)
    
    struct DailyWellness {
        let date: Date
        let stressLevel: StressLevel
        let activityLevel: ActivityLevel
        let sleepQuality: SleepQuality
        let recommendedPreset: String
        let explanation: String
        
        enum StressLevel: String, CaseIterable {
            case low = "낮음"
            case moderate = "보통" 
            case high = "높음"
            
            var emoji: String {
                switch self {
                case .low: return "😌"
                case .moderate: return "😐"
                case .high: return "😰"
                }
            }
        }
        
        enum ActivityLevel: String, CaseIterable {
            case sedentary = "비활동적"
            case active = "활동적"
            case veryActive = "매우 활동적"
        }
        
        enum SleepQuality: String, CaseIterable {
            case poor = "부족"
            case fair = "보통"
            case good = "양호"
        }
    }
    
    // MARK: - 메인 분석 함수 - ⚠️ 가상 데이터로 대체
    
    /// 오늘의 건강 데이터를 분석하여 프리셋 추천
    /// ⚠️ Apple Developer 계정 권한 부족으로 가상 데이터 사용
    func analyzeTodayAndRecommend(completion: @escaping (DailyWellness?) -> Void) {
        print("⚠️ [HealthKit] Apple Developer 계정 권한 부족으로 가상 데이터 생성")
        
        // 시뮬레이터용 가상 건강 데이터 생성
        let mockWellness = generateMockWellness()
        completion(mockWellness)
        
        /* 원본 코드 - Apple Developer 계정 필요
        guard isAuthorized else {
            print("❌ [HealthKit] 권한이 없습니다")
            completion(nil)
            return
        }
        
        let group = DispatchGroup()
        
        var heartRateAvg: Double = 0
        var stepCount: Double = 0
        var caloriesBurned: Double = 0
        var sleepHours: Double = 0
        
        // 1. 심박수 평균
        group.enter()
        fetchTodayHeartRate { avgHR in
            heartRateAvg = avgHR
            group.leave()
        }
        
        // 2. 걸음 수
        group.enter()
        fetchTodaySteps { steps in
            stepCount = steps
            group.leave()
        }
        
        // 3. 소모 칼로리
        group.enter()
        fetchTodayCalories { calories in
            caloriesBurned = calories
            group.leave()
        }
        
        // 4. 어제 수면 시간
        group.enter()
        fetchLastNightSleep { sleep in
            sleepHours = sleep
            group.leave()
        }
        
        group.notify(queue: .main) {
            let wellness = self.analyzeWellness(
                heartRate: heartRateAvg,
                steps: stepCount,
                calories: caloriesBurned,
                sleep: sleepHours
            )
            completion(wellness)
        }
        */
    }
    
    // MARK: - ⚠️ 시뮬레이터용 가상 데이터 생성 (Apple Developer 계정 무관)
    
    private func generateMockWellness() -> DailyWellness {
        // 현실적인 가상 건강 데이터 생성
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isEvening = currentHour >= 18
        
        let mockHeartRate = Double.random(in: 65...85)
        let mockSteps = Double.random(in: 3000...12000)
        let mockCalories = Double.random(in: 200...800)
        let mockSleep = Double.random(in: 5.5...8.5)
        
        print("📱 [Mock HealthKit] 가상 건강 데이터:")
        print("   심박수: \(Int(mockHeartRate))bpm")
        print("   걸음수: \(Int(mockSteps))걸음")
        print("   칼로리: \(Int(mockCalories))kcal")
        print("   수면: \(String(format: "%.1f", mockSleep))시간")
        
        return analyzeWellness(
            heartRate: mockHeartRate,
            steps: mockSteps,
            calories: mockCalories,
            sleep: mockSleep
        )
    }
    
    // MARK: - 데이터 수집 메서드들 - ⚠️ Apple Developer 계정 필요로 주석처리
    
    /*
    private func fetchTodayHeartRate(completion: @escaping (Double) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            
            guard error == nil,
                  let heartRateSamples = samples as? [HKQuantitySample],
                  !heartRateSamples.isEmpty else {
                print("❌ [HealthKit] 심박수 데이터 없음")
                completion(0)
                return
            }
            
            let heartRates = heartRateSamples.map {
                $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }
            
            let average = heartRates.reduce(0, +) / Double(heartRates.count)
            print("📈 [HealthKit] 평균 심박수: \(Int(average))bpm")
            completion(average)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchTodaySteps(completion: @escaping (Double) -> Void) {
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        fetchTodayTotal(for: stepsType, unit: .count()) { steps in
            print("🚶‍♂️ [HealthKit] 오늘 걸음 수: \(Int(steps))걸음")
            completion(steps)
        }
    }
    
    private func fetchTodayCalories(completion: @escaping (Double) -> Void) {
        let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        fetchTodayTotal(for: caloriesType, unit: .kilocalorie()) { calories in
            print("🔥 [HealthKit] 오늘 소모 칼로리: \(Int(calories))kcal")
            completion(calories)
        }
    }
    
    private func fetchTodayTotal(for quantityType: HKQuantityType, unit: HKUnit, completion: @escaping (Double) -> Void) {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            
            guard error == nil, let result = result, let sum = result.sumQuantity() else {
                print("❌ [HealthKit] 데이터 수집 실패")
                completion(0)
                return
            }
            
            let value = sum.doubleValue(for: unit)
            completion(value)
        }
        
        healthStore.execute(query)
    }
    
    private func fetchLastNightSleep(completion: @escaping (Double) -> Void) {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let now = Date()
        
        // 어제 밤부터 오늘 아침까지 (21:00 ~ 09:00)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let startTime = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: yesterday)!
        let endTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { _, samples, error in
            
            guard error == nil,
                  let sleepSamples = samples as? [HKCategorySample] else {
                print("❌ [HealthKit] 수면 데이터 없음")
                completion(0)
                return
            }
            
            // 실제 수면 시간만 계산 (inBed 제외)
            let actualSleep = sleepSamples.filter {
                $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
            }
            
            let totalSleepTime = actualSleep.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            
            let sleepHours = totalSleepTime / 3600.0 // 초를 시간으로 변환
            print("😴 [HealthKit] 어제 수면 시간: \(String(format: "%.1f", sleepHours))시간")
            completion(sleepHours)
        }
        
        healthStore.execute(query)
    }
    */
    
    // MARK: - 분석 로직 (Apple Developer 계정 무관)
    
    private func analyzeWellness(heartRate: Double, steps: Double, calories: Double, sleep: Double) -> DailyWellness {
        let currentDate = Date()
        
        // 스트레스 레벨 분석
        let stressLevel = calculateStressLevel(heartRate: heartRate, sleep: sleep)
        
        // 활동 레벨 분석
        let activityLevel = calculateActivityLevel(steps: steps, calories: calories)
        
        // 수면 품질 분석
        let sleepQuality = calculateSleepQuality(hours: sleep)
        
        // 프리셋 추천
        let (preset, explanation) = recommendPreset(
            stress: stressLevel,
            activity: activityLevel,
            sleep: sleepQuality
        )
        
        return DailyWellness(
            date: currentDate,
            stressLevel: stressLevel,
            activityLevel: activityLevel,
            sleepQuality: sleepQuality,
            recommendedPreset: preset,
            explanation: explanation
        )
    }
    
    private func calculateStressLevel(heartRate: Double, sleep: Double) -> DailyWellness.StressLevel {
        var stressScore = 0
        
        // 심박수 기반 (안정시 심박수 대비)
        if heartRate > 80 { stressScore += 2 }
        else if heartRate > 70 { stressScore += 1 }
        
        // 수면 부족 기반
        if sleep < 6 { stressScore += 2 }
        else if sleep < 7 { stressScore += 1 }
        
        switch stressScore {
        case 0...1: return .low
        case 2...3: return .moderate
        default: return .high
        }
    }
    
    private func calculateActivityLevel(steps: Double, calories: Double) -> DailyWellness.ActivityLevel {
        let stepScore = min(steps / 3000, 3) // 3000걸음당 1점, 최대 3점
        let calorieScore = min(calories / 200, 3) // 200칼로리당 1점, 최대 3점
        
        let totalScore = (stepScore + calorieScore) / 2
        
        if totalScore >= 2.0 { return .veryActive }
        else if totalScore >= 1.0 { return .active }
        else { return .sedentary }
    }
    
    private func calculateSleepQuality(hours: Double) -> DailyWellness.SleepQuality {
        switch hours {
        case 7.5...: return .good
        case 6.5..<7.5: return .fair
        default: return .poor
        }
    }
    
    private func recommendPreset(
        stress: DailyWellness.StressLevel,
        activity: DailyWellness.ActivityLevel,
        sleep: DailyWellness.SleepQuality
    ) -> (preset: String, explanation: String) {
        
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isEvening = currentHour >= 18
        
        switch (stress, sleep, isEvening) {
        case (.high, _, true):
            return ("🌊 자연의 소리", "스트레스가 높아 자연 소리로 마음을 진정시켜보세요")
        case (.high, _, false):
            return ("🌧️ 빗소리 집중", "스트레스 완화를 위한 빗소리 집중 모드")
        case (_, .poor, true):
            return ("🌙 깊은 수면", "수면 부족 회복을 위한 깊은 휴식 모드")
        case (.low, .good, _):
            return ("⌨️ 작업 집중", "컨디션이 좋으니 집중 작업에 도전해보세요")
        default:
            return ("🐱 평화로운 오후", "편안한 휴식을 위한 기본 모드")
        }
    }
}

// MARK: - 사용법 예시

/*
// 1. 권한 요청
HealthKitManager.shared.requestPermission { granted in
    if granted {
        print("HealthKit 사용 가능")
    } else {
        print("HealthKit 권한 거부됨")
    }
}

// 2. 분석 및 추천
HealthKitManager.shared.analyzeTodayAndRecommend { wellness in
    guard let wellness = wellness else {
        print("분석 실패")
        return
    }
    
    print("📊 건강 분석 결과:")
    print("스트레스: \(wellness.stressLevel.emoji) \(wellness.stressLevel.rawValue)")
    print("활동량: \(wellness.activityLevel.rawValue)")
    print("수면: \(wellness.sleepQuality.rawValue)")
    print("추천 프리셋: \(wellness.recommendedPreset)")
    print("설명: \(wellness.explanation)")
}

이 방식의 장점:
✅ 애플워치 전용 앱 불필요
✅ 복잡한 실시간 연동 없음
✅ 간단한 권한 요청
✅ 실용적인 AI 추천
✅ 배터리 부담 최소화
✅ 개발 시간 단축
*/ 