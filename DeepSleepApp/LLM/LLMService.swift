//
//  LLMService.swift
//  DeepSleep
//
//  Created by AI on 2025/06/28.
//

import Foundation

public protocol LLMService {
    func generateResponse(prompt: String) async throws -> String
} 