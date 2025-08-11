import Foundation
#if canImport(SwiftData)
import SwiftData
#endif
import CoreData
import SwiftUI
import Combine

// MARK: - Core Data Entity for Preset Feedback
@objc(PresetFeedbackCoreData)
public class PresetFeedbackCoreData: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var timestamp: Date
    @NSManaged public var presetName: String
    @NSManaged public var contextEmotion: String
    @NSManaged public var contextTime: Int16
    @NSManaged public var recommendedVolumes: [Float]
    @NSManaged public var recommendedVersions: [Int]
    @NSManaged public var finalVolumes: [Float]
    @NSManaged public var listeningDuration: TimeInterval
    @NSManaged public var wasSkipped: Bool
    @NSManaged public var wasSaved: Bool
    @NSManaged public var userSatisfaction: Int16
}

public extension PresetFeedbackCoreData {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PresetFeedbackCoreData> {
        return NSFetchRequest<PresetFeedbackCoreData>(entityName: "PresetFeedbackCoreData")
    }
}

/// Phase 2: 피드백 수집 및 관리 매니저
/// SwiftData를 사용한 사용자 피드백 데이터 관리 시스템
@available(iOS 17.0, *)
@MainActor
final class FeedbackManager: ObservableObject {
    public static let shared = FeedbackManager()
    
    // MARK: - SwiftData (iOS 17+)
    // private var modelContainer: ModelContainer?
    // private var modelContext: ModelContext?
    
    // MARK: - CoreData (iOS 16 이하)
    private var persistentContainer: NSPersistentContainer?
    private var coreDataContext: NSManagedObjectContext? {
        persistentContainer?.viewContext
    }
    
    // MARK: - 현재 세션 추적
    @Published var currentSession: PresetFeedback?
    private var sessionStartTime: Date?
    
    // MARK: - 데이터 저장 (임시 UserDefaults 구현)
    private let userDefaults = UserDefaults.standard
    private var feedbackData: [PresetFeedback] = []
    
    private init() {
        // SwiftData initialization for iOS 17+
        // modelContainer = try? ModelContainer(for: PresetFeedback.self)
        loadFeedbackData()
    }
    
    private func loadFeedbackData() {
        // UserDefaults에서 피드백 데이터 로드 (임시)
        if let data = userDefaults.data(forKey: "feedback_data"),
           let decoded = try? JSONDecoder().decode([PresetFeedbackWrapper].self, from: data) {
            self.feedbackData = decoded.map { $0.feedback }
        }
    }
    
    private func saveFeedbackData() {
        // UserDefaults에 피드백 데이터 저장 (임시)
        let wrappers = feedbackData.map { PresetFeedbackWrapper(feedback: $0) }
        if let encoded = try? JSONEncoder().encode(wrappers) {
            userDefaults.set(encoded, forKey: "feedback_data")
        }
    }
    
    // MARK: - 세션 관리
    
