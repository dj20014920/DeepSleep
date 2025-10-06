import CryptoKit
import Foundation
import OSLog

// RemoteAssetClient.swift
// HTTP(S) 기반 모델 다운로드 클라이언트
// - URLSession background 다운로드 + 재시도 + 레쥼 + 진행률 + SHA256 무결성 검증
// - 설치 위치: Application Support/Models/{fileName}
// - presigned GET 우선, 실패 시 CDN 고정 경로로 폴백
//
// 설계 원칙
// - KISS/DRY/YAGNI: 단일 진입, 중복/과도한 복잡성 금지
// - 보안: HTTPS 전용, SHA256 필수 검증
// - 신뢰성: 지수 백오프 3회, resumeData 활용
//
// 외부 의존
// - FileIntegrity.sha256Hex(of:) 제공 (DeepSleepApp/OnDevice/Runtime/ModelCatalog.swift)
//
// API
// - ensureInstalled(fileName:expectedSha256:progress:) -> URL
// - cancel(fileName:)
// - status(fileName:) -> (installed: Bool, progress: Double)

extension Notification.Name {
    public static let onDeviceDownloadProgress = Notification.Name("OnDeviceDownloadProgress")
    public static let onDeviceDownloadFinished = Notification.Name("OnDeviceDownloadFinished")
    public static let onDeviceDownloadFailed = Notification.Name("OnDeviceDownloadFailed")
    public static let onDeviceDownloadCancelled = Notification.Name("OnDeviceDownloadCancelled")
}

public final class RemoteAssetClient: NSObject {

    // MARK: - Public Types

    public struct Config: Sendable {
        // presign endpoint 예: https://api.example.com/presign?file={filename}
        public var presignEndpoint: URL?
        // CDN 고정 경로 예: https://cdn.example.com/models/{filename}
        public var cdnBaseURL: URL?
        // background session 식별자(앱 범위 고정)
        public var backgroundSessionID: String
        // 재시도 횟수
        public var maxAttempts: Int
        // 백오프 시퀀스(초): 1, 2, 4
        public var backoffSchedule: [TimeInterval]
        // User-Agent
        public var userAgent: String

        public init(
            presignEndpoint: URL? = URL(string: "https://api.example.com/presign"),
            cdnBaseURL: URL? = URL(string: "https://cdn.example.com/models"),
            backgroundSessionID: String = "com.deepsleep.models.bg",
            maxAttempts: Int = 3,
            backoffSchedule: [TimeInterval] = [1.0, 2.0, 4.0],
            userAgent: String = "DeepSleep/RemoteAssetClient"
        ) {
            self.presignEndpoint = presignEndpoint
            self.cdnBaseURL = cdnBaseURL
            self.backgroundSessionID = backgroundSessionID
            self.maxAttempts = max(1, maxAttempts)
            self.backoffSchedule = backoffSchedule
            self.userAgent = userAgent
        }
    }

