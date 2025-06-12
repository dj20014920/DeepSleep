import Foundation
import SwiftData

/// Phase 2: 피드백 수집 및 관리 매니저
/// SwiftData를 사용한 사용자 피드백 데이터 관리 시스템
@MainActor
final class FeedbackManager: ObservableObject {
    static let shared = FeedbackManager()
    
    // MARK: - SwiftData 컨텍스트
    private var modelContainer: ModelContainer
    private var modelContext: ModelContext
    
    // MARK: - 현재 세션 추적
    private var currentSession: PresetFeedback?
    private var sessionStartTime: Date?
    
    private init() {
        do {
            // SwiftData 모델 컨테이너 초기화
            self.modelContainer = try ModelContainer(for: PresetFeedback.self)
            self.modelContext = modelContainer.mainContext
            
            print("✅ [FeedbackManager] SwiftData 초기화 성공")
        } catch {
            print("❌ [FeedbackManager] SwiftData 초기화 실패: \(error)")
            fatalError("SwiftData 초기화에 실패했습니다.")
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
            print("⚠️ [FeedbackManager] 기존 세션 강제 종료: \(existingSession.presetName)")
            endCurrentSession(
                finalVolumes: existingSession.recommendedVolumes,
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
        
        // 새로운 세션 생성
        currentSession = PresetFeedback(
            presetName: presetName,
            contextEmotion: contextEmotion,
            contextTime: currentHour,
            recommendedVolumes: volumes,
            recommendedVersions: versions
        )
        
        sessionStartTime = Date()
        
        print("🎯 [FeedbackManager] 새로운 세션 시작: \(presetName) (감정: \(contextEmotion), 시간: \(currentHour)시)")
    }
    
    /// 현재 세션 종료 및 피드백 저장
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
        
        // 세션 정보 업데이트
        session.finalVolumes = finalVolumes
        session.listeningDuration = listeningDuration
        session.wasSaved = wasSaved
        session.userSatisfaction = satisfaction
        
        // 30초 이내 종료 시 스킵으로 간주
        session.wasSkipped = listeningDuration < 30
        
        // SwiftData에 저장
        do {
            modelContext.insert(session)
            try modelContext.save()
            
            print("✅ [FeedbackManager] 세션 저장 완료: \(session.presetName)")
            print("  - 청취 시간: \(String(format: "%.1f", listeningDuration))초")
            print("  - 만족도 점수: \(String(format: "%.2f", session.satisfactionScore))")
            print("  - 저장 여부: \(wasSaved)")
            
        } catch {
            print("❌ [FeedbackManager] 세션 저장 실패: \(error)")
        }
        
        // 세션 초기화
        currentSession = nil
        sessionStartTime = nil
    }
    
    /// 현재 세션에 볼륨 변경 사항 업데이트
    func updateCurrentSessionVolumes(_ volumes: [Float]) {
        guard let session = currentSession else { return }
        
        // 실시간으로 최종 볼륨 업데이트 (사용자가 슬라이더 조정 시)
        session.finalVolumes = volumes
        
        print("🔄 [FeedbackManager] 현재 세션 볼륨 업데이트")
    }
    
    /// 명시적 피드백 설정 (좋아요/싫어요)
    func setExplicitFeedback(satisfaction: Int) {
        guard let session = currentSession else {
            print("⚠️ [FeedbackManager] 활성 세션이 없어 피드백을 설정할 수 없습니다")
            return
        }
        
        session.userSatisfaction = satisfaction
        
        // 즉시 저장 (명시적 피드백은 중요하므로)
        do {
            try modelContext.save()
            print("✅ [FeedbackManager] 명시적 피드백 저장: \(satisfaction == 1 ? "👎 싫어요" : satisfaction == 2 ? "👍 좋아요" : "😐 보통")")
        } catch {
            print("❌ [FeedbackManager] 피드백 저장 실패: \(error)")
        }
    }
    
    // MARK: - 데이터 조회
    
    /// 최근 N개의 피드백 데이터 조회
    func getRecentFeedback(limit: Int = 20) -> [PresetFeedback] {
        #if DEBUG
        print("📋 [FeedbackManager] 최근 \(limit)개 피드백 조회 시작...")
        #endif
        
        let descriptor = FetchDescriptor<PresetFeedback>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let allFeedback = try modelContext.fetch(descriptor)
            let result = Array(allFeedback.prefix(limit))
            
            #if DEBUG
            print("✅ [FeedbackManager] 피드백 조회 완료: \(result.count)개")
            #endif
            
            return result
        } catch {
            print("❌ [FeedbackManager] 피드백 조회 실패: \(error)")
            return []
        }
    }
    
    /// 특정 감정에 대한 피드백 데이터 조회
    func getFeedbackByEmotion(_ emotion: String, limit: Int = 10) -> [PresetFeedback] {
        let descriptor = FetchDescriptor<PresetFeedback>(
            predicate: #Predicate { $0.contextEmotion == emotion },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let feedbacks = try modelContext.fetch(descriptor)
            return Array(feedbacks.prefix(limit))
        } catch {
            print("❌ [FeedbackManager] 감정별 피드백 조회 실패: \(error)")
            return []
        }
    }
    
