

---

⚠️ **필수 사전 준비사항 (2025-08-21 기준)**

### Apple Developer Program 가입 상태
- **현재 상태**: 무료 개발자 계정
- **필요한 작업**: Apple Developer Program 가입 필수
- **비용**: 연 $99 (한국: ₩129,000)
- **가입 링크**: https://developer.apple.com/programs/

### 가입 후 진행 가능한 작업
1. **StoreKit 테스트**
   - 시뮬레이터에서 .storekit 파일을 통한 로컬 테스트
   - 실기기에서 Sandbox 테스터 계정으로 테스트
2. **App Store Connect 설정**
   - 앱 등록 및 메타데이터 입력
   - 인앱 구매 상품 등록
3. **TestFlight 배포**
   - 내부/외부 베타 테스트
4. **App Store 심사 및 출시**

### 현재까지 완료된 작업
- ✅ StoreKit 2 기반 구독 시스템 전체 구현
- ✅ PaywallViewController UI 구현
- ✅ SubscriptionStatusCenter 상태 관리
- ✅ DeepSleep.storekit 테스트 설정 파일 생성
- ✅ 월간/연간 구독 상품 정의 (com.deepsleep.premium.monthly/yearly)
- ✅ 7일 무료 체험 설정

---

2025-08-21 업데이트: 정책 허브 텍스트 내장 + Privacy Manifest 반영
- 설정 > 앱 정보 > 정책 모음집: 개인정보/약관/구독관리/면책을 앱 내 텍스트로 직접 표시(외부 URL 불필요). 구독 관리는 iOS 설정 딥링크 유지.
- 파일/경로: DeepSleepApp/Settings/PolicyHubViewController.swift (텍스트 내장), Privacy/PrivacyInfo.xcprivacy 추가(추적=false, 민감 API 미사용 기본 템플릿).
- 심사 메모: 정책은 앱 내에서 쉽게 접근 가능하면 URL 필수 아님(단, 제출 시 메타데이터와 문구 일치 필요). 구독 관리는 설정 앱 딥링크 권장.

2025-08-21 업데이트: .storekit 실행 요령 추가
- Xcode > Scheme > Run > Options: StoreKit Configuration = DeepSleepApp/StoreKit/DeepSleep.storekit로 설정
- 앱 실행 후 Paywall 화면에서 월/연/Trial/복원 흐름 점검
- 상세 시나리오와 체크 포인트는 STOREKIT_QA_CHECKLIST.md 참고



---

2025-08-21 업데이트: 설정 화면 정책 모음집(Policy Hub) 도입
- 설정 > 앱 정보 섹션에 “정책 모음집” 항목을 추가했습니다.
- 포함 항목: 개인정보처리방침, 이용약관, iOS 구독 관리(설정 앱 딥링크), 건강/의학적 조언 면책 고지.
- 파일/경로: DeepSleepApp/Settings/PolicyHubViewController.swift, SettingsViewController.swift (항목명 교체 및 네비게이션).
- 문구 원칙: KISS/DRY/YAGNI/SOLID를 준수하여 단일 허브로 정책 접근 경로 일원화.

사용자 액션 경로
- 설정 → 앱 정보 → 정책 모음집 → 각 정책 항목 진입

향후 조치
- 실제 정책 URL(privacy, terms) 확정 시 PolicyHubViewController 내 placeholder URL 교체.
- 필요 시 면책 고지 추가 세부 항목(수면 데이터/건강 데이터 관련 고지) 분리 가능.

아래는 App Store 심사 지침(2025-06-09 최신) 대비 실제 코드/설정(DeepSleep) 정밀 점검 결과입니다. Must-fix(출시 전), Should-fix(1주 내), Nice-to-have(권장)로 우선순위를 명확히 구분했습니다. 각 항목은 실제 파일/코드 위치와 함께 “왜(심사 조항)”, “무엇을” 보강해야 하는지로 요약합니다.

요약 결론 • 출시 전 필수(Must-fix): 6건 • 1주 내 권장(Should-fix): 7건 • 권장(Nice-to-have): 6건 • 전반적으로 개인정보/권한 고지와 결제 모델(모의 구독) 정합성, Background Audio 선언, Privacy Manifest 부재가 핵심 리스크입니다.

A. Must-fix: 제출 전 반드시 보완

