// Temporary placeholder stubs for legacy references.
// Remove these once the respective features are re-implemented using the new Core architecture.

import Foundation
import UIKit

// MARK: - AI Orchestrator & Recommendation (Legacy)

// Legacy orchestrator placeholder (to be replaced by LLMRouter-based implementation)
@available(*, deprecated, message: "Use LLMRouter instead")
enum EnhancedUnifiedAIOrchestrator { }

@available(*, deprecated, message: "Use new Recommendation pipeline in Core module")
enum ComprehensiveRecommendationEngine {
    static let shared = ComprehensiveRecommendationEngine()
    func generateMasterRecommendation() -> String { "AI 추천 (플레이스홀더)" }
    func triggerModelUpdate() async -> Bool { false }
    func applyUpdatedModel() { }
}

// MARK: - Dynamic LoRA Adapter (stub)
@available(*, deprecated, message: "LoRA adapter system to be re-implemented")
struct DynamicLoRAAdapter {
    static let shared = DynamicLoRAAdapter()
    func downloadAdapter(from url: URL, rank: Int) async throws -> URL {
        return url // Placeholder
    }
}

// MARK: - Missing global helpers

func createUserContext() async -> String { "{}" } // Placeholder JSON

// MARK: - Compatibility shims for iOS 17-only types

@available(iOS 17.0, *)
public struct PresetFeedback: Hashable, Codable { }

@available(iOS 17.0, *)
public struct SoundItem: Hashable, Codable { }

// MARK: - Legacy ProcessingStep protocol
// Redirects to new PreProcessingStep so old code compiles without change.
import Core
public typealias ProcessingStep = PreProcessingStep 