    public enum ClientError: Error, LocalizedError {
        case invalidURL
        case nonHTTPSNotAllowed
        case presignFailed(String)
        case downloadCancelled
        case downloadFailed(String)
        case integrityMismatch(expected: String, actual: String)
        case fileSystem(String)

        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "유효하지 않은 URL입니다."
            case .nonHTTPSNotAllowed: return "보안 정책: HTTPS만 허용됩니다."
            case .presignFailed(let r): return "서명 URL 획득 실패: \(r)"
            case .downloadCancelled: return "다운로드가 취소되었습니다."
            case .downloadFailed(let r): return "다운로드 실패: \(r)"
            case .integrityMismatch(let e, let a):
                return "무결성 검증 실패(sha256). expected=\(e) actual=\(a)"
            case .fileSystem(let r): return "파일 시스템 오류: \(r)"
            }
        }
    }

    // MARK: - Private Types

    private struct Waiter {
        let id: UUID
        let progress: ((Double) -> Void)?
        let continuation: CheckedContinuation<URL, Error>
    }

    private final class StateBox {
        // 직렬 큐로 상태 보호(KISS)
        private let q = DispatchQueue(label: "RemoteAssetClient.state", qos: .utility)

        // 파일명 → 진행중 task
        private var taskByFile: [String: URLSessionDownloadTask] = [:]
        // 파일명 → 진행률 (0.0 ~ 1.0)
        private var progressByFile: [String: Double] = [:]
        // 파일명 → 재시도 횟수(시도 완료 수)
        private var attemptByFile: [String: Int] = [:]
        // 파일명 → resumeData
        private var resumeDataByFile: [String: Data] = [:]
        // 파일명 → ETag(가능 시)
        private var etagByFile: [String: String] = [:]
        // 파일명 → expected sha256
        private var expectedShaByFile: [String: String] = [:]
        // 파일명 → 대기자(여러 호출이 붙을 수 있음)
        private var waitersByFile: [String: [Waiter]] = [:]
        // 파일명 → 완료 처리 여부(중복 완료 방지)
        private var finishedByFile: Set<String> = []
        // 파일명 → 마지막으로 로깅된 진행 퍼센트(진단 로그 스로틀링)
        private var lastLoggedPctByFile: [String: Int] = [:]
        // 파일명 → 사용자 취소 플래그
        private var userCancelledByFile: Set<String> = []
        // 파일명 → 시작 중 플래그(레이스 방지: getTask==nil 윈도우 보호)
        private var startingFiles: Set<String> = []

        func markUserCancelled(file: String) { q.sync { userCancelledByFile.insert(file) } }
        func isUserCancelled(file: String) -> Bool { q.sync { userCancelledByFile.contains(file) } }

        func isStarting(file: String) -> Bool { q.sync { startingFiles.contains(file) } }
        /// 최초 시작 시도(원자적): 이미 시작/진행 중이면 false 반환
        func beginStartIfNeeded(file: String) -> Bool {
            q.sync {
                if taskByFile[file] != nil || startingFiles.contains(file) { return false }
                startingFiles.insert(file)
                return true
            }
        }
        func endStart(file: String) { q.sync { startingFiles.remove(file) } }

        func getTask(file: String) -> URLSessionDownloadTask? { q.sync { taskByFile[file] } }
        func setTask(file: String, task: URLSessionDownloadTask?) {
            q.sync { taskByFile[file] = task }
        }

        func getProgress(file: String) -> Double { q.sync { progressByFile[file] ?? 0.0 } }
        func setProgress(file: String, value: Double) { q.sync { progressByFile[file] = value } }

        func getAttempts(file: String) -> Int { q.sync { attemptByFile[file] ?? 0 } }
        func setAttempts(file: String, value: Int) { q.sync { attemptByFile[file] = value } }

        func getResumeData(file: String) -> Data? { q.sync { resumeDataByFile[file] } }
        func setResumeData(file: String, data: Data?) { q.sync { resumeDataByFile[file] = data } }

        func getETag(file: String) -> String? { q.sync { etagByFile[file] } }
        func setETag(file: String, etag: String?) { q.sync { etagByFile[file] = etag } }
        func getExpectedSha(file: String) -> String? { q.sync { expectedShaByFile[file] } }
        func setExpectedSha(file: String, sha: String?) { q.sync { expectedShaByFile[file] = sha } }

        func addWaiter(file: String, waiter: Waiter) {
            q.sync {
                var arr = waitersByFile[file] ?? []
                arr.append(waiter)
                waitersByFile[file] = arr
            }
        }
        func popWaiters(file: String) -> [Waiter] {
            q.sync {
                let arr = waitersByFile[file] ?? []
                waitersByFile[file] = []
                return arr
            }
        }

        func markFinished(file: String) { q.sync { finishedByFile.insert(file) } }
        func isFinished(file: String) -> Bool { q.sync { finishedByFile.contains(file) } }
        func getLastLoggedPct(file: String) -> Int? { q.sync { lastLoggedPctByFile[file] } }
        func setLastLoggedPct(file: String, value: Int?) { q.sync { lastLoggedPctByFile[file] = value } }
        func clear(file: String) {
            q.sync {
                taskByFile[file] = nil
                progressByFile[file] = nil
                attemptByFile[file] = nil
                resumeDataByFile[file] = nil
                etagByFile[file] = nil
                expectedShaByFile[file] = nil
                waitersByFile[file] = nil
                finishedByFile.remove(file)
                userCancelledByFile.remove(file)
                lastLoggedPctByFile[file] = nil
                startingFiles.remove(file)
            }
        }
    }

    // MARK: - Properties

    private let cfg: Config
    private let log = Logger(subsystem: "DeepSleep.OnDevice", category: "RemoteAssetClient")
    private let state = StateBox()

    // URLSession (background)
    private lazy var session: URLSession = {
        let conf = URLSessionConfiguration.background(withIdentifier: cfg.backgroundSessionID)
        conf.allowsExpensiveNetworkAccess = true
        conf.allowsConstrainedNetworkAccess = true
        conf.allowsCellularAccess = true
        conf.isDiscretionary = false
        conf.waitsForConnectivity = true
        conf.httpMaximumConnectionsPerHost = 2
        conf.timeoutIntervalForRequest = 60
        conf.timeoutIntervalForResource = 7 * 24 * 3600  // background 장수명
        conf.httpAdditionalHeaders = [
            "User-Agent": cfg.userAgent
        ]
        return URLSession(configuration: conf, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Init

    public init(config: Config = Config()) {
        self.cfg = config
        super.init()
    }

    // MARK: - Public API

    /// 설치 보장: 존재+무결성 OK면 즉시 반환, 아니면 다운로드/재시도 후 설치
    @discardableResult
    public func ensureInstalled(
        fileName: String,
        expectedSha256: String,
        progress: ((Double) -> Void)? = nil
    ) async throws -> URL {
        // 0) 이미 설치/무결성?
        if let url = installedURL(for: fileName) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? -1
            log.info(
                "📂 Found existing file: \(url.lastPathComponent, privacy: .public) size=\(size, privacy: .public)"
            )
            // sha256 검증: 기대값이 비어있다면 건너뜀(로컬 수동 배치 시)
            if expectedSha256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                progress?(1.0)
                log.info("🟡 No expected SHA provided for \(fileName, privacy: .public); trusting existing file")
                return url
            }
            let actual = try FileIntegrity.sha256Hex(of: url)
            log.info(
                "🔍 Integrity check: expected=\(expectedSha256, privacy: .public) actual=\(actual, privacy: .public)"
            )
            if actual.caseInsensitiveCompare(expectedSha256) == .orderedSame {
                progress?(1.0)
                log.info("🟢 Integrity OK for \(fileName, privacy: .public); skipping download")
                return url
            } else {
                log.warning(
                    "🟠 Integrity mismatch for \(fileName, privacy: .public); re-downloading")
                // 불일치 → 제거 후 재다운로드
                try? FileManager.default.removeItem(at: url)
            }
        }

        // 1) 진행 중 작업이 있으면 waiter로 붙기 (또는 시작 중이면 합류)
        if state.getTask(file: fileName) != nil || state.isStarting(file: fileName) {
            log.info("🪝 Join existing download for \(fileName, privacy: .public)")
            return try await withCheckedThrowingContinuation { cont in
                let waiter = Waiter(id: UUID(), progress: progress, continuation: cont)
                state.addWaiter(file: fileName, waiter: waiter)
            }
        }

        // 2) 새 다운로드 시작: 레이스 방지(원자적 시작 가드)
        guard state.beginStartIfNeeded(file: fileName) else {
            // 누군가가 방금 시작했음 → waiter로 붙기
            log.info("🪝 Join existing (raced) for \(fileName, privacy: .public)")
            return try await withCheckedThrowingContinuation { cont in
                let waiter = Waiter(id: UUID(), progress: progress, continuation: cont)
                state.addWaiter(file: fileName, waiter: waiter)
            }
        }
        
        // waiter 자기 자신 추가(완료 신호 받을 수 있게)
        return try await withCheckedThrowingContinuation { cont in
            let waiter = Waiter(id: UUID(), progress: progress, continuation: cont)
            state.addWaiter(file: fileName, waiter: waiter)
            state.setAttempts(file: fileName, value: 0)
            state.setProgress(file: fileName, value: 0.0)
            state.setExpectedSha(file: fileName, sha: expectedSha256)
            log.info("🆕 Enqueue download for \(fileName, privacy: .public)")
            Task { [weak self] in
                await self?.startOrResumeDownload(
                    fileName: fileName, expectedSha256: expectedSha256)
                self?.state.endStart(file: fileName)
            }
        }
    }

    /// 다운로드/설치 취소
    public func cancel(fileName: String) {
        let hadTask = (state.getTask(file: fileName) != nil)
        let prog = state.getProgress(file: fileName)
        let attempts = state.getAttempts(file: fileName)
        log.warning(
            "🛑 Cancel requested for \(fileName, privacy: .public) hadTask=\(hadTask, privacy: .public) progress=\(prog, privacy: .public) attempts=\(attempts, privacy: .public)"
        )
        state.markUserCancelled(file: fileName)
        if let task = state.getTask(file: fileName) {
            task.cancel()
        }
        // 대기자 전원에 취소 전달
        let waiters = state.popWaiters(file: fileName)
        for w in waiters {
            w.progress?(0.0)
            w.continuation.resume(throwing: ClientError.downloadCancelled)
        }
        state.clear(file: fileName)
        NotificationCenter.default.post(
            name: .onDeviceDownloadCancelled,
            object: nil,
            userInfo: ["fileName": fileName]
        )
        log.info("🚫 Cancelled \(fileName, privacy: .public)")
    }

    /// 상태(간단): 파일 존재 여부 + 진행률
    public func status(fileName: String) -> (installed: Bool, progress: Double) {
        let url = installedURL(for: fileName)
        let installed = (url != nil)
        let p = state.getProgress(file: fileName)
        // 설치 완료 상태면 1.0 고정
        return (installed, installed ? 1.0 : p)
    }

    // MARK: - Paths

    private func modelsDirURL() throws -> URL {
        guard
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else {
            throw ClientError.fileSystem("Application Support 디렉터리 접근 실패")
        }
        let dir = base.appendingPathComponent("Models", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func installedURL(for fileName: String) -> URL? {
        guard let dir = try? modelsDirURL() else { return nil }
        let url = dir.appendingPathComponent(fileName, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func destinationURL(for fileName: String) throws -> URL {
        let dir = try modelsDirURL()
        return dir.appendingPathComponent(fileName, isDirectory: false)
    }

    // MARK: - Download Orchestration

    private func remoteURL(for fileName: String) async -> URL? {
        log.info(
            "🌐 Resolving remote URL for \(fileName, privacy: .public) presign=\(self.cfg.presignEndpoint?.absoluteString ?? "nil", privacy: .public) cdn=\(self.cfg.cdnBaseURL?.absoluteString ?? "nil", privacy: .public)"
        )
        // 1) presign 우선
        if let presignBase = cfg.presignEndpoint {
            if var comp = URLComponents(url: presignBase, resolvingAgainstBaseURL: false) {
                var query = comp.queryItems ?? []
                query.append(URLQueryItem(name: "file", value: fileName))
                comp.queryItems = query
                if let reqURL = comp.url {
                    do {
                        if let u = try await fetchPresignURL(endpoint: reqURL) {
                            log.info(
                                "🌐 Using presigned URL for \(fileName, privacy: .public): \(u.absoluteString, privacy: .public)"
                            )
                            return u
                        }
                    } catch {
                        log.error(
                            "🔐 Presign failed: \(error.localizedDescription, privacy: .public)")
                        // continue to CDN
                    }
                }
            }
        }
        // 2) CDN 고정 경로
        if let base = cfg.cdnBaseURL {
            let u = base.appendingPathComponent(fileName, isDirectory: false)
            log.info(
                "🌐 Using CDN URL for \(fileName, privacy: .public): \(u.absoluteString, privacy: .public)"
            )
            return u
        }
        log.error("🌐 Failed to resolve remote URL for \(fileName, privacy: .public)")
        return nil
    }

    private func startOrResumeDownload(fileName: String, expectedSha256: String) async {
        guard let url = await remoteURL(for: fileName) else {
            log.error("🌐 remoteURL nil for \(fileName, privacy: .public)")
            finish(fileName: fileName, failure: ClientError.invalidURL)
            return
        }
        log.info(
            "🚀 Starting/resuming download for \(fileName, privacy: .public) url=\(url.absoluteString, privacy: .public)"
        )
        // HTTPS 전용
        if url.scheme?.lowercased() != "https" {
            log.error("❗️Non-HTTPS URL blocked: \(url.absoluteString, privacy: .public)")
            finish(fileName: fileName, failure: ClientError.nonHTTPSNotAllowed)
            return
        }

        // 재시도 루프는 delegate에서 관리(에러/무결성 실패 시 재스케줄)
        // 첫 task 생성(또는 resumeData 기반)
        scheduleDownloadTask(fileName: fileName, url: url)
    }

    private func scheduleDownloadTask(fileName: String, url: URL, withResumeData: Data? = nil) {
        // If-None-Match 헤더 설정(가능 시)
        var request = URLRequest(url: url)
        request.setValue(cfg.userAgent, forHTTPHeaderField: "User-Agent")
        if let etag = state.getETag(file: fileName), !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let task: URLSessionDownloadTask
        let usingResume = (withResumeData != nil)
        if let rd = withResumeData {
            task = session.downloadTask(withResumeData: rd)
        } else {
            task = session.downloadTask(with: request)
        }
        if let etagHdr = request.value(forHTTPHeaderField: "If-None-Match") {
            log.info(
                "📥 Scheduling download: \(fileName, privacy: .public) resume=\(usingResume, privacy: .public) If-None-Match=\(etagHdr, privacy: .public)"
            )
        } else {
            log.info(
                "📥 Scheduling download: \(fileName, privacy: .public) resume=\(usingResume, privacy: .public)"
            )
        }
        state.setTask(file: fileName, task: task)
        task.taskDescription = fileName
        task.resume()
        log.info(
            "⬇️ Download scheduled: \(fileName, privacy: .public) (\(url.absoluteString, privacy: .public))"
        )
    }

    private func handleDownloadSuccess(fileName: String, tempLocation: URL) {
        // 임시 파일 무결성 검증 → 성공 시 최종 위치로 이동, 실패 시 재시도
        do {
            // sha256 (임시 파일에서 직접 계산)
            let actual = try FileIntegrity.sha256Hex(of: tempLocation)
            let expected = state.getExpectedSha(file: fileName)
            if let exp = expected, !exp.isEmpty, actual.caseInsensitiveCompare(exp) != .orderedSame
            {
                // 무결성 실패 → 임시파일 삭제 후 재시도 스케줄
                let attrs = try? FileManager.default.attributesOfItem(atPath: tempLocation.path)
                let tmpSize = (attrs?[.size] as? NSNumber)?.int64Value ?? -1
                log.warning(
                    "🔐 sha256 mismatch for \(fileName, privacy: .public) expected=\(exp, privacy: .public) actual=\(actual, privacy: .public) tempSize=\(tmpSize, privacy: .public)"
                )
                try? FileManager.default.removeItem(at: tempLocation)
                let attempts = state.getAttempts(file: fileName)
                let max = cfg.maxAttempts
                if attempts + 1 >= max {
                    finish(
                        fileName: fileName,
                        failure: ClientError.integrityMismatch(expected: exp, actual: actual)
                    )
                    return
                }
                let delay =
                    (attempts < cfg.backoffSchedule.count)
                    ? cfg.backoffSchedule[attempts] : cfg.backoffSchedule.last ?? 2.0
                state.setAttempts(file: fileName, value: attempts + 1)
                log.warning(
                    "🔐 sha256 mismatch retry \(attempts+1)/\(max) after \(delay)s for \(fileName, privacy: .public)"
                )
                Task.detached(priority: .utility) { [weak self] in
                    guard let self else { return }
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    guard let url = await self.remoteURL(for: fileName) else {
                        self.finish(fileName: fileName, failure: ClientError.invalidURL)
                        return
                    }
                    self.scheduleDownloadTask(fileName: fileName, url: url, withResumeData: nil)
                }
                return
            }
            // 최종 경로로 이동
            let dest = try destinationURL(for: fileName)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: tempLocation, to: dest)
            // 완료 처리
            state.markFinished(file: fileName)
            let waiters = state.popWaiters(file: fileName)
            for w in waiters {
                w.progress?(1.0)
                w.continuation.resume(returning: dest)
            }
            cleanupAfterFinish(fileName: fileName)

            NotificationCenter.default.post(
                name: .onDeviceDownloadFinished,
                object: nil,
                userInfo: [
                    "fileName": fileName,
                    "localURL": dest,
                ]
            )

            log.info(
                "✅ Download finished: \(fileName, privacy: .public) sha256=\(actual, privacy: .public)"
            )
        } catch {
            finish(fileName: fileName, failure: ClientError.fileSystem(error.localizedDescription))
        }
    }

    private func handleDownloadError(fileName: String, error: Error) {
        let ns = error as NSError
        if let urlError = error as? URLError {
            log.error(
                "🌩️ URL error for \(fileName, privacy: .public): code=\(urlError.code.rawValue) \(urlError.localizedDescription, privacy: .public)"
            )
        } else {
            log.error(
                "🌩️ Error for \(fileName, privacy: .public): code=\(ns.code) domain=\(ns.domain, privacy: .public) \(ns.localizedDescription, privacy: .public)"
            )
        }
        // 취소: 사용자 취소 vs 스푸리어스(-999) 구분

        if ns.code == NSURLErrorCancelled {
            if state.isUserCancelled(file: fileName) {
                finish(fileName: fileName, failure: ClientError.downloadCancelled)
                return
            } else {
                log.info(
                    "🟡 Spurious cancellation (-999), will retry: \(fileName, privacy: .public)")
                // fallthrough to retry logic
            }
        }

        // resumeData 있으면 저장
        if let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        {
            log.info(
                "🧵 resumeData saved for \(fileName, privacy: .public) bytes=\(resumeData.count)")
            state.setResumeData(file: fileName, data: resumeData)
        }

        // 재시도 판단
        let attempts = state.getAttempts(file: fileName)
        let max = cfg.maxAttempts
        if attempts + 1 >= max {
            finish(
                fileName: fileName, failure: ClientError.downloadFailed(error.localizedDescription))
            return
        }

        // 백오프
        let delay =
            (attempts < cfg.backoffSchedule.count)
            ? cfg.backoffSchedule[attempts] : cfg.backoffSchedule.last ?? 2.0
        state.setAttempts(file: fileName, value: attempts + 1)

        log.warning(
            "🧯 Download error (attempt \(attempts+1)/\(max), delay \(delay)s): \(fileName, privacy: .public) — \(error.localizedDescription, privacy: .public)"
        )

        // 재스케줄
        let urlForFile = Task.detached(priority: .utility) { [weak self] () -> URL? in
            guard let self else { return nil }
            return await self.remoteURL(for: fileName)
        }

        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let url = await urlForFile.value else {
                self.finish(fileName: fileName, failure: ClientError.invalidURL)
                return
            }
            let rd = self.state.getResumeData(file: fileName)
            self.scheduleDownloadTask(fileName: fileName, url: url, withResumeData: rd)
        }
    }

    private func cleanupAfterFinish(fileName: String) {
        // task는 이미 끝났을 수 있음
        if let task = state.getTask(file: fileName) {
            task.cancel()  // 안전 종료
        }
        state.clear(file: fileName)
    }

    private func finish(fileName: String, failure: Error) {
        let waiters = state.popWaiters(file: fileName)
        for w in waiters {
            w.progress?(0.0)
            w.continuation.resume(throwing: failure)
        }
        cleanupAfterFinish(fileName: fileName)

        NotificationCenter.default.post(
            name: .onDeviceDownloadFailed,
            object: nil,
            userInfo: [
                "fileName": fileName,
                "error": (failure as NSError).localizedDescription,
            ]
        )

        log.error(
            "❌ Download failed: \(fileName, privacy: .public) — \(failure.localizedDescription, privacy: .public)"
        )
    }

    // MARK: - Presign helper

    private func fetchPresignURL(endpoint: URL) async throws -> URL? {
        var req = URLRequest(url: endpoint)
        req.setValue(cfg.userAgent, forHTTPHeaderField: "User-Agent")
        req.httpMethod = "GET"

        let session = URLSession(configuration: .ephemeral)
        log.info("🔐 Presign request: \(endpoint.absoluteString, privacy: .public)")
        let (data, resp) = try await session.data(for: req)

        guard let http = resp as? HTTPURLResponse else {
            log.error("🔐 Presign response not HTTP")
            throw ClientError.presignFailed("HTTP 응답 아님")
        }

        log.info(
            "🔐 Presign HTTP \(http.statusCode, privacy: .public) bytes=\(data.count, privacy: .public)"
        )

        switch http.statusCode {
        case 200:
            // JSON {"url": "..."} 또는 본문에 URL(plain text)
            if let url = parseURLFromPresignBody(data: data) { return url }
            throw ClientError.presignFailed("본문 파싱 실패")
        case 302, 303, 307, 308:
            if let loc = http.allHeaderFields["Location"] as? String, let url = URL(string: loc) {
                return url
            }
            throw ClientError.presignFailed("리다이렉트 Location 누락")
        default:
            throw ClientError.presignFailed("상태 코드 \(http.statusCode)")
        }
    }

    private func parseURLFromPresignBody(data: Data) -> URL? {
        // JSON 우선, 실패 시 plain text
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let s = obj["url"] as? String,
            let u = URL(string: s)
        {
            return u
        }
        if let s = String(data: data, encoding: .utf8),
            let u = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines))
        {
            return u
        }
        return nil
    }
}

