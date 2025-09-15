import Foundation
import os.log

// MARK: - 온디바이스 LLM 런타임: llama.cpp 바인딩 어댑터 스텁
// - 단일 출처(SSOT): 모델 ID/파일명/권장 파라미터는 ModelCatalog.swift만 참조
// - 본 파일은 엔진 바인딩 추상화와 로더를 제공합니다.
// - 실제 llama.cpp iOS 바인딩은 조건부 컴파일(#if canImport)로 분리하며,
//   바인딩이 없을 경우 안전하게 오류를 던져 상위 폴백(기본/클라우드)로 전환되도록 합니다.
//
// 설계 원칙:
// - KISS/DRY/YAGNI: 꼭 필요한 최소 API만 노출, 중복 로직 금지
// - SOLID: 인터페이스 분리(바인딩/로더/무결성은 별 책임), 의존 역전(로더 ← 바인딩)
// - "비슷한 로직 중복 금지": 파라미터 매핑/프롬프트 조립/무결성은 기존 SSOT 함수만 사용
//
// 주의:
// - GGUF 메타의 채팅 템플릿/토크나이저는 엔진에 위임해야 합니다(수동 포맷팅 금지).
// - 시스템 프롬프트는 ModelCatalog.SystemPrompts.empathyKR 또는 호출자 제공값 사용.

#if canImport(Combine)
    import Combine
#endif

// MARK: - 바깥에서 제공되는 타입들 (ModelCatalog.swift)
// public enum OnDeviceModelID: String, CaseIterable, Sendable { ... }
// public struct InferenceParams { context, threads, temperature, topK, topP, gpuLayers, embeddingHBM }
// public enum OnDeviceError: Error, LocalizedError { ... }
// public enum SystemPrompts { static let empathyKR: String = "..." }
// public protocol OnDeviceModelLoader { ... }

// MARK: - 내부 바인딩 추상화(엔진 인터페이스)

/// llama.cpp 바인딩이 만족해야 하는 최소 기능 집합
/// - 구현체는 GGUF 메타의 chat-template을 자동 사용해야 합니다.
protocol LlamaCppBinding: Sendable {
    var isLoaded: Bool { get }
    var modelPath: String { get }

    init(
        modelPath: String,
        context: Int,
        threads: Int,
        gpuLayers: Int?,
        embeddingHBM: Bool?
    ) throws

    /// 스트리밍 생성
    /// - 엔진 내부에서 stop 조건/Task.isCancelled를 주기적으로 확인해야 합니다.
    func generate(
        input: String,
        system: String?,
        temperature: Double,
        topK: Int,
        topP: Double,
        onToken: @escaping @Sendable (String) -> Void
    ) throws

    func unload()
}

#if canImport(LlamaCpp)
    // MARK: - 실제 llama.cpp 바인딩 (예시 스텁)
    // - 실제 API 타입/이니셜라이저/옵션 이름은 통합 시점에 맞춰 구현하세요.
    final class LlamaCppBindingImpl: LlamaCppBinding {
        private(set) var isLoaded: Bool = false
        private(set) var modelPath: String = ""

        // MLtodo: 실제 llama.cpp 세션/컨텍스트 핸들 보관용 프로퍼티
        // private var ctx: llama_context_t?

        required init(
            modelPath: String,
            context: Int,
            threads: Int,
            gpuLayers: Int?,
            embeddingHBM: Bool?
        ) throws {
            self.modelPath = modelPath
            // MLtodo: llama.cpp 초기화 로직 구현(메탈 백엔드/ggml 설정 포함)
            // - context(프롬프트 길이), threads, n_gpu_layers(gpuLayers) 매핑
            // - emb-hbm/계산 정밀도 옵션
            // - 실패 시 throw OnDeviceError.engineNotInitialized
            self.isLoaded = true
        }

        func generate(
            input: String,
            system: String?,
            temperature: Double,
            topK: Int,
            topP: Double,
            onToken: @escaping @Sendable (String) -> Void
        ) throws {
            guard isLoaded else { throw OnDeviceError.engineNotInitialized }
            // MLtodo: 엔진에 system(있으면) + input을 전달(채팅 템플릿 자동)
            // - 스트리밍 토큰 콜백 발생 시 onToken(delta) 호출
            // - Task.isCancelled 감지 후 안전 종료
            // - 샘플링: temperature/topK/topP 전달
            // - 오류 시 적절히 throw
        }

        func unload() {
            // MLtodo: llama_free 등 리소스 해제
            isLoaded = false
        }
    }
