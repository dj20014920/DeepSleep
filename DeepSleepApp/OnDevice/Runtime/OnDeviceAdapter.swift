import CryptoKit
import Foundation
import OSLog

// MARK: - OnDeviceAdapter
// UnifiedAIService와 온디바이스 런타임(RemoteAssetClient(HTTP) + llama.cpp)을 연결하는 단일 어댑터.
// - DRY/SSOT: 모델 메타/권장 파라미터/시스템 프롬프트는 ModelCatalog와 SystemPrompts에서만 읽는다.
// - 책임 분리: 설치/무결성은 RemoteAssetClient(HTTP) + sha256 검증, 로딩/생성은 OnDeviceModelLoader 담당.
// - KISS: UnifiedAIService는 본 어댑터의 간단한 API를 통해 on-device 경로를 호출한다.
public final class OnDeviceAdapter: @unchecked Sendable {

    // MARK: Singleton
    public static let shared = OnDeviceAdapter()

    // MARK: Dependencies
    private let log = Logger(subsystem: "DeepSleep.OnDevice", category: "Adapter")
    private var remote: RemoteAssetClient
    private let loader: OnDeviceModelLoader

    // UTF-8 스트리밍 디코더(바이트 경계 SSOT)
    private var utf8Buffer = UTF8ByteStreamDecoder()
    // 그래펨(문자 클러스터) 경계 보호 버퍼
    private var graphemeBuffer = GraphemeStreamBuffer()
    // 템플릿 토큰 스트리밍 보류 버퍼
    private var templateHold: String = ""

    // 전환/성능 정책
    private var policy = FallbackPolicy()

    // 성능 적응(모델별 TTI 초과 카운트)
    private var ttiExceedCount: [OnDeviceModelID: Int] = [:]

    // 동시성 보호(간단 직렬 큐)
    private let q = DispatchQueue(label: "DeepSleep.OnDevice.Adapter", qos: .userInitiated)
    // 현재 생성 진행 여부(프리워밍과의 충돌 방지용)
    private var generationInFlight: Bool = false

    // MARK: State
    public private(set) var activeModelID: OnDeviceModelID? {
        get { q.sync { loader.activeModelID } }
        set { /* read-only 바인딩: loader.switchModel에서 갱신됨 */  }
    }

    private init() {
        // HTTP(S) 원격 자산 클라이언트
        self.remote = RemoteAssetClient()
        // llama.cpp 기반 로더(조건부 컴파일된 바인딩 사용)
        self.loader = LlamaModelLoader()
        // 원격 설정 반영하여 정책 동기화
        self.syncPolicyFromConfig()
        // 메모리 압박 후 자동 모델 재활성화 리스너 설정
        self.setupMemoryRecoveryListener()
    }

    /// 원격 설정으로부터 폴백 정책을 동기화한다(KISS: 한 지점에서만 적용).
    private func syncPolicyFromConfig() {
        let maxTTI = ConfigReader.int("ONDEVICE_MAX_TTI_MS", default: 4000) ?? 4000
        var p = self.policy
        p.maxTTIMilliseconds = maxTTI
        self.policy = p
    }