    /// 새로운 추천 세션 시작
    func startSession(
        presetName: String,
        recommendation: Any, // EnhancedRecommendationResponse - IDE 호환성 문제로 임시 Any 사용
        contextEmotion: String,
        contextTime: Int? = nil
    ) {
        // 기존 세션이 있으면 강제 종료
        if let existingSession = currentSession {
            print("⚠️ [FeedbackManager] 기존 세션 강제 종료: \(existingSession.presetName ?? "-")")
            endCurrentSession(
                finalVolumes: existingSession.finalVolumes ?? [],
                listeningDuration: Date().timeIntervalSince(sessionStartTime ?? Date()),
                wasSaved: false,
                satisfaction: 0
            )
        }
        
        let currentHour = contextTime ?? Calendar.current.component(.hour, from: Date())
        
        // 런타임 값 추출 (타입 체크 우회)
        let volumes: [Float]
        let versions: [Int]
        
        // Mirror를 사용한 안전한 값 추출
        let mirror = Mirror(reflecting: recommendation)
        if let volumesValue = mirror.children.first(where: { $0.label == "volumes" })?.value as? [Float],
           let versionsValue = mirror.children.first(where: { $0.label == "selectedVersions" })?.value as? [Int] {
            volumes = volumesValue
            versions = versionsValue
        } else {
            // 기본값 사용
            volumes = Array(repeating: 50.0, count: 13)
            versions = Array(repeating: 0, count: 13)
            print("⚠️ [FeedbackManager] 추천 데이터 파싱 실패, 기본값 사용")
        }
        
        // 새로운 세션 생성 - UserDefaults 기반 임시 구현
        let sessionId = UUID().uuidString
        let quantitativeData: [String: Any] = [
            "presetName": presetName,
            "contextEmotion": contextEmotion,
            "contextTime": currentHour,
            "recommendedVolumes": volumes,
            "recommendedVersions": versions
        ]
        
        let qualitative = PresetFeedback.QualitativeFeedback(
            freeText: "", 
            moodAfter: "알 수 없음", 
            tags: []
        )
        
        let context = PresetFeedback.Context(
            usageDuration: 0,
            intentionalStop: false,
            repeatUsageIntent: false,
            recommendationIntent: true
        )
        
        currentSession = PresetFeedback(
            presetId: presetName,
            sessionId: sessionId,
            timestamp: Date(),
            quantitative: quantitativeData,
            qualitative: qualitative,
            context: context,
            deviceContext: nil,
            environmentContext: nil,
            userEmotion: nil
        )
        
        sessionStartTime = Date()
        
        print("🎯 [FeedbackManager] 새로운 세션 시작: \(presetName) (감정: \(contextEmotion), 시간: \(currentHour)시)")
    }
    
    /// Phase 2: SessionManager 통합 - 현재 세션 종료 및 피드백 저장
    func endCurrentSession(
        finalVolumes: [Float],
        listeningDuration: TimeInterval,
        wasSaved: Bool,
        satisfaction: Int = 0
    ) {
        guard let session = currentSession else {
            print("⚠️ [FeedbackManager] 종료할 세션이 없습니다")
            return
        }
        
        // 세션 정보 업데이트 - quantitative 데이터에 추가
        var updatedQuantitative = session.quantitative
        updatedQuantitative["finalVolumes"] = finalVolumes
        updatedQuantitative["listeningDuration"] = listeningDuration
        updatedQuantitative["wasSaved"] = wasSaved
        updatedQuantitative["userSatisfaction"] = satisfaction
        updatedQuantitative["wasSkipped"] = listeningDuration < 30
        
        let updatedContext = PresetFeedback.Context(
            usageDuration: listeningDuration,
            intentionalStop: true,
            repeatUsageIntent: wasSaved,
            recommendationIntent: session.context.recommendationIntent
        )
        
        // 업데이트된 세션 생성
        currentSession = PresetFeedback(
            presetId: session.presetId,
            sessionId: session.sessionId,
            timestamp: session.timestamp,
            quantitative: updatedQuantitative,
            qualitative: session.qualitative,
            context: updatedContext,
            deviceContext: session.deviceContext,
            environmentContext: session.environmentContext,
            userEmotion: session.userEmotion
        )
        
        // 🎯 Phase 2: SessionManager를 통한 통합 저장
        let unifiedSession = SessionManager.shared.getCurrentOrCreateSession()
        SessionManager.shared.addFeedbackData(to: unifiedSession.id, feedback: currentSession!)
        
        // 🎯 기존 UserDefaults 저장도 유지 (호환성)
        feedbackData.append(currentSession!)
        saveFeedbackData()
        
        // UserBehaviorAnalytics에 알림 (비동기 처리)
        notifyAnalytics(currentSession!)
            
        print("✅ [FeedbackManager] Phase 2: SessionManager 통합 저장 완료: \(currentSession!.presetName ?? "-")")
        print("  - 청취 시간: \(String(format: "%.1f", currentSession!.listeningDuration ?? 0))초")
        print("  - 저장 여부: \(currentSession!.wasSaved?.description ?? "-")")
        
        // 세션 초기화
        currentSession = nil
        sessionStartTime = nil
    }
    
