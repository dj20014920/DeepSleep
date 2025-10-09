import Foundation

/// SSOT 기반 온디바이스 프롬프트/템플릿/Stop 시퀀스/샘플링 설정 및
/// DRY한 설치 진행률 빌더 헬퍼.
/// - 목적:
///   1) 템플릿/stop 시퀀스/샘플링 파라미터 선택 로직의 단일 출처화(SSOT)
///   2) UI/Adapter/Loader에서의 중복 제거(DRY)
///   3) 카탈로그 루프 기반 진행률 빌더로 확장 용이성 확보
///
/// 사용 지침:
/// - 템플릿/Stop/샘플링은 항상 본 유틸을 통해 조회/적용하세요.
/// - 모델 추가/변경 시 본 파일만 수정하도록 유지(SSOT).
public enum OnDevicePromptProfile {
    // MARK: - 내부 역할/프로필

    /// 템플릿 구분자(SSOT)
    /// - gemma3Style: Gemma 3 계열 템플릿(HF: <start_of_turn> / <end_of_turn>)
    /// - hcx05bStyle: HyperCLOVA X Seed 0.5B 계열(HF: <|im_start|> / <|im_end|>)
    /// - hcx15bStyle: HyperCLOVA X Seed 1.5B 계열(HF: <|im_start|> / <|im_end|>)
    public enum TemplateKind: Sendable {
        case gemma3Style
        case hcx05bStyle
        case hcx15bStyle
    }

    /// 대화 역할(간이형). 외부 RoleMessage가 있으면 맵핑 후 사용.
    public enum PromptRole: Sendable {
        case user
        case assistant
    }

    // MARK: - SSOT 매핑: 모델 → 템플릿/stop 시퀀스

    /// 모델 ID → 템플릿 종류 매핑(SSOT)
    @inlinable
    public static func templateKind(for id: OnDeviceModelID) -> TemplateKind {
        switch id {
        case .amoral_gemma3_1b_v2_q5_k_m:
            return .gemma3Style
        case .hyperclovax_seed_text_instruct_0_5b_q4_k_m, .hyperclovax_seed_text_instruct_0_5b_q8_0:
            return .hcx05bStyle
        case .hyperclovax_seed_text_instruct_1_5b_q4_k_m:
            return .hcx15bStyle
        }
    }

    /// 모델 ID → stop 시퀀스 (SSOT)
    /// - 템플릿 에코 방지, 다음 턴 시작 토큰 방지 목적
    /// - ✅ DRY: SpecialTokenSanitizer에서 중앙 관리
    @inlinable
    public static func stopSequences(for id: OnDeviceModelID) -> [String] {
        // SSOT: SpecialTokenSanitizer가 모든 토큰 정의를 관리
        return SpecialTokenSanitizer.getStopSequences(for: id)
    }

    // MARK: - 템플릿 직렬화/포매팅

    public enum PromptFormatter {
        /// user 턴 포맷(모델 템플릿별)
        @inlinable
        public static func formatUserTurn(_ user: String, for id: OnDeviceModelID) -> String {
            switch templateKind(for: id) {
            case .gemma3Style:
                // HF Gemma3 chat_template: '<start_of_turn>role ' + content + '<end_of_turn> ' ; assistant prefix: '<start_of_turn>model '
                return "<start_of_turn>user \(user)<end_of_turn> <start_of_turn>model "
            case .hcx05bStyle, .hcx15bStyle:
                // HF chat_template: '<|im_start|>role ' + content + '<|im_end|> ' ; assistant prefix: '<|im_start|>assistant '
                return "<|im_start|>user \(user)<|im_end|> <|im_start|>assistant "
            }
        }

        /// 최근 대화 직렬화(3+3 등 상위에서 제한). system은 별도 처리(엔진/상위 정책).
        /// - 입력: [(role, content)] 간이형. 외부 RoleMessage → PromptRole 맵핑 후 전달.
        @inlinable
        public static func serializeRecent(
            _ messages: [(OnDevicePromptProfile.PromptRole, String)],
            for id: OnDeviceModelID
        ) -> String {
            guard !messages.isEmpty else { return "" }
            switch templateKind(for: id) {
            case .gemma3Style:
                return messages.compactMap { (role, content) in
                    switch role {
                    case .user:
                        return "<start_of_turn>user\n\(content)<end_of_turn>\n"
                    case .assistant:
                        return "<start_of_turn>model\n\(content)<end_of_turn>\n"
                    }
                }
                .joined()
            case .hcx05bStyle, .hcx15bStyle:
                // Align with HF chat_template spacing
                return messages.compactMap { (role, content) in
                    switch role {
                    case .user:
                        return "<|im_start|>user \(content)<|im_end|> "
                    case .assistant:
                        return "<|im_start|>assistant \(content)<|im_end|> "
                    }
                }
                .joined()
            }
        }
    }

