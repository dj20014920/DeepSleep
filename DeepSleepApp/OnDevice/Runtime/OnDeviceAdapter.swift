import Foundation
import OSLog

// MARK: - OnDeviceAdapter
// UnifiedAIService와 온디바이스 런타임(Background Assets + llama.cpp)을 연결하는 단일 어댑터.
// - DRY/SSOT: 모델 메타/권장 파라미터/시스템 프롬프트는 ModelCatalog와 SystemPrompts에서만 읽는다.
// - 책임 분리: 설치/무결성은 BackgroundAssetClient+CatalogResolver, 로딩/생성은 OnDeviceModelLoader 담당.
// - KISS: UnifiedAIService는 본 어댑터의 간단한 API를 통해 on-device 경로를 호출한다.
public final class OnDeviceAdapter: @unchecked Sendable {

    // MARK: Singleton
    public static let shared = OnDeviceAdapter()

    // MARK: Dependencies
    private let log = Logger(subsystem: "DeepSleep.OnDevice", category: "Adapter")
    private let baClient: BackgroundAssetClient
    private let loader: OnDeviceModelLoader
    private let resolver: CatalogResolver

    // 전환/성능 정책
    private var policy = FallbackPolicy()

    // 성능 적응(모델별 TTI 초과 카운트)
    private var ttiExceedCount: [OnDeviceModelID: Int] = [:]

    // 동시성 보호(간단 직렬 큐)
    private let q = DispatchQueue(label: "DeepSleep.OnDevice.Adapter", qos: .userInitiated)

    // MARK: State
    public private(set) var activeModelID: OnDeviceModelID? {
        get { q.sync { loader.activeModelID } }
        set { /* read-only 바인딩: loader.switchModel에서 갱신됨 */  }
    }

    private init() {
        // 환경에 맞는 BA 클라이언트 생성(iOS18+ 또는 Noop)
        self.baClient = BackgroundAssetClientFactory.make()
        self.resolver = CatalogResolver(baClient: baClient)
        // llama.cpp 기반 로더(조건부 컴파일된 바인딩 사용)
        self.loader = LlamaModelLoader()
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
        public init(systemPrompt: String? = nil, params: InferenceParams? = nil) {
            self.systemPrompt = systemPrompt
            self.params = params
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
                group.addTask { [baClient] in
                    let st = await baClient.status(packID: r.packID, fileName: r.fileName)
                    return ModelEntry(record: r, state: st)
                }
            }
            var result: [ModelEntry] = []
            for await e in group {
                result.append(e)
            }
            return result
        }
    }

    /// 특정 모델의 BA 상태를 조회한다.
    public func status(for id: OnDeviceModelID) async -> BackgroundAssetState {
        let r = ModelCatalog.record(for: id)
        return await baClient.status(packID: r.packID, fileName: r.fileName)
    }

    // MARK: - Install/Ensure

    /// BA 설치 보장(무결성 검증 포함). 진행률 콜백 지원.
    @discardableResult
    public func ensureInstalled(
        id: OnDeviceModelID,
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        let rec = ModelCatalog.record(for: id)
        // CatalogResolver가 sha256(있으면) 검증 수행
        let url = try await resolver.resolveLocalURL(for: id, progress: progress)
        log.info(
            "📦 Installed/Ready: \(rec.displayName, privacy: .public) @\(url.lastPathComponent, privacy: .public)"
        )
        return url
    }

    /// 다운로드/설치를 취소한다.
    public func cancelInstall(id: OnDeviceModelID) {
        let rec = ModelCatalog.record(for: id)
        baClient.cancel(packID: rec.packID)
    }

    // MARK: - Activate / Switch

    /// 모델을 활성화(로드)한다. 이미 로드된 동일 모델이면 noop.
    public func activate(id: OnDeviceModelID) async throws {
        let rec = ModelCatalog.record(for: id)
        let url = try await ensureInstalled(id: id)
        // 동일이면 스킵
        if loader.activeModelID == id, loader.isLoaded {
            log.info("🔁 Already active: \(rec.displayName, privacy: .public)")
            return
        }
        // 권장 파라미터로 세션 로드
        try loader.load(modelURL: url, modelID: id, params: rec.recommended)
        log.info("🚀 Activated: \(rec.displayName, privacy: .public)")
    }

    /// 모델을 교체(핫스왑)한다. 설치-확보 → 세션 재생성.
    public func switchModel(id: OnDeviceModelID) async throws {
        let rec = ModelCatalog.record(for: id)
        let url = try await ensureInstalled(id: id)
        try await loader.switchModel(to: id, modelURL: url, params: rec.recommended)
        log.info("♻️ Switched: \(rec.displayName, privacy: .public)")
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
        // 1) 후보 결정
        let candidates = buildCandidates(preferred: preferred)
        var lastError: Error?

        for (idx, id) in candidates.enumerated() {
            do {
                let summary = try await runOnce(
                    id: id, input: input, config: config, onToken: onToken)
                // TTI 정책 카운트 업데이트
                self.updateTTICounters(id: id, ttiMs: summary.ttiMilliseconds)
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

        // 0) 설치 보장(무결성 포함)
        let _ = try await ensureInstalled(id: id)

        // 1) 세션 준비/전환
        if loader.activeModelID != id || !loader.isLoaded {
            try await switchModel(id: id)
        }

        // 2) 파라미터 구성(SSOT 권장값 기반)
        let rec = ModelCatalog.record(for: id)
        let params = config.params ?? rec.recommended
        let system =
            (config.systemPrompt?.isEmpty == false) ? config.systemPrompt : SystemPrompts.empathyKR

        // 3) 스트리밍 생성(TTI 측정)
        let started = Date()
        var emittedFirst = false
        var ttiMs: Int = -1

        do {
            try await loader.generate(
                input: input,
                systemPrompt: system,
                params: params
            ) { delta in
                if !emittedFirst {
                    emittedFirst = true
                    ttiMs = Int(Date().timeIntervalSince(started) * 1000)
                    self.log.info(
                        "⏱️ TTI=\(ttiMs, privacy: .public)ms [\(id.rawValue, privacy: .public)]")
                }
                onToken(delta)
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

        let finished = Date()
        let usedTTI = max(0, ttiMs)
        return GenerationSummary(
            modelID: id, ttiMilliseconds: usedTTI, startedAt: started, finishedAt: finished)
    }

    // MARK: - Candidate building / TTI adaptation

    private func buildCandidates(preferred: OnDeviceModelID?) -> [OnDeviceModelID] {
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
                log.info(
                    "📉 TTI-adapt: prefer \(next.rawValue, privacy: .public) over \(head.rawValue, privacy: .public)"
                )
            }
        }
        return order
    }

    private func updateTTICounters(id: OnDeviceModelID, ttiMs: Int) {
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

    /// 활성 세션 해제(메모리 반환). 전환 실패/온도 상승 시 상위에서 호출 가능.
    public func unload() {
        loader.unload()
        log.info("🧹 Unloaded on-device session")
    }

    /// 전환 정책(폴백/TTI/열 완화) 설정(테스트/튜닝용).
    public func setPolicy(_ newPolicy: FallbackPolicy) {
        q.sync { self.policy = newPolicy }
    }
}