    /// 현재 세션에 볼륨 변경 사항 업데이트
    func updateCurrentSessionVolumes(_ volumes: [Float]) {
        guard let session = currentSession else { return }
        
        // 실시간으로 최종 볼륨 업데이트 (사용자가 슬라이더 조정 시)
        var updatedQuantitative = session.quantitative
        updatedQuantitative["finalVolumes"] = volumes
        
        currentSession = PresetFeedback(
            presetId: session.presetId,
            sessionId: session.sessionId,
            timestamp: session.timestamp,
            quantitative: updatedQuantitative,
            qualitative: session.qualitative,
            context: session.context,
            deviceContext: session.deviceContext,
            environmentContext: session.environmentContext,
            userEmotion: session.userEmotion
        )
        
        print("🔄 [FeedbackManager] 현재 세션 볼륨 업데이트")
    }
    
    /// 명시적 피드백 설정 (좋아요/싫어요)
    func setExplicitFeedback(satisfaction: Int) {
        guard let session = currentSession else {
            print("⚠️ [FeedbackManager] 활성 세션이 없어 피드백을 설정할 수 없습니다")
            return
        }
        
        var updatedQuantitative = session.quantitative
        updatedQuantitative["userSatisfaction"] = satisfaction
        
        currentSession = PresetFeedback(
            presetId: session.presetId,
            sessionId: session.sessionId,
            timestamp: session.timestamp,
            quantitative: updatedQuantitative,
            qualitative: session.qualitative,
            context: session.context,
            deviceContext: session.deviceContext,
            environmentContext: session.environmentContext,
            userEmotion: session.userEmotion
        )
        
        // 즉시 저장 (명시적 피드백은 중요하므로) - UserDefaults 임시 구현
        saveFeedbackData()
            print("✅ [FeedbackManager] 명시적 피드백 저장: \(satisfaction == 1 ? "👎 싫어요" : satisfaction == 2 ? "👍 좋아요" : "😐 보통")")
    }
    
    // MARK: - 데이터 조회
    
    /// 최근 세션 데이터 조회 (UserBehaviorAnalytics 연동용)
    func loadRecentSessions(limit: Int = 20) -> [PresetFeedback] {
        // feedbackData를 시간 역순으로 정렬하여 최근 데이터부터 반환
        let sortedFeedback = feedbackData.sorted { $0.timestamp > $1.timestamp }
        return Array(sortedFeedback.prefix(limit))
    }
    
    /// 최근 N개의 피드백 데이터 조회 - UserDefaults 기반 임시 구현
    func getRecentFeedback(limit: Int = 20) -> [PresetFeedback] {
        #if DEBUG
        print("📋 [FeedbackManager] 최근 \(limit)개 피드백 조회 시작...")
        #endif
        
        // UserDefaults에서 저장된 피드백 데이터 로드
        let result = Array(feedbackData.prefix(limit))
            
            #if DEBUG
            print("✅ [FeedbackManager] 피드백 조회 완료: \(result.count)개")
            #endif
            
            return result
    }
    
    /// 특정 감정에 대한 피드백 데이터 조회 - UserDefaults 기반 임시 구현
    func getFeedbackByEmotion(_ emotion: String, limit: Int = 10) -> [PresetFeedback] {
        let filtered = feedbackData.filter { $0.contextEmotion == emotion }
        return Array(filtered.prefix(limit))
    }
    
    /// 특정 시간대의 피드백 데이터 조회 - UserDefaults 기반 임시 구현
    func getFeedbackByTimeRange(startHour: Int, endHour: Int, limit: Int = 10) -> [PresetFeedback] {
        let filtered = feedbackData.filter { feedback in
            guard let contextTime = feedback.contextTime else { return false }
            return contextTime >= startHour && contextTime <= endHour
        }
        return Array(filtered.prefix(limit))
    }
    
