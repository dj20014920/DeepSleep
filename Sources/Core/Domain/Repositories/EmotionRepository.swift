import Foundation

// MARK: - Emotion Repository Protocol
// Note: Entities will be imported from their respective modules in actual implementation

public protocol EmotionRepository {
    // MARK: - Emotion Operations
    func getAllEmotions() async throws -> [Any] // Will be [EmotionEntity]
    func getEmotion(id: UUID) async throws -> Any? // Will be EmotionEntity?
    func getEmotionsByCategory(category: String) async throws -> [Any] // Will be [EmotionEntity]
    func createCustomEmotion<T: Codable & Identifiable>(_ emotion: T) async throws
    func updateEmotion<T: Codable & Identifiable>(_ emotion: T) async throws
    func deleteEmotion(id: UUID) async throws
    
    // MARK: - Emotional Profile Operations
    func saveEmotionalProfile<T: Codable & Identifiable>(_ profile: T) async throws
    func getEmotionalProfile(id: UUID) async throws -> Any? // Will be EmotionalProfileEntity?
    func getEmotionalProfiles(limit: Int?) async throws -> [Any] // Will be [EmotionalProfileEntity]
    func getEmotionalProfilesInDateRange(from: Date, to: Date) async throws -> [Any]
    func updateEmotionalProfile<T: Codable & Identifiable>(_ profile: T) async throws
    func deleteEmotionalProfile(id: UUID) async throws
    
    // MARK: - Diary Entry Operations
    func saveDiaryEntry<T: Codable & Identifiable>(_ entry: T) async throws
    func getDiaryEntry(id: UUID) async throws -> Any? // Will be EmotionDiaryEntryEntity?
    func getDiaryEntries(limit: Int?) async throws -> [Any] // Will be [EmotionDiaryEntryEntity]
    func getDiaryEntriesForEmotion(emotionId: UUID) async throws -> [Any]
    func getDiaryEntriesInDateRange(from: Date, to: Date) async throws -> [Any]
    func updateDiaryEntry<T: Codable & Identifiable>(_ entry: T) async throws
    func deleteDiaryEntry(id: UUID) async throws
    
    // MARK: - Search and Analytics
    func searchDiaryEntries(query: String) async throws -> [Any]
    func getEmotionFrequency(in dateRange: ClosedRange<Date>) async throws -> [String: Int] // Will be [EmotionCategory: Int]
    func getEmotionalTrends(days: Int) async throws -> [Date: Float] // intensity over time
    func getMostCommonEmotions(limit: Int) async throws -> [Any] // Will be [EmotionEntity]
} 