    /// 특정 시간대의 피드백 데이터 조회
    func getFeedbackByTimeRange(startHour: Int, endHour: Int, limit: Int = 10) -> [PresetFeedback] {
        let descriptor = FetchDescriptor<PresetFeedback>(
            predicate: #Predicate { feedback in
                feedback.contextTime >= startHour && feedback.contextTime <= endHour
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let feedbacks = try modelContext.fetch(descriptor)
            return Array(feedbacks.prefix(limit))
        } catch {
            print("❌ [FeedbackManager] 시간대별 피드백 조회 실패: \(error)")
            return []
        }
    }
    
    /// 사용자 프로필 벡터 생성
    func generateUserProfileVector() -> UserProfileVector {
        let recentFeedback = getRecentFeedback(limit: 50) // 최근 50개 데이터 기반
        return UserProfileVector(feedbackData: recentFeedback)
    }
    
    /// 전체 피드백 데이터 개수
    func getTotalFeedbackCount() -> Int {
        let descriptor = FetchDescriptor<PresetFeedback>()
        
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            print("❌ [FeedbackManager] 피드백 개수 조회 실패: \(error)")
            return 0
        }
    }
    
    /// 평균 만족도 계산
    func getAverageSatisfaction() -> Float {
        let recentFeedback = getRecentFeedback(limit: 20)
        guard !recentFeedback.isEmpty else { return 0.5 }
        
        let totalSatisfaction = recentFeedback.map { $0.satisfactionScore }.reduce(0, +)
        return totalSatisfaction / Float(recentFeedback.count)
    }
    
    // MARK: - 데이터 관리
    
    /// 🧹 오래된 피드백 데이터 자동 정리 (30일 이상 된 데이터)
    func cleanupOldFeedback() {
        let retentionDays = 30 // 30일간 보관 (AI 학습에 충분한 기간)
        let cutoffDate = Date().addingTimeInterval(-Double(retentionDays) * 24 * 60 * 60)
        let descriptor = FetchDescriptor<PresetFeedback>(
            predicate: #Predicate { $0.timestamp < cutoffDate }
        )
        
        do {
            let oldFeedbacks = try modelContext.fetch(descriptor)
            let deletedCount = oldFeedbacks.count
            
            // 삭제 전 용량 계산
            let beforeCount = getTotalFeedbackCount()
            let beforeSizeKB = beforeCount * 3 // 피드백당 약 3KB (볼륨 배열 + 메타데이터)
            
            for feedback in oldFeedbacks {
                modelContext.delete(feedback)
            }
            try modelContext.save()
            
            // 삭제 후 통계
            let afterCount = getTotalFeedbackCount()
            let afterSizeKB = afterCount * 3
            let freedSpaceKB = beforeSizeKB - afterSizeKB
            
            print("""
            🧹 [FeedbackManager] 피드백 데이터 정리 완료
            • 삭제된 데이터: \(deletedCount)개 (\(retentionDays)일 이상)
            • 남은 데이터: \(afterCount)개
            • 절약된 용량: ~\(freedSpaceKB)KB (~\(freedSpaceKB/1024)MB)
            • 현재 예상 용량: ~\(afterSizeKB)KB (~\(afterSizeKB/1024)MB)
            """)
            
        } catch {
            print("❌ [FeedbackManager] 오래된 데이터 정리 실패: \(error)")
        }
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
    
    /// 🗂️ 데이터베이스 최적화
    private func optimizeDatabase() {
        do {
            // SwiftData에서는 명시적 VACUUM이 없으므로 컨텍스트 저장으로 최적화
            try modelContext.save()
            print("💾 [FeedbackManager] 데이터베이스 최적화 완료")
        } catch {
            print("❌ [FeedbackManager] 데이터베이스 최적화 실패: \(error)")
        }
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
    
    /// 모든 피드백 데이터 삭제 (개발/테스트 용도)
    func deleteAllFeedback() {
        let descriptor = FetchDescriptor<PresetFeedback>()
        
        do {
            let allFeedbacks = try modelContext.fetch(descriptor)
            for feedback in allFeedbacks {
                modelContext.delete(feedback)
            }
            try modelContext.save()
            
            print("🗑️ [FeedbackManager] 모든 피드백 데이터 삭제 완료")
        } catch {
            print("❌ [FeedbackManager] 데이터 삭제 실패: \(error)")
        }
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
            
            let feedback = PresetFeedback(
                presetName: preset,
                contextEmotion: emotion,
                contextTime: hour,
                recommendedVolumes: volumeData,
                recommendedVersions: Array(0..<volumeData.count).map { _ in Int.random(in: 1...3) }
            )
            
            // 추가 데이터 설정
            feedback.listeningDuration = TimeInterval(duration)
            feedback.userSatisfaction = satisfaction >= 0.8 ? 2 : (satisfaction >= 0.5 ? 1 : 0)
            
            modelContext.insert(feedback)
        }
        
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ [FeedbackManager] 테스트 데이터 생성 완료: \(testFeedbacks.count)개")
            print("📊 총 피드백 데이터: \(getTotalFeedbackCount())개")
            #endif
        } catch {
            print("❌ [FeedbackManager] 테스트 데이터 저장 실패: \(error)")
        }
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
}

// MARK: - 편의 메서드들
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
        let avgListeningTime = recentFeedback.isEmpty ? 0 : recentFeedback.map { $0.listeningDuration }.reduce(0, +) / Double(recentFeedback.count)
        
        return """
        📊 피드백 통계:
        • 총 세션 수: \(totalCount)개
        • 평균 만족도: \(String(format: "%.1f%%", avgSatisfaction * 100))
        • 평균 청취 시간: \(String(format: "%.1f", avgListeningTime / 60))분
        • 데이터 기간: 최근 30일
        """
    }
} 
