import Foundation

// MARK: - Emotion Repository Implementation
final class EmotionRepositoryImpl: EmotionRepository {
    
    // MARK: - Emotion Operations
    func getAllEmotions() async throws -> [Any] {
        return EmotionType.allCases.map { $0.toEntity() }
    }
    
    func getEmotion(id: UUID) async throws -> Any? {
        // Simple implementation - in a real app this would query a database
        return EmotionType.allCases.first?.toEntity()
    }
    
    func getEmotionsByCategory(category: String) async throws -> [Any] {
        return EmotionType.allCases
            .filter { $0.category.rawValue == category }
            .map { $0.toEntity() }
    }
    
    func createCustomEmotion<T>(_ emotion: T) async throws where T : Codable, T : Identifiable {
        // Implementation would save to database
        print("Creating custom emotion: \(emotion)")
    }
    
    func updateEmotion<T>(_ emotion: T) async throws where T : Codable, T : Identifiable {
        // Implementation would update in database
        print("Updating emotion: \(emotion)")
    }
    
    func deleteEmotion(id: UUID) async throws {
        // Implementation would delete from database
        print("Deleting emotion with id: \(id)")
    }
    
    // MARK: - Emotional Profile Operations
    func saveEmotionalProfile<T>(_ profile: T) async throws where T : Codable, T : Identifiable {
        print("Saving emotional profile: \(profile)")
    }
    
    func getEmotionalProfile(id: UUID) async throws -> Any? {
        return nil // Implementation would query database
    }
    
    func getEmotionalProfiles(limit: Int?) async throws -> [Any] {
        return [] // Implementation would query database
    }
    
    func getEmotionalProfilesInDateRange(from: Date, to: Date) async throws -> [Any] {
        return [] // Implementation would query database
    }
    
    func updateEmotionalProfile<T>(_ profile: T) async throws where T : Codable, T : Identifiable {
        print("Updating emotional profile: \(profile)")
    }
    
    func deleteEmotionalProfile(id: UUID) async throws {
        print("Deleting emotional profile with id: \(id)")
    }
    
    // MARK: - Diary Entry Operations
    func saveDiaryEntry<T>(_ entry: T) async throws where T : Codable, T : Identifiable {
        print("Saving diary entry: \(entry)")
    }
    
    func getDiaryEntry(id: UUID) async throws -> Any? {
        return nil // Implementation would query database
    }
    
    func getDiaryEntries(limit: Int?) async throws -> [Any] {
        return [] // Implementation would query database
    }
    
    func getDiaryEntriesForEmotion(emotionId: UUID) async throws -> [Any] {
        return [] // Implementation would query database
    }
    
    func getDiaryEntriesInDateRange(from: Date, to: Date) async throws -> [Any] {
        return [] // Implementation would query database
    }
    
    func updateDiaryEntry<T>(_ entry: T) async throws where T : Codable, T : Identifiable {
        print("Updating diary entry: \(entry)")
    }
    
    func deleteDiaryEntry(id: UUID) async throws {
        print("Deleting diary entry with id: \(id)")
    }
    
    // MARK: - Search and Analytics
    func searchDiaryEntries(query: String) async throws -> [Any] {
        return [] // Implementation would search database
    }
    
    func getEmotionFrequency(in dateRange: ClosedRange<Date>) async throws -> [String: Int] {
        return [:] // Implementation would analyze database
    }
    
    func getEmotionalTrends(days: Int) async throws -> [Date: Float] {
        return [:] // Implementation would analyze database
    }
    
