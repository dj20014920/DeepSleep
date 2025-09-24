#if BA_LEGACY
    // LEGACY: Background Assets path; build only when BA_LEGACY is defined
    import BackgroundAssets
    import Foundation
    import OSLog

    // MARK: - AssetPackManager Stub (iOS18 BA 연동 대기 중)
    // - 목적: SystemBackgroundAssetClient가 의존하는 AssetPackManager 타입을 임시 제공
    // - 원칙: KISS/DRY/YAGNI. 실제 Apple Background Assets 연동 전까지 최소 동작 스텁 제공
    // - 동작: 파일이 이미 존재하는 경우 즉시 완료 신호(.finished)만 내보내고, 내용은 로컬 파일에서 읽음
    public struct AssetPack: Sendable {
        public let id: String
        public init(id: String) { self.id = id }
    }

    public enum AssetPackStatusUpdate: Sendable {
        case began
        case paused
        case downloading(String?, Progress)
        case finished
        case failed(Int, Error)
    }

    public final class AssetPackManager: @unchecked Sendable {
        public static let shared = AssetPackManager()
        private init() {}

        // BA 팩 핸들 획득(스텁)
        public func assetPack(withID id: String) async throws -> AssetPack {
            return AssetPack(id: id)
        }

        // 진행 상태 업데이트 스트림(간단 스텁: began → finished)
        public func statusUpdates(forAssetPackWithID id: String) -> AsyncStream<
            AssetPackStatusUpdate
        > {
            return AsyncStream { continuation in
                continuation.yield(.began)
                // 실제 다운로드 없이 즉시 완료 신호
                continuation.yield(.finished)
                continuation.finish()
            }
        }

        // 로컬 가용성 보장(스텁: no-op)
        public func ensureLocalAvailability(of pack: AssetPack) async throws {
            // 실제 BA 연동 시 다운로드 예약/확보 로직이 들어감
        }

        // BA 네임스페이스에서 파일 내용 읽기(폴리필: 샌드박스 후보 경로에서 조회)
        public func contents(at fileName: String, searchingInAssetPackWithID id: String) throws
            -> Data
        {
            if let url = BAPathProvider.firstExistingURL(packID: id, fileName: fileName) {
                return try Data(contentsOf: url)
            }
            throw OnDeviceError.modelAssetMissing
        }

        // 설치 제거(스텁: no-op)
        public func remove(assetPackWithID id: String) async throws {
            // 실제 BA 연동 시 OS가 관리하는 팩 제거 호출 필요
        }
    }

    /// Background Assets 클라이언트(iOS18+) 스텁 + iOS17- 폴리필
    /// - 설계 목표:
    ///   - 단일 진입점(SSOT)으로 BA(Background Assets) 접근을 추상화한다.
    ///   - iOS 18의 Apple-hosted Background Assets 연동부는 이후 교체 가능하도록 스텁으로 분리한다.
    ///   - 구 OS(iOS 17-)에서는 안전 폴리필(파일 존재 폴링)로 동작하여 개발/테스트를 지원한다.
    /// - 중요한 원칙:
    ///   - DRY: 모델/파일명/팩ID는 ModelCatalog에서만 관리(본 파일은 절대 하드코딩 금지)
    ///   - YAGNI: 실제 BA 연동이 도입되기 전까지 과도한 복잡성 도입 금지
    ///   - 폴백: 설치 실패/미지원 시 상위 로직에서 클라우드 또는 기본 모델로 전환
    ///
    /// 주의:
    /// - 실제 Apple-hosted Background Assets API 연동은 // MLtodo 로 표시된 지점에 구현하세요.
    /// - 본 스텁은 다음 경로 우선으로 "설치된" 파일을 탐색합니다:
    ///   1) Application Support/BackgroundAssets/<packID>/<fileName>
    ///   2) Documents/BackgroundAssets/<packID>/<fileName>
    /// - 외부(개발 단계)에서 해당 경로에 정확 파일을 투입하면 즉시 "설치 완료"로 간주됩니다.
    #if canImport(UIKit)
        import UIKit
    #endif

    // MARK: - 파일 경로 유틸

    private enum BAPathProvider {
        static func candidateFileURLs(packID: String, fileName: String) -> [URL] {
            var urls: [URL] = []

            // Application Support/BackgroundAssets/<packID>/<fileName>
            if let appSup = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first {
                urls.append(
                    appSup.appendingPathComponent("BackgroundAssets", isDirectory: true)
                        .appendingPathComponent(packID, isDirectory: true)
                        .appendingPathComponent(fileName, isDirectory: false))
            }

            // Documents/BackgroundAssets/<packID>/<fileName>
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                .first
            {
                urls.append(
                    docs.appendingPathComponent("BackgroundAssets", isDirectory: true)
                        .appendingPathComponent(packID, isDirectory: true)
                        .appendingPathComponent(fileName, isDirectory: false))
            }

            return urls
        }

        static func firstExistingURL(packID: String, fileName: String) -> URL? {
            for url in candidateFileURLs(packID: packID, fileName: fileName) {
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
            return nil
        }

        /// 개발 편의를 위해 디렉터리를 생성(없으면)합니다.
        static func ensureParentDirs(for url: URL) {
            let parent = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
    }

    // MARK: - iOS18+ 시스템 BA 클라이언트 스텁
    // 실제 Apple-hosted Background Assets 연동 이전까지는 파일 폴링 기반으로 동작합니다.

    public final class SystemBackgroundAssetClient: BackgroundAssetClient {
        // 진행 중 설치 작업 관리
        private let queue = DispatchQueue(label: "ondevice.ba.client", qos: .utility)
        private var installTasks = [String: Task<URL, Error>]()  // key: packID
        private var progressMap = [String: Double]()  // key: packID
        private var progressObjMap = [String: Progress]()  // key: packID (cancel 지원)

        public init() {}

        // MARK: - BackgroundAssetClient

        /// 설치 보장: 이미 설치되어 있으면 즉시 URL 반환.
        /// 설치가 필요하면 iOS18+에서는 시스템 BA에 위임하도록 구현하고,
        /// 현재 스텁/폴리필에서는 지정 경로를 폴링해 파일 도착을 감지합니다.
        public func ensureInstalled(
            packID: String,
            fileName: String,
            progress: ((Double) -> Void)?
        ) async throws -> URL {
            // 1) 이미 존재 → 즉시 반환
            if let url = installedURL(packID: packID, fileName: fileName) {
                updateProgress(packID: packID, value: 1.0, cb: progress)
                return url
            }

            // 2) 진행 중 작업 있으면 대기
            if let existing = getTask(for: packID) {
                let url = try await existing.value
                updateProgress(packID: packID, value: 1.0, cb: progress)
                return url
            }

            // 3) 신규 설치 시도
            let task = Task<URL, Error> { [weak self] in
                guard let self else { throw OnDeviceError.unknown("client deallocated") }

                // iOS 18+ Apple-hosted Background Assets 실제 연동 + sha256 검증/재시도
                let logger = Logger(subsystem: "DeepSleep.OnDevice", category: "BA")
                let maxAttempts = 3
                var attempt = 0
                var backoff: TimeInterval = 1.0

                // 대상 로컬 경로(앱 샌드박스) — BA에서 읽은 Data를 파일로 물리화해 엔진에 URL 제공
                func materializeLocalCopy(_ data: Data) throws -> URL {
                    // Application Support/BackgroundAssets/<packID>/<fileName>
                    let candidates = BAPathProvider.candidateFileURLs(
                        packID: packID, fileName: fileName)
                    guard let target = candidates.first else {
                        throw OnDeviceError.unknown("No candidate path for \(packID)/\(fileName)")
                    }
                    BAPathProvider.ensureParentDirs(for: target)
                    try data.write(
                        to: target, options: [.atomic, .completeFileProtectionUnlessOpen])
                    return target
                }

                while attempt < maxAttempts && !Task.isCancelled {
                    attempt += 1
                    self.updateProgress(packID: packID, value: 0.0, cb: progress)
                    logger.info(
                        "📦 BA ensure attempt \(attempt, privacy: .public) for packID=\(packID, privacy: .public)"
                    )

                    do {
                        // 1) AssetPack 핸들 획득
                        let assetPack = try await AssetPackManager.shared.assetPack(withID: packID)

                        // 2) 진행률 모니터(AsyncSequence)
                        let updates = AssetPackManager.shared.statusUpdates(
                            forAssetPackWithID: packID)
                        let monitorTask = Task {
                            for await update in updates {
                                switch update {
                                case .downloading(_, let prog):
                                    // 진행률/취소 핸들 저장
                                    self.queue.sync {
                                        self.progressObjMap[packID] = prog
                                    }
                                    let f = max(0.0, min(1.0, prog.fractionCompleted))
                                    self.updateProgress(packID: packID, value: f, cb: progress)
                                case .began, .paused:
                                    continue
                                case .finished:
                                    self.updateProgress(packID: packID, value: 1.0, cb: progress)
                                case .failed(_, let err):
                                    logger.error(
                                        "❌ BA failed: \(err.localizedDescription, privacy: .public)"
                                    )
                                @unknown default:
                                    break
                                }
                            }
                        }

                        // 3) 다운로드/가용성 보장 (정책에 따라 즉시 완료될 수 있음)
                        try await AssetPackManager.shared.ensureLocalAvailability(of: assetPack)

                        // 4) 파일 로드(BA 네임스페이스에서 Data 가져오기)
                        let data = try AssetPackManager.shared.contents(
                            at: fileName, searchingInAssetPackWithID: packID)

                        // 5) 로컬 파일로 물리화 → sha256 검증
                        let targetURL = try materializeLocalCopy(data)
                        let actual = try FileIntegrity.sha256Hex(of: targetURL)

                        // sha256 기대값(있으면 검증)
                        let expected = ModelCatalog.all().first(where: { $0.packID == packID })?
                            .sha256Hex
                        if let exp = expected, !exp.isEmpty {
                            if actual.lowercased() != exp.lowercased() {
                                logger.error(
                                    "🔐 sha256 mismatch for \(packID, privacy: .public). expected=\(exp, privacy: .public) actual=\(actual, privacy: .public)"
                                )
                                // 클린업 및 재시도 준비
                                try? FileManager.default.removeItem(at: targetURL)
                                try? await AssetPackManager.shared.remove(assetPackWithID: packID)
                                monitorTask.cancel()
                                throw OnDeviceError.hashMismatch(expected: exp, actual: actual)
                            }
                        } else {
                            logger.warning(
                                "⚠️ sha256 not provided for \(packID, privacy: .public); skipping integrity check"
                            )
                        }

                        // 6) 성공 — 진행률/모니터 정리 후 반환
                        monitorTask.cancel()
                        self.queue.sync {
                            self.progressObjMap[packID] = nil
                        }
                        self.updateProgress(packID: packID, value: 1.0, cb: progress)
                        return targetURL

                    } catch {
                        // 오류 로깅 및 재시도 백오프
                        logger.error(
                            "🧯 BA ensure error (attempt \(attempt, privacy: .public)) for \(packID, privacy: .public): \(String(describing: error), privacy: .public)"
                        )
                        if attempt >= maxAttempts || Task.isCancelled {
                            throw error
                        }
                        try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                        backoff = min(backoff * 2.0, 8.0)
                        continue
                    }
                }

                throw OnDeviceError.unknown("BA ensure exhausted attempts for pack: \(packID)")
            }

            setTask(task, for: packID)

            do {
                let url = try await task.value
                clearTask(for: packID)
                return url
            } catch {
                clearTask(for: packID)
                throw error
            }
        }

        /// 상태 조회: 파일 존재 → installed, 진행 중 → installing, 그 외 → notInstalled
        public func status(packID: String, fileName: String) async -> BackgroundAssetState {
            if let url = installedURL(packID: packID, fileName: fileName) {
                return .installed(localURL: url)
            }
            if let prog = progressValue(for: packID) {
                return .installing(progress: prog)
            }
            return .notInstalled
        }

        /// 설치 취소
        public func cancel(packID: String) {
            // 진행 중 태스크 취소
            queue.sync {
                if let t = installTasks[packID] {
                    t.cancel()
                }
                installTasks[packID] = nil
            }
            // BA Progress 취소(실제 다운로드 중단)
            var prog: Progress?
            queue.sync {
                prog = progressObjMap[packID]
                progressObjMap[packID] = nil
                progressMap[packID] = nil
            }
            prog?.cancel()
        }

        /// 즉시 설치된 파일 URL 조회(없으면 nil)
        public func installedURL(packID: String, fileName: String) -> URL? {
            return BAPathProvider.firstExistingURL(packID: packID, fileName: fileName)
        }

        // MARK: - 내부 상태 관리

        private func getTask(for packID: String) -> Task<URL, Error>? {
            queue.sync { installTasks[packID] }
        }
        private func setTask(_ task: Task<URL, Error>, for packID: String) {
            queue.sync { installTasks[packID] = task }
        }
        private func clearTask(for packID: String) {
            queue.sync {
                installTasks[packID] = nil
                progressMap[packID] = nil
            }
        }
        private func progressValue(for packID: String) -> Double? {
            queue.sync { progressMap[packID] }
        }
        private func updateProgress(packID: String, value: Double, cb: ((Double) -> Void)?) {
            queue.sync { progressMap[packID] = value }
            cb?(value)
        }
    }

    // MARK: - iOS17- 폴리필/기본 팩토리

    public enum BackgroundAssetClientFactory {
        /// OS/환경에 맞는 BA 클라이언트를 반환합니다.
        /// - iOS 18+: SystemBackgroundAssetClient(현재는 폴리필 동작, 차후 실제 BA 연동 교체)
        /// - iOS 17-: NoopBackgroundAssetClient(항상 backgroundAssetsUnavailable 오류)
        public static func make() -> BackgroundAssetClient {
            #if os(iOS)
                if #available(iOS 18.0, *) {
                    return SystemBackgroundAssetClient()
                } else {
                    return NoopBackgroundAssetClient()
                }
            #else
                // 비 iOS 환경은 안전하게 Noop 반환
                return NoopBackgroundAssetClient()
            #endif
        }
    }

// MARK: - 개발 가이드(요약)
//
// 1) App Store Connect에서 Apple-hosted Background Assets로 팩 생성(3개):
//    - pack.model.gemma270.q8 → amoral-gemma3-1B-v2-Q4_K_M.gguf (~769MB)
//    - pack.model.qwen05b.q4 → hyperclovax-seed-text-instruct-0.5b-q4_k_m.gguf (~412MB)
//    - pack.model.gemma1b.iq4 → gemma-3-1b-it-q4_0.gguf (~957MB)
//
// 2) 실제 BA 연동 구현(// MLtodo):
//    - iOS 18의 Background Assets API로 packID별 다운로드 예약/진행/취소/로컬 URL 획득 구현
//    - ensureInstalled에서 API 호출/진행률 콜백을 연결하고 완료 URL 반환
//    - status에서 현재 BA 상태를 조회해 BackgroundAssetState로 매핑
//
// 3) 개발/테스트(BA 미사용) 방법:
//    - Application Support/BackgroundAssets/<packID>/<fileName>
//      또는 Documents/BackgroundAssets/<packID>/<fileName> 에 정확 파일을 투입
//    - ensureInstalled 호출 시 폴링으로 감지되어 installedURL 반환
//
// 4) 상위 사용:
//    - let ba = BackgroundAssetClientFactory.make()
//    - let url = try await ba.ensureInstalled(packID: rec.packID, fileName: rec.fileName) { p in ... }
//    - 무결성 검증은 CatalogResolver.resolveLocalURL(for:)가 처리(sha256 설정 시)
#endif  // BA_LEGACY
