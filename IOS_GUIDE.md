아래는 App Store 심사 지침(2025-06-09 최신) 대비 실제 코드/설정(DeepSleep) 정밀 점검 결과입니다. Must-fix(출시 전), Should-fix(1주 내), Nice-to-have(권장)로 우선순위를 명확히 구분했습니다. 각 항목은 실제 파일/코드 위치와 함께 “왜(심사 조항)”, “무엇을” 보강해야 하는지로 요약합니다.

요약 결론 • 출시 전 필수(Must-fix): 6건 • 1주 내 권장(Should-fix): 7건 • 권장(Nice-to-have): 6건 • 전반적으로 개인정보/권한 고지와 결제 모델(모의 구독) 정합성, Background Audio 선언, Privacy Manifest 부재가 핵심 리스크입니다.

A. Must-fix: 제출 전 반드시 보완

In‑App Purchase 미구현(모의 구독 사용) 리스크 • 근거(지침 3.1.1, 2.3.1): 기능 잠금 해제/유료 티어(프리미엄)를 제공하면 반드시 IAP(StoreKit2) 사용이 필요. 현재 Subscription/SubscriptionManager.swift는 Mock(“구독 구매/복원/무료체험” 시뮬레이션)이며 실제 결제 흐름이 아님. • 확인 파일: DeepSleepApp/Subscription/SubscriptionManager.swift (mock 구매/복원/체험 로직, UserDefaults로 상태 저장). • 조치: • 옵션 A(권장): StoreKit2로 실제 자동갱신 구독 구현(구독 제품 등록, 영수증 검증, 복원 처리). • 옵션 B(임시 대안): App Store 제출 빌드에서 “구독/복원/무료체험 UI/문구/기능” 전부 제거(또는 전부 무료 동작). Mock 결제 흐름이 남아 있으면 “현혹/오해 소지”로 거절될 수 있음(2.3.1). • 메타데이터에도 “구독/체험” 관련 문구 제거 또는 실제 구독 구현 후 반영.

Info.plist 권한/설명 문자열 미비 • 근거(지침 5.1.1, 2.5): 민감 데이터 접근/기능 사용 시 정확한 설명 문자열 요구. • 현재 상태: Info.plist에 NSHealthShareUsageDescription/NSHealthUpdateUsageDescription 등 개인 정보 사용 설명 키가 없음. HealthKit 기능은 코드상 “임시 비활성화”지만(HealthKitManager.swift), 향후 활성화 시 필수. • 조치: • HealthKit 실제 사용 시: NSHealthShareUsageDescription, NSHealthUpdateUsageDescription 추가(“앱이 어떤 건강 데이터를 왜 읽고/쓰는지”). • ATT 사용 시(코드에 AppTrackingTransparency 참조 흔적 존재): NSUserTrackingUsageDescription 추가 또는 ATT 호출 제거(사용 안 할 경우). • 마이크/카메라/사진/위치 사용 안 함이 맞는지 재확인. 사용 시 각 NS…UsageDescription 필수.

Background Audio 사용인데 UIBackgroundModes 미선언 • 근거(지침 2.4.2 전원 효율/하드웨어 손상 방지, 2.5 소프트웨어 요구사항): 백그라운드 오디오 재생 시 Info.plist에 UIBackgroundModes=audio 선언 필요. • 확인: AppDelegate에서 오디오 세션(.playback) 활성화 및 원격 제어 이벤트 수신. 수면용 사운드 앱 컨셉으로 보면 백그라운드 재생이 핵심일 가능성 높음. 그러나 Info.plist에 UIBackgroundModes 없음. • 조치: Info.plist에 UIBackgroundModes → [audio] 추가. 과도한 배터리 소모/발열 유발 로직은 없는지 재점검.

Privacy Manifest(PrivacyManifest.json) 부재 • 근거(지침 5.1, Xcode 15+/SDK 최신 정책): 앱/서드파티 SDK의 데이터 접근/추적 여부를 선언하는 Privacy Manifest 권장/사실상 요구. • 확인: 프로젝트 루트/타겟 리소스에 PrivacyManifest.json 없음. • 조치: “tracking”: false(추적 미사용 시), “accessedAPITypes”에 사용하는 민감 API 없으면 최소 템플릿이라도 추가. 타 SDK 연동 시 해당 SDK의 Privacy Manifest 충족 확인.

푸시/로컬 알림 사용의 투명성 및 프로모션 알림 금지 • 근거(지침 4.5.4): 사용자가 동의하지 않은 마케팅/프로모션 목적의 푸시 금지. 옵트아웃 경로 필요. • 확인: 현재는 주로 로컬 알림(Todo 리마인더, API 설정 안내) 사용. 마케팅 푸시 없음. 다만 앱 내 “알림 설정/해제” 진입점(옵트아웃) UI가 있는지 확인 필요. • 조치: 설정 화면에 알림 안내/해제 링크 제공(시스템 설정으로 이동하는 버튼) 및 알림 용도 명시.

