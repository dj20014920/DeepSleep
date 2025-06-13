import Foundation
import CryptoKit
#if canImport(Compression)
import Compression
#endif

/// LoRA 어댑터 동적 다운로드/적용 매니저
@available(iOS 17.0, *)
public final class DynamicLoRAAdapter {
    public static let shared = DynamicLoRAAdapter()
    private let cacheDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("com.deepsleep/adapter_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    /// 어댑터 파일 다운로드 및 캐시
    /// - Parameters:
    ///   - url: HTTPS .adapter 파일 URL
    ///   - rank: Core ML 7용 rank 파라미터
    /// - Returns: 캐시된 어댑터 파일 경로
    public func downloadAdapter(from url: URL, rank: Int) async throws -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        let cached = cacheDir.appendingPathComponent("\(hash)_rank\(rank).adapter")
        if FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        #if canImport(Compression)
        let decompressed = try decompressGzip(data: data)
        #else
        let decompressed = data // fallback: 압축 해제 미지원 시 원본 저장
        #endif
        try decompressed.write(to: cached, options: .atomic)
        return cached
    }
    /// Gzip 압축 해제
    private func decompressGzip(data: Data) throws -> Data {
        #if canImport(Compression)
        var dst = Data()
        try data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) in
            let src = srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
            let srcSize = data.count
            let bufferSize = 64 * 1024
            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { dstBuffer.deallocate() }
            var stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
            defer { stream.deallocate() }
            var status = compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            guard status == COMPRESSION_STATUS_OK else { throw NSError(domain: "Gzip", code: -1) }
            stream.pointee.src_ptr = src
            stream.pointee.src_size = srcSize
            stream.pointee.dst_ptr = dstBuffer
            stream.pointee.dst_size = bufferSize
            repeat {
                status = compression_stream_process(stream, 0)
                let written = bufferSize - stream.pointee.dst_size
                if written > 0 {
                    dst.append(dstBuffer, count: written)
                }
                stream.pointee.dst_ptr = dstBuffer
                stream.pointee.dst_size = bufferSize
            } while status == COMPRESSION_STATUS_OK
            compression_stream_destroy(stream)
            if status != COMPRESSION_STATUS_END {
                throw NSError(domain: "Gzip", code: -2)
            }
        }
        return dst
        #else
        throw NSError(domain: "Gzip", code: -999)
        #endif
    }
} 