    // MARK: - 샘플링/메탈 오프로딩 보정(SSOT)

    public enum SamplingTuning {
        /// 소형(0.5B) 안정화를 위한 보수 샘플링 적용.
        /// - qwen05b_q4km, hcx05b_q8_0: temp 0.7, topK 40, topP 0.90
        /// - 그 외: 변경 없음
        @inlinable
        public static func applyConservativeDefaults(
            for id: OnDeviceModelID,
            into params: inout InferenceParams
        ) {
            switch id {
            case .hyperclovax_seed_text_instruct_0_5b_q4_k_m, .hyperclovax_seed_text_instruct_0_5b_q8_0, .hyperclovax_seed_text_instruct_1_5b_q4_k_m:
                // 기본 값 유지(과거 안정 동작): temp 0.7
                params.temperature = 0.7
                params.topK = 40
                params.topP = 0.90
            case .amoral_gemma3_1b_v2_q5_k_m:
                // 그대로 둠(카탈로그 recommended에 따름)
                break
            }
        }

        /// 메탈 오프로딩 토글
        /// - disableMetal == true → gpuLayers = 0
        /// - disableMetal == false & 기존 nil → gpuLayers = -1(가능 시 전체 오프로딩)
        @inlinable
        public static func applyMetalOverride(
            into params: inout InferenceParams,
            disableMetal: Bool
        ) {
            if disableMetal {
                params.gpuLayers = 0
            } else if params.gpuLayers == nil {
                params.gpuLayers = -1
            }
        }
    }

    // MARK: - DRY 진행률 빌더(카탈로그 루프 기반)

    /// 진행률 표시 엔트리
    public struct ProgressEntry: Sendable, Equatable {
        public let title: String
        public let progress: Double
        public let id: OnDeviceModelID
        public init(title: String, progress: Double, id: OnDeviceModelID) {
            self.title = title
            self.progress = progress
            self.id = id
        }
    }

    public enum ProgressBuilder {
        /// 카탈로그 순서(SSOT)로 모델 ID 배열 제공
        @inlinable
        public static func orderedIDs() -> [OnDeviceModelID] {
            // ModelCatalog.fallbackOrder를 그대로 사용
            return ModelCatalog.fallbackOrder
        }

        /// 상태 맵을 받아 설치 진행 중인 모델 엔트리 배열을 반환(카탈로그 순서 보장).
        /// - 파라미터: statusByID – 각 모델 ID의 BackgroundAssetState
        /// - 반환: [ProgressEntry] – 진행 중인 모델만 포함
        public static func buildInstallingEntries(
            statusByID: [OnDeviceModelID: BackgroundAssetState]
        ) -> [ProgressEntry] {
            var result: [ProgressEntry] = []
            for id in orderedIDs() {
                guard let st = statusByID[id] else { continue }
                if case .installing(let p) = st {
                    let r = ModelCatalog.record(for: id)
                    let title = "\(r.displayName) \(humanSize(r.approxBytes))"
                    result.append(.init(title: title, progress: p, id: id))
                }
            }
            return result
        }

        /// 상태 배열을 받아 맵으로 변환하는 헬퍼(편의용).
        /// - status: [(id, state)]
        /// - 반환: [id: state]
        @inlinable
        public static func mapFromPairs(
            _ status: [(OnDeviceModelID, BackgroundAssetState)]
        ) -> [OnDeviceModelID: BackgroundAssetState] {
            var dict: [OnDeviceModelID: BackgroundAssetState] = [:]
            for (k, v) in status { dict[k] = v }
            return dict
        }

        /// 바이트를 사람이 읽기 쉬운 문자열로 변환
        @inlinable
        public static func humanSize(_ bytes: Int) -> String {
            let units = ["B", "KB", "MB", "GB"]
            var v = Double(bytes)
            var i = 0
            while v >= 1024 && i < units.count - 1 {
                v /= 1024
                i += 1
            }
            if i <= 1 {
                return String(format: "%.0f%@", v, units[i])
            } else {
                return String(format: "%.1f%@", v, units[i])
            }
        }
    }
}
