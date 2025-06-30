import Foundation

/// Represents a single correction or definition taught by the user.
/// This structure is `Codable` to allow for easy saving/loading to/from a file.
struct UserDefinedRule: Codable, Hashable, Identifiable {
    let id: UUID
    let userInput: String
    let correctedMeaning: String
    let timestamp: Date
    
    init(userInput: String, correctedMeaning: String) {
        self.id = UUID()
        self.userInput = userInput
        self.correctedMeaning = correctedMeaning
        self.timestamp = Date()
    }
}

/// Manages the persistence (saving and loading) of user-defined rules.
/// This class acts as a centralized repository for all custom rules created by the user.
class UserRulesManager {
    
    static let shared = UserRulesManager()
    
    private var userRules: [UserDefinedRule] = []
    private let fileName = "user_defined_rules.json"
    
    private var fileURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent(fileName)
    }
    
    private init() {
        loadRules()
    }
    
    /// Adds a new rule and saves the updated list to the disk.
    /// - Parameters:
    ///   - userInput: The original text the user entered.
    ///   - correctedMeaning: The correct interpretation provided by the user.
    func addRule(userInput: String, correctedMeaning: String) {
        // To prevent duplicates, remove any old rule for the same user input.
        userRules.removeAll { $0.userInput.lowercased() == userInput.lowercased() }
        
        let newRule = UserDefinedRule(userInput: userInput, correctedMeaning: correctedMeaning)
        userRules.append(newRule)
        saveRules()
        
        // TODO: Integrate with FeedbackManager to queue this for upload.
        print("[UserRulesManager] Added new rule: '\(userInput)' -> '\(correctedMeaning)'. Total rules: \(userRules.count)")
    }
    
    /// Retrieves all currently stored user rules.
    /// - Returns: An array of `UserDefinedRule`.
    func getAllRules() -> [UserDefinedRule] {
        return userRules
    }
    
    /// Provides a simple dictionary representation for quick lookups in the processing pipeline.
    /// - Returns: A dictionary mapping user input to its corrected meaning.
    func getRulesAsDictionary() -> [String: String] {
        return Dictionary(uniqueKeysWithValues: userRules.map { ($0.userInput, $0.correctedMeaning) })
    }
    
    /// Saves the current list of rules to a JSON file on the disk.
    private func saveRules() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(userRules)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[UserRules-Error] Failed to save rules: \(error.localizedDescription)")
        }
    }
    
    /// Loads rules from the JSON file on the disk.
    private func loadRules() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[UserRulesManager] No rule file found. Starting fresh.")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            self.userRules = try decoder.decode([UserDefinedRule].self, from: data)
            print("[UserRulesManager] Successfully loaded \(userRules.count) user rules.")
        } catch {
            print("[User-RulesError] Failed to load rules: \(error.localizedDescription)")
        }
    }
} 