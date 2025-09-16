# Repository Guidelines

## 프로젝트 구조 & 모듈
- 소스: `DeepSleepApp/` (AI, Chat, Sound, Security, StoreKit 등 Swift 코드).
- 테스트: `DeepSleepTests/`(단위) 및 `DeepSleepUITests/`(UI/XCUITest).
- 프로젝트: `DeepSleep.xcodeproj`, 에셋은 `DeepSleepApp/Assets.xcassets`.
- 스크립트: `scripts/`(스모크 빌드/테스트, 금지 API 스캔, PII 내보내기 검증).
- 참고사항: `DeelSleep내부 .md로 끝나는 가이드, 로드맵의 이름을 가진 파일들을 참조할것.`

## 빌드 · 테스트 · 로컬 실행
- Xcode 열기: `open DeepSleep.xcodeproj` → 스킴 `DeepSleep` 선택 후 시뮬레이터 실행.
- 스모크 체크: `bash scripts/dev_build_test_smoke.sh` (클린 빌드 + 단위 테스트, iPhone 16 Pro 시뮬레이터).
- 정적 스캔: `bash scripts/scan_banned_calls.sh` (AI 호출 단일 진입점 위반 탐지).
- PII 검증: `bash scripts/verify_export_pii.sh` (공유 텍스트 익명화 보장).
- 예시: `xcodebuild -scheme DeepSleep -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test`.

## 코딩 스타일 & 네이밍
- Swift 5.x, 스페이스 4칸, 가독성 120자 내 권장(프로젝트 기본 규칙 준수).
- 타입: UpperCamelCase, 메서드/변수: lowerCamelCase, 파일명=대표 타입명.
- 아키텍처: 모든 AI 메시지는 `SessionManager` 단일 진입점 경유, 프롬프트는 `AIContextBuilder` 조립, 시스템 프롬프트는 `AIContextManager` 캐시(TTL≈3h). `UnifiedAIServiceImpl.shared` 직접 사용 금지(스クリ프트로 강제).

## 테스트 가이드
- 프레임워크: XCTest. 테스트는 `DeepSleepTests/*Tests.swift`에 배치.
- 명명: `testFeature_Scenario_Expected()` 형태로 의도 명확히.
- 실행: 스모크 스크립트 또는 `xcodebuild ... test` 사용.
- 새 기능/버그 수정 시 필수로 단위 테스트 추가, 로컬 그린 상태에서 PR.

## 커밋 & PR 가이드
- 커밋 메시지: 짧고 명령형(히스토리 예: “크래시 수정”, “저장소 개선”).
- PR 요구사항: 변경 의도/범위, UI 변경 시 스크린샷, 테스트 노트, 관련 이슈 링크.
- 필수 체크: 빌드/테스트 통과, `scan_banned_calls.sh`·`verify_export_pii.sh` 무위반.

## 보안 & 설정 팁
- 비밀/설정은 `DeepSleepApp/*.xcconfig` 사용(`gpt.xcconfig`, `gemini.xcconfig`, `Secrets.xcconfig` 등). 실제 키는 커밋 금지.
- 텍스트 공유/내보내기 전 반드시 `SettingsManager.maskPIIForExport(...)`(또는 `exportUserDataSanitized`/`sanitizePII`) 호출. 정적 문자열만 `// PII_OK` 예외 허용.