    /// 메모리 복구 후 선택된 온디바이스 모델 자동 재활성화 설정
    private func setupMemoryRecoveryListener() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OnDeviceModel.ReactivateSelected"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            Task {
                await self.handleModelReactivation(notification: notification)
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MemoryPressure.GentleCleanup"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            // 메모리 압박 시 현재 활성 모델 ID 백업
            if let activeID = self.activeModelID {
                UserDefaults.standard.set(activeID.rawValue, forKey: "LastActiveOnDeviceModel")
                self.log.info("🔄 메모리 압박으로 인한 모델 백업: \(activeID.rawValue)")
            }
        }
    }

    /// 메모리 복구 후 모델 재활성화 처리
    private func handleModelReactivation(notification: Notification) async {
        let reason = notification.userInfo?["reason"] as? String ?? "unknown"
        self.log.info("🔄 모델 재활성화 요청: \(reason)")

        // 1. 사용자가 선택한 온디바이스 모델 확인
        let selectedModel = SettingsManager.shared.selectedOnDeviceModel

        // 2. 백업된 모델 ID 확인 (메모리 압박 전 활성 모델)
        let lastActiveModelRaw = UserDefaults.standard.string(forKey: "LastActiveOnDeviceModel")
        let lastActiveModel = lastActiveModelRaw.flatMap(OnDeviceModelID.init(rawValue:))

        // 3. 재활성화할 모델 결정 (우선순위: 사용자 선택 > 백업 모델)
        let targetModel: OnDeviceModelID?
        if let selected = selectedModel {
            targetModel = selected
        } else if let backup = lastActiveModel {
            targetModel = backup
        } else {
            // 기본값: 첫 번째 권장 모델
            targetModel = ModelCatalog.fallbackOrder.first
        }

        guard let modelToActivate = targetModel else {
            self.log.warning("재활성화할 온디바이스 모델을 찾을 수 없음")
            return
        }

        // 4. 모델이 이미 활성화되어 있으면 건너뛰기
        if self.activeModelID == modelToActivate && self.loader.isLoaded {
            self.log.info("🟢 모델 이미 활성화됨: \(modelToActivate.rawValue)")
            return
        }

        // 5. 모델 재활성화 시도
        do {
            self.log.info("🔄 모델 재활성화 시작: \(modelToActivate.rawValue)")
            try await self.activate(id: modelToActivate)
            self.log.info("✅ 모델 재활성화 성공: \(modelToActivate.rawValue)")

            // 백업 정보 정리
            UserDefaults.standard.removeObject(forKey: "LastActiveOnDeviceModel")

        } catch {
            self.log.error(
                "❌ 모델 재활성화 실패: \(modelToActivate.rawValue) - \(error.localizedDescription)")

            // 재시도 로직: 5초 후 다시 시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                Task {
                    await self.handleModelReactivation(notification: notification)
                }
            }
        }
    }

    /// 토큰 스트림에서 UTF-8 인코딩 문제 및 템플릿 토큰 누출 실시간 정리
    ///
    /// **개선사항:**
    /// - ✅ UTF-8 멀티바이트 경계 안전 처리 (한글 등 문자 손실 방지)
    /// - ✅ 스트리밍 중 U+FFFD 제거 금지 (미완성 바이트 복구 기회 보장)
    /// - ✅ 중앙화된 SpecialTokenSanitizer 사용 (DRY 원칙 준수)
    ///
    /// - Note: UTF8ByteStreamDecoder를 통해 멀티바이트 문자가 스트림 경계에서
    ///         잘려도 안전하게 복구됩니다 (업계 표준 방식)
    private func cleanTokenDelta(_ delta: String, modelID: OnDeviceModelID) -> String {
        // 1) UTF-8 바이트 경계 복구
        let byteSafe = utf8Buffer.processBytes(Array(delta.utf8))
        // 2) 그래펨(이모지/결합표/국기) 경계 복구
        let graphemeSafe = graphemeBuffer.process(byteSafe)
        // 3) 템플릿 마커 스트리밍 제거 (경계 넘나드는 조각까지 안전 처리)
        let templateCleaned = self.stripTemplateMarkersStreaming(in: graphemeSafe, modelID: modelID)
        // 4) 특수 토큰 정리 (U+FFFD는 스트리밍 단계에서 제거하지 않음)
        return SpecialTokenSanitizer.cleanStreamingToken(templateCleaned, modelID: modelID)
    }

    // MARK: Adapter-facing Types

    public struct ModelEntry: Sendable, Equatable {
        public let record: ModelRecord
        public let state: BackgroundAssetState
        public init(record: ModelRecord, state: BackgroundAssetState) {
            self.record = record
            self.state = state
        }
    }

    public struct StreamConfig: Sendable {
        public let systemPrompt: String?
        public let params: InferenceParams?
        public let recentMessages: [RoleMessage]?
        public let disableKVCache: Bool
        public let aiMode: AIMode?  // 🔑 캐시 키 생성에 사용할 AI 모드
        
        public init(
            systemPrompt: String? = nil,
            params: InferenceParams? = nil,
            recentMessages: [RoleMessage]? = nil,
            disableKVCache: Bool = false,
            aiMode: AIMode? = nil
        ) {
            self.systemPrompt = systemPrompt
            self.params = params
            self.recentMessages = recentMessages
            self.disableKVCache = disableKVCache
            self.aiMode = aiMode
        }
    }

    public struct GenerationSummary: Sendable {
        public let modelID: OnDeviceModelID
        public let ttiMilliseconds: Int
        public let startedAt: Date
        public let finishedAt: Date
        public var durationMs: Int { Int(finishedAt.timeIntervalSince(startedAt) * 1000) }
    }

    public enum AdapterError: Error, LocalizedError, Sendable {
        case noInstalledModel
        case notAvailableForOS
        case cancelled
        case cloudFallbackSuggested
        case underlying(Error)

        public var errorDescription: String? {
            switch self {
            case .noInstalledModel: return "설치된 온디바이스 모델이 없습니다."
            case .notAvailableForOS: return "이 iOS 버전에서는 온디바이스 기능을 사용할 수 없습니다."
            case .cancelled: return "요청이 취소되었습니다."
            case .cloudFallbackSuggested: return "온디바이스 실패: 클라우드 폴백을 제안합니다."
            case .underlying(let e): return e.localizedDescription
            }
        }
    }

    // MARK: - Catalog/Status

    /// 카탈로그 + 현재 상태(설치/다운로드중/미설치)를 조회한다.
    public func listModels() async -> [ModelEntry] {
        let items = ModelCatalog.all()
        // 상태 병렬 취득
        return await withTaskGroup(of: ModelEntry.self, returning: [ModelEntry].self) { group in
            for r in items {
                group.addTask { [remote] in
                    let st = remote.status(fileName: r.fileName)
                    let state: BackgroundAssetState
                    if st.installed, let url = OnDeviceAdapter.installedURL(fileName: r.fileName) {
                        state = .installed(localURL: url)
                    } else if st.progress > 0 {
                        state = .installing(progress: st.progress)
                    } else {
                        state = .notInstalled
                    }
                    return ModelEntry(record: r, state: state)
                }
            }
            var result: [ModelEntry] = []
            for await e in group {
                result.append(e)
            }
            return result
        }
    }

    /// 특정 모델의 상태를 조회한다(HTTP 다운로드 경로).
    public func status(for id: OnDeviceModelID) async -> BackgroundAssetState {
        let r = ModelCatalog.record(for: id)
        let st = remote.status(fileName: r.fileName)
        if st.installed, let url = OnDeviceAdapter.installedURL(fileName: r.fileName) {
            return .installed(localURL: url)
        }
        if st.progress > 0 {
            return .installing(progress: st.progress)
        }
        return .notInstalled
    }

    // MARK: - Install/Ensure

    /// 원격 설치 보장(무결성 검증 포함). 진행률 콜백 지원.
    @discardableResult
    public func ensureInstalled(
        id: OnDeviceModelID,
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let rec = ModelCatalog.record(for: id)
        let t0 = Date()
        log.info(
            "⬇️ [Adapter] ensureInstalled start id=\(rec.id.rawValue, privacy: .public) file=\(rec.fileName, privacy: .public) sha=\(rec.sha256Hex, privacy: .public)"
        )
        var __lastLoggedPct = -1
        let url = try await remote.ensureInstalled(
            fileName: rec.fileName,
            expectedSha256: rec.sha256Hex,
            progress: { p in
                let pct = Int(p * 100)
                if pct != __lastLoggedPct && (pct == 0 || pct == 100 || pct % 5 == 0) {
                    self.log.debug("📈 [Adapter] \(rec.displayName, privacy: .public) \(pct)%")
                    __lastLoggedPct = pct
                }
                progress?(p)
            }
        )
        // 최종 무결성 재확인(양방향 방어)
        let actual = try FileIntegrity.sha256Hex(of: url)
        guard actual.lowercased() == rec.sha256Hex.lowercased() else {
            throw OnDeviceError.hashMismatch(expected: rec.sha256Hex, actual: actual)
        }
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? -1
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        log.info(
            "📦 Installed/Ready: \(rec.displayName, privacy: .public) @\(url.lastPathComponent, privacy: .public) size=\(size, privacy: .public) took=\(ms, privacy: .public)ms"
        )
        return url
    }

    /// 다운로드/설치를 취소한다.
    public func cancelInstall(id: OnDeviceModelID) {
        let rec = ModelCatalog.record(for: id)
        remote.cancel(fileName: rec.fileName)
    }

    // MARK: - Activate / Switch

    /// 모델을 활성화(로드)한다. 이미 로드된 동일 모델이면 noop.
    public func activate(id: OnDeviceModelID) async throws {
        let rec = ModelCatalog.record(for: id)
        let t0 = Date()
        log.info("⚙️ [Adapter] activate start id=\(rec.id.rawValue, privacy: .public)")
        let url = try await ensureInstalled(id: id)
        // 동일이면 스킵
        if loader.activeModelID == id, loader.isLoaded {
            log.info("🔁 Already active: \(rec.displayName, privacy: .public)")
            return
        }
        // 권장 파라미터로 세션 로드
        try loader.load(modelURL: url, modelID: id, params: rec.recommended)
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        log.info("🚀 Activated: \(rec.displayName, privacy: .public) took=\(ms, privacy: .public)ms")
    }

    /// 모델을 교체(핫스왑)한다. 설치-확보 → 세션 재생성.
    public func switchModel(id: OnDeviceModelID) async throws {
        let rec = ModelCatalog.record(for: id)
        let t0 = Date()
        log.info("♻️ [Adapter] switchModel start id=\(rec.id.rawValue, privacy: .public)")
        let url = try await ensureInstalled(id: id)
        try await loader.switchModel(to: id, modelURL: url, params: rec.recommended)
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        log.info("♻️ Switched: \(rec.displayName, privacy: .public) took=\(ms, privacy: .public)ms")
    }
    // MARK: - Remote config gates
    private func isOnDeviceEnabled() -> Bool {
        return ConfigReader.bool("ONDEVICE_ENABLED", default: true) ?? true
    }
    private func isForcedCloud() -> Bool {
        return ConfigReader.bool("ONDEVICE_FORCE_CLOUD", default: false) ?? false
    }

    // MARK: - Thermal-aware preference
    private func preferredAdjustedForThermal(preferred: OnDeviceModelID?) -> OnDeviceModelID? {
        guard policy.thermalMitigation else { return preferred }
#if os(iOS)
        if #available(iOS 11.0, *) {
            let state = ProcessInfo.processInfo.thermalState
            switch state {
            case .serious, .critical:
                // 고온 시 가장 경량 모델부터 시도하도록 선호 무시
                return ModelCatalog.fallbackOrder.first
            default:
                return preferred
            }
        } else {
            return preferred
        }