// MARK: - URLSessionDownloadDelegate

extension RemoteAssetClient: URLSessionDownloadDelegate {

    // 진행률 업데이트
    public func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard
            let fileName = downloadTask.taskDescription
                ?? downloadTask.originalRequest?.url?.lastPathComponent
        else { return }
        let expected = totalBytesExpectedToWrite
        let prog: Double
        if expected > 0 {
            prog = max(0.0, min(1.0, Double(totalBytesWritten) / Double(expected)))
        } else {
            // Content-Length 미보고 시 추정 불가 → 0~1 내부만 증가(보수적)
            let current = state.getProgress(file: fileName)
            prog = min(0.95, current + 0.01)
        }
        state.setProgress(file: fileName, value: prog)

        // Throttle progress logs to milestones 0/25/50/75/100
        let pct = Int(prog * 100)
        let milestones: Set<Int> = [0, 25, 50, 75, 100]
        if milestones.contains(pct) {
            let last = state.getLastLoggedPct(file: fileName) ?? -1
            if last != pct {
                log.info(
                    "📈 [\(fileName, privacy: .public)] written=\(totalBytesWritten, privacy: .public) expected=\(totalBytesExpectedToWrite, privacy: .public) (\(pct, privacy: .public)%)"
                )
                state.setLastLoggedPct(file: fileName, value: pct)
            }
        }