    /// 사용자 프로필 벡터 생성
    func generateUserProfileVector() -> UserProfileVector {
        let recentFeedback = getRecentFeedback(limit: 50) // 최근 50개 데이터 기반
        return UserProfileVector(feedbackData: recentFeedback)
    }
    
    /// 전체 피드백 데이터 개수 - UserDefaults 기반 임시 구현
    func getTotalFeedbackCount() -> Int {
        return feedbackData.count
    }
    
    /// 평균 만족도 계산
    func getAverageSatisfaction() -> Float {
        let recentFeedback = getRecentFeedback(limit: 20)
        guard !recentFeedback.isEmpty else { return 0.5 }
        
        let totalSatisfaction = recentFeedback.map { $0.satisfactionScore }.reduce(0, +)
        return totalSatisfaction / Float(recentFeedback.count)
    }
    
    // MARK: - 데이터 관리
    
    /// UserBehaviorAnalytics에 피드백 데이터 알림
    private func notifyAnalytics(_ feedback: PresetFeedback) {
        // 비동기로 UserBehaviorAnalytics에 통지
        DispatchQueue.global(qos: .background).async {
            // UserBehaviorAnalytics는 FeedbackManager의 loadRecentSessions를 호출하여
            // 필요한 데이터를 가져가므로, 여기서는 패턴 분석만 트리거
            UserBehaviorAnalytics.shared.triggerPatternAnalysis()
            
            print("🔔 [FeedbackManager] UserBehaviorAnalytics에 패턴 분석 트리거")
        }
    }
    
    /// 🧹 오래된 피드백 데이터 자동 정리 (30일 이상 된 데이터) - UserDefaults 기반 임시 구현
    func cleanupOldFeedback() {
        let retentionDays = 30 // 30일간 보관 (AI 학습에 충분한 기간)
        let cutoffDate = Date().addingTimeInterval(-Double(retentionDays) * 24 * 60 * 60)
        
        let beforeCount = feedbackData.count
        feedbackData = feedbackData.filter { $0.timestamp >= cutoffDate }
        let afterCount = feedbackData.count
        let deletedCount = beforeCount - afterCount
        
        // UserDefaults에 저장
        saveFeedbackData()
        
            let beforeSizeKB = beforeCount * 3 // 피드백당 약 3KB (볼륨 배열 + 메타데이터)
            let afterSizeKB = afterCount * 3
            let freedSpaceKB = beforeSizeKB - afterSizeKB
            
            print("""
            🧹 [FeedbackManager] 피드백 데이터 정리 완료
            • 삭제된 데이터: \(deletedCount)개 (\(retentionDays)일 이상)
            • 남은 데이터: \(afterCount)개
            • 절약된 용량: ~\(freedSpaceKB)KB (~\(freedSpaceKB/1024)MB)
            • 현재 예상 용량: ~\(afterSizeKB)KB (~\(afterSizeKB/1024)MB)
            """)
    }
    
    /// 🔧 앱 시작 시 자동 정리 (백그라운드에서 실행)
    func performStartupCleanup() async {
        await performAsyncCleanup()
    }
    
    @MainActor
    private func performAsyncCleanup() async {
        // 1. 오래된 피드백 정리
        cleanupOldFeedback()
        
        // 2. 데이터베이스 최적화 (SQLite VACUUM 상당)
        optimizeDatabase()
        
        // 3. 통계 정보 로깅
        logStorageStatistics()
    }
    
    /// 📊 저장소 사용량 통계
    func getStorageStatistics() -> (feedbackCount: Int, estimatedSizeKB: Int, retentionDays: Int) {
        let count = getTotalFeedbackCount()
        let sizeKB = count * 3 // 피드백당 약 3KB 추정 (볼륨 배열, 메타데이터, 명시적 피드백 포함)
        return (feedbackCount: count, estimatedSizeKB: sizeKB, retentionDays: 30)
    }
    