#else
        return preferred
#endif
    }

    // MARK: - Prewarm (reduce TTI by pre-filling system prompt KV)

    /// 시스템 프롬프트만 미리 프리필하여 KV 상태를 캐시에 저장한다.
    /// - 목적: 실제 생성 전에 접두부(시스템) 토큰화를 끝내 TTI를 낮춤.
    /// - 주의: 최근 대화/유저 입력은 포함하지 않음(가벼운 사전 준비).
    public func prewarm(systemPrompt: String) async {
        // 온디바이스 비활성/클라우드 강제면 수행하지 않음
        if isForcedCloud() || !isOnDeviceEnabled() { return }

        // 대상 모델: 사용자 선호 → 활성 → 폴백
        let targetID: OnDeviceModelID = {
            if let p = SettingsManager.shared.preferredOnDeviceModelID { return p }
            if let a = self.activeModelID { return a }
            return ModelCatalog.fallbackOrder.first ?? .hcx05b_q4_k_m
        }()

        // 설치됨일 때만 프리워밍 (다운로드/전환 유발 금지)
        let st = await status(for: targetID)
        guard case .installed = st else { return }
        // 현재 로더가 로드된 경우에만 수행 (활성화는 외부 흐름에서 담당)
        guard loader.activeModelID == targetID, loader.isLoaded else { return }

        do {
            guard let io = loader as? (any KVPromptCache.LlamaSessionIO) else { return }
            let nSys = try io.prefillSystem(systemPrompt)
            let selectedModelType = SettingsManager.shared.selectedLLM
            let mappedModel = AIContextSignature.mapModel(from: selectedModelType)
            let userSettingsForTones = UserSettingsModel.loadFromUserDefaults()
            let components = UserRulesManager.shared.personaSignatureComponents(
                currentMode: .generalConversation,
                model: mappedModel,
                conversationTones: userSettingsForTones.conversationTones
            )
            let kvKey = KVPromptKeyBuilder.from(
                modelRaw: targetID.rawValue, personaCompositeHash: components.composite)
            let _ = await KVPromptCache.shared.saveIfBeneficial(
                for: kvKey, using: io, nPrefixTokens: nSys)
            self.log.debug("[Prewarm] success: systemPrompt prefilled (\(nSys) tokens)")
        } catch {
            // llama_decode 실패 시 KV cache가 clearKVCache()로 이미 클리어됨
            // 다음 요청에서 정상 작동하도록 에러 로그만 출력
            self.log.warning("[Prewarm] failed but KV cache cleared: \(error.localizedDescription)")
        }
    }

    // MARK: - Generate (stream)

    /// 스트리밍 생성. 첫 토큰 시간(TTI)을 측정하고 요약을 반환한다.
    /// - onToken: 토큰 델타가 도착할 때 호출
    @discardableResult
    public func generate(
        preferred: OnDeviceModelID?,
        text input: String,
        config: StreamConfig = .init(),
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> GenerationSummary {
        // 원격 설정 기반 가드: 온디바이스 비활성/클라우드 강제 시 즉시 폴백 제안
        if isForcedCloud() || !isOnDeviceEnabled() {
            log.info(
                "🚧 [Adapter] on-device gated forcedCloud=\(self.isForcedCloud()) enabled=\(self.isOnDeviceEnabled()) → cloudFallbackSuggested"
            )
            throw AdapterError.cloudFallbackSuggested
        }
        // 프리워밍과의 KV pos 충돌 방지: 생성 중 플래그 세팅
        q.sync { generationInFlight = true }
        defer { q.sync { generationInFlight = false } }

        // 0) 열 완화: 고온 상태에서는 경량 모델 우선 시도
        let adjustedPreferred = preferredAdjustedForThermal(preferred: preferred)

        // 1) 후보 결정
        let candidates = buildCandidates(preferred: adjustedPreferred)
#if DEBUG
        self.log.info(
            "🍎 [Adapter] on-device generate start preferred=\(adjustedPreferred?.rawValue ?? "nil", privacy: .public) candidates=\(candidates.map { $0.rawValue }.joined(separator: ","), privacy: .public)"
        )
#endif
        var lastError: Error?

        for (idx, id) in candidates.enumerated() {
            do {
                let summary = try await runOnce(
                    id: id, input: input, config: config, onToken: onToken)
                // TTI 정책 카운트 업데이트
                self.updateTTICounters(id: id, ttiMs: summary.ttiMilliseconds)
#if DEBUG
                self.log.info(
                    "🍎 [Adapter] on-device success model=\(id.rawValue, privacy: .public) ttiMs=\(summary.ttiMilliseconds, privacy: .public)"
                )
#endif
                // 성공
                return summary
            } catch {
                lastError = error
                log.warning(
                    "❌ Generate failed on \(id.rawValue, privacy: .public) (idx=\(idx, privacy: .public)): \(error.localizedDescription, privacy: .public)"
                )
                // 다음 후보 시도
                continue
            }
        }

        // 모든 후보 실패
        if policy.allowCloudFallback {
            throw AdapterError.cloudFallbackSuggested
        }
        throw AdapterError.underlying(lastError ?? OnDeviceError.unknown("unknown"))
    }

    // 단일 시도: 설치 보장 → (필요 시) 전환 → 스트리밍 생성
    private func runOnce(
        id: OnDeviceModelID,
        input: String,
        config: StreamConfig,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> GenerationSummary {

        // 0) 세션 준비/전환 (내부에서 필요 시 자동으로 설치 보장)
        // ⚡ 최적화: 이미 로드된 모델이면 ensureInstalled 중복 호출 방지 (572ms 절약)
        if loader.activeModelID != id || !loader.isLoaded {
            do {
                try await switchModel(id: id)
            } catch {
                // GPU 레이어로 인한 초기화 실패 가능성에 대비, 1회 CPU 강제 재시도 경로 제공
                var fallback = ModelCatalog.record(for: id).recommended
                fallback.gpuLayers = 0
                print(
                    "🛟 [OnDeviceAdapter] switchModel failed (\(error.localizedDescription)). Retrying with gpuLayers=0"
                )
                // 직접 로드 경로로 재시도
                let rec = ModelCatalog.record(for: id)
                let url = try await ensureInstalled(id: id)
                try loader.load(modelURL: url, modelID: id, params: fallback)
            }
        }

        // 모델별 채팅 템플릿에 맞춰 사용자 턴을 구성 (resume 안전 버전)
        let formatUserTurn: (String) -> String = { user in
            OnDevicePromptProfile.PromptFormatter.formatUserTurn(user, for: id)
        }
        let rec = ModelCatalog.record(for: id)
        var params = config.params ?? rec.recommended
        // 모델별 stop 시퀀스 기본값(템플릿 에코 억제)
        if params.stops == nil {
            params.stops = OnDevicePromptProfile.stopSequences(for: id)
        }
        // 강제 비메탈 토글 시 GPU 레이어 비활성화, 아니면 기본 -1(가능 시 전체 오프로딩)
        // 메탈 오프로딩/보수 샘플링(SSOT)
        let disableMetal = ConfigReader.bool("ONDEVICE_DISABLE_METAL", default: false) ?? false
        OnDevicePromptProfile.SamplingTuning.applyMetalOverride(
            into: &params, disableMetal: disableMetal)
        OnDevicePromptProfile.SamplingTuning.applyConservativeDefaults(for: id, into: &params)
        // 시스템 프롬프트: 옵셔널/빈 문자열 안전 처리 → 항상 비옵셔널(String)
        // Gemma는 system 역할 미지원: system 지시는 초기 user 입력에 내재화
        let systemOriginal: String = {
            if let s = config.systemPrompt,
               !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                return s
            }
            return SystemPrompts.empathyKR
        }()
        // 모든 모델에서 systemOriginal을 시스템 프롬프트로 유지하고, 사용자 입력은 템플릿으로 연결한다.
        let system: String = systemOriginal
        let inputWithSystem: String = input
        // 일반 대화 모드 외에는 KV 캐시 오염을 방지하기 위해 KV 복원을 비활성화
        var disableKV = config.disableKVCache
        if config.aiMode != nil && config.aiMode != .generalConversation {
            disableKV = true
        }
        // 최근 3+3 직렬화(모델별 템플릿) — SSOT
        let recentSerialized: String = {
            guard let msgs = config.recentMessages, !msgs.isEmpty else { return "" }
            let pairs: [(OnDevicePromptProfile.PromptRole, String)] = msgs.compactMap { m in
                switch m.role {
                case .user: return (.user, m.content)
                case .assistant: return (.assistant, m.content)
                default: return nil
                }
            }
            return OnDevicePromptProfile.PromptFormatter.serializeRecent(pairs, for: id)
        }()
        // 3) 스트리밍 생성(TTI 측정)
        let started = Date()
        var emittedFirst = false
        var ttiMs: Int = -1

        do {
            // 스트리밍 정책: 일기 분석 등 민감 컨텍스트에서는 일반대화 캐시 복원을 끕니다.
            if disableKV {
                try await loader.generate(
                    input: input,
                    systemPrompt: system,
                    params: params,
                    onToken: { delta in
                        if !emittedFirst {
                            emittedFirst = true
                            ttiMs = Int(Date().timeIntervalSince(started) * 1000)
                            self.log.info("⏱️ firstTokenMs=\(ttiMs, privacy: .public) (no-kv)")
                            self.log.info("⏱️ TTI=\(ttiMs, privacy: .public)ms [\(id.rawValue, privacy: .public)]")
                        }
                        let cleanedDelta = self.cleanTokenDelta(delta, modelID: id)
                        onToken(cleanedDelta)
                    }
                )
                // 종료 처리(아래와 동일 경로)
            } else {
                // 2.5) KV 프롬프트 캐시: 시스템 프롬프트 접두부 재사용 시도
                // 키 = 모델ID + 페르소나 컴포지트 해시 (AIContextBuilder 내부 로직과 동일 소스 사용)
                let selectedModelType = SettingsManager.shared.selectedLLM
                let mappedModel = AIContextSignature.mapModel(from: selectedModelType)
                let userSettingsForTones = UserSettingsModel.loadFromUserDefaults()
                
                // 🔑 핵심 개선: config.aiMode를 사용하여 각 모드별 독립적인 캐시 키 생성
                let currentMode = config.aiMode ?? .generalConversation
                let components = UserRulesManager.shared.personaSignatureComponents(
                    currentMode: currentMode,
                    model: mappedModel,
                    conversationTones: userSettingsForTones.conversationTones
                )
                let kvKey = KVPromptKeyBuilder.from(
                    modelRaw: id.rawValue, personaCompositeHash: components.composite)

                // 바인딩이 세션 I/O를 지원하는 경우에만 사용
                if let io = loader as? (any KVPromptCache.LlamaSessionIO) {
                    let restore = await KVPromptCache.shared.restoreIfPossible(for: kvKey, using: io)
                    // 관측성 강화: RESTORE 결과를 콘솔에도 브릿지(런타임 토글)
                    if ConfigReader.bool("ONDEVICE_KV_LOG_VERBOSE", default: false) ?? false {
                        print(
                            "[KVCacheBridge] restore result success=\(restore.success) reason=\(restore.reason) key=\(kvKey.prefix(12))…"
                        )
                    }
                    KVMetricsHook.shared.onRestore(restore)
                    if restore.success {
                        // 프리필 성공: 캐시의 마지막 위치 다음부터 이어붙이기
                        // 현재 llama_state에는 시스템 프롬프트까지의 KV가 포함됨
                        // startPos는 해당 마지막 토큰 위치 + 1
                        let startPos = Int32((restore.entry?.nPrefixTokens ?? 0))
                        // 접두부(KV) 이후: 직렬화된 최근 3+3 + 현재 사용자 턴만 주입 후 생성
                        let resumeInput = recentSerialized + formatUserTurn(inputWithSystem)
                        try await loader.generateResuming(
                            input: resumeInput,
                            systemPrompt: nil,
                            startPos: startPos,
                            params: params,
                            onToken: { delta in
                                if !emittedFirst {
                                    emittedFirst = true
                                    ttiMs = Int(Date().timeIntervalSince(started) * 1000)
                                    self.log.info(
                                        "⏱️ firstTokenMs=\(ttiMs, privacy: .public) (resume)"
                                    )
                                    self.log.info(
                                        "⏱️ TTI=\(ttiMs, privacy: .public)ms [\(id.rawValue, privacy: .public)]"
                                    )
                                }
                                // UTF-8 인코딩 문제 해결 및 템플릿 토큰 정리
                                let cleanedDelta = self.cleanTokenDelta(delta, modelID: id)
                                onToken(cleanedDelta)
                            }
                        )
                    } else {
                        // 최초 1회: 시스템 + 직렬화된 최근 3+3을 프리필 후 저장 → 현재 사용자만 이어서 생성
                        do {
                            // 모델별 템플릿으로 최근 3+3 직렬화
                            let recentSerialized: String = {
                                guard let msgs = config.recentMessages, !msgs.isEmpty else { return "" }
                                switch id {
                                case .amoral_gemma1b_v2_q4km:
                                    return msgs.compactMap { m in
                                        switch m.role {
                                        case .user:
                                            return "<start_of_turn>user\n\(m.content)<end_of_turn>\n"
                                        case .assistant:
                                            return "<start_of_turn>model\n\(m.content)<end_of_turn>\n"
                                        default: return nil
                                        }
                                    }.joined()
                                case .hcx05b_q4_k_m, .hcx05b_q8_0, .gemma1b_iq4xs:
                                    return msgs.compactMap { m in
                                        switch m.role {
                                        case .user: return "<|im_start|>user\n\(m.content)<|im_end|>\n"
                                        case .assistant:
                                            return "<|im_start|>assistant\n\(m.content)<|im_end|>\n"
                                        default: return nil
                                        }
                                    }.joined()
                                }
                            }()

                            let nSys = try io.prefillSystem(system)
                            // 최근 대화는 캐시에 포함하지 않음
                            // 이유: 매번 변경되어 캐시 히트율이 낮고, 복원 후 배치로 처리하는 것이 더 효율적
                            let nPrefix = nSys

                            let saved = await KVPromptCache.shared.saveIfBeneficial(
                                for: kvKey,
                                using: io,
                                nPrefixTokens: nPrefix
                            )
                            // 관측성 강화: SAVE 결과를 콘솔에도 브릿지(런타임 토글)
                            if ConfigReader.bool("ONDEVICE_KV_LOG_VERBOSE", default: false) ?? false {
                                print(
                                    "[KVCacheBridge] save result success=\(saved.success) reason=\(saved.reason) key=\(kvKey.prefix(12))… tokens=\(nPrefix)"
                                )
                            }
                            KVMetricsHook.shared.onSave(saved)

                            // 접두부 프리필 후: 현재 사용자 턴만 템플릿으로 이어붙여 생성(resume)
                            let templated = formatUserTurn(inputWithSystem)
                            try await loader.generateResuming(
                                input: templated,
                                systemPrompt: nil,
                                startPos: Int32(nPrefix),
                                params: params,
                                onToken: { delta in
                                    if !emittedFirst {
                                        emittedFirst = true
                                        ttiMs = Int(Date().timeIntervalSince(started) * 1000)
                                        self.log.info(
                                            "⏱️ firstTokenMs=\(ttiMs, privacy: .public) (resume)"
                                        )
                                        self.log.info(
                                            "⏱️ TTI=\(ttiMs, privacy: .public)ms [\(id.rawValue, privacy: .public)]"
                                        )
                                    }
                                    // UTF-8 인코딩 문제 해결 및 템플릿 토큰 정리
                                    let cleanedDelta = self.cleanTokenDelta(delta, modelID: id)
                                    onToken(cleanedDelta)
                                }
                            )
                        } catch {
                            // 프리필 경로 실패 시 전체 경로 폴백
                            try await loader.generate(
                                input: input,
                                systemPrompt: system,
                                params: params,
                                onToken: { delta in
                                    if !emittedFirst {
                                        emittedFirst = true
                                        ttiMs = Int(Date().timeIntervalSince(started) * 1000)
                                        self.log.info(
                                            "⏱️ firstTokenMs=\(ttiMs, privacy: .public) (fallback)"
                                        )
                                        self.log.info(
                                            "⏱️ TTI=\(ttiMs, privacy: .public)ms [\(id.rawValue, privacy: .public)]"
                                        )
                                    }
                                    // UTF-8 인코딩 문제 해결 및 템플릿 토큰 정리
                                    let cleanedDelta = self.cleanTokenDelta(delta, modelID: id)
                                    onToken(cleanedDelta)
                                }
                            )
                        }
                    }
                } else {
                    // 기존 경로 유지
                    try await loader.generate(
                        input: input,
                        systemPrompt: system,
                        params: params,
                        onToken: { delta in
                            if !emittedFirst {
                                emittedFirst = true
                                ttiMs = Int(Date().timeIntervalSince(started) * 1000)
                                self.log.info(
                                    "⏱️ firstTokenMs=\(ttiMs, privacy: .public) (legacy)"
                                )
                                self.log.info(
                                    "⏱️ TTI=\(ttiMs, privacy: .public)ms [\(id.rawValue, privacy: .public)]"
                                )
                            }
                            // UTF-8 인코딩 문제 해결 및 템플릿 토큰 정리
                            let cleanedDelta = self.cleanTokenDelta(delta, modelID: id)
                            onToken(cleanedDelta)
                        }
                    )
                }
            }
        } catch {
            // 에러 유형별 재매핑(폴백 의사결정에 활용)
            if let e = error as? OnDeviceError {
                switch e {
                case .generationCancelled: throw AdapterError.cancelled
                case .engineNotInitialized, .modelAssetMissing, .hashMismatch:
                    // 설치/무결성/엔진 문제 → 상위에서 다음 후보 시도
                    throw AdapterError.underlying(e)
                case .backgroundAssetsUnavailable:
                    throw AdapterError.notAvailableForOS
                case .unknown:
                    throw AdapterError.underlying(e)
                }
            }
            throw AdapterError.underlying(error)
        }

        // ✅ 스트림 종료: 모든 버퍼 완전 플러시 (누락 방지 강화)
        // 1단계: UTF-8 바이트 경계 완전 처리
        var tail = utf8Buffer.flush()
        // 2단계: 그래펨 클러스터 경계 완전 처리
        tail = graphemeBuffer.process(tail) + graphemeBuffer.flush()
        // 3단계: 템플릿 마커 최종 정리
        tail = self.stripTemplateMarkersStreaming(in: tail, modelID: id)
        // 4단계: 템플릿 보류 버퍼 완전 비우기 (잔여 누락 방지)
        if !templateHold.isEmpty {
            // 보류된 불완전 템플릿 조각도 최종적으로 출력 (스트림 끝에서는 템플릿 아님)
            tail += templateHold
            templateHold.removeAll(keepingCapacity: false)
        }
        // 5단계: 최종 특수 토큰 정리 후 방출
        if !tail.isEmpty {
            let cleaned = SpecialTokenSanitizer.cleanStreamingToken(tail, modelID: id)
            if !cleaned.isEmpty {
                onToken(cleaned)
            }
        }
        // 6단계: 다음 생성을 위해 모든 버퍼 완전 리셋
        utf8Buffer.reset()
        graphemeBuffer.reset()
        templateHold.removeAll(keepingCapacity: false)

            let finished = Date()
            let usedTTI = max(0, ttiMs)
            return GenerationSummary(
                modelID: id, ttiMilliseconds: usedTTI, startedAt: started, finishedAt: finished)
        }
    }