IAP 상태 업데이트(2025-08-20)
- 기존: In‑App Purchase 미구현(모의 구독 사용) 리스크
- 현재: StoreKit2 기본 플로우 연결됨(제품 로드/구매/복원/트랜잭션 스트림/권리 방송), Paywall ↔ StoreKit 결선 완료
- 남은 사항: 환불/만료 UI 안내, 전역 화면의 구독 상태 옵저버 적용, .storekit QA 시나리오 실행, PrivacyManifest/Info 키 최종 점검
- 관련 파일(싱크 지점):
  • DeepSleepApp/Subscription/StoreKitSubscriptionManager.swift, SubscriptionStatusCenter.swift
  • DeepSleepApp/Paywall/PaywallViewController.swift, Paywall/EntitlementUI.swift, Subscription/AppFeature.swift, Subscription/EntitlementGate.swift
  • DeepSleepApp/AI/UsageLimitManager.swift, Core/FeatureFlags.swift, Core/KSTDatePolicy.swift
  • DeepSleepApp/StoreKit/DeepSleep.storekit, Secrets.xcconfig (DeepSleepApp/Secrets.xcconfig)

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

IAP/App Review 체크리스트(2025-08-21 업데이트)
- 결제 흐름
  - [✅] StoreKit Configuration 파일 연결됨 (Run > Options) — DeepSleepApp/StoreKit/DeepSleep.storekit
  - [✅] 월간/연간 제품 노출 및 현지화 표시가(Product.displayPrice)
  - [✅] 7일 Intro Offer 표기, 동일 그룹 1회 정책 카피 반영
  - [✅] 복원 버튼(AppStore.sync) 동작 및 설정 화면 복원 경로
- 권리/게이트/한도
  - [✅] SubscriptionStatusCenter 연동으로 권리 변경 즉시 반영
  - [✅] EntitlementGate.canAccess 적용(차단 시 Paywall 자연 노출)
  - [✅] 무료=Gemini 고정, Trial/프리미엄=상향 한도(UsageLimitManager)
  - [✅] 월간 통계: KST 월요일 00:00 주 1회 제한, UI 노출/활성 동기
- 정책/문구/자산
  - [✅] 연간은 월 대비 ~20% 할인 문구 일관성(앱/스토어)
  - [ ] 의료/건강 면책 고지 위치 명확(해당 화면/설정)
  - [✅] 개인정보처리방침/이용약관/문의 링크 노출 (PolicyHubViewController)
- 시스템/설정
  - [ ] Info.plist: UIBackgroundModes=audio, (ATT 사용 시) NSUserTrackingUsageDescription
  - [✅] PrivacyManifest.json 최소 템플릿(tracking=false 등) - PrivacyInfo.xcprivacy 추가됨
  - [✅] .gitignore에 Secrets.xcconfig 포함, 실제 키 미커밋

F. 권장 작업 순서(빠른 합격 목적)

Info.plist: • UIBackgroundModes → audio 추가. • (ATT 사용 시) NSUserTrackingUsageDescription 추가 또는 ATT 코드 제거. • (향후 HealthKit 활성 시) NSHealthShareUsageDescription/NSHealthUpdateUsageDescription 준비.

IAP 정리: • 이번 제출에서 구독/복원/무료 체험 전면 비활성(스토어 문구/화면 포함) 또는 StoreKit2 구현.

앱 내 고지/정책: • 설정에 “개인정보처리방침/이용약관/문의하기” 버튼 추가. • 건강/수면 코칭 화면에 “의학적 조언 아님/의사 상담 권고” 고지 추가.

Privacy Manifest 추가: • 추적 안 함 선언, 민감 API 비사용이면 최소 템플릿.

알림 안내: • 알림 목적 설명(리마인더 등), 설정 이동 버튼 제공.

AI 전송 전 필터 최종점검: • UnifiedAIServiceImpl 외부 전송 직전 PII 필터 확실히 적용(이미 문서상 원칙 존재 — 코드 경로 재검증).

불확실성/주의점 • ATT 실사용 여부: 코드에 흔적이 있으나 실제 호출/노출 경로를 전부 열람하지는 않았음. 빌드 플래그/조건부 분기 확인 권장. • HealthKit: 현재 비활성 경로지만, 스토어 메타데이터/스크린샷에 HealthKit 연동을 암시하지 않도록 주의. • 배터리/발열: 장시간 오디오 재생 앱 특성상 리뷰어가 전원 효율을 유심히 봄. 오디오 엔진/샘플 레이트/믹싱 옵션 과도 사용 방지 점검 권장.