    /// 🗂️ 데이터베이스 최적화 - UserDefaults 기반 임시 구현
    private func optimizeDatabase() {
        saveFeedbackData()
            print("💾 [FeedbackManager] 데이터베이스 최적화 완료")
    }
    
    /// 📈 저장소 통계 로깅
    private func logStorageStatistics() {
        let stats = getStorageStatistics()
        print("""
        📊 [Storage Statistics]
        • 피드백 데이터: \(stats.feedbackCount)개
        • 예상 용량: ~\(stats.estimatedSizeKB)KB (~\(stats.estimatedSizeKB/1024)MB)
        • 보관 기간: \(stats.retentionDays)일
        • 자동 정리: 매일 실행
        """)
    }
    
    /// 모든 피드백 데이터 삭제 (개발/테스트 용도) - UserDefaults 기반 임시 구현
    func deleteAllFeedback() {
        feedbackData.removeAll()
        saveFeedbackData()
            print("🗑️ [FeedbackManager] 모든 피드백 데이터 삭제 완료")
    }
    
    // MARK: - ✅ 테스트 피드백 데이터 생성
    func createTestFeedbackData() {
        #if DEBUG
        print("🧪 [FeedbackManager] 테스트 피드백 데이터 생성 시작...")
        #endif
        
        let testFeedbacks: [(preset: String, emotion: String, satisfaction: Float, duration: Int, dayOffset: Int)] = [
            ("비 내리는 밤", "불안", 0.8, 1800, 1),
            ("숲속 새소리", "스트레스", 0.9, 2400, 2),
            ("파도 소리", "우울", 0.7, 1200, 3),
            ("피아노 연주", "긴장", 0.85, 2100, 4),
            ("백색소음", "불면", 0.75, 3600, 5),
            ("명상 음악", "스트레스", 0.95, 1800, 6),
            ("자연 소리", "우울", 0.8, 2700, 7),
            ("클래식 음악", "불안", 0.9, 2100, 8),
            ("바람 소리", "긴장", 0.7, 1500, 9),
            ("심박동 소리", "불면", 0.8, 2400, 10)
        ]
        
        for (preset, emotion, satisfaction, duration, dayOffset) in testFeedbacks {
            let timestamp = Date().addingTimeInterval(-Double(dayOffset * 86400)) // dayOffset일 전
            let hour = Calendar.current.component(.hour, from: timestamp)
            
            // 볼륨 데이터 생성 (실제적인 패턴)
            let sampleCount = duration / 10 // 10초마다 샘플
            let volumeData = (0..<sampleCount).map { i in
                let baseVolume = Float.random(in: 0.3...0.7)
                let timeDecay = 1.0 - (Float(i) / Float(sampleCount)) * 0.3 // 시간이 지날수록 살짝 감소
                return baseVolume * timeDecay
            }
            
            let quantitativeData: [String: Any] = [
                "presetName": preset,
                "contextEmotion": emotion,
                "contextTime": hour,
                "recommendedVolumes": volumeData,
                "recommendedVersions": Array(0..<volumeData.count).map { _ in Int.random(in: 1...3) },
                "listeningDuration": TimeInterval(duration),
                "userSatisfaction": satisfaction >= 0.8 ? 2 : (satisfaction >= 0.5 ? 1 : 0)
            ]
            
            let qualitative = PresetFeedback.QualitativeFeedback(
                freeText: "테스트 데이터", 
                moodAfter: "좋음", 
                tags: []
            )
            
            let context = PresetFeedback.Context(
                usageDuration: TimeInterval(duration),
                intentionalStop: true,
                repeatUsageIntent: satisfaction >= 0.8,
                recommendationIntent: true
            )
            
            let feedback = PresetFeedback(
                presetId: preset,
                sessionId: UUID().uuidString,
                timestamp: timestamp,
                quantitative: quantitativeData,
                qualitative: qualitative,
                context: context,
                deviceContext: nil,
                environmentContext: nil,
                userEmotion: nil
            )
            
            feedbackData.append(feedback)
        }
        
        saveFeedbackData()
            #if DEBUG
            print("✅ [FeedbackManager] 테스트 데이터 생성 완료: \(testFeedbacks.count)개")
            print("📊 총 피드백 데이터: \(getTotalFeedbackCount())개")
            #endif
    }
    
