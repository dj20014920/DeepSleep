import CryptoKit
import Foundation

// MARK: - 온디바이스 LLM: 모델 카탈로그 + BA(Background Assets) 인터페이스 + 로더 인터페이스
// 단일 출처(SSOT)로 유지: 모델 ID/파일명/팩ID/권장 파라미터를 본 파일에서만 정의해 사용하세요.
// DRY 엄수: 다른 파일에서 동일 정보를 재정의/복사 금지.

// iOS SDK 가용성:
// - Apple-hosted Background Assets(BA) 실구현은 iOS 18+ 전제.
// - 본 파일은 프로토콜/카탈로그 및 안전한 No-Op 기본 구현만 포함합니다.
// - 실제 BA 연동과 llama.cpp 엔진 연동은 별도 파일에서 @available(iOS 18.0, *)로 구현하세요.

// MARK: - 공통 타입

public enum OnDeviceModelID: String, CaseIterable, Sendable {
    case amoral_gemma1b_v2_q4km  // Amoral Gemma 3 1B v2 Q4_K_M
    case qwen05b_q4km  // HyperCLOVA X Seed 0.5B Q4_K_M
    case gemma1b_iq4xs  // Gemma 3 1B Q4_0
    case hcx05b_q8_0  // HyperCLOVA X Seed 0.5B Q8_0
}

public struct InferenceParams: Sendable, Equatable {
    public var context: Int
    public var threads: Int
    public var temperature: Double
    public var topK: Int
    public var topP: Double
    public var gpuLayers: Int?  // ngl (가능 시 모든 레이어 메탈)
    public var embeddingHBM: Bool?  // emb-hbm = auto/true/false (엔진별 해석)
    public var stops: [String]?  // 출력 중단 시퀀스(모델 템플릿 에코/다음 턴 시작 토큰 방지)

    public init(
        context: Int = 2048,
        threads: Int = 4,
        temperature: Double = 0.8,
        topK: Int = 64,
        topP: Double = 0.95,
        gpuLayers: Int? = nil,
        embeddingHBM: Bool? = nil,
        stops: [String]? = nil
    ) {
        self.context = context
        self.threads = threads
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
        self.gpuLayers = gpuLayers
        self.embeddingHBM = embeddingHBM
        self.stops = stops
    }
}

public struct ModelRecord: Sendable, Equatable {
    public let id: OnDeviceModelID
    public let displayName: String
    public let packID: String  // Background Assets pack ID
    public let fileName: String  // GGUF 파일명(정확)
    public let approxBytes: Int  // 참고치(정확 용량은 다운로드 후 확인)
    public let sha256Hex: String  // 무결성 체크 값(필수). BA 설치 후 스트리밍 검증에 사용
    public let recommended: InferenceParams  // 권장 추론 파라미터
    public let notes: String?

    public init(
        id: OnDeviceModelID,
        displayName: String,
        packID: String,
        fileName: String,
        approxBytes: Int,
        sha256Hex: String,
        recommended: InferenceParams,
        notes: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.packID = packID
        self.fileName = fileName
        self.approxBytes = approxBytes
        self.sha256Hex = sha256Hex
        self.recommended = recommended
        self.notes = notes
    }
}

// MARK: - 시스템 프롬프트(공감/존댓말 톤, 짧은 1~3문단, 확인 질문 포함)

public enum SystemPrompts {
    public static let empathyKR: String =
        """
        당신은 한국어로 다정하고 담백하게 공감하는 대화 파트너입니다.
        판단·충고보다 공감 먼저, 존댓말, 과장 없음. 1~3문단.
        마지막에 “제가 제대로 이해했나요?”로 확인 질문 1개.
        """
}

// MARK: - 모델 카탈로그(SSOT)

public enum ModelCatalog {
    // Background Assets: Apple-hosted asset pack IDs (App Store Connect에 등록 필요)
    public static let packID_amoral_gemma1b_v2_q4km = "pack.model.amoral.gemma1b.v2.q4km"
    public static let packID_qwen05b_q4 = "pack.model.qwen05b.q4"
    public static let packID_gemma1b_iq4 = "pack.model.gemma1b.iq4"
    public static let packID_hcx05b_q8 = "pack.model.hcx05b.q8"

