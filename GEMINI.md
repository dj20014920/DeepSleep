# 🚀 DeepSleep AI-Powered iOS App

## 📋 Project Overview

DeepSleep is a comprehensive iOS application designed to improve users' sleep quality and emotional well-being. The app provides a variety of features, including personalized soundscapes, an emotion diary, a todo list, and an AI-powered chat assistant.

The core of the application is its sophisticated AI system, which integrates multiple large language models (LLMs) including Claude, OpenAI's GPT-4o Mini, Google's Gemini, and Naver's HyperCLOVA X. This allows the app to offer a wide range of intelligent features, from personalized recommendations to in-depth emotional analysis.

The project is built using Swift and Xcode, and it leverages modern iOS technologies like SwiftUI and Combine. It also integrates with HealthKit to provide health-related insights and coaching.

## 2025-09-12 Notes (Streaming & Cache)
- Streaming: Use the proxy endpoint `POST /v1/chat/stream` with `Accept: text/event-stream`. The server normalizes Gemini streamGenerateContent (SSE/NDJSON) into pure `data: <text>` events.
- Cache policy: Gemini cachedContents creation is skipped when the system prompt prefix is < 1024 tokens. Headers expose `X-Cache-Action=bypass:too-small(1024)` and `X-Cache-Tokens=readIn=…;min=1024;action=…`.

## 🏗️ Building and Running

To build and run the DeepSleep project, you will need:

*   macOS with Xcode installed
*   An Apple Developer account (for HealthKit integration)

1.  **Open the project in Xcode:**
    ```bash
    open DeepSleep.xcodeproj
    ```

2.  **Configure API Keys:**
    Create a `Secrets.xcconfig` file in the `DeepSleepApp` directory and add your API keys for the various AI services:
    ```
    CLAUDE_API_KEY = sk-ant-your-claude-api-key
    OPEN_AI_4oMINI_API_KEY = sk-your-openai-api-key
    GEMINI_API_KEY = AIzaYour-gemini-api-key
    NAVER_CLOUD_API_KEY = your-naver-api-key:your-secret
    ```

3.  **Build and Run:**
    Select the "DeepSleep" scheme and a target device or simulator in Xcode, then click the "Run" button.

## 📝 Development Conventions

*   **Code Style:** The project follows the standard Swift style guide.
*   **Architecture:** The app uses a modular architecture with a clear separation of concerns. Key components include the `SessionManager` for data management, the `UnifiedAIService` for AI integration, and various view controllers for the UI.
*   **Asynchronous Programming:** The project makes extensive use of `async/await` for handling asynchronous operations.
*   **Error Handling:** The app uses a custom `SessionManagerError` enum and a `UserFriendlyErrorHandler` to provide clear and helpful error messages.
*   **Testing:** The project includes unit tests and UI tests. New features should be accompanied by corresponding tests.

## 📂 Key Files

*   `DeepSleepApp/ViewController.swift`: The main view controller for the application.
*   `DeepSleepApp/SessionManager.swift`: A centralized data management system that handles all app data, including chat history, feedback, and user behavior analytics.
*   `DeepSleepApp/AI/UnifiedAIServiceImpl.swift`: The core of the AI system, which integrates multiple LLMs and provides a unified interface for sending messages to them.
*   `DeepSleepApp/AIContextManager.swift`: Manages the context for AI conversations, including system prompts and user information.
*   `DeepSleepApp/EmotionAnalysisService.swift`: Provides services for analyzing user emotions from text and generating personalized recommendations.
*   `DeepSleepApp/HealthKitManager.swift`: Integrates with HealthKit to provide health-related insights and coaching.
*   `DeepSleepApp/SoundManager.swift`: Manages the playback of sounds and soundscapes.
*   `DEEPSLEEP_COMPREHENSIVE_REFACTORING_ROADMAP.md`: A detailed roadmap for the project's refactoring and future development.
*   `AI_CONTEXT_MANAGEMENT_ROADMAP.md`: A roadmap for the development of the AI context management system.

## 🤖 AI System

The DeepSleep app features a powerful and flexible AI system that can be accessed through the `UnifiedAIServiceImpl` class. The system supports multiple AI models and various modes for different tasks.

**AI Models:**

*   Claude
*   OpenAI GPT-4o Mini
*   Google Gemini
*   Naver HyperCLOVA X

**AI Modes:**

*   General Conversation
*   Emotion Diary Analysis
*   Preset Recommendation
*   Task Advice
*   And more...

To send a message to the AI, you can use the `sendMessage` method in the `UnifiedAIServiceImpl` class:

```swift
let aiService = UnifiedAIServiceImpl.shared

let response = try await aiService.sendMessage(
    content: "Tell me a bedtime story.",
    model: .gemini,
    mode: .generalConversation,
    context: AIContext(userId: "user123", sessionId: "session1"),
    tokenConfig: nil
)

print(response.content)
```

## 🗺️ Roadmap

The project has a detailed roadmap for future development, which includes:

*   **Phase 1: Basic Foundation (Completed)**
    *   Persona system integration
    *   Dead code removal
    *   Subscription system implementation

*   **Phase 2: Basic Context Management (1-2 months)**
    *   Basic subscription system
    *   Simple conversation history system

*   **Phase 3: Advanced Context Management (3-6 months)**
    *   System prompt caching
    *   Core memory system

*   **Phase 4: Complete Memory Management (6-12 months)**
    *   Automatic summary system
    *   Advanced management features