    // MARK: - ✅ 피드백 상태 출력
    func printFeedbackStatus() {
        #if DEBUG
        let totalCount = getTotalFeedbackCount()
        let recentFeedback = getRecentFeedback(limit: 20)
        let avgSatisfaction = getAverageSatisfaction()
        let stats = getStorageStatistics()
        
        print("=== 📊 피드백 상태 보고서 ===")
        print("""
        📋 피드백 데이터 현황:
        • 총 피드백 수: \(totalCount)개
        • 최근 데이터: \(recentFeedback.count)개
        • 평균 만족도: \(String(format: "%.1f", avgSatisfaction * 100))%
        • 예상 용량: ~\(stats.estimatedSizeKB)KB
        
        🎯 최근 피드백 요약:
        """)
        
        let emotionCounts = Dictionary(grouping: recentFeedback, by: { $0.contextEmotion })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        let presetCounts = Dictionary(grouping: recentFeedback, by: { $0.presetName })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
        
        print("• 주요 감정: \(emotionCounts.prefix(3).map { "\($0.key)(\($0.value)회)" }.joined(separator: ", "))")
        print("• 인기 프리셋: \(presetCounts.prefix(3).map { "\($0.key)(\($0.value)회)" }.joined(separator: ", "))")
        
        if let latest = recentFeedback.first {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d HH:mm"
            print("• 최근 피드백: \(formatter.string(from: latest.timestamp)) - \(latest.presetName)")
        }
        
        print("===============================")
        #endif
    }
    
    /// PresetFeedback 업데이트 - UserDefaults 기반 임시 구현
    func updateFeedback(id: UUID, updateBlock: (Any) -> Void) {
        // 임시로 주석 처리 - 복잡한 업데이트 로직은 나중에 구현
        print("⚠️ [FeedbackManager] updateFeedback - 임시 구현 필요")
    }

    /// PresetFeedback 삭제 - UserDefaults 기반 임시 구현
    func deleteFeedback(id: UUID) {
        // 임시로 주석 처리 - ID 기반 삭제는 나중에 구현
        print("⚠️ [FeedbackManager] deleteFeedback - 임시 구현 필요")
    }
}

// MARK: - 편의 메서드들
@available(iOS 17.0, *)
extension FeedbackManager {
    /// 현재 세션이 활성화되어 있는지 확인
    var hasActiveSession: Bool {
        return currentSession != nil
    }
    
    /// 현재 세션의 프리셋 이름
    var currentPresetName: String? {
        return currentSession?.presetName
    }
    
    /// 🎯 현재 세션 프리셋 이름 가져오기 (메서드)
    func getCurrentSessionPresetName() -> String? {
        return currentSession?.presetName
    }
    