    // 정확 파일명(레포·브랜치 변경 시 반드시 동기화)
    public static let file_amoral_gemma1b_v2_q4km = "amoral-gemma3-1B-v2-Q4_K_M.gguf"
    public static let file_qwen05b_q4km = "hyperclovax-seed-text-instruct-0.5b-q4_k_m.gguf"
    public static let file_gemma1b_iq4xs = "gemma-3-1b-it-q4_0.gguf"
    public static let file_hcx05b_q8 = "hyperclovax-seed-text-instruct-0.5b-q8_0.gguf"

    // 참고 크기(Bytes) — 런타임 무결성은 sha256 또는 파일 크기 검증으로 보강
    public static let bytes_amoral_gemma1b_v2_q4km = 769_000_000
    public static let bytes_qwen05b_q4km = 412_000_000
    public static let bytes_gemma1b_iq4xs = 957_000_000
    public static let bytes_hcx05b_q8 = 693_000_000

    // 권장 파라미터(아이폰12 A14 4GB 기준 시작점)
    // removed: params_gemma270 (unused)
    private static let params_qwen05b: InferenceParams = .init(
        context: 2048, threads: 4, temperature: 0.8, topK: 64, topP: 0.95, gpuLayers: nil,
        embeddingHBM: nil
    )
    private static let params_gemma1b: InferenceParams = .init(
        context: 2048, threads: 4, temperature: 0.8, topK: 64, topP: 0.95, gpuLayers: nil,
        embeddingHBM: nil
    )

    // sha256Hex는 런타임 BA 설치 후 무결성 검증에 사용한다(필수). 불일치 시 OnDeviceError.hashMismatch로 표면화.
    public static func all() -> [ModelRecord] {
        return [
            ModelRecord(
                id: .amoral_gemma1b_v2_q4km,
                displayName: "Amoral Gemma 3 1B v2 (Q4_K_M)",
                packID: packID_amoral_gemma1b_v2_q4km,
                fileName: file_amoral_gemma1b_v2_q4km,
                approxBytes: bytes_amoral_gemma1b_v2_q4km,
                sha256Hex: "97862025aff65cd5caeb4eb84814ddcfd86d4d1607cfb2805f95b4d254e664a6",
                recommended: params_gemma1b,
                notes: "고품질 1B Q4_K_M 변형(Amoral v2)."
            ),
            ModelRecord(
                id: .qwen05b_q4km,
                displayName: "HyperCLOVA X Seed 0.5B Instruct (Q4_K_M)",
                packID: packID_qwen05b_q4,
                fileName: file_qwen05b_q4km,
                approxBytes: bytes_qwen05b_q4km,
                sha256Hex: "4b6422a2b57c9f2776c6810b4f60845596dcccbb45798779bb4bc4e4dcab013d",
                recommended: params_qwen05b,
                notes: "한국어 성능 우선(하이퍼클로바)."
            ),
            ModelRecord(
                id: .gemma1b_iq4xs,
                displayName: "Gemma 3 1B (Q4_0)",
                packID: packID_gemma1b_iq4,
                fileName: file_gemma1b_iq4xs,
                approxBytes: bytes_gemma1b_iq4xs,
                sha256Hex: "95e5b8d891cd6a794f66c2a6fb59a41e9562b4660560b854274eceffb628b22a",
                recommended: params_gemma1b,
                notes: "품질↑. Q4_0 양자화."
            ),
            ModelRecord(
                id: .hcx05b_q8_0,
                displayName: "HyperCLOVA X Seed 0.5B Instruct (Q8_0)",
                packID: packID_hcx05b_q8,
                fileName: file_hcx05b_q8,
                approxBytes: bytes_hcx05b_q8,
                sha256Hex: "9c9f76a83a112c62b9cba06f5cb3c5cc4e9ce74834d8ac09e81f35d5bd3ac871",
                recommended: params_qwen05b,
                notes: "0.5B Q8_0 변형(정밀도↑, 메모리 여유 시 권장)."
            ),
        ]
    }

    public static func record(for id: OnDeviceModelID) -> ModelRecord {
        guard let r = all().first(where: { $0.id == id }) else {
            fatalError("Unknown OnDeviceModelID \(id)")
        }
        return r
    }

    public static var defaultModelID: OnDeviceModelID { .qwen05b_q4km }

    // 비용/성능/한국어 가중 순 후보(좌→우)
    public static var fallbackOrder: [OnDeviceModelID] {
        // 용량 경량→중량 기준으로도 무리가 없게 구성: Q4_K_M(0.5B) → Q8_0(0.5B) → Gemma 1B(Q4_0) → Amoral Gemma 1B(Q4_K_M)
        return [.qwen05b_q4km, .hcx05b_q8_0, .gemma1b_iq4xs, .amoral_gemma1b_v2_q4km]
    }

