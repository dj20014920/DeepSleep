import Foundation

// MARK: - Sound Repository Protocol
// Note: Entities will be imported from their respective modules in actual implementation

public protocol SoundRepository {
    // MARK: - Sound Operations
    func getAllSounds() async throws -> [Any] // Will be [SoundEntity]
    func getSound(id: UUID) async throws -> Any? // Will be SoundEntity?
    func getSoundsByCategory(category: String) async throws -> [Any] // Will be [SoundEntity]
    func addCustomSound<T: Codable & Identifiable>(_ sound: T) async throws
    func updateSound<T: Codable & Identifiable>(_ sound: T) async throws
    func deleteSound(id: UUID) async throws
    
    // MARK: - Preset Operations
    func savePreset<T: Codable & Identifiable>(_ preset: T) async throws
    func getPreset(id: UUID) async throws -> Any? // Will be SoundPresetEntity?
    func getAllPresets() async throws -> [Any] // Will be [SoundPresetEntity]
    func getDefaultPresets() async throws -> [Any] // Will be [SoundPresetEntity]
    func getUserPresets() async throws -> [Any] // Will be [SoundPresetEntity]
    func updatePreset<T: Codable & Identifiable>(_ preset: T) async throws
    func deletePreset(id: UUID) async throws
    
    // MARK: - Audio Session Operations
    func saveAudioSession<T: Codable & Identifiable>(_ session: T) async throws
    func getAudioSession(id: UUID) async throws -> Any? // Will be AudioSessionEntity?
    func getRecentAudioSessions(limit: Int) async throws -> [Any] // Will be [AudioSessionEntity]
    func getAudioSessionsInDateRange(from: Date, to: Date) async throws -> [Any]
    func updateAudioSession<T: Codable & Identifiable>(_ session: T) async throws
    func deleteAudioSession(id: UUID) async throws
    
    // MARK: - Search and Filter
    func searchSounds(query: String) async throws -> [Any] // Will be [SoundEntity]
    func searchPresets(query: String) async throws -> [Any] // Will be [SoundPresetEntity]
    func getSoundsByTags(_ tags: [String]) async throws -> [Any] // Will be [SoundEntity]
    func getPresetsByTags(_ tags: [String]) async throws -> [Any] // Will be [SoundPresetEntity]
    
    // MARK: - Analytics and Recommendations
    func getMostUsedPresets(limit: Int) async throws -> [Any] // Will be [SoundPresetEntity]
    func getPresetUsageStats() async throws -> [UUID: Int] // presetId -> usage count
    func getTotalListeningTime() async throws -> TimeInterval
    func getListeningTimeByCategory() async throws -> [String: TimeInterval] // Will be [SoundCategory: TimeInterval]
    
    // MARK: - File Management
    func getSoundFileURL(soundId: UUID) async throws -> URL
    func downloadSound(from url: URL, soundId: UUID) async throws
    func deleteSoundFile(soundId: UUID) async throws
    func getCacheSize() async throws -> Int64 // bytes
    func clearCache() async throws
} 