마지막 점검 체크리스트(출시 전 최종) • IAP: Mock 결제 전면 제거 또는 StoreKit2 구현 완료 • Info.plist: UIBackgroundModes(audio), 필요한 NS…UsageDescription(ATT/HealthKit 등) 반영 • 앱 내: 개인정보처리방침/문의/면책 고지/알림 옵트아웃 경로 • PrivacyManifest.json 추가 • 메타데이터: 실제 기능과 정확히 일치(“구독/HealthKit/무료체험” 문구/이미지 불일치 제거) • 로그/분석: PII 미포함 확인

---

## 🔒 프록시 서버 구축 가이드 (상용화 필수)

### 🎯 프록시 서버 필요성

#### 현재 아키텍처의 치명적 보안 위험
**문제점:**
- API 키가 앱 바이너리에 포함됨 (Secrets.xcconfig → 컴파일 시 앱에 내장)
- 리버스 엔지니어링으로 API 키 탈취 가능
- 악의적 사용자의 무제한 API 남용 → **수만 달러 비용 폭탄 위험**

**해결책:**
- 프록시 서버를 통한 API 키 안전 보관
- 앱 → 프록시 서버 → AI 서비스 구조로 변경
- 서버에서 사용량 제한 및 모니터링

### 🏗️ 프록시 서버 아키텍처

#### 1단계: 기본 프록시 서버 (필수)
```
[iOS 앱] → [프록시 서버] → [Claude/OpenAI/Gemini/Naver API]
```

**핵심 기능:**
- API 키 안전 보관 (환경변수/시크릿 관리)
- AI 요청 중계 및 응답 전달
- 기본적인 요청 검증 및 로깅

#### 2단계: 사용량 관리 서버 (권장)
```
[iOS 앱] → [프록시 서버] ← [데이터베이스]
                ↓
        [AI 서비스들]
```

**추가 기능:**
- 사용자별 사용량 추적
- 실시간 제한 적용
- 사용 통계 수집

#### 3단계: 완전한 관리 시스템 (고도화)
```
[iOS 앱] → [프록시 서버] ← [데이터베이스]
                ↓              ↓
        [AI 서비스들]    [관리자 콘솔]
                ↓
        [신고 처리 시스템]
```

**고급 기능:**
- 웹 기반 관리자 대시보드
- 사용자 신고 처리
- 실시간 모니터링 및 알림

### 💻 기술 스택 권장사항

#### 백엔드 프레임워크
**Node.js + Express (권장)**
```javascript
// 장점: 빠른 개발, JSON 처리 우수, 비동기 처리
// 단점: 대용량 처리 시 성능 한계
```

**Python + FastAPI (대안)**
```python
# 장점: AI/ML 생태계 친화적, 타입 힌트 지원
# 단점: Node.js 대비 약간 느림
```

**Go + Gin (고성능 필요 시)**
```go
// 장점: 높은 성능, 낮은 메모리 사용
// 단점: 개발 속도 상대적으로 느림
```

#### 클라우드 플랫폼
**AWS (권장)**
- EC2 (서버) + RDS (데이터베이스) + CloudWatch (모니터링)
- 월 예상 비용: $30-80

**Google Cloud Platform**
- Compute Engine + Cloud SQL + Cloud Monitoring
- 월 예상 비용: $25-70

**Vercel/Railway (간단한 시작)**
- 서버리스 함수 기반
- 월 예상 비용: $20-50

### 🔧 구현 단계별 가이드

#### Phase 1: 기본 프록시 서버 (1-2주)

**1. 서버 설정**
```javascript
// server.js (Node.js + Express 예시)
const express = require('express');
const axios = require('axios');
const app = express();

app.use(express.json());

// API 키 환경변수로 관리
const API_KEYS = {
  claude: process.env.CLAUDE_API_KEY,
  openai: process.env.OPENAI_API_KEY,
  gemini: process.env.GEMINI_API_KEY,
  naver: process.env.NAVER_API_KEY
};

// Claude API 프록시
app.post('/api/claude', async (req, res) => {
  try {
    const response = await axios.post('https://api.anthropic.com/v1/messages', 
      req.body, {
        headers: {
          'Authorization': `Bearer ${API_KEYS.claude}`,
          'Content-Type': 'application/json'
        }
      });
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: 'API 요청 실패' });
  }
});

app.listen(3000);
```