의료/건강 조언 관련 고지(면책) 부족 • 근거(지침 1.4.1 의료/건강 데이터, 1.4 신체적 부상 방지): 의학적 진단/치료 대체 금지, 의사 상담 권고 명시. • 확인: HealthKitManager.swift가 “수면 부족 감지/스트레스 관리 필요” 등 건강 조언 문자열을 생성. 면책 고지/의사 상담 권고 고지 위치 미확인. • 조치: 관련 화면/설정에 “의학적 조언 아님, 의사 상담 권고” 고지 추가. App Store 설명에도 반영.

B. Should-fix: 1주 내 보완

ATT(추적) 코드 정리와 NSUserTrackingUsageDescription • 근거(지침 5.1.2 추적): AppTrackingTransparency API 사용 시 명확한 목적과 설명 필요. 사용 안 하면 호출 제거. • 확인: 코드 전역에 AppTrackingTransparency/ requestTrackingAuthorization 검색 히트 존재(여러 파일). Info.plist에 NSUserTrackingUsageDescription 없음. • 조치: 실제 추적/광고가 없으면 ATT 호출 제거. 필요하면 NSUserTrackingUsageDescription 추가 및 목적 고지.

“정확한 메타데이터” 점검(스크린샷/미리보기/설명) • 근거(지침 2.3.x): 스크린샷/미리보기는 실제 앱 동작을 보여야 함. “구독/건강 조언/AI 기능” 등 실제 구현과 문구 일치 필요. • 조치: IAP가 미구현이면 관련 문구/스크린샷 제거. HealthKit 비활성이라면 해당 기능 홍보 금지. “무료 체험” 문구 제거(모의 흐름 금지).

개발자 연락처/지원 URL • 근거(지침 1.5 개발자 정보): 앱/지원 URL에 개발자 연락 수단 제공. • 확인: 코드 내 별도 확인 어려움. App Store Connect 메타데이터/앱 내 “설정>문의/지원” 버튼 제공 권장. • 조치: SettingsViewController 등에서 “개발자에게 문의하기/개인정보처리방침/이용약관” 링크 제공.

어린이 카테고리 오해 소지 제거 • 근거(지침 1.3, 2.3.8): “어린이용/아동용” 등 메타데이터 금지(해당 카테고리 아닌 경우). • 확인: 코드상 직접 용어는 보이지 않으나, 스토어 메타데이터 작성 시 주의.

알림 사용 범위 표준화(프로모션 금지, 옵트아웃) • 근거(지침 4.5.4): 이미 Must-fix 맥락과 연계. UI에서 끄는 경로/설명을 명시적으로 제공.

AI 개인정보 최소화/필터링 고도화 • 근거(지침 5.1 데이터 최소화): 외부 AI로 전송 전 필터/익명화. 문서는 “비식별 서술형 컨텍스트만 전송” 원칙 명확. • 확인: InputValidationManager/AISecurityManager/AIContextManager 등 존재. 실제 외부 전송 경로(UnifiedAIServiceImpl)에서 PII 필터가 항상 적용되는지 재점검. • 조치: 외부 전송 직전에 마지막 한 번 더 필터링/로그 비식별 확인. 로그에 민감값 미출력 유지.

앱 내 “개인정보처리방침” 링크 노출 • 근거(지침 5.1.1(i)): 앱 내부에서 쉽게 볼 수 있어야 함. • 조치: 설정화면에 “개인정보처리방침/이용약관” 버튼 추가(웹 링크).

C. Nice-to-have: 권장 개선

PrivacyManifest.json 최소 템플릿 추가 • “NSPrivacyTracking”: false • “NSPrivacyCollectedDataTypes”: 사용하지 않음(또는 실제 사용 데이터 유형 반영) • “NSPrivacyAccessedAPITypes”: 민감 API 미사용이면 빈 구조.

Core Data 오류 처리 고도화 완료 확인 • 확인: AppDelegate.swift의 fatalError 제거 및 우아한 폴백/알림/로깅 구현됨(좋음). 이 상태 유지.

HealthKit Entitlements/권한 완전 비활성 또는 완전 활성 • 현재 DeepSleep.entitlements는 주석 형태로 “비활성”처럼 보이나, 실제 타겟 Capabilities에서 HealthKit 꺼져 있어야 함. 나중에 활성화 시 Info.plist 설명/권한/승인 UI/데이터 처리 합치.

Notification 사용자 흐름 개선 • 첫 실행 시 알림 권한 요청 맥락 설명(왜 필요한지), 설정에서 다시 허용 안내(시스템 설정 딥링크).