    // 파일명 → 모델 ID 매핑 헬퍼(SSOT: 상수 기반)
    // - DRY: 파일명 상수(file_*)를 단일 출처로 사용
    // - 사용 예: 네트워킹/다운로더에서 lastPathComponent로 ID 유추 시
    public static func id(forFileName fileName: String) -> OnDeviceModelID? {
        switch fileName {
        case file_amoral_gemma1b_v2_q4km: return .amoral_gemma1b_v2_q4km
        case file_qwen05b_q4km: return .qwen05b_q4km
        case file_gemma1b_iq4xs: return .gemma1b_iq4xs
        case file_hcx05b_q8: return .hcx05b_q8_0
        default: return nil
        }
    }
}

// MARK: - BA(Background Assets) 추상화

public enum BackgroundAssetState: Sendable, Equatable {
    case notInstalled
    case installing(progress: Double)  // 0.0 ... 1.0
    case installed(localURL: URL)
    case failed(errorDescription: String)
}

public protocol BackgroundAssetClient: Sendable {
    /// BA 팩 설치 보장. 이미 설치되었으면 바로 URL 반환.
    func ensureInstalled(packID: String, fileName: String, progress: ((Double) -> Void)?)
        async throws -> URL

    /// 팩 상태 조회(빠른 폴링용). 필요 시 내부에서 최신 상태 동기화.
    func status(packID: String, fileName: String) async -> BackgroundAssetState

    /// 설치/다운로드 취소
    func cancel(packID: String)

    /// 설치된 로컬 URL을 즉시 조회(없으면 nil).
    func installedURL(packID: String, fileName: String) -> URL?
}

/// iOS 18 미만 또는 BA 비활성 환경에서의 안전한 No-Op 구현.
/// - ensureInstalled: not available 에러를 던져 호출 측 폴백(클라우드/다른 모델)을 유도합니다.
/// - status: notInstalled 반환.
public final class NoopBackgroundAssetClient: BackgroundAssetClient {
    public init() {}

    public func ensureInstalled(packID: String, fileName: String, progress: ((Double) -> Void)?)
        async throws -> URL
    {
        throw OnDeviceError.backgroundAssetsUnavailable
    }

    public func status(packID: String, fileName: String) async -> BackgroundAssetState {
        .notInstalled
    }

    public func cancel(packID: String) {
        // no-op
    }

    public func installedURL(packID: String, fileName: String) -> URL? {
        nil
    }
}

// MARK: - 로더 인터페이스(엔진 추상화: llama.cpp 등)

public enum OnDeviceError: Error, LocalizedError, Sendable {
    case backgroundAssetsUnavailable
    case modelAssetMissing
    case hashMismatch(expected: String, actual: String)
    case engineNotInitialized
    case generationCancelled
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .backgroundAssetsUnavailable:
            return "Background Assets 기능을 사용할 수 없습니다."
        case .modelAssetMissing:
            return "모델 파일을 찾을 수 없습니다."
        case .hashMismatch(let e, let a):
            return "모델 파일 무결성 불일치(sha256). expected=\(e) actual=\(a)"
        case .engineNotInitialized:
            return "엔진이 초기화되지 않았습니다."
        case .generationCancelled:
            return "생성이 취소되었습니다."
        case .unknown(let msg):
            return msg
        }
    }
}

public protocol OnDeviceModelLoader: Sendable {
    /// 현재 세션이 로드되었는지
    var isLoaded: Bool { get }
    /// 현재 활성 모델 ID
    var activeModelID: OnDeviceModelID? { get }

    /// 모델 로드(엔진 초기화). 동일 모델/동일 URL이면 내부 재사용 가능.
    func load(modelURL: URL, modelID: OnDeviceModelID, params: InferenceParams) throws

