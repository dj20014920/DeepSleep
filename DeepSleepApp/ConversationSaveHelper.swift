//
//  ConversationSaveHelper.swift
//  DeepSleep
//
//  Created by dj on 2024/06/18.
//

import Foundation

// MARK: -  ARCHITECTURAL NOTE (2025-08-12)
// This file has been deprecated and its logic is now obsolete.
// The functionality of batching and saving conversations has been fully integrated
// into the SessionManager and the application lifecycle (AppDelegate).
// ChatViewController now interacts directly with SessionManager, making this helper class redundant.
// This file is retained temporarily to resolve build errors and will be deleted in the final cleanup phase.

final class ConversationSaveHelper {
    static let shared = ConversationSaveHelper()
    private init() {}

    // All methods are now no-ops (no-operations) to prevent side effects.
    func startNewConversation(emotionContext: Any) {}
    func addMessage(content: String, isFromUser: Bool, emotionIntensity: Double? = nil) {}
    func saveCurrentConversation() async {}
    func endCurrentConversation() async {}
    func getCurrentConversationStats() -> (messageCount: Int, duration: TimeInterval?) { return (0, nil) }
    func handleNewUserMessage(_ message: String, currentEmotion: String? = nil) {}
    func handleAIResponse(_ response: String) {}
}