    func getMostCommonEmotions(limit: Int) async throws -> [Any] {
        return Array(EmotionType.allCases.prefix(limit)).map { $0.toEntity() }
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    func analyzeEmotion(from text: String) async throws -> EmotionAnalysisResult {
        // Simple keyword-based emotion analysis for now
        // In a real implementation, this would use ML models or external APIs
        
        let lowercasedText = text.lowercased()
        let emotions = EmotionType.allCases
        
        var scores: [EmotionType: Double] = [:]
        
        // Simple keyword matching
        for emotion in emotions {
            let keywords = getKeywords(for: emotion)
            let score = keywords.reduce(0.0) { result, keyword in
                return result + (lowercasedText.contains(keyword) ? 1.0 : 0.0)
            }
            scores[emotion] = score / Double(keywords.count)
        }
        
        // Find dominant emotion
        let dominantEmotion = scores.max { $0.value < $1.value }?.key ?? .neutral
        let sentimentScore = calculateSentimentScore(from: lowercasedText)
        let confidence = scores[dominantEmotion] ?? 0.0
        
        return EmotionAnalysisResult(
            dominantEmotion: dominantEmotion,
            sentimentScore: sentimentScore,
            confidence: min(confidence + 0.5, 1.0) // Add base confidence
        )
    }
    
    private func getKeywords(for emotion: EmotionType) -> [String] {
        switch emotion {
        case .happy:
            return ["기쁘", "행복", "즐거", "좋", "웃", "반가", "만족", "신나"]
        case .sad:
            return ["슬프", "우울", "눈물", "힘들", "괴로", "아픔", "상처", "아쉬"]
        case .anxious:
            return ["불안", "걱정", "초조", "긴장", "떨림", "두려", "염려", "조급"]
        case .stressed:
            return ["스트레스", "압박", "부담", "피곤", "지침", "짜증", "답답", "막막"]
        case .excited:
            return ["신나", "들뜨", "흥미", "기대", "설레", "즐거", "활기", "에너지"]
        case .tired:
            return ["피곤", "지침", "졸림", "무기력", "귀찮", "나른", "힘없", "축 늘어"]
        case .angry:
            return ["화나", "짜증", "분노", "열받", "속상", "빡침", "억울", "약 올라"]
        case .calm:
            return ["평온", "차분", "고요", "안정", "편안", "여유", "침착", "평화"]
        case .nostalgic:
            return ["그리", "그립", "추억", "옛날", "예전", "기억", "회상", "향수"]
        case .grateful:
            return ["감사", "고마", "고맙", "감동", "은혜", "고귀", "축복", "다행"]
        case .confused:
            return ["혼란", "헷갈", "모르겠", "막막", "애매", "복잡", "어려", "이해"]
        case .neutral:
            return ["그냥", "보통", "평범", "무난", "일반", "그저", "특별"]
        // 통합된 EmotionType case들
        case .peaceful:
            return ["평화", "고요", "평온", "조용", "고즈넉", "정적", "안온", "평안"]
        case .tense:
            return ["긴장", "경직", "뻣뻣", "불편", "딱딱", "어색", "부자연", "어김"]
        case .focused:
            return ["집중", "몰입", "열중", "전념", "정신", "주의", "채중", "응시"]
        case .energetic:
            return ["활기", "에너지", "활력", "역동", "생동", "생기", "발랄", "활발"]
        }
    }
    
    private func calculateSentimentScore(from text: String) -> Double {
        let positiveWords = ["좋", "행복", "기쁘", "만족", "감사", "훌륭", "멋진", "완벽"]
        let negativeWords = ["나쁘", "슬프", "화나", "짜증", "힘들", "괴로", "답답", "우울"]
        
        let positiveCount = positiveWords.reduce(0) { count, word in
            return count + (text.lowercased().contains(word) ? 1 : 0)
        }
        
        let negativeCount = negativeWords.reduce(0) { count, word in
            return count + (text.lowercased().contains(word) ? 1 : 0)
        }
        
        let total = positiveCount + negativeCount
        if total == 0 { return 0.5 } // Neutral
        
        return Double(positiveCount) / Double(total)
    }
}

// MARK: - Analysis Result
struct EmotionAnalysisResult {
    let dominantEmotion: EmotionType
    let sentimentScore: Double
    let confidence: Double
} 