    /// 단발 생성(스트리밍 콜백). 엔진의 chat-template은 GGUF 메타를 자동 사용해야 함.
    func generate(
        input: String,
        systemPrompt: String?,
        params: InferenceParams,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws

    /// (KV 복원/프리필 이후) 이어서 생성. startPos는 직전 토큰 위치 + 1.
    func generateResuming(
        input: String,
        systemPrompt: String?,
        startPos: Int32,
        params: InferenceParams,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws

    /// 다른 모델로 전환(핫스왑). 구현체는 기존 세션 안전 해제/재초기화.
    func switchModel(to modelID: OnDeviceModelID, modelURL: URL, params: InferenceParams)
        async throws

    /// 리소스 해제
    func unload()
}

// MARK: - 무결성 유틸(sha256 스트리밍)

public enum FileIntegrity {
    /// 대용량 파일도 안전한 스트리밍 방식으로 sha256 계산
    public static func sha256Hex(of url: URL, chunkSize: Int = 1_048_576) throws -> String {
        guard let stream = InputStream(url: url) else {
            throw OnDeviceError.unknown("InputStream open failed: \(url.path)")
        }
        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: chunkSize)
            if read < 0 {
                throw OnDeviceError.unknown("InputStream read error for \(url.lastPathComponent)")
            }
            if read == 0 { break }
            hasher.update(data: Data(bytes: buffer, count: read))
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - 카탈로그 보조: BA 설치→경로→무결성 검증(선택)

public struct CatalogResolver {
    public let baClient: BackgroundAssetClient

    public init(baClient: BackgroundAssetClient) {
        self.baClient = baClient
    }

    /// 모델 자산을 설치/확보하고(필요 시) 선택적 sha256 검증을 수행하여 로컬 URL 반환
    public func resolveLocalURL(for id: OnDeviceModelID, progress: ((Double) -> Void)? = nil)
        async throws -> URL
    {
        let rec = ModelCatalog.record(for: id)
        // 1) BA로 설치 보장
        let local = try await baClient.ensureInstalled(
            packID: rec.packID, fileName: rec.fileName, progress: progress)

        // 2) sha256 무결성 검증(필수)
        let expected = rec.sha256Hex
        let actual = try FileIntegrity.sha256Hex(of: local)
        guard actual.lowercased() == expected.lowercased() else {
            throw OnDeviceError.hashMismatch(expected: expected, actual: actual)
        }
        return local
    }
}

// MARK: - 권장 전환 정책(지연/온도/OOM 기반)

public struct FallbackPolicy {
    public var maxTTIMilliseconds: Int = 4000  // 1B에서 2회 연속 >4s → 0.5B로
    public var allowCloudFallback: Bool = true  // 최후 수단으로 클라우드 전환 허용 여부
    public var thermalMitigation: Bool = true  // 온도 상승 시 즉시 다운스케일
    public var preferKoreanQuality: Bool = true  // 한국어↑ 모델 선호(0.5B 우선)

    public init(
        maxTTIMilliseconds: Int = 4000,
        allowCloudFallback: Bool = true,
        thermalMitigation: Bool = true,
        preferKoreanQuality: Bool = true
    ) {
        self.maxTTIMilliseconds = maxTTIMilliseconds
        self.allowCloudFallback = allowCloudFallback
        self.thermalMitigation = thermalMitigation
        self.preferKoreanQuality = preferKoreanQuality
    }

    /// 현재 모델에서 다음 후보를 결정(간단 규칙)
    public func nextCandidate(from current: OnDeviceModelID, cause: String) -> OnDeviceModelID? {
        switch current {
        case .gemma1b_iq4xs:
            // 무거운 모델에서 문제가 생기면 0.5B 계열로 우선 전환
            return .qwen05b_q4km
        case .qwen05b_q4km:
            return .hcx05b_q8_0
        case .hcx05b_q8_0:
            return .amoral_gemma1b_v2_q4km
        case .amoral_gemma1b_v2_q4km:
            // 더 낮출 수 없음 → 클라우드로(호출 측에서 처리)
            return nil
        }
    }
}

// MARK: - 예시 사용(설정 화면/전환 UX에서)
//
// let catalog = ModelCatalog.all()
// let resolver = CatalogResolver(baClient: SystemBackgroundAssetClient()) // iOS18+ 별도 구현체
// Task {
//   do {
//     let url = try await resolver.resolveLocalURL(for: .amoral_gemma1b_v2_q4km) { progress in
//       print("progress:", progress)
//     }
//     try loader.load(modelURL: url, modelID: .amoral_gemma1b_v2_q4km, params: ModelCatalog.record(for: .amoral_gemma1b_v2_q4km).recommended)
//   } catch {
//     // 실패 시 FallbackPolicy에 따라 다음 후보/클라우드로 전환
//   }
// }
//
// 채팅 시:
// try await loader.generate(input: userText, systemPrompt: SystemPrompts.empathyKR, params: currentParams) { delta in
//    streamHandler(delta)
// }
