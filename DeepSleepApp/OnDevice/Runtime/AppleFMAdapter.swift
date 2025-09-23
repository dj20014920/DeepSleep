import Foundation
import OSLog

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - AppleFMAdapter
// - Apple Foundation Models 연동 어댑터(간결/직관/KISS)
// - iOS 26.0+에서 FoundationModels 프레임워크가 제공하는 SystemLanguageModel 사용
// - iOS 26.0 미만 또는 프레임워크 미제공 환경에서는 안전하게 오류를 던지고 호출자가 폴백
//
// 사용 예:
//   if AppleFMAdapter.isAvailable {
//       let text = try await AppleFMAdapter.generateFull(sys: systemPrompt, user: content)
//   } else {
//       AppleFMAdapter.openSettingsShortcut()
//   }

public enum AppleFMAdapter {
    private static let log = Logger(subsystem: "DeepSleep.AppleFM", category: "Adapter")

    // 가용성: OS(26.0+) + FoundationModels 모듈
    public static var isAvailable: Bool {
        #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                return true
            }
        #endif
        return false
    }

    // 설정 바로가기(사용자가 Apple Intelligence/관련 설정을 찾을 수 있도록 앱 설정 화면으로 이동)
    // 반환값: open 호출 성공 여부
    @discardableResult
    public static func openSettingsShortcut() -> Bool {
        #if canImport(UIKit)
            let url = URL(string: UIApplication.openSettingsURLString)!
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                return true
            }
        #endif
        return false
    }

    // 간단 경고/안내를 띄우고 설정으로 유도(UIViewController 문맥에서 호출)
    #if canImport(UIKit)
        public static func presentEnableAlert(on presenter: UIViewController) {
            let alert = UIAlertController(
                title: "Apple Foundation Models 사용",
                message: "애플 온디바이스 모델을 사용하려면 기기에서 관련 기능을 활성화해야 합니다. 설정으로 이동할까요?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "취소", style: .cancel, handler: nil))
            alert.addAction(
                UIAlertAction(
                    title: "설정으로 이동", style: .default,
                    handler: { _ in
                        _ = AppleFMAdapter.openSettingsShortcut()
                    }))
            presenter.present(alert, animated: true, completion: nil)
        }
    #endif
}

// MARK: - 실제 구현 (iOS 26.0+ / FoundationModels)
#if canImport(FoundationModels)
    import FoundationModels

    @available(iOS 26.0, *)
    extension AppleFMAdapter {
        // 단일 요청(완성본) 생성
        // - 시스템 프롬프트(sys)가 있으면 사용자 입력 앞에 간단히 접두(가장 단순하고 견고한 방식)
        // - FoundationModels의 지시어/세션 API가 변경될 수 있으므로 최소 가정으로 구성
        public static func generateFull(sys: String?, user: String) async throws -> String {
            // 방어적 전처리
            let trimmed = user.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw AppleFMError.invalidInput
            }

            // 1) 세션 획득: 세션 풀 우선, 비활성/미지원 시 새로 생성
            let instructions = sys?.trimmingCharacters(in: .whitespacesAndNewlines)
            let session: LanguageModelSession
            if AppleFMSessionPool.isEnabled {
                // tone 해시를 포함한 세션 키 구성 (페르소나/모드/모델/톤 일관성 유지)
                let userSettingsForTones = UserSettingsModel.loadFromUserDefaults()
                let comps = UserRulesManager.shared.personaSignatureComponents(
                    currentMode: .generalConversation,
                    model: .onDevice,
                    conversationTones: userSettingsForTones.conversationTones
                )
                let key = AppleFMSessionPool.buildKey(
                    personaCoreHash: comps.coreHash,
                    mode: .generalConversation,
                    model: .onDevice,
                    tone: comps.toneHash,
                    systemPrompt: instructions
                )
                session = try await AppleFMSessionPool.shared.acquire(
                    key: key, instructions: instructions)
            } else {
                if let s = instructions, !s.isEmpty {
                    session = LanguageModelSession(instructions: s)
                } else {
                    session = LanguageModelSession()
                }
            }

            // 2) 요청/응답
            let t0 = Date()
            let result = try await session.respond(to: trimmed)
            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            Self.log.info("🍎 AppleFM responded (\(ms) ms, \(result.content.count) chars)")

            // 응답 캐시 저장 제거: 세션 풀 재사용으로 지연 최적화
            return result.content
        }
    }

#endif  // canImport(FoundationModels)

// MARK: - 오류 타입

public enum AppleFMError: Error, LocalizedError {
    case notAvailable  // OS/프레임워크 비가용
    case invalidInput  // 빈 입력 등
    case operationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Apple Foundation Models을 사용할 수 없는 환경입니다."
        case .invalidInput:
            return "입력이 비어 있습니다."
        case .operationFailed(let reason):
            return "Apple Foundation Models 처리 중 오류: \(reason)"
        }
    }
}