extension OnDeviceAdapter {
    // MARK: - Streaming template marker stripping

    /// 모델 템플릿 마커(예: Qwen: <|im_start|> .. |>, Gemma: <start_of_turn>) 스트리밍 제거
    /// - 원칙: '<'로 시작해 템플릿 접두와 일치하면 종결('>' 또는 "|>")까지 제거. 없으면 보류.
    fileprivate func stripTemplateMarkersStreaming(in s: String, modelID: OnDeviceModelID) -> String {
        if s.isEmpty { return s }
        // 1) 보류분과 결합
        var text = templateHold.isEmpty ? s : (templateHold + s)
        templateHold.removeAll(keepingCapacity: false)
        // 2) 스캔
        var out = String()
        out.reserveCapacity(text.count)
        var i = text.startIndex
        let end = text.endIndex
        while i < end {
            let ch = text[i]
            if ch == "<" {
                let nextIdx = text.index(after: i)
                if nextIdx < end {
                    let nxt = text[nextIdx]
                    if nxt == "|" {
                        // Qwen: <| ... |>
                        if let close = text.range(of: "|>", range: nextIdx..<end) {
                            i = text.index(after: close.upperBound)
                            continue
                        } else {
                            templateHold = String(text[i..<end])
                            break
                        }
                    } else if nxt == "s" || nxt == "e" || nxt == "b" || nxt == "p" || nxt == "u" || nxt == "m" {
                        // Gemma/공통: <start_of_...> <end_of_...> <bos> <eos> <pad> <unk> <mask>
                        if let j = text[i...].firstIndex(of: ">") {
                            i = text.index(after: j)
                            continue
                        } else {
                            templateHold = String(text[i..<end])
                            break
                        }
                    }
                }
            }
            out.append(ch)
            i = text.index(after: i)
        }
        return out
    }

