import Foundation

/// **Stage 0: User Rules Applier**
/// Applies custom rules defined by the user. This runs first to ensure user overrides are respected.
struct UserRulesApplierStep: PreProcessingStep {
    private let rules: [String: String]

    init() {
        // Access the shared manager to get the latest rules
        self.rules = UserRulesManager.shared.getRulesAsDictionary()
    }

    func process(input: String) async -> String {
        guard !rules.isEmpty else { return input }
        
        var processed = input
        
        // Sort rules by key length (descending) to match longer phrases first.
        // e.g., "오늘 날씨" should be matched before "오늘".
        let sortedRules = rules.sorted { $0.key.count > $1.key.count }

        for (userInput, correctedMeaning) in sortedRules {
            processed = processed.replacingOccurrences(of: userInput, with: correctedMeaning, options: .caseInsensitive)
        }
        
        if processed != input {
             print("[UserRulesApplier] Applied user rules. Original: '\(input)'. Result: '\(processed)'")
        }
        
        return processed
    }
} 
