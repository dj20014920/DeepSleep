//
//  ConversationPipelineProtocols.swift
//  DeepSleep
//
//  Created by AI on 2025/06/28.
//

import Foundation

// MARK: - Conversation Processing Pipeline Protocols

/// A protocol for a single step in the conversation pre-processing pipeline.
/// Each step takes a user input string and transforms it.
public protocol PreProcessingStep {
    func process(input: String) async -> String
}

/// A protocol for a single step in the conversation post-processing pipeline.
/// Each step takes the raw output from the AI model and refines it.
public protocol PostProcessingStep {
    /// Processes the raw output from the model.
    /// - Parameters:
    ///   - output: The raw output from the language model.
    ///   - context: The original user input for contextual enhancement.
    /// - Returns: The processed output string, ready for the user.
    func process(output: String, context: String) async -> String
} 
