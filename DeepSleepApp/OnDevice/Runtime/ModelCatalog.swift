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
    case amoral_gemma3_1b_v2_q5_k_m            // amoral-gemma3-1B-v2-Q5_K_M.gguf
    case hyperclovax_seed_text_instruct_0_5b_q4_k_m  // hyperclovax-seed-text-instruct-0.5b-q4_k_m.gguf
    case hyperclovax_seed_text_instruct_0_5b_q8_0    // hyperclovax-seed-text-instruct-0.5b-q8_0.gguf
    case hyperclovax_seed_text_instruct_1_5b_q4_k_m  // hyperclovax-seed-text-instruct-1.5b-q4_k_m.gguf
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
        threads: Int = 6,
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

        규칙:
        - 자기소개/반복 인사는 첫 번째 응답에서만 허용하고, 이후 턴에서는 절대 반복하지 않습니다.
        - 매 응답은 사용자의 직전 질문/발언에 직접적으로 답합니다(대답 우선, 자기 설명 금지).
        - 같은 말의 재진술을 피하세요.
        """
}

// MARK: - 모델 카탈로그(SSOT)

public enum ModelCatalog {
    // Background Assets: Apple-hosted asset pack IDs (App Store Connect에 등록 필요)
    public static let packID_amoral_gemma3_1b_v2_q5_k_m = "pack.model.amoral.gemma3.1b.v2.q5km"
    public static let packID_hyperclovax_seed_text_instruct_0_5b_q4_k_m = "pack.model.hcx.seed0.5b.q4km"
    public static let packID_hyperclovax_seed_text_instruct_0_5b_q8_0 = "pack.model.hcx.seed0.5b.q8_0"
    public static let packID_hyperclovax_seed_text_instruct_1_5b_q4_k_m = "pack.model.hcx.seed1.5b.q4km"

    // 정확 파일명(레포·브랜치 변경 시 반드시 동기화)
    public static let file_amoral_gemma3_1b_v2_q5_k_m = "amoral-gemma3-1B-v2-Q5_K_M.gguf"
    public static let file_hyperclovax_seed_text_instruct_0_5b_q4_k_m = "kexplo_hyperclovax-seed-text-instruct-0.5b-q4_k_m.gguf"
    public static let file_hyperclovax_seed_text_instruct_0_5b_q8_0 = "cherrydavid_hyperclovax-seed-text-instruct-0.5b-q8_0.gguf"
    public static let file_hyperclovax_seed_text_instruct_1_5b_q4_k_m = "yeebwn_hyperclovax-seed-text-instruct-1.5b-q4_k_m.gguf"

    // 참고 크기(Bytes) — 런타임 무결성은 sha256 또는 파일 크기 검증으로 보강
    public static let bytes_amoral_gemma3_1b_v2_q5_k_m = 851_000_000
    public static let bytes_hcx05b_q4_k_m = 432_000_000
    public static let bytes_hyperclovax_seed_text_instruct_0_5b_q8_0 = 726_000_000
    public static let bytes_hyperclovax_seed_text_instruct_1_5b_q4_k_m = 1_010_000_000

    // 권장 파라미터(아이폰12 A14 4GB 기준 시작점)

    private static let params_hcx05b_q4km: InferenceParams = .init(
        context: 4096, threads: 6, temperature: 0.75, topK: 40, topP: 0.90, gpuLayers: nil,
        embeddingHBM: nil
    )
    private static let params_hcx05b_q8_0: InferenceParams = .init(
        context: 8192, threads: 6, temperature: 0.75, topK: 40, topP: 0.90, gpuLayers: nil,
        embeddingHBM: nil
    )
    private static let params_hyperclova_1p5b_q4km: InferenceParams = .init(
        context: 8192, threads: 6, temperature: 0.75, topK: 40, topP: 0.90, gpuLayers: nil,
        embeddingHBM: nil
    )
    private static let params_gemma3_1b_q5km: InferenceParams = .init(
        context: 8192, threads: 6, temperature: 0.75, topK: 40, topP: 0.90, gpuLayers: nil,
        embeddingHBM: nil
    )

    // sha256Hex는 런타임 BA 설치 후 무결성 검증에 사용한다(필수). 불일치 시 OnDeviceError.hashMismatch로 표면화.
    public static func all() -> [ModelRecord] {
        return [
            ModelRecord(
                id: .amoral_gemma3_1b_v2_q5_k_m,
                displayName: "Amoral Gemma 3 1B v2 (Q5_K_M)",
                packID: packID_amoral_gemma3_1b_v2_q5_k_m,
                fileName: file_amoral_gemma3_1b_v2_q5_k_m,
                approxBytes: bytes_amoral_gemma3_1b_v2_q5_k_m,
                sha256Hex: "ed6eafe1b3f056df5d783498316bb553877ebe73ce93c462f6a5cef0218882e5",
                recommended: params_gemma3_1b_q5km,
                notes: "고품질 1B Q5_K_M 변형(Amoral v2)."
            ),
            ModelRecord(
                id: .hyperclovax_seed_text_instruct_0_5b_q4_k_m,
                displayName: "HyperCLOVA X Seed 0.5B Instruct (Q4_K_M)",
                packID: packID_hyperclovax_seed_text_instruct_0_5b_q4_k_m,
                fileName: file_hyperclovax_seed_text_instruct_0_5b_q4_k_m,
                approxBytes: bytes_hcx05b_q4_k_m,
                sha256Hex: "4b6422a2b57c9f2776c6810b4f60845596dcccbb45798779bb4bc4e4dcab013d",
                recommended: params_hcx05b_q4km,
                notes: "한국어 성능 우선(하이퍼클로바)."
            ),
            ModelRecord(
                id: .hyperclovax_seed_text_instruct_1_5b_q4_k_m,
                displayName: "HyperCLOVA X Seed 1.5B (Q4_K_M)",
                packID: packID_hyperclovax_seed_text_instruct_1_5b_q4_k_m,
                fileName: file_hyperclovax_seed_text_instruct_1_5b_q4_k_m,
                approxBytes: bytes_hyperclovax_seed_text_instruct_1_5b_q4_k_m,
                sha256Hex: "c5bcc5fad55d6361307fd91e2d0685b1b8cc99e5bc1dd506995fee0ef84d8044",
                recommended: params_hyperclova_1p5b_q4km,
                notes: "1.5B Q4_K_M 변형(yeebwn)."
            ),
            ModelRecord(
                id: .hyperclovax_seed_text_instruct_0_5b_q8_0,
                displayName: "HyperCLOVA X Seed 0.5B Instruct (Q8_0)",
                packID: packID_hyperclovax_seed_text_instruct_0_5b_q8_0,
                fileName: file_hyperclovax_seed_text_instruct_0_5b_q8_0,
                approxBytes: bytes_hyperclovax_seed_text_instruct_0_5b_q8_0,
                sha256Hex: "9c9f76a83a112c62b9cba06f5cb3c5cc4e9ce74834d8ac09e81f35d5bd3ac871",
                recommended: params_hcx05b_q4km,
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

    // 사용자 선호를 우선 기본값으로 사용. 미설정 시만 최소용량(.hyperclovax_seed_text_instruct_0_5b_q4_k_m)로 폴백
    public static var defaultModelID: OnDeviceModelID {
        // SSOT 레이어에서는 앱 설정에 의존하지 않는다. 최소 용량 모델로 고정.
        return .hyperclovax_seed_text_instruct_0_5b_q4_k_m
    }

    // 비용/성능/한국어 가중 순 후보(좌→우)
    public static var fallbackOrder: [OnDeviceModelID] {
        // 용량 경량→중량 기준으로도 무리가 없게 구성: Q4_K_M(0.5B) → Q8_0(0.5B) → 1.5B(Q4_K_M) → Amoral 1B(Q5_K_M)
        return [
            .hyperclovax_seed_text_instruct_0_5b_q4_k_m,
            .hyperclovax_seed_text_instruct_0_5b_q8_0,
            .hyperclovax_seed_text_instruct_1_5b_q4_k_m,
            .amoral_gemma3_1b_v2_q5_k_m
        ]
    }

    /// 모델 파일을 저장할 수 있는 모든 가능한 디렉토리 경로를 반환합니다
    /// - Returns: 모델 파일을 찾을 수 있는 디렉토리 경로 배열
    public static func modelDirectories() -> [String] {
        var directories: [String] = []

        // 1. Application Support/Models (주 저장소 - OnDeviceAdapter에서 사용)
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            directories.append(appSupport.appendingPathComponent("Models", isDirectory: true).path)
        }

        // 2. 개발 환경의 model 폴더 (현재 작업 디렉토리 기준)
        let projectModelPath = FileManager.default.currentDirectoryPath + "/model"
        if FileManager.default.fileExists(atPath: projectModelPath) {
            directories.append(projectModelPath)
        }

        // 3. Documents/models 디렉토리
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            directories.append(docs.appendingPathComponent("models", isDirectory: true).path)
        }

        // 4. 앱 Bundle 리소스
        if let bundle = Bundle.main.resourcePath {
            directories.append(bundle)
        }

        return directories
    }

    /// 특정 파일명의 모델 파일 경로를 찾습니다
    /// - Parameter fileName: 찾을 모델 파일명
    /// - Returns: 파일이 존재하는 전체 경로 (없으면 nil)
    public static func findModelFile(fileName: String) -> String? {
        for directory in modelDirectories() {
            let filePath = URL(fileURLWithPath: directory).appendingPathComponent(fileName).path
            if FileManager.default.fileExists(atPath: filePath) {
                return filePath
            }
        }
        return nil
    }

    /// 모델의 실제 파일 크기를 동적으로 읽어옵니다 (설치된 경우)
    /// - Parameter id: 온디바이스 모델 ID
    /// - Returns: 실제 파일 크기(bytes). 파일이 없으면 근사치 반환
    public static func actualFileSize(for id: OnDeviceModelID) -> Int {
        let record = ModelCatalog.record(for: id)

        // 파일 경로 찾기
        guard let filePath = findModelFile(fileName: record.fileName) else {
            // 파일을 찾을 수 없으면 근사치 반환
            return record.approxBytes
        }

        // 파일 크기 읽기
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            if let fileSize = attributes[.size] as? Int {
                return fileSize
            }
        } catch {
            // 오류 발생 시 근사치 반환
            return record.approxBytes
        }

        // 기타 경우 근사치 반환
        return record.approxBytes
    }

    /// 디렉토리를 스캔하여 설치된 모든 모델 파일과 크기를 반환합니다
    /// - Returns: (모델ID, 파일경로, 실제크기) 튜플 배열
    public static func scanInstalledModels() -> [(OnDeviceModelID, String, Int)] {
        var installedModels: [(OnDeviceModelID, String, Int)] = []

        for directory in modelDirectories() {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
                continue
            }

            // GGUF 파일만 필터링
            let ggufFiles = files.filter { $0.lowercased().hasSuffix(".gguf") }

            for fileName in ggufFiles {
                // 파일명으로 모델 ID 찾기
                if let modelID = OnDeviceModelID.id(forFileName: fileName) {
                    let filePath = URL(fileURLWithPath: directory).appendingPathComponent(fileName).path

                    // 파일 크기 읽기
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
                       let fileSize = attributes[.size] as? Int {
                        installedModels.append((modelID, filePath, fileSize))
                    }
                }
            }
        }

        // 중복 제거 (같은 모델이 여러 경로에 있을 수 있음 - 첫 번째 것만 사용)
        var uniqueModels: [(OnDeviceModelID, String, Int)] = []
        var seenIDs = Set<OnDeviceModelID>()

        for model in installedModels {
            if !seenIDs.contains(model.0) {
                uniqueModels.append(model)
                seenIDs.insert(model.0)
            }
        }

        return uniqueModels
    }
}

// MARK: - OnDeviceModelID Extensions

extension OnDeviceModelID {
    /// 온디바이스 모델 ID를 친근한 별명으로 변환 (용량 순서 기준)
    public var friendlyNickname: String {
        switch self {
        case .hyperclovax_seed_text_instruct_0_5b_q4_k_m: return "작은 클로버"      // 432MB (가장 작음)
        case .hyperclovax_seed_text_instruct_0_5b_q8_0: return "클로버"          // 726MB
        case .amoral_gemma3_1b_v2_q5_k_m: return "잼민이"   // 851MB
        case .hyperclovax_seed_text_instruct_1_5b_q4_k_m: return "큰 클로버"      // 1010MB (가장 큼)
        }
    }

    // 파일명 → 모델 ID 매핑 헬퍼(SSOT: 상수 기반)
    // - DRY: 파일명 상수(file_*)를 단일 출처로 사용
    // - 사용 예: 네트워킹/다운로더에서 lastPathComponent로 ID 유추 시
    public static func id(forFileName fileName: String) -> OnDeviceModelID? {
        switch fileName {
        case ModelCatalog.file_amoral_gemma3_1b_v2_q5_k_m: return .amoral_gemma3_1b_v2_q5_k_m
        case ModelCatalog.file_hyperclovax_seed_text_instruct_0_5b_q4_k_m: return .hyperclovax_seed_text_instruct_0_5b_q4_k_m
        case ModelCatalog.file_hyperclovax_seed_text_instruct_1_5b_q4_k_m: return .hyperclovax_seed_text_instruct_1_5b_q4_k_m
        case ModelCatalog.file_hyperclovax_seed_text_instruct_0_5b_q8_0: return .hyperclovax_seed_text_instruct_0_5b_q8_0
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
}

// 간단한 후보 전환 헬퍼: SSOT fallbackOrder를 기준으로 다음 후보를 반환
public extension FallbackPolicy {
    @inlinable
    func nextCandidate(from current: OnDeviceModelID, cause: String) -> OnDeviceModelID? {
        let order = ModelCatalog.fallbackOrder
        guard let idx = order.firstIndex(of: current) else { return nil }
        let nextIdx = idx + 1
        return nextIdx < order.count ? order[nextIdx] : nil
    }
}



// MARK: - 예시 사용(설정 화면/전환 UX에서)
//
// let catalog = ModelCatalog.all()
// let resolver = CatalogResolver(baClient: SystemBackgroundAssetClient()) // iOS18+ 별도 구현체
// Task {
//   do {
//     let url = try await resolver.resolveLocalURL(for: .amoral_gemma3_1b_v2_q5_k_m) { progress in
//       print("progress:", progress)
//     }
//     try loader.load(modelURL: url, modelID: .amoral_gemma3_1b_v2_q5_k_m, params: ModelCatalog.record(for: .amoral_gemma3_1b_v2_q5_k_m).recommended)
//   } catch {
//     // 실패 시 FallbackPolicy에 따라 다음 후보/클라우드로 전환
//   }
// }
//
// 채팅 시:
// try await loader.generate(input: userText, systemPrompt: SystemPrompts.empathyKR, params: currentParams) { delta in
//    streamHandler(delta)
// }