**2. iOS 앱 수정**
```swift
// UnifiedAIServiceImpl.swift 수정
class UnifiedAIServiceImpl {
    private let proxyBaseURL = "https://your-proxy-server.com/api"
    
    func sendToClaude(message: String) async throws -> String {
        let url = URL(string: "\(proxyBaseURL)/claude")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["message": message]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        // 응답 처리...
    }
}
```

**3. 보안 설정**
- HTTPS 필수 (Let's Encrypt 무료 SSL)
- CORS 설정으로 앱에서만 접근 허용
- Rate Limiting 적용

#### Phase 2: 사용량 관리 (2-3주)

**1. 데이터베이스 스키마**
```sql
-- 사용자 테이블
CREATE TABLE users (
    id VARCHAR(255) PRIMARY KEY,
    subscription_tier ENUM('free', 'premium'),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 사용량 추적 테이블
CREATE TABLE usage_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255),
    ai_model VARCHAR(50),
    feature VARCHAR(50),
    tokens_used INT,
    cost_usd DECIMAL(10,6),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_date (user_id, created_at)
);

-- 일일 사용량 집계 테이블
CREATE TABLE daily_usage (
    user_id VARCHAR(255),
    date DATE,
    ai_model VARCHAR(50),
    feature VARCHAR(50),
    total_requests INT,
    total_tokens INT,
    total_cost DECIMAL(10,6),
    PRIMARY KEY (user_id, date, ai_model, feature)
);
```

**2. 사용량 제한 로직**
```javascript
// 사용량 체크 미들웨어
async function checkUsageLimit(req, res, next) {
    const { userId, aiModel, feature } = req.body;
    
    // 오늘 사용량 조회
    const today = new Date().toISOString().split('T')[0];
    const usage = await db.query(`
        SELECT total_requests 
        FROM daily_usage 
        WHERE user_id = ? AND date = ? AND ai_model = ? AND feature = ?
    `, [userId, today, aiModel, feature]);
    
    // 제한 확인
    const limit = await getUserLimit(userId, aiModel, feature);
    if (usage.total_requests >= limit) {
        return res.status(429).json({ 
            error: '일일 사용량 초과',
            limit: limit,
            used: usage.total_requests
        });
    }
    
    next();
}
```

**3. 비용 추적**
```javascript
// 비용 계산 및 기록
async function logUsage(userId, aiModel, feature, tokensUsed) {
    const costPerToken = getCostPerToken(aiModel);
    const totalCost = tokensUsed * costPerToken;
    
    await db.query(`
        INSERT INTO usage_logs (user_id, ai_model, feature, tokens_used, cost_usd)
        VALUES (?, ?, ?, ?, ?)
    `, [userId, aiModel, feature, tokensUsed, totalCost]);
    
    // 일일 집계 업데이트
    await updateDailyUsage(userId, aiModel, feature, 1, tokensUsed, totalCost);
}
```

#### Phase 3: 관리자 콘솔 (3-4주)

**1. 대시보드 기능**
- 실시간 사용량 모니터링
- 비용 추적 및 예산 알림
- 사용자별 사용 패턴 분석
- API 응답 시간 모니터링

**2. 신고 처리 시스템**
```javascript
// 신고 접수 API
app.post('/api/report', async (req, res) => {
    const { userId, reportType, content, aiResponse } = req.body;
    
    await db.query(`
        INSERT INTO reports (user_id, type, content, ai_response, status)
        VALUES (?, ?, ?, ?, 'pending')
    `, [userId, reportType, content, aiResponse]);
    
    // 관리자에게 알림 발송
    await sendAdminNotification('새로운 신고가 접수되었습니다.');
    
    res.json({ success: true });
});
```

### 📊 비용 및 성능 예상

#### 서버 비용 (월간)
**소규모 (1,000명 사용자)**
- 서버: AWS EC2 t3.micro ($10)
- 데이터베이스: RDS t3.micro ($15)
- 트래픽: CloudFront + 데이터 전송 ($5)
- **총합: $30/월**

**중간 규모 (10,000명 사용자)**
- 서버: AWS EC2 t3.small ($20)
- 데이터베이스: RDS t3.small ($25)
- 트래픽 및 스토리지 ($15)
- **총합: $60/월**

#### 성능 지표
- **응답 시간**: 기존 대비 +100-200ms (프록시 오버헤드)
- **가용성**: 99.9% (로드밸런서 + 헬스체크)
- **처리량**: 초당 100-500 요청 처리 가능

### 🔐 보안 고려사항

#### 1. API 키 관리
```bash
# 환경변수로 관리 (절대 코드에 하드코딩 금지)
export CLAUDE_API_KEY="sk-ant-api03-..."
export OPENAI_API_KEY="sk-..."
export GEMINI_API_KEY="AIza..."
export NAVER_API_KEY="nv-..."
```

#### 2. 접근 제어
```javascript
// JWT 토큰 기반 인증
const jwt = require('jsonwebtoken');

function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
        return res.sendStatus(401);
    }
    
    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) return res.sendStatus(403);
        req.user = user;
        next();
    });
}
```

#### 3. 입력 검증
```javascript
// 요청 데이터 검증
const { body, validationResult } = require('express-validator');

app.post('/api/claude', [
    body('message').isLength({ min: 1, max: 2000 }).trim().escape(),
    body('userId').isUUID(),
    body('feature').isIn(['chat', 'diary', 'todo', 'preset'])
], (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
    }
    // 처리 로직...
});
```

### 🚀 배포 및 운영

#### 1. CI/CD 파이프라인
```yaml
# .github/workflows/deploy.yml
name: Deploy to Production
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Deploy to AWS
        run: |
          # Docker 빌드 및 배포
          docker build -t deepsleep-proxy .
          docker push $ECR_REGISTRY/deepsleep-proxy:latest
```

#### 2. 모니터링 설정
```javascript
// 헬스체크 엔드포인트
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// 메트릭 수집
const prometheus = require('prom-client');
const httpRequestDuration = new prometheus.Histogram({
    name: 'http_request_duration_seconds',
    help: 'Duration of HTTP requests in seconds',
    labelNames: ['method', 'route', 'status_code']
});
```

### ⚠️ 주의사항 및 위험 요소

#### 1. 단일 장애점 (SPOF)
**위험**: 프록시 서버 다운 시 앱 전체 기능 마비
**대응**: 
- 로드밸런서 + 다중 서버 구성
- 헬스체크 및 자동 복구
- 클라이언트 사이드 재시도 로직

#### 2. 레이턴시 증가
**위험**: 프록시 경유로 인한 응답 지연
**대응**:
- 서버 지역 최적화 (한국 리전 사용)
- 캐싱 전략 적용
- Keep-alive 연결 유지

#### 3. 비용 급증
**위험**: 예상보다 높은 서버 운영비
**대응**:
- 오토스케일링 설정
- 비용 알림 설정
- 사용량 기반 최적화

### 📋 구현 체크리스트

#### Phase 1 (기본 프록시)
- [ ] 서버 환경 구축 (AWS/GCP)
- [ ] API 프록시 엔드포인트 구현
- [ ] HTTPS 설정 및 보안 강화
- [ ] iOS 앱 API 호출 경로 변경
- [ ] 기본 로깅 및 모니터링

#### Phase 2 (사용량 관리)
- [ ] 데이터베이스 설계 및 구축
- [ ] 사용량 추적 로직 구현
- [ ] 제한 초과 시 처리 로직
- [ ] 비용 계산 및 기록 시스템

#### Phase 3 (관리 콘솔)
- [ ] 웹 기반 대시보드 구현
- [ ] 신고 처리 시스템
- [ ] 실시간 알림 시스템
- [ ] 데이터 분석 및 리포팅

### 🎯 결론

프록시 서버는 **상용화를 위한 필수 인프라**입니다. API 키 보안 위험을 해결하고, 사용량을 체계적으로 관리하며, 향후 확장성을 확보하는 핵심 요소입니다.

**권장 접근법:**
1. **즉시 시작**: Phase 1 기본 프록시 서버 구축
2. **단계적 확장**: 사용자 증가에 따라 Phase 2, 3 순차 구현
3. **지속적 모니터링**: 비용과 성능을 실시간으로 추적

초기 투자 비용($30-60/월)은 API 키 탈취로 인한 잠재적 손실(수만 달러)을 방지하는 **필수적인 보험**입니다.