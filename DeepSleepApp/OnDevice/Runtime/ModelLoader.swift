import Foundation
import os.log

#if canImport(llama)
    import llama
#elseif canImport(LlamaCpp)
    import LlamaCpp
#elseif canImport(LlamaFramework)
    import LlamaFramework
#endif

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

#if canImport(llama) || canImport(LlamaCpp) || canImport(LlamaFramework)
    // MARK: - 실제 llama.cpp 바인딩 (예시 스텁)
    // - 실제 API 타입/이니셜라이저/옵션 이름은 통합 시점에 맞춰 구현하세요.
    final class LlamaCppBindingImpl: LlamaCppBinding {
        private(set) var isLoaded: Bool = false
        private(set) var modelPath: String = ""

        // llama.cpp 핸들
        private var model: OpaquePointer?
        private var ctx: OpaquePointer?
        private var vocab: OpaquePointer?

        required init(
            modelPath: String,
            context: Int,
            threads: Int,
            gpuLayers: Int?,
            embeddingHBM: Bool?
        ) throws {
            self.modelPath = modelPath

            // 백엔드 초기화
            llama_backend_init()

            // 모델 로드
            var mparams = llama_model_default_params()
            if let ngl = gpuLayers {
                mparams.n_gpu_layers = Int32(ngl)
            }
            guard let model = modelPath.withCString({ llama_model_load_from_file($0, mparams) })
            else {
                throw OnDeviceError.engineNotInitialized
            }
            self.model = model

            // 컨텍스트 생성
            var cparams = llama_context_default_params()
            cparams.n_ctx = UInt32(max(256, context))
            cparams.n_threads = Int32(max(1, threads))
            guard let ctx = llama_init_from_model(model, cparams) else {
                llama_model_free(model)
                self.model = nil
                throw OnDeviceError.engineNotInitialized
            }
            self.ctx = ctx
            self.vocab = llama_model_get_vocab(model)

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
            guard isLoaded, let ctx = self.ctx, let model = self.model, let vocab = self.vocab
            else {
                throw OnDeviceError.engineNotInitialized
            }

            // 1) Chat template 적용 → 프롬프트 문자열 생성
            let maxLen = Int32(((system?.utf8.count ?? 0) + input.utf8.count) * 2 + 4096)
            var formatted = [CChar](repeating: 0, count: Int(maxLen))
            var promptBytes: Int32 = 0

            let roleUser = "user"
            let roleSystem = "system"

            if let system = system, !system.isEmpty {
                roleSystem.withCString { sysRoleC in
                    roleUser.withCString { usrRoleC in
                        system.withCString { sysC in
                            input.withCString { inpC in
                                var msgs = [
                                    llama_chat_message(role: sysRoleC, content: sysC),
                                    llama_chat_message(role: usrRoleC, content: inpC),
                                ]
                                // tmpl == nil → 모델 기본 템플릿 사용
                                promptBytes = llama_chat_apply_template(
                                    nil, &msgs, 2, true, &formatted, maxLen)
                            }
                        }
                    }
                }
            } else {
                roleUser.withCString { usrRoleC in
                    input.withCString { inpC in
                        var msgs = [llama_chat_message(role: usrRoleC, content: inpC)]
                        promptBytes = llama_chat_apply_template(
                            nil, &msgs, 1, true, &formatted, maxLen)
                    }
                }
            }

            if promptBytes <= 0 {
                throw OnDeviceError.unknown("prompt formatting failed (\(promptBytes))")
            }

            // 2) 토크나이즈
            var tokens = [llama_token](repeating: 0, count: Int(promptBytes) + 8)
            let nTok = llama_tokenize(
                vocab, formatted, promptBytes, &tokens, Int32(tokens.count), false, false)
            if nTok <= 0 {
                throw OnDeviceError.unknown("tokenize failed (\(nTok))")
            }

            // 3) 프롬프트 평가
            var batch = llama_batch_init(nTok, 0, 1)
            defer { llama_batch_free(batch) }
            batch.n_tokens = nTok
            for i in 0..<Int(nTok) {
                batch.token[i] = tokens[i]
                batch.pos[i] = Int32(i)
                batch.n_seq_id[i] = 1
                if let seq = batch.seq_id[i] { seq[0] = 0 }
                batch.logits[i] = (i == Int(nTok) - 1) ? 1 : 0
            }
            if llama_decode(ctx, batch) != 0 {
                throw OnDeviceError.unknown("llama_decode failed (prompt)")
            }

            // 4) 샘플러 체인 구성(temperature/top-k/top-p)
            var sparams = llama_sampler_chain_default_params()
            guard let smpl = llama_sampler_chain_init(sparams) else {
                throw OnDeviceError.unknown("sampler init failed")
            }
            defer { llama_sampler_free(smpl) }
            if topK > 0 {
                llama_sampler_chain_add(smpl, llama_sampler_init_top_k(Int32(topK)))
            }
            llama_sampler_chain_add(smpl, llama_sampler_init_top_p(Float(topP), 1))
            llama_sampler_chain_add(smpl, llama_sampler_init_temp(Float(temperature)))
            llama_sampler_chain_add(smpl, llama_sampler_init_dist(1234))

            // 5) 생성 루프(스트리밍)
            var n_cur = nTok
            var n_gen: Int32 = 0
            let maxGen: Int32 = 512

            while n_gen < maxGen {
                if Task.isCancelled {
                    throw OnDeviceError.generationCancelled
                }

                let new_id = llama_sampler_sample(smpl, ctx, -1)
                if llama_vocab_is_eog(vocab, new_id) {
                    break
                }

                // 토큰을 텍스트로 변환해 스트리밍 콜백
                var tmp = [CChar](repeating: 0, count: 8)
                let rc = llama_token_to_piece(vocab, new_id, &tmp, Int32(tmp.count), 0, false)
                var delta = ""
                if rc < 0 {
                    let need = -Int(rc)
                    tmp = [CChar](repeating: 0, count: need)
                    _ = llama_token_to_piece(vocab, new_id, &tmp, Int32(need), 0, false)
                    delta = String(cString: tmp + [0])
                } else {
                    let used = Int(rc)
                    tmp.removeLast(tmp.count - used)
                    delta = String(cString: tmp + [0])
                }
                if !delta.isEmpty {
                    onToken(delta)
                }

                // 단일 스텝 디코드
                var nb = llama_batch_init(1, 0, 1)
                nb.n_tokens = 1
                nb.token[0] = new_id
                nb.pos[0] = n_cur
                nb.n_seq_id[0] = 1
                if let seq = nb.seq_id[0] { seq[0] = 0 }
                nb.logits[0] = 1
                if llama_decode(ctx, nb) != 0 {
                    llama_batch_free(nb)
                    throw OnDeviceError.unknown("llama_decode failed (step)")
                }
                llama_batch_free(nb)

                n_cur += 1
                n_gen += 1
            }
        }

        func unload() {
            if let ctx = self.ctx {
                llama_free(ctx)
                self.ctx = nil
            }
            if let model = self.model {
                llama_model_free(model)
                self.model = nil
            }
            // 백엔드 정리
            llama_backend_free()
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

    // Loading guard helpers to avoid nested q.sync deadlocks
    func beginLoading() -> Bool {
        q.sync {
            if _loading { return false }
            _loading = true
            return true
        }
    }
    func endLoading() {
        q.sync { _loading = false }
    }
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
        guard state.beginLoading() else {
            throw OnDeviceError.unknown("동시 로딩은 지원하지 않습니다.")
        }
        defer { state.endLoading() }

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
        try await withTaskCancellationHandler {
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

        // 디버그: 현재 컴파일된 바인딩 브랜치 확인용 로그(운영 영향 없음)
        let log = OSLog(subsystem: "DeepSleep.OnDevice", category: "LlamaModelLoader")

        #if canImport(llama) || canImport(LlamaCpp) || canImport(LlamaFramework)
            os_log("🔧 binding flavor=real (llama/LlamaCpp/LlamaFramework) ctx=%{public}@ thr=%{public}@ ngl=%{public}@",
                   log: log, type: .info, String(ctx), String(thr), String(ngl ?? -1))
            return try LlamaCppBindingImpl(
                modelPath: modelPath,
                context: ctx,
                threads: thr,
                gpuLayers: ngl,
                embeddingHBM: hbm
            )
        #else
            os_log("🔧 binding flavor=noop (no llama framework available)", log: log, type: .error)
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