        NotificationCenter.default.post(
            name: .onDeviceDownloadProgress,
            object: nil,
            userInfo: [
                "fileName": fileName,
                "progress": prog,
                "bytesWritten": bytesWritten,
                "totalBytesWritten": totalBytesWritten,
                "totalBytesExpectedToWrite": totalBytesExpectedToWrite,
            ]
        )

        // 대기자 콜백
        let waiters = state.popWaiters(file: fileName)
        for w in waiters {
            w.progress?(prog)
        }
        // 다시 붙여두기(콜백 반복 허용)
        for w in waiters { state.addWaiter(file: fileName, waiter: w) }
    }

    // 다운로드 완료(임시파일 제공)
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard
            let fileName = downloadTask.taskDescription
                ?? downloadTask.originalRequest?.url?.lastPathComponent
        else { return }

        // ETag 저장(가능 시)
        if let http = downloadTask.response as? HTTPURLResponse,
            let etag = http.allHeaderFields["ETag"] as? String
        {
            state.setETag(file: fileName, etag: etag)
            let status = http.statusCode
            let contentLength = (http.allHeaderFields["Content-Length"] as? String) ?? "-"
            log.info(
                "✅ HTTP finished: \(fileName, privacy: .public) status=\(status, privacy: .public) ETag=\(etag, privacy: .public) Content-Length=\(contentLength, privacy: .public)"
            )
        } else {
            log.info("✅ HTTP finished: \(fileName, privacy: .public) (no HTTPURLResponse)")
        }

        let attrs = try? FileManager.default.attributesOfItem(atPath: location.path)
        let tmpSize = (attrs?[.size] as? NSNumber)?.int64Value ?? -1
        log.info(
            "📦 Temp file: \(location.lastPathComponent, privacy: .public) size=\(tmpSize, privacy: .public)"
        )

        // 무결성 검증/이동은 별도 처리
        handleDownloadSuccess(fileName: fileName, tempLocation: location)
    }

    // 태스크 완료(성공/오류)
    public func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
    ) {
        guard let fileName = task.taskDescription ?? task.originalRequest?.url?.lastPathComponent
        else { return }

        if let error = error {
            let ns = error as NSError
            let resumeData = ns.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            let resumeSize = resumeData?.count ?? 0
            log.error(
                "🧯 Task completed with error: \(fileName, privacy: .public) code=\(ns.code) domain=\(ns.domain, privacy: .public) resumeData=\(resumeSize, privacy: .public)"
            )
            // 실패 처리 → 재시도/종료(사용자 취소는 handleDownloadError에서 판단)
            handleDownloadError(fileName: fileName, error: error)
        } else {
            log.info("🏁 Task completed successfully: \(fileName, privacy: .public)")
            // 성공 시 didFinishDownloadingTo 에서 처리됨
        }
    }

    // 세션 무효화 콜백
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error as NSError? {
            log.error(
                "🧨 URLSession became invalid: domain=\(error.domain, privacy: .public) code=\(error.code)"
            )
        } else {
            log.info("🧨 URLSession became invalid: no error")
        }
    }

    // 백그라운드 이벤트 완료 콜백
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        log.info(
            "📬 urlSessionDidFinishEvents(forBackgroundURLSession:) called for \(self.cfg.backgroundSessionID, privacy: .public)"
        )
    }
}