#endif

// MARK: - 바인딩이 없는 환경용 No-Op (iOS 18 미만/바이너리 미연동 시)
final class NoopLlamaBinding: LlamaCppBinding {
    private(set) var isLoaded: Bool = false
    private(set) var modelPath: String = ""

    required init(
        modelPath: String,
        context: Int,
        threads: Int,
        gpuLayers: Int?,
        embeddingHBM: Bool?
    ) throws {
        self.modelPath = modelPath
        // 바인딩 없음: 즉시 실패 유도(상위 폴백 트리거)
        throw OnDeviceError.engineNotInitialized
    }

    func generate(
        input: String,
        system: String?,
        temperature: Double,
        topK: Int,
        topP: Double,
        onToken: @escaping @Sendable (String) -> Void
    ) throws {
        throw OnDeviceError.engineNotInitialized
    }

    func unload() {
        // no-op
        isLoaded = false
    }
}

// MARK: - 스레드 안전 상태 보관 상자
/// 단순 직렬 큐 기반 스레드 세이프 상태 관리(KISS)
private final class EngineStateBox {
    private let q = DispatchQueue(label: "ondevice.llama.loader", qos: .userInitiated)
    private var _engine: (any LlamaCppBinding)?
    private var _activeID: OnDeviceModelID?
    private var _loading: Bool = false

    var engine: (any LlamaCppBinding)? {
        get { q.sync { _engine } }
        set { q.sync { _engine = newValue } }
    }

    var activeID: OnDeviceModelID? {
        get { q.sync { _activeID } }
        set { q.sync { _activeID = newValue } }
    }

    var isLoading: Bool {
        get { q.sync { _loading } }
        set { q.sync { _loading = newValue } }
    }

    func sync<T>(_ block: () throws -> T) rethrows -> T { try q.sync(execute: block) }
}

// MARK: - Llama.cpp 기반 ModelLoader 구현
public final class LlamaModelLoader: OnDeviceModelLoader {
    // 상태
    private let state = EngineStateBox()
    private let log = OSLog(subsystem: "DeepSleep.OnDevice", category: "LlamaModelLoader")

    public init() {}

    public var isLoaded: Bool {
        state.engine?.isLoaded ?? false
    }

    public var activeModelID: OnDeviceModelID? {
        state.activeID
    }

    // MARK: - Load/Unload/Hot-Swap

    public func load(modelURL: URL, modelID: OnDeviceModelID, params: InferenceParams) throws {
        try state.sync {
            guard !state.isLoading else {
                throw OnDeviceError.unknown("동시 로딩은 지원하지 않습니다.")
            }
            state.isLoading = true
        }
        defer { state.isLoading = false }

        // 이전 세션 있으면 안전 해제
        if let eng = state.engine {
            os_log("🔄 이전 세션 해제", log: log, type: .info)
            eng.unload()
            state.engine = nil
            state.activeID = nil
        }

        let path = modelURL.path
        os_log(
            "🚚 모델 로드 시작(%{public}@) id=%{public}@ ctx=%{public}d thr=%{public}d ngl=%{public}@",
            log: log, type: .info,
            (path as NSString).lastPathComponent, modelID.rawValue, params.context, params.threads,
            String(params.gpuLayers ?? -1))

        // 바인딩 생성
        let binding: any LlamaCppBinding
        do {
            binding = try Self.makeBinding(
                modelPath: path,
                params: params
            )
        } catch {
            os_log("❌ 바인딩 생성 실패: %{public}@", log: log, type: .error, String(describing: error))
            throw error
        }

        // 성공 적용
        state.engine = binding
        state.activeID = modelID
        os_log("✅ 모델 로드 완료: %{public}@", log: log, type: .info, modelID.rawValue)
    }

