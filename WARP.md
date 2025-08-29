# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

- Repo type: iOS (Swift, Xcode project)
- Primary target/scheme: DeepSleep
- Key modules: App (UI, data), AI subsystem (multi-model LLM orchestration), Context/Usage/Metrics, Audio, Storage

Common commands (Mac, zsh)
- Open project in Xcode
  open DeepSleep.xcodeproj

- Build (Debug, iPhone 16 Pro simulator)
  xcodebuild -scheme DeepSleep -configuration Debug \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    clean build

- Run unit tests (all)
  xcodebuild -scheme DeepSleep -configuration Debug \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    test

- Run a single test or class
  # One test class
  xcodebuild -scheme DeepSleep -configuration Debug \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    test -only-testing:DeepSleepTests/SessionManagerTests

  # Single test method
  xcodebuild -scheme DeepSleep -configuration Debug \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    test -only-testing:DeepSleepTests/SessionManagerTests/testExample

- UI tests only
  xcodebuild -scheme DeepSleep -configuration Debug \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    test -only-testing:DeepSleepUITests

- Smoke (clean build + unit tests) script
  bash scripts/dev_build_test_smoke.sh

Notes
- The scheme name is DeepSleep. Adjust the simulator name with xcrun simctl list if needed.
- Secrets and limits are injected via xcconfig → Info.plist; do not hardcode in source. Create a Secrets.xcconfig (ignored) with API keys if you need to run live AI calls.

High-level architecture
1) Application shell
- AppDelegate, SceneDelegate, main ViewControllers under DeepSleepApp/ manage UI, routing (e.g., ChatViewController, Emotion* screens, Settings, Todo, Sound features).
- Storage: Core Data stack (DeepSleepApp/Models/CoreData*), MessageStore/SessionManager centralize chat/state persistence.

2) AI subsystem (DeepSleepApp/AI)
- Unified entrypoint: UnifiedAIService + UnifiedAIServiceImpl
  • Single sendMessage(...) API handles model selection, mode, context assembly, safety, fallback, and parsing.
- Providers: ClaudeAPIService, OpenAIAPIService, GeminiAPIService, NaverAPIService, plus FreeAIModels/OpenRouterFallbackManager for a tiered free-model fallback path.
- Types/utilities: AIServiceTypes (enums, errors), AIResponseParser (normalizes heterogeneous provider payloads), TokenOptimizer (context budgeting), AICallLogger/RemoteLogger (observability), AIErrorHandler (user-safe errors).

3) Context, memory, and limits
- AIContextManager: builds and caches system prompts (TTL ~3h) keyed by personaSignature; never sends raw identifiers externally—only anonymized descriptive context is sent.
- AIContextBuilder: assembles final prompt: [system prompt cache] + [core memory summary] + [recent N messages]. Integrates TokenOptimizer to fit token budgets.
- MemoryManager & PersonaMemoryManager: user-selected “core memories” and persona traits; updates trigger cache invalidation via AIContextManager.clearCache(reason: ...).
- UsageLimitManager: daily caps by feature (e.g., chat, diary analysis) + weekly caps where applicable.
  • Tier-aware chat limits via Info keys: AI_LIMITS_CHAT, AI_LIMITS_CHAT_PRO, AI_LIMITS_CHAT_MAX (fallback to DAILY_CHAT_LIMIT_{FREE,PREMIUM}).
  • Claude daily caps: DAILY_CLAUDE_LIMIT_{FREE,PREMIUM}. If exceeded, UnifiedAIServiceImpl auto-routes to Gemini (or next fallback).
  • Monthly statistics uses a weekly limit (KST Monday reset) under the key path implemented by UsageLimitManager.canUseWeeklyLimitedFeature.
  • 80%/100% events (.aiUsageLimitWarning/.aiUsageLimitReached) notify UI; ChatViewController shows an alert with remaining counts, reset time, and an Upgrade CTA.
  • Buttons show remaining quotas inline: EmotionDiaryViewController (일기 분석), EmotionCalendarViewController (월간/주간 통계 패턴 분석).
- ContextMetrics: request counters by model/mode, cache hit/miss, fallback attempts, and periodic one-line summaries for ops visibility.

4) Fallback and cost strategy
- Preferred order (cost-first): free model tier (OpenRouter) → Gemini Flash-Lite → OpenAI GPT-4o Mini → Naver HyperCLOVA X → Claude tier.
- UnifiedAIServiceImpl orchestrates sequential fallback with provider-specific adapters; failures are logged, and parsing is robust to malformed or provider-specific shapes.

5) Parsing and safety
- AIResponseParser: three-stage parse pipeline
  1) Common keys (message/response/text/content)
  2) Provider adapters (e.g., OpenAI choices[0].message.content)
  3) Sanitized fallback (strip code fences/markdown/partial JSON)
- AISecurityManager & InputValidationManager sanitize inputs/outputs; no PII or raw secrets should reach providers or logs.

6) Audio and background behavior
- Sound subsystem (SoundManager, catalogs, filters) powers sleep soundscapes; background audio requires UIBackgroundModes=audio in Info.plist for production.

7) Configuration and secrets
- Keys and limits flow: Secrets.xcconfig → Info.plist → Bundle lookup (ConfigReader/EnvironmentConfig/SecurityConfig). Example keys (to be placed in Secrets.xcconfig, not tracked):
  CLAUDE_API_KEY, OPEN_AI_4oMINI_API_KEY, GEMINI_API_KEY, NAVER_CLOUD_API_KEY, OPENROUTER_API_KEY
- Daily/feature limits defined in xcconfig and read at runtime (e.g., DAILY_CHAT_LIMIT, MAX_DAILY_REQUESTS).

Development quick facts
- Tests live in DeepSleepTests/ and DeepSleepUITests/. Some legacy tests under Tests/ are .disabled.
- The repo includes comprehensive architecture/roadmap docs helpful for deeper context:
  • README 2.md: feature summary, usage, cost mapping
  • DeepSleepApp/AI/AI-README.md: provider/fallback matrix, examples, free-model tier
  • AI_CONTEXT_MANAGEMENT_ROADMAP.md: cache/metrics/limits/streaming unification and hardening plan
  • IOS_GUIDE.md: App Store compliance checklist (IAP, privacy, background audio)

Assistant behavior in this repo
- Prefer building with xcodebuild against the DeepSleep scheme; use the provided smoke script for fast validation.
- For AI features, assume Secrets.xcconfig exists locally; when absent, mock paths should run but provider calls will fail gracefully.
- When editing code, keep the unified sendMessage entrypoint and shared builders/parsers DRY; do not reintroduce parallel ad-hoc call paths.