    // MARK: - Candidate building / TTI adaptation

    fileprivate func buildCandidates(preferred: OnDeviceModelID?) -> [OnDeviceModelID] {
        // 사용자가 명시적으로 선호 모델을 선택했고, 설정이 엄격 모드를 허용하면 해당 모델만 시도
        if let p = preferred, ConfigReader.bool("ONDEVICE_STRICT_PREFERRED", default: true) ?? true {
            return [p]
        }
        // 기본 순서: 사용자가 고른 모델(있으면) → SSOT fallbackOrder(중복 제거)
        var order: [OnDeviceModelID] = []
        if let p = preferred { order.append(p) }
        for m in ModelCatalog.fallbackOrder where !order.contains(m) { order.append(m) }

        // 최근 TTI 초과 카운트를 반영해, 과열 모델이 선두에 있으면 한 단계 아래부터 시도
        if let head = order.first, (ttiExceedCount[head] ?? 0) >= 2 {
            if let next = policy.nextCandidate(from: head, cause: "TTI_EXCEED_RECENT") {
                // next를 최우선으로 배치(중복 제거)
                var reordered = [next]
                for x in order where x != next { reordered.append(x) }
                order = reordered
                log.info("📉 TTI-adapt: prefer \(next.rawValue, privacy: .public) over \(head.rawValue, privacy: .public)")
            }
        }
        return order
    }

