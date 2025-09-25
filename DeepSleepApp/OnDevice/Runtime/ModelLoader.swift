import Darwin
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

    /// 스트리밍 생성(레거시 전체 경로) - 유지
    /// - 엔진 내부에서 stop 조건/Task.isCancelled를 주기적으로 확인해야 합니다.
    func generate(
        input: String,
        system: String?,
        temperature: Double,
        topK: Int,
        topP: Double,
        onToken: @escaping @Sendable (String) -> Void
    ) throws

    /// 세션 스냅샷 저장(KV 포함)
    func saveState() throws -> Data

    /// 세션 스냅샷 복원(KV 포함)
    func loadState(_ data: Data) throws

    /// 시스템 프롬프트만 프리필(토큰화+디코드). 반환: 누적 토큰 수(프리픽스 길이)
    func prefillSystem(_ system: String) throws -> Int

    /// 임의의 접두 텍스트(직렬화된 recent 3+3 등)를 프리필
    /// - 반환: 누적 토큰 수 증가분(해당 텍스트 토큰 길이)
    func prefillText(_ text: String) throws -> Int

    /// 복원/프리필 이후 사용자 입력만 이어서 평가 + 생성 루프 시작
    /// - startPos: 프리필된 마지막 토큰 위치 다음 시작 위치
    func generateResuming(
        input: String,
        startPos: Int32,
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
    final class LlamaCppBindingImpl: LlamaCppBinding, KVPromptCache.LlamaSessionIO {
        private(set) var isLoaded: Bool = false
        private(set) var modelPath: String = ""

        // llama.cpp 핸들
        private var model: OpaquePointer?
        private var ctx: OpaquePointer?
        private var vocab: OpaquePointer?
        // 모델 메타에서 추론되는 종료/전환 토큰 ID 캐시
        // - 일부 모델(Gemma: <end_of_turn>, Qwen: <|im_end|>)은 서로 다른 EOT 토큰을 사용
        // - 추가로 다음 턴 시작 토큰(<start_of_turn>, <|im_start|>)이 출력되면 즉시 종료하는 것이 안전
        private var stopTokenSet = Set<llama_token>()
        private var stopLiterals: [String] = []  // 문자열 시퀀스 형태의 stop (OnDeviceAdapter → InferenceParams.stops)
        public func setStopLiterals(_ arr: [String]) { self.stopLiterals = arr }

        // 동시성 제어: llama_* 호출은 동시 실행되면 안 됨 (이진 세마포어)
        private let useLock = DispatchSemaphore(value: 1)
        // 언로드 요청 시 생성 루프가 조기 중단할 수 있도록 신호
        private var stopRequested = false
        // 접두 프리필 누적 위치(시스템+최근 대화). resume 시 startPos 계산과 일치해야 함.
        private var prefillPos: Int32 = 0

        required init(
            modelPath: String,
            context: Int,
            threads: Int,
            gpuLayers: Int?,
            embeddingHBM: Bool?
        ) throws {
            self.stopLiterals = []
            self.modelPath = modelPath

            // 백엔드 초기화(로그 억제: INFO 이하 숨김)
            _ = setenv("GGML_LOG_LEVEL", "3", 1)
            _ = setenv("LLAMA_LOG_LEVEL", "3", 1)
            _ = setenv("LLAMA_LOG_COLORS", "0", 1)
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
            // 메타에서 종료 관련 토큰들을 가능한 한 많이 확보
            if let v = self.vocab {
                let candidates = [
                    "<end_of_turn>",  // Gemma 3 (end)
                    "<|im_end|>",  // Qwen, 일부 OpenAI 스타일 gguf (end)
                    "<|eot_id|>",  // 기타 (end)
                    "<start_of_turn>",  // 다음 턴 시작도 출력되면 즉시 중단
                    "<|im_start|>",  // OpenAI 스타일 시작 토큰
                ]
                for lit in candidates {
                    var tmp = [llama_token](repeating: 0, count: 8)
                    lit.withCString { cstr in
                        let n = llama_tokenize(
                            v, cstr, Int32(strlen(cstr)), &tmp, Int32(tmp.count), false, true)
                        if n == 1 { self.stopTokenSet.insert(tmp[0]) }
                    }
                }
            }

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

            // Acquire engine lock for the entire generation to prevent unload/free races
            useLock.wait()
            defer { useLock.signal() }
            stopRequested = false
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
                                formatted.withUnsafeMutableBufferPointer { buf in
                                    promptBytes = llama_chat_apply_template(
                                        nil, &msgs, 2, true, buf.baseAddress, maxLen)
                                }
                            }
                        }
                    }
                }
            } else {
                roleUser.withCString { usrRoleC in
                    input.withCString { inpC in
                        var msgs = [llama_chat_message(role: usrRoleC, content: inpC)]
                        formatted.withUnsafeMutableBufferPointer { buf in
                            promptBytes = llama_chat_apply_template(
                                nil, &msgs, 1, true, buf.baseAddress, maxLen)
                        }
                    }
                }
            }

            if promptBytes <= 0 {
                throw OnDeviceError.unknown("prompt formatting failed (\(promptBytes))")
            }

            // 2) 토크나이즈 (널 종료 및 버퍼 크기 방어)
            var tokens = [llama_token](repeating: 0, count: max(16, Int(promptBytes) + 8))
            let ntotal = Int(promptBytes)
            if ntotal >= formatted.count { throw OnDeviceError.unknown("prompt overflow") }
            formatted[ntotal] = 0  // C 문자열 보장
            let nTok = llama_tokenize(
                vocab, &formatted, Int32(ntotal), &tokens, Int32(tokens.count), false, true
            )
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

            // 4) 샘플러 체인 구성(temperature/top-k/top-p + 반복 억제)
            var sparams = llama_sampler_chain_default_params()
            guard let smpl = llama_sampler_chain_init(sparams) else {
                throw OnDeviceError.unknown("sampler init failed")
            }
            defer { llama_sampler_free(smpl) }
            if topK > 0 {
                llama_sampler_chain_add(smpl, llama_sampler_init_top_k(Int32(topK)))
            }
            llama_sampler_chain_add(smpl, llama_sampler_init_top_p(Float(topP), 1))
            // 반복 억제: last_n=256, repeat=1.2, freq/present=0.0 (경량 모델 안정화)
            llama_sampler_chain_add(smpl, llama_sampler_init_penalties(256, 1.20, 0.0, 0.0))
            llama_sampler_chain_add(smpl, llama_sampler_init_temp(Float(temperature)))
            llama_sampler_chain_add(smpl, llama_sampler_init_dist(1234))
            // stops 적용: 사전 토큰화된 stopTokenSet 기반 + setStopLiterals로 전달된 문자열을 토크나이즈 후 병합
            if let v = self.vocab {
                for lit in self.stopLiterals {
                    var tmp = [llama_token](repeating: 0, count: 8)
                    let n = lit.withCString { cstr in
                        llama_tokenize(
                            v, cstr, Int32(strlen(cstr)), &tmp, Int32(tmp.count), false, true)
                    }
                    if n == 1 { self.stopTokenSet.insert(tmp[0]) }
                }
            }

            // 5) 생성 루프(스트리밍)
            var n_cur = nTok
            var n_gen: Int32 = 0
            let maxGen: Int32 = Int32(ConfigReader.int("ONDEVICE_MAX_TOKENS", default: 128) ?? 128)
            var accText = ""
            var stopByLiteral = false

            while n_gen < maxGen {
                if Task.isCancelled || stopRequested {
                    throw OnDeviceError.generationCancelled
                }
                let new_id = llama_sampler_sample(smpl, ctx, -1)
                // 1) 모델 메타 지정 EOG 우선
                var reachedEnd = llama_vocab_is_eog(vocab, new_id)
                // 2) 템플릿 종료 토큰 집합에 속하면 종료
                if !reachedEnd && self.stopTokenSet.contains(new_id) {
                    reachedEnd = true
                }
                if reachedEnd { break }

                // 토큰을 텍스트로 변환해 스트리밍 콜백
                var tmp = [CChar](repeating: 0, count: 8)
                let rc = llama_token_to_piece(vocab, new_id, &tmp, Int32(tmp.count), 0, false)
                var delta = ""
                if rc < 0 {
                    let need = max(8, -Int(rc))
                    tmp = [CChar](repeating: 0, count: need)
                    _ = llama_token_to_piece(vocab, new_id, &tmp, Int32(need), 0, false)
                    delta = String(cString: tmp + [0])
                } else if rc > 0 {
                    let used = Int(rc)
                    if used < tmp.count { tmp[used] = 0 }
                    delta = String(cString: tmp)
                }
                if !delta.isEmpty {
                    accText += delta
                    // 리터럴 기반 중단 시퀀스 검사(문자열 조합 기준)
                    if !self.stopLiterals.isEmpty {
                        for lit in self.stopLiterals {
                            if accText.contains(lit) {
                                stopByLiteral = true
                                break
                            }
                        }
                    }
                    if stopByLiteral {
                        // 마지막에 누적된 stop 리터럴은 사용자에게 스트리밍하지 않도록 잘라낸 후 전달
                        var trimmed = accText
                        for lit in self.stopLiterals {
                            trimmed = trimmed.replacingOccurrences(of: lit, with: "")
                        }
                        if !trimmed.isEmpty { onToken(trimmed) }
                        break
                    } else {
                        onToken(delta)
                    }
                }

                // 단일 스텝 ��������
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
            // Request cancellation and wait for any ongoing generation to finish
            stopRequested = true
            useLock.wait()
            defer { useLock.signal() }

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
            prefillPos = 0
            isLoaded = false
            stopRequested = false
        }

        // MARK: - KV session I/O
        func saveState() throws -> Data {
            guard let ctx = self.ctx else { throw OnDeviceError.engineNotInitialized }
            let size = llama_state_get_size(ctx)
            var buf = Data(count: size)
            let written = buf.withUnsafeMutableBytes {
                (ptr: UnsafeMutableRawBufferPointer) -> Int in
                guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return 0
                }
                return llama_state_get_data(ctx, base, size)
            }
            if written <= 0 { throw OnDeviceError.unknown("state_get_data failed") }
            if written != size { buf.removeSubrange(written..<size) }
            return buf
        }

        func loadState(_ data: Data) throws {
            guard let ctx = self.ctx else { throw OnDeviceError.engineNotInitialized }
            let read = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int in
                guard let base = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return 0
                }
                return llama_state_set_data(ctx, base, data.count)
            }
            if read <= 0 { throw OnDeviceError.unknown("state_set_data failed") }
        }

        // MARK: - Prefix prefill and resume APIs
        func prefillSystem(_ system: String) throws -> Int {
            guard let ctx = self.ctx, let vocab = self.vocab else {
                throw OnDeviceError.engineNotInitialized
            }
            // 엔진 리소스 경합 방지: prefill 동안 언로드/다른 호출과 겹치지 않도록 전체 잠금
            useLock.wait()
            defer { useLock.signal() }
            if stopRequested || Task.isCancelled { throw OnDeviceError.generationCancelled }
            // 새로운 프리필 체인 시작 시 접두 위치를 초기화
            prefillPos = 0

            // chat template로 system만 포맷
            let roleSystem = "system"
            let maxLen = Int32(system.utf8.count * 2 + 1024)
            var formatted = [CChar](repeating: 0, count: Int(maxLen))
            var promptBytes: Int32 = 0
            roleSystem.withCString { sysRoleC in
                system.withCString { sysC in
                    var msgs = [llama_chat_message(role: sysRoleC, content: sysC)]
                    formatted.withUnsafeMutableBufferPointer { buf in
                        promptBytes = llama_chat_apply_template(
                            nil, &msgs, 1, true, buf.baseAddress, maxLen)
                    }
                }
            }
            if promptBytes <= 0 {
                throw OnDeviceError.unknown("system prompt formatting failed (\(promptBytes))")
            }

            // 토큰화 후 디코드 (logits 출력은 마지막 토큰만) — 버퍼 방어 + 널 종료
            var tokens = [llama_token](repeating: 0, count: max(16, Int(promptBytes) + 8))
            let ntotal = Int(promptBytes)
            if ntotal >= formatted.count { throw OnDeviceError.unknown("prefill prompt overflow") }
            formatted[ntotal] = 0
            let nTok = llama_tokenize(
                vocab, &formatted, Int32(ntotal), &tokens, Int32(tokens.count), false, true
            )
            if nTok <= 0 { throw OnDeviceError.unknown("tokenize failed (\(nTok))") }

            var batch = llama_batch_init(nTok, 0, 1)
            defer { llama_batch_free(batch) }
            batch.n_tokens = nTok
            for i in 0..<Int(nTok) {
                batch.token[i] = tokens[i]
                batch.pos[i] = prefillPos + Int32(i)
                batch.n_seq_id[i] = 1
                if let seq = batch.seq_id[i] { seq[0] = 0 }
                batch.logits[i] = (i == Int(nTok) - 1) ? 1 : 0
            }
            if llama_decode(ctx, batch) != 0 {
                throw OnDeviceError.unknown("llama_decode failed (system prefill)")
            }
            prefillPos += nTok
            return Int(nTok)
        }

        // 새 접두 텍스트 프리필: 직렬화된 recent 3+3 등에 사용
        func prefillText(_ text: String) throws -> Int {
            guard let ctx = self.ctx, let vocab = self.vocab else {
                throw OnDeviceError.engineNotInitialized
            }
            // 엔진 리소스 경합 방지: prefill 동안 언로드/다른 호출과 겹치지 않도록 전체 잠금
            useLock.wait()
            defer { useLock.signal() }
            if stopRequested || Task.isCancelled { throw OnDeviceError.generationCancelled }

            // 템플릿 적용 없이 순수 텍스트 토큰화 → 디코드
            var tokens = [llama_token](repeating: 0, count: max(16, text.utf8.count * 2))
            let nTok = text.withCString { cstr in
                llama_tokenize(
                    vocab, cstr, Int32(strlen(cstr)), &tokens, Int32(tokens.count), false, false
                )
            }
            if nTok <= 0 { throw OnDeviceError.unknown("tokenize failed (prefillText)") }

            var batch = llama_batch_init(nTok, 0, 1)
            defer { llama_batch_free(batch) }
            batch.n_tokens = nTok
            for i in 0..<Int(nTok) {
                batch.token[i] = tokens[i]
                batch.pos[i] = prefillPos + Int32(i)
                batch.n_seq_id[i] = 1
                if let seq = batch.seq_id[i] { seq[0] = 0 }
                batch.logits[i] = (i == Int(nTok) - 1) ? 1 : 0
            }
            if llama_decode(ctx, batch) != 0 {
                throw OnDeviceError.unknown("llama_decode failed (prefillText)")
            }
            prefillPos += nTok
            return Int(nTok)
        }

        func generateResuming(
            input: String,
            startPos: Int32,
            temperature: Double,
            topK: Int,
            topP: Double,
            onToken: @escaping @Sendable (String) -> Void
        ) throws {
            guard let ctx = self.ctx, let vocab = self.vocab else {
                throw OnDeviceError.engineNotInitialized
            }

            // 엔진 리소스 경합 방지: 전체 작업 동안 락을 획득하여 언로드와의 레이스를 차단
            useLock.wait()
            defer { useLock.signal() }
            if stopRequested || Task.isCancelled { throw OnDeviceError.generationCancelled }

            // 토큰화
            var tokens = [llama_token](repeating: 0, count: max(16, input.utf8.count * 2))
            let nTok = input.withCString { cstr in
                llama_tokenize(
                    vocab, cstr, Int32(strlen(cstr)), &tokens, Int32(tokens.count), false, false)
            }
            if nTok <= 0 { throw OnDeviceError.unknown("tokenize failed (resume)") }

            // 샘플러
            var sparams = llama_sampler_chain_default_params()
            guard let smpl = llama_sampler_chain_init(sparams) else {
                throw OnDeviceError.unknown("sampler init failed")
            }
            defer { llama_sampler_free(smpl) }
            if topK > 0 { llama_sampler_chain_add(smpl, llama_sampler_init_top_k(Int32(topK))) }
            llama_sampler_chain_add(smpl, llama_sampler_init_top_p(Float(topP), 1))
            // 반복 억제: last_n=256, repeat=1.2, freq/present=0.0 (경량 모델 안정화)
            llama_sampler_chain_add(smpl, llama_sampler_init_penalties(256, 1.20, 0.0, 0.0))
            llama_sampler_chain_add(smpl, llama_sampler_init_temp(Float(temperature)))
            llama_sampler_chain_add(smpl, llama_sampler_init_dist(1234))

            var curPos = startPos

            // 입력 토큰을 먼저 주입하여 컨텍스트를 최신 위치로 맞춤
            for i in 0..<Int(nTok) {
                if Task.isCancelled || stopRequested { throw OnDeviceError.generationCancelled }
                var nb = llama_batch_init(1, 0, 1)
                nb.n_tokens = 1
                nb.token[0] = tokens[i]
                nb.pos[0] = curPos
                nb.n_seq_id[0] = 1
                if let seq = nb.seq_id[0] { seq[0] = 0 }
                nb.logits[0] = 1
                if llama_decode(ctx, nb) != 0 {
                    llama_batch_free(nb)
                    throw OnDeviceError.unknown("llama_decode failed (resume inject)")
                }
                llama_batch_free(nb)
                curPos += 1
            }

            // 생성 루프
            var n_gen: Int32 = 0
            let maxGen: Int32 = Int32(ConfigReader.int("ONDEVICE_MAX_TOKENS", default: 128) ?? 128)
            var accText = ""
            var stopByLiteral = false
            while n_gen < maxGen {
                if Task.isCancelled || stopRequested {
                    throw OnDeviceError.generationCancelled
                }
                let new_id = llama_sampler_sample(smpl, ctx, -1)
                var reachedEnd = llama_vocab_is_eog(vocab, new_id)
                if !reachedEnd && self.stopTokenSet.contains(new_id) {
                    reachedEnd = true
                }
                if reachedEnd { break }

                var tmp = [CChar](repeating: 0, count: 8)
                let rc = llama_token_to_piece(vocab, new_id, &tmp, Int32(tmp.count), 0, false)
                var delta = ""
                if rc < 0 {
                    let need = max(8, -Int(rc))
                    tmp = [CChar](repeating: 0, count: need)
                    _ = llama_token_to_piece(vocab, new_id, &tmp, Int32(need), 0, false)
                    delta = String(cString: tmp + [0])
                } else if rc > 0 {
                    let used = Int(rc)
                    if used < tmp.count { tmp[used] = 0 }
                    delta = String(cString: tmp)
                }
                if !delta.isEmpty {
                    accText += delta
                    if !self.stopLiterals.isEmpty {
                        for lit in self.stopLiterals {
                            if accText.contains(lit) {
                                stopByLiteral = true
                                break
                            }
                        }
                    }
                    if stopByLiteral {
                        var trimmed = accText
                        for lit in self.stopLiterals {
                            trimmed = trimmed.replacingOccurrences(of: lit, with: "")
                        }
                        if !trimmed.isEmpty { onToken(trimmed) }
                        break
                    } else {
                        onToken(delta)
                    }
                }

                var nb = llama_batch_init(1, 0, 1)
                nb.n_tokens = 1
                nb.token[0] = new_id
                nb.pos[0] = curPos
                nb.n_seq_id[0] = 1
                if let seq = nb.seq_id[0] { seq[0] = 0 }
                nb.logits[0] = 1
                if llama_decode(ctx, nb) != 0 {
                    llama_batch_free(nb)
                    throw OnDeviceError.unknown("llama_decode failed (resume step)")
                }
                llama_batch_free(nb)

                curPos += 1
                n_gen += 1
            }
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
        // 바인딩 없음: 정상 생성 후, 호출 시점에 오류를 던져 상위 폴백 유도
        self.isLoaded = false
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

    func saveState() throws -> Data { throw OnDeviceError.engineNotInitialized }
    func loadState(_ data: Data) throws { throw OnDeviceError.engineNotInitialized }
    func prefillSystem(_ system: String) throws -> Int { throw OnDeviceError.engineNotInitialized }
    func prefillText(_ text: String) throws -> Int { throw OnDeviceError.engineNotInitialized }
    func generateResuming(
        input: String,
        startPos: Int32,
        temperature: Double,
        topK: Int,
        topP: Double,
        onToken: @escaping @Sendable (String) -> Void
    ) throws { throw OnDeviceError.engineNotInitialized }

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

        let sysOriginal: String = {
            if let s = systemPrompt, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return s
            }
            return SystemPrompts.empathyKR
        }()
        // Gemma는 system 역할을 지원하지 않으므로 system 지시는 초기 user 입력에 내재화한다.
        // activeModelID는 상위 로더가 설정하며 여기서 분기 처리한다.
        let isGemma =
            (self.activeModelID == .amoral_gemma1b_v2_q4km)
        let sys: String? = isGemma ? nil : sysOriginal
        let effectiveInput: String =
            isGemma ? ((sysOriginal.isEmpty ? input : sysOriginal + "\n\n" + input)) : input

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
            // 전달된 stops를 바인딩에 주입하여 템플릿 종료 토큰에서 즉시 중단/트리밍
            (eng as? LlamaCppBindingImpl)?.setStopLiterals(params.stops ?? [])
            try eng.generate(
                input: effectiveInput,
                system: sys,
                temperature: params.temperature,
                topK: params.topK,
                topP: params.topP,
                onToken: wrappedOnToken
            )
        }

        try Task.checkCancellation()
    }

    public func generateResuming(
        input: String,
        systemPrompt: String?,
        startPos: Int32,
        params: InferenceParams,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws {
        // 상태 점검
        guard let eng = state.engine, eng.isLoaded else {
            throw OnDeviceError.engineNotInitialized
        }
        // Gemma는 system 역할 미지원 → resume에서도 동일 정책 적용
        let sysOriginal: String = {
            if let s = systemPrompt, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return s
            }
            return SystemPrompts.empathyKR
        }()
        let isGemma =
            (self.activeModelID == .amoral_gemma1b_v2_q4km)
        let effectiveInput: String =
            isGemma ? ((sysOriginal.isEmpty ? input : sysOriginal + "\n\n" + input)) : input

        // 1st-token 시간 측정
        let t0 = CFAbsoluteTimeGetCurrent()
        var emittedFirst = false
        let wrappedOnToken: @Sendable (String) -> Void = { delta in
            if !emittedFirst {
                emittedFirst = true
                let ms = Int((CFAbsoluteTimeGetCurrent() - t0) * 1000)
                os_log("⏱️ firstTokenMs=%{public}d (resume)", log: self.log, type: .info, ms)
            }
            onToken(delta)
        }
        try Task.checkCancellation()
        try await withTaskCancellationHandler {
        } operation: {
            // 전달된 stops를 바인딩에 주입하여 템플릿 종료 토큰에서 즉시 중단/트리밍
            (eng as? LlamaCppBindingImpl)?.setStopLiterals(params.stops ?? [])
            try eng.generateResuming(
                input: effectiveInput,
                startPos: startPos,
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
        var ngl = params.gpuLayers
        let hbm = params.embeddingHBM

        // 런타임 세이프티: 시뮬레이터 / 강제 비메탈 / 디바이스 이슈 시 GPU 레이어 비활성화
        #if targetEnvironment(simulator)
            ngl = 0
        #endif
        if ConfigReader.bool("ONDEVICE_DISABLE_METAL", default: false) ?? false {
            ngl = 0
        }
        // 기본값: 명시적 설정이 없고 메탈이 가능하면 전체 오프로딩(-1)
        if ngl == nil {
            ngl = -1
        }

        // 디버그: 현재 컴파일된 바인딩 브랜치 확인용 로그(운영 영향 없음)
        let log = OSLog(subsystem: "DeepSleep.OnDevice", category: "LlamaModelLoader")

        #if canImport(llama) || canImport(LlamaCpp) || canImport(LlamaFramework)
            os_log(
                "🔧 binding flavor=real (llama/LlamaCpp/LlamaFramework) ctx=%{public}@ thr=%{public}@ ngl=%{public}@",
                log: log, type: .info, String(ctx), String(thr), String(ngl ?? -1))
            let binding = try LlamaCppBindingImpl(
                modelPath: modelPath,
                context: ctx,
                threads: thr,
                gpuLayers: ngl,
                embeddingHBM: hbm
            )
            // 문자열 기반 stops를 바인딩에 전달(토크나이즈는 바인딩 내부에서 수행)
            if let stops = params.stops {
                (binding as? LlamaCppBindingImpl)?.setStopLiterals(stops)
            }
            return binding
        #else
            os_log("🔧 binding flavor=noop (no llama framework available)", log: log, type: .error)
            // 바인딩 없음 → 즉시 실패(상위 자동 폴백)
            // 노옵 경로: 즉시 실패시키기보다 명확한 로그 후 예외로 상위 폴백 유도
            os_log(
                "❌ llama framework not available (noop binding). Failing fast.", log: log,
                type: .error)
            throw OnDeviceError.engineNotInitialized
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

// MARK: - LlamaModelLoader ↔ KVPromptCache.LlamaSessionIO 브리지
extension LlamaModelLoader: KVPromptCache.LlamaSessionIO {
    public func saveState() throws -> Data {
        guard let eng = self.state.engine else { throw OnDeviceError.engineNotInitialized }
        return try eng.saveState()
    }
    public func loadState(_ data: Data) throws {
        guard let eng = self.state.engine else { throw OnDeviceError.engineNotInitialized }
        try eng.loadState(data)
    }
    public func prefillSystem(_ system: String) throws -> Int {
        guard let eng = self.state.engine else { throw OnDeviceError.engineNotInitialized }
        return try eng.prefillSystem(system)
    }
    public func prefillText(_ text: String) throws -> Int {
        guard let eng = self.state.engine else { throw OnDeviceError.engineNotInitialized }
        return try eng.prefillText(text)
    }
}

// MARK: - 문서 메모
// iPhone 12(A14, 4GB) 권장 시작값:
// - context=2048, threads=4, ngl=max(가능하면 모든 레이어 메탈), emb-hbm=auto
// - Amoral Gemma 1B(Q4_K_M): temp=0.8~1.0, top_k=64, top_p=0.95
// - 0.5B/1B: temp=0.7~0.9, top_k=64, top_p=0.95
// - 시스템 프롬프트: SystemPrompts.empathyKR 고정 사용(상황에 따라 호출자가 대체 가능)
//
// 실패/발열/지연>4s 연속: 상위 FallbackPolicy 로직으로 0.5B(Q4_K_M) → 0.5B(Q8_0) → 1B(Q4_0) → 1B(Q4_K_M v2) 순 전환 (ModelCatalog.fallbackOrder)