    /// 현재 세션의 진행 시간
    var currentSessionDuration: TimeInterval {
        guard let startTime = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    /// 통계 정보 요약
    var statisticsSummary: String {
        let totalCount = getTotalFeedbackCount()
        let avgSatisfaction = getAverageSatisfaction()
        let recentFeedback = getRecentFeedback(limit: 10)
        let avgListeningTime = recentFeedback.isEmpty ? 0 : recentFeedback.compactMap { $0.listeningDuration }.reduce(0, +) / Double(recentFeedback.count)
        
        return """
        📊 피드백 통계:
        • 총 세션 수: \(totalCount)개
        • 평균 만족도: \(String(format: "%.1f%%", avgSatisfaction * 100))
        • 평균 청취 시간: \(String(format: "%.1f", avgListeningTime / 60))분
        • 데이터 기간: 최근 30일
        """
    }
}

// MARK: - CRUD (공통 인터페이스)
@available(iOS 17.0, *)
extension FeedbackManager {
    /// PresetFeedback 저장
    func saveFeedback(
        presetName: String,
        contextEmotion: String,
        contextTime: Int,
        recommendedVolumes: [Float],
        recommendedVersions: [Int],
        finalVolumes: [Float],
        listeningDuration: TimeInterval,
        wasSkipped: Bool,
        wasSaved: Bool,
        userSatisfaction: Int
    ) {
        // UserDefaults 기반 임시 구현
        let quantitativeData: [String: Any] = [
            "presetName": presetName,
            "contextEmotion": contextEmotion,
            "contextTime": contextTime,
            "recommendedVolumes": recommendedVolumes,
            "recommendedVersions": recommendedVersions,
            "finalVolumes": finalVolumes,
            "listeningDuration": listeningDuration,
            "wasSkipped": wasSkipped,
            "wasSaved": wasSaved,
            "userSatisfaction": userSatisfaction
        ]
        
        let qualitative = PresetFeedback.QualitativeFeedback(
            freeText: "", 
            moodAfter: "알 수 없음", 
            tags: []
        )
        
        let context = PresetFeedback.Context(
            usageDuration: listeningDuration,
            intentionalStop: !wasSkipped,
            repeatUsageIntent: wasSaved,
            recommendationIntent: true
        )
        
            let feedback = PresetFeedback(
            presetId: presetName,
            sessionId: UUID().uuidString,
            timestamp: Date(),
            quantitative: quantitativeData,
            qualitative: qualitative,
            context: context,
            deviceContext: nil,
            environmentContext: nil,
            userEmotion: nil
        )
        
        feedbackData.append(feedback)
        saveFeedbackData()
    }
    
    /// PresetFeedback 전체 조회 - UserDefaults 기반 임시 구현
    func fetchAllFeedback() -> [Any] {
        return feedbackData
    }
    // (필요시 update/delete 등 추가)
}

// MARK: - Wrapper for JSON encoding/decoding
private struct PresetFeedbackWrapper: Codable {
    let feedback: PresetFeedback
    
    init(feedback: PresetFeedback) {
        self.feedback = feedback
    }
    
    enum CodingKeys: String, CodingKey {
        case presetId, sessionId, timestamp, quantitative, qualitative, context
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let presetId = try container.decode(String.self, forKey: .presetId)
        let sessionId = try container.decode(String.self, forKey: .sessionId)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let quantitative = try container.decode([String: AnyCodableValue].self, forKey: .quantitative)
        
        // 간단한 더미 값들로 초기화
        let qualitative = PresetFeedback.QualitativeFeedback(freeText: "", moodAfter: "", tags: [])
        let context = PresetFeedback.Context(usageDuration: 0, intentionalStop: false, repeatUsageIntent: false, recommendationIntent: false)
        
        // quantitative 데이터를 [String: Any]로 변환
        let quantitativeDict = quantitative.mapValues { $0.value }
        
        self.feedback = PresetFeedback(
            presetId: presetId,
            sessionId: sessionId,
            timestamp: timestamp,
            quantitative: quantitativeDict,
            qualitative: qualitative,
            context: context,
            deviceContext: nil,
            environmentContext: nil,
            userEmotion: nil
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(feedback.presetId, forKey: .presetId)
        try container.encode(feedback.sessionId, forKey: .sessionId)
        try container.encode(feedback.timestamp, forKey: .timestamp)
        
        // quantitative 데이터를 Codable로 변환
        let codableQuantitative = feedback.quantitative.compactMapValues { AnyCodableValue($0) }
        try container.encode(codableQuantitative, forKey: .quantitative)
    }
}

// MARK: - Helper for Any value encoding
private struct AnyCodableValue: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodableValue].self) {
            value = arrayValue.map { $0.value }
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let floatValue as Float:
            try container.encode(floatValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            let codableArray = arrayValue.compactMap { AnyCodableValue($0) }
            try container.encode(codableArray)
        default:
            try container.encode(String(describing: value))
        }
    }
} 