    fileprivate func updateTTICounters(id: OnDeviceModelID, ttiMs: Int) {
        q.sync {
            if ttiMs > policy.maxTTIMilliseconds {
                let cur = ttiExceedCount[id] ?? 0
                ttiExceedCount[id] = min(cur + 1, 4)
            } else {
                ttiExceedCount[id] = max((ttiExceedCount[id] ?? 0) - 1, 0)
            }
        }
    }

    // MARK: - Utilities

    /// Application Support/Models 경로에서 설치된 파일의 URL(존재 시) 반환
    fileprivate static func installedURL(fileName: String) -> URL? {
        guard
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else { return nil }
        let url = base.appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// RemoteAssetClient 재구성(엔드포인트 등).
    /// - Parameters:
    ///   - config: 새 원격 자산 클라이언트 설정
    ///   - cancelOngoing: true일 때만 진행 중 다운로드를 취소(파괴적). 기본은 false(비파괴).
    public func reconfigureRemote(config: RemoteAssetClient.Config, cancelOngoing: Bool = false) {
        q.sync {
            if cancelOngoing {
                for rec in ModelCatalog.all() {
                    self.remote.cancel(fileName: rec.fileName)
                }
            }
            self.remote = RemoteAssetClient(config: config)
        }
        if cancelOngoing {
            log.info("🔧 RemoteAssetClient reconfigured (cancelled outstanding model downloads)")
        } else {
            log.info("🔧 RemoteAssetClient reconfigured (non-destructive)")
        }
    }

    /// 엔드포인트 간편 재구성(서명 URL/고정 CDN/BG 세션 ID)
    /// - Parameters:
    ///   - presignEndpoint: 프리사인 엔드포인트(URL)
    ///   - cdnBaseURL: CDN 베이스(URL)
    ///   - backgroundSessionID: 백그라운드 세션 식별자
    ///   - cancelOngoing: true일 때만 진행 중 다운로드를 취소(파괴적). 기본은 false(비파괴).
    public func reconfigureRemote(
        presignEndpoint: URL?,
        cdnBaseURL: URL?,
        backgroundSessionID: String? = nil,
        cancelOngoing: Bool = false
    ) {
        var cfg = RemoteAssetClient.Config()
        cfg.presignEndpoint = presignEndpoint
        cfg.cdnBaseURL = cdnBaseURL
        if let sid = backgroundSessionID {
            cfg.backgroundSessionID = sid
        }
        reconfigureRemote(config: cfg, cancelOngoing: cancelOngoing)
    }

    /// 설치된 모델 파일 삭제(다운로드 취소 및 활성 세션 언로드 포함)
    public func deleteInstalled(id: OnDeviceModelID) throws {
        let rec = ModelCatalog.record(for: id)
        // 진행 중 작업이 있다면 취소
        remote.cancel(fileName: rec.fileName)
        // 활성 모델이면 먼저 언로드
        if loader.activeModelID == id {
            unload()
        }
        // 설치 파일 제거
        if let url = Self.installedURL(fileName: rec.fileName) {
            try FileManager.default.removeItem(at: url)
            log.info("🗑️ Deleted installed model: \(rec.displayName, privacy: .public)")
        }
    }

    /// 활성 세션 해제(메모리 반환). 전환 실패/온도 상승 시 상위에서 호출 가능.
    public func unload() {
        loader.unload()
        log.info("🧹 Unloaded on-device session")
    }

    /// 설치 디렉터리에서 카탈로그에 없는 과거/불필요 모델 파일을 정리한다.
    /// - Returns: 삭제된 파일 이름 배열
    @discardableResult
    public func purgeObsoleteInstalledFiles() -> [String] {
        var removed: [String] = []
        do {
            guard
                let base = FileManager.default.urls(
                    for: .applicationSupportDirectory, in: .userDomainMask
                ).first
            else { return [] }
            let dir = base.appendingPathComponent("Models", isDirectory: true)
            let exist = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            let keepSet = Set(ModelCatalog.all().map { $0.fileName })
            for name in exist where name.lowercased().hasSuffix(".gguf") {
                if !keepSet.contains(name) {
                    let url = dir.appendingPathComponent(name, isDirectory: false)
                    try? FileManager.default.removeItem(at: url)
                    removed.append(name)
                    log.info("🗑️ Purged obsolete model file: \(name)")
                }
            }
        } catch {
            log.error("⚠️ purgeObsoleteInstalledFiles error: \(error.localizedDescription)")
        }
        return removed
    }

    /// 전환 정책(폴백/TTI/열 완화) 설정(테스트/튜닝용).
    public func setPolicy(_ newPolicy: FallbackPolicy) {
        q.sync { self.policy = newPolicy }
    }
}
