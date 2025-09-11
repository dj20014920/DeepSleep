import Foundation
// Catalog 의존 타입 사용
import AVFoundation

/// SoundPresetUtilities
/// - 목적: 사운드 프리셋 관련 공통 유틸을 단일 장소에서 제공해 DRY 및 SSoT를 보장
/// - 통합 대상:
///   1) safePresetName  : 프리셋 이름 정리 및 기본값 부여
///   2) generateOptimalVersions : 볼륨 기반 버전 선택 로직(결정적, 비랜덤)
///
/// 사용처 예:
/// - AIResponseParser / ChatViewController / 기타 추천 파이프라인에서 동일 로직 재사용
/// - 버전 선택의 랜덤 요소 제거(E 규칙 준수)
public enum SoundPresetUtilities {

    // MARK: - Public API

    /// 프리셋 이름을 안전하게 정리하여 반환합니다.
    /// - Rules:
    ///   - nil 또는 공백 전용 문자열 → "🎵 AI 추천"
    ///   - 좌우 공백 제거
    public static func safePresetName(_ name: String?) -> String {
        let cleaned = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "🎵 AI 추천" : cleaned
    }

    /// 프리셋 이름을 안전하게 정리하여 반환합니다.
    /// - Overload: Non-optional 파라미터 버전
    public static func safePresetName(_ name: String) -> String {
        safePresetName(Optional(name))
    }

    /// 볼륨 배열을 기반으로 각 카테고리의 최적 버전을 결정적으로 선택합니다.
    /// - 주의:
    ///   - 절대 랜덤을 사용하지 않습니다. (E 규칙: 랜덤 제거)
    ///   - SoundPresetCatalog의 동적 카테고리/버전 정보를 활용합니다.
    ///   - 인덱스별 휴리스틱(기존 구현과 동등)을 유지하여 기존 동작을 보존합니다.
    ///
    /// - Parameter volumes: 카테고리별 볼륨(0...100), 길이는 카탈로그 카테고리 수와 다를 수 있음
    /// - Returns: 카테고리별 선택된 버전 인덱스 배열
    public static func generateOptimalVersions(volumes: [Float]) -> [Int] {
        // 카탈로그 기준으로 볼륨 배열을 안전하게 정규화
        let normalizedVolumes = normalizeVolumesToCatalog(volumes)

        // 카탈로그에서 기본 버전 배열을 가져와 수정(카탈로그가 보장하는 유효한 범위)
        var versions = SoundPresetCatalog.defaultVersions

        for (index, volume) in normalizedVolumes.enumerated() {
            // 카탈로그 기준으로 해당 카테고리에 다중 버전이 존재할 때만 휴리스틱 적용
            if SoundPresetCatalog.hasMultipleVersions(at: index) {
                // 기존 구현과 동일한 인덱스별 휴리스틱(결정적)
                switch index {
                case 1:
                    versions[index] = volume > 60 ? 1 : 0
                case 2:
                    versions[index] = volume > 70 ? 1 : 0
                case 4:
                    versions[index] = volume > 50 ? 1 : 0
                case 9:
                    versions[index] = volume > 65 ? 1 : 0
                case 10:
                    versions[index] = volume > 60 ? 1 : 0
                case 11:
                    versions[index] = volume > 55 ? 1 : 0
                case 12:
                    versions[index] = volume > 50 ? 1 : 0
                default:
                    // 명시 휴리스틱이 없는 카테고리는 기본 버전 유지
                    break
                }
            }
        }

        return versions
    }

    // MARK: - Internal Helpers

    /// 카탈로그 메타데이터에 맞게 볼륨 배열을 안전하게 정규화합니다.
    /// - clamp: 각 값은 0...100 범위로 제한
    /// - size  : SoundPresetCatalog.categoryCount 길이에 맞춰 자르거나 패딩(0) 처리
    static func normalizeVolumesToCatalog(_ volumes: [Float]) -> [Float] {
        let count = SoundPresetCatalog.categoryCount
        if count <= 0 {
            return []
        }

        // 1) 길이 조정 (부족하면 0으로 패딩, 초과하면 잘라냄)
        var adjusted = volumes
        if adjusted.count < count {
            adjusted.append(contentsOf: Array(repeating: 0, count: count - adjusted.count))
        } else if adjusted.count > count {
            adjusted = Array(adjusted.prefix(count))
        }

        // 2) 범위 클램프
        for i in 0..<adjusted.count {
            adjusted[i] = min(100, max(0, adjusted[i]))
        }

        return adjusted
    }
}