배터리/성능 방지 문구/로직 • 지침 2.4.2 맥락: “충전 중/베개 아래 두고 사용” 등 위험 유도 금지. 문구 점검.

로그/메트릭 PII 제로 정책 • UnifiedLogger/RemoteLogger가 민감값을 남기지 않도록 최종 점검.

D. 코드/파일별 구체적 점검 스냅샷 • Info.plist: 다수의 설정 키/비밀은 xcconfig→Info.plist로 주입(좋음). 그러나 NS…UsageDescription(Health/Tracking 등) 없음, UIBackgroundModes 없음. • DeepSleep.entitlements: HealthKit 키 주석 처리(사실상 비어있음). 실제 Capabilities “Off” 확인 필요. • AppDelegate.swift: • AVAudioSession playback 설정/원격 제어 시작 → UIBackgroundModes=audio 필요. • 알림 권한 요청/로컬 알림 스케줄 사용(OK). 프로모션 없음. • Core Data fatalError 제거(우아한 폴백/알림/로깅 구현됨) – 지침 친화적. • HealthKitManager.swift: • “개발자 계정 부족으로 임시 비활성화” 주석/Mock 데이터 경로. 실제 배포 시 HealthKit 사용 전면 재검토(권한/설명/엔타이틀먼트/데이터 처리 고지/면책). • SubscriptionManager.swift: • Mock 결제/복원/무료 체험(위험). App Store 빌드에서 제거 또는 StoreKit2로 교체 필요. • InputValidationManager.swift, SecureStorageManager.swift: • 입력 검증/살균, Keychain 저장 등 보안 관점 양호. 로그 민감정보 노출 금지 계속 준수 필요.

E. 심사 항목 매핑(핵심만) • 1.4.x(신체/의료): 건강 조언 면책 고지·의사 상담 권고 필수. • 2.3.x(정확한 메타데이터): 스토어 설명/스크린샷/미리보기와 실제 기능 일치(구독/HealthKit/AI 기능). • 2.4.2(전원/자원): Background Audio 사용 시 Info.plist 선언, 과도한 리소스 소모 방지. • 2.5(공개 API/현재 OS): 공개 API만 사용. WebKit 대체 엔진 없음(OK). • 3.1.1(IAP): 모의 결제 금지. 실제 StoreKit2 또는 유료기능 제거. • 4.5.4(푸시): 프로모션 푸시 금지, 옵트아웃 제공. • 5.1(개인정보): 개인정보처리방침 노출, 데이터 최소화, ATT/HealthKit 등 설명·동의.

F. 권장 작업 순서(빠른 합격 목적)

Info.plist: • UIBackgroundModes → audio 추가. • (ATT 사용 시) NSUserTrackingUsageDescription 추가 또는 ATT 코드 제거. • (향후 HealthKit 활성 시) NSHealthShareUsageDescription/NSHealthUpdateUsageDescription 준비.

IAP 정리: • 이번 제출에서 구독/복원/무료 체험 전면 비활성(스토어 문구/화면 포함) 또는 StoreKit2 구현.

앱 내 고지/정책: • 설정에 “개인정보처리방침/이용약관/문의하기” 버튼 추가. • 건강/수면 코칭 화면에 “의학적 조언 아님/의사 상담 권고” 고지 추가.

Privacy Manifest 추가: • 추적 안 함 선언, 민감 API 비사용이면 최소 템플릿.

알림 안내: • 알림 목적 설명(리마인더 등), 설정 이동 버튼 제공.

AI 전송 전 필터 최종점검: • UnifiedAIServiceImpl 외부 전송 직전 PII 필터 확실히 적용(이미 문서상 원칙 존재 — 코드 경로 재검증).

불확실성/주의점 • ATT 실사용 여부: 코드에 흔적이 있으나 실제 호출/노출 경로를 전부 열람하지는 않았음. 빌드 플래그/조건부 분기 확인 권장. • HealthKit: 현재 비활성 경로지만, 스토어 메타데이터/스크린샷에 HealthKit 연동을 암시하지 않도록 주의. • 배터리/발열: 장시간 오디오 재생 앱 특성상 리뷰어가 전원 효율을 유심히 봄. 오디오 엔진/샘플 레이트/믹싱 옵션 과도 사용 방지 점검 권장.

마지막 점검 체크리스트(출시 전 최종) • IAP: Mock 결제 전면 제거 또는 StoreKit2 구현 완료 • Info.plist: UIBackgroundModes(audio), 필요한 NS…UsageDescription(ATT/HealthKit 등) 반영 • 앱 내: 개인정보처리방침/문의/면책 고지/알림 옵트아웃 경로 • PrivacyManifest.json 추가 • 메타데이터: 실제 기능과 정확히 일치(“구독/HealthKit/무료체험” 문구/이미지 불일치 제거) • 로그/분석: PII 미포함 확인
