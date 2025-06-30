//
//  GeminiService.swift
//  DeepSleep
//
//  Created by AI on 2025/06/28.
//

import Foundation
import GoogleGenerativeAI

/// A service to interact with the Google Gemini API.
final class GeminiService: LLMService {
    
    static let shared: LLMService = GeminiService()
    
    private let generativeModel: GenerativeModel
    
    private init() {
        // As per the guide v9.1, we use the specific stable version for production.
        // This ensures consistent behavior and avoids unexpected changes from 'latest' tags.
        let modelName = "gemini-2.0-flash-lite-001"
        
        // The API key should be stored securely, not hardcoded.
        // For now, we assume it's loaded from a secure source like `EnvironmentConfig`.
        guard let apiKey = EnvironmentConfig.geminiApiKey else {
            fatalError("Gemini API key not found. Please set it in your environment configuration.")
        }
        
        self.generativeModel = GenerativeModel(
            name: modelName,
            apiKey: apiKey
        )
    }
    
    func generateResponse(prompt: String) async throws -> String {
        do {
            let response = try await generativeModel.generateContent(prompt)
            
            guard let text = response.text else {
                throw LLMError.noResponseText
            }
            return text
        } catch {
            // Log the actual error for debugging purposes
            print("GeminiService Error: \(error.localizedDescription)")
            // Re-throw a more specific error for the app to handle
            throw LLMError.apiError(error.localizedDescription)
        }
    }
}

// Defines custom errors for the LLM services
enum LLMError: Error, LocalizedError {
    case noResponseText
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .noResponseText:
            return "The API returned a response without any text."
        case .apiError(let message):
            return "An API error occurred: \(message)"
        }
    }
} 