    public func switchModel(to modelID: OnDeviceModelID, modelURL: URL, params: InferenceParams)
        async throws
    {
        // 단순: unload → load
        unload()
        try load(modelURL: modelURL, modelID: modelID, params: params)
    }

    public func unload() {
        if let eng = state.engine {
            os_log("🧹 세션 해제", log: log, type: .info)
            eng.unload()
        }
        state.engine = nil
        state.activeID = nil
    }

    // MARK: - Generation

    public func generate(
        input: String,
        systemPrompt: String?,
        params: InferenceParams,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws {
        // 상태 점검
        guard let eng = state.engine, eng.isLoaded else {
            throw OnDeviceError.engineNotInitialized
        }

        let sys = (systemPrompt?.isEmpty == false) ? systemPrompt : SystemPrompts.empathyKR

        // 1st-token 시간 측정
        let t0 = CFAbsoluteTimeGetCurrent()
        var emittedFirst = false
        let wrappedOnToken: @Sendable (String) -> Void = { delta in
            if !emittedFirst {
                emittedFirst = true
                let ms = Int((CFAbsoluteTimeGetCurrent() - t0) * 1000)
                os_log("⏱️ firstTokenMs=%{public}d", log: self.log, type: .info, ms)
            }
            onToken(delta)
        }

        // 실제 엔진 호출은 동기 API로 감싸두고, Task 취소 여부는 내부/외부에서 모두 주기 확인
        try Task.checkCancellation()
        try withTaskCancellationHandler {
            // 취소 시점: 엔진이 내부 루프에서 Task.isCancelled 확인해야 즉시 중단 가능
        } operation: {
            try eng.generate(
                input: input,
                system: sys,
                temperature: params.temperature,
                topK: params.topK,
                topP: params.topP,
                onToken: wrappedOnToken
            )
        }

        try Task.checkCancellation()
    }

    // MARK: - 바인딩 선택(조건부 컴파일)

    private static func makeBinding(modelPath: String, params: InferenceParams) throws
        -> any LlamaCppBinding
    {
        // 단일 출처: 파라미터 매핑은 여기서만 수행
        let ctx = max(256, params.context)
        let thr = max(1, params.threads)
        let ngl = params.gpuLayers
        let hbm = params.embeddingHBM

        #if canImport(LlamaCpp)
            return try LlamaCppBindingImpl(
                modelPath: modelPath,
                context: ctx,
                threads: thr,
                gpuLayers: ngl,
                embeddingHBM: hbm
            )
        #else
            // 바인딩 없음 → 즉시 실패(상위 자동 폴백)
            return try NoopLlamaBinding(
                modelPath: modelPath,
                context: ctx,
                threads: thr,
                gpuLayers: ngl,
                embeddingHBM: hbm
            )
        #endif
    }
}

// MARK: - 편의 확장: OnDeviceModelLoader 인터페이스 보완
extension OnDeviceModelLoader {
    /// 단발 텍스트 생성(전체 문자열 반환) — 스트리밍 콜백을 내부 버퍼로 흡수
    /// - 주의: 장문 생성은 메모리/시간 비용이 커질 수 있으니 UI에서 제한하세요.
    public func generateToString(
        input: String,
        systemPrompt: String?,
        params: InferenceParams
    ) async throws -> String {
        var acc = ""
        try await generate(input: input, systemPrompt: systemPrompt, params: params) { delta in
            acc += delta
        }
        return acc
    }
}

// MARK: - 문서 메모
// iPhone 12(A14, 4GB) 권장 시작값:
// - context=2048, threads=4, ngl=max(가능하면 모든 레이어 메탈), emb-hbm=auto
// - 270M: temp=1.0, top_k=64, top_p=0.95
// - 0.5B/1B: temp=0.7~0.9, top_k=64, top_p=0.95
// - 시스템 프롬프트: SystemPrompts.empathyKR 고정 사용(상황에 따라 호출자가 대체 가능)
//
// 실패/발열/지연>4s 연속: 상위 FallbackPolicy 로직으로 270M/0.5B/1B/클라우드 순 전환
