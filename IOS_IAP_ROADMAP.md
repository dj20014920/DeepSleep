

---

## 2025-08-26 마스터 블루프린트 업데이트 (결제/IAP 상용화 준비 확정)

본 섹션은 지금 시점(2025-08-26) 기준으로 확정된 의사결정과 즉시 실행 계획, 검증 체크리스트를 한눈에 볼 수 있도록 정리한 상위 청사진입니다. 세부 구현/배경은 본문 각 장의 링크를 따릅니다.

승인/고정 사항
- 가격 티어: Pro 월 ₩6,600 / 연 ₩66,000, Max 월 ₩11,000 / 연 ₩99,000 (ASC 티어로 반영).
- 출시 지역: 1차 대한민국(KR) 우선. 추후 일본(JP), 미국(US) 등 확장 전제(가격/세금/카피 현지화 계획 포함).
- 로캘: 앱/스토어 카피 ko-KR 기본 + en-US 보조 제공(심사/글로벌 확장 대비 일관 유지).
- 테스트 전략: Xcode StoreKit(.storekit) 로컬 환경 + 실기기 샌드박스 이중 검증.

네이밍 명시
- 앱 표시명: EmoZleep (코드네임/리포지토리: DeepSleep)
- 구독 그룹 이름(ASC): EmoZleep Premium
- Product ID 프리픽스: com.emozleep.*

즉시 실행(이번 커밋 포함)
1) StoreKit 구성 파일 신설(로컬 테스트)
   - 경로: DeepSleepApp/StoreKit/DeepSleep.storekit
   - 내용: 구독 그룹 EmoZleep Premium(그룹 1회 7일 Intro) + Pro/Max 2티어 × 월/연 4개 상품(com.emozleep.pro.monthly, com.emozleep.pro.yearly, com.emozleep.max.monthly, com.emozleep.max.yearly), KR 통화 우선. 
   - 비고: .storekit는 Xcode에서 즉시 열어 가격/언어/스토어프론트 시뮬레이션 가능. 
2) Xcode 스킴 수정
   - 기존 DeepSleepNoTrial.storekit 참조 제거 → DeepSleep.storekit로 교체(시뮬레이터 제품 0건 문제 예방).
3) 문서/코드 싱크
   - 본 파일(로드맵) 상단에 본 섹션 신설. 아래 ‘ASC 체크리스트’/‘QA’ 최신화.

App Store Connect(ASC) 설정 체크리스트(최소 구매 가능 상태 도달용)
1) Agreements, Tax, Banking 유료 계약 완료
2) 앱 내 구입(IAP)
   - 구독 그룹 생성: EmoZleep Premium (Group ID 권장: emozleep.premium)
   - 구독 상품 4개:
     • com.emozleep.pro.monthly (Pro, 1개월)
     • com.emozleep.pro.yearly (Pro, 1년)
     • com.emozleep.max.monthly (Max, 1개월)
     • com.emozleep.max.yearly (Max, 1년)
   - Cleared for Sale 체크, 로캘(ko-KR 기본 + en-US), 표시명/설명/스크린샷(페이월 캡처) 입력
   - Introductory Offer: Free Trial 7일(그룹 1회) 설정
   - 앱 버전 메타데이터에 IAP 연결(심사 시 노출)
3) 가격 및 사용 가능 여부
   - 앱 자체 가격=무료, 국가=KR(1차)만 선택
   - 세금 카테고리/세율 확인(구독형 디지털 서비스)

QA/검증 체크리스트(로컬→샌드박스)
- 로컬(.storekit): 제품 로드, 월/연 구매, 복원(AppStore.sync), Trial/만료/환불, Ask to Buy/중단구매/가격인상동의 시나리오
- 샌드박스(실기기): StoreKit Configuration=None → Product.products(for:) 정상 로딩, 결제/복원/Trial 자격 판별/만료 반영
- 전역 UI 반영: Notification.subscriptionStatusChanged 수신 후 Paywall 자동 닫힘/버튼/배지 갱신

스토어 카피 초안(동일 그룹 1회 7일 체험 고지 일관)
- ko-KR(요약): “7일 무료체험 후 자동 갱신. 언제든 취소 가능. 연간은 Pro 약 17%, Max 약 25% 절약.”
- en-US(요약): “7-day free trial. Auto-renews. Cancel anytime. Yearly: Pro ~17% off, Max ~25% off.”

심사 노트 템플릿(예시)
- 테스트 경로: 앱 실행 → 챗 진입 → 무료 한도 소진 시 Paywall 표시 → 월/연 선택 → 결제 → 설정 화면에서 ‘구매 복원’ 확인
- 샌드박스 계정: <review-sandbox@apple.com> / <password>
- 구현 요약: StoreKit 2(구매/복원/트랜잭션 업데이트/환불 그레이스 30일), 그룹 1회 7일 Intro, IAP 게이팅(EntitlementGate)

일정/책임(요지)
- D0: .storekit 생성/스킴 수정/문서 최신화(본 커밋)
- D0~D2: ASC IAP 등록/연결, 로컬·샌드박스 QA 완주
- D3: 스토어 메타데이터/스크린샷 확정, 심사 제출

참고: 상세 근거/배경은 아래 ‘2025-08-25…’ 이하 기존 로그와 “ASC 설정(초안)”, “테스트 계획”, “IAP/App Review 체크리스트” 절을 따릅니다.

### 실행 상태 업데이트(2025-08-26 07:30 KST)
- 현재 스킴에서 StoreKit Configuration는 DeepSleepApp/StoreKit/DeepSleep.storekit로 설정됨(완료).
- 빌드/실행 결과 Paywall 가격/Trial 미표시, 로그:
  ```
  [IAP] Requesting products for IDs: com.deepsleep.premium.yearly, com.deepsleep.premium.monthly
  [IAP] Running on Device - using App Store Connect
  [IAP] Raw products returned: 0 items
  [IAP] Missing products: com.deepsleep.premium.yearly, com.deepsleep.premium.monthly
  ```
- 진단
  1) 디바이스 실행 시 런타임이 App Store Connect 경로를 사용 중 → .storekit가 무시되는 상태. 
     (정식 .storekit 파일은 Xcode UI로 생성/저장해야 하며, 일시적으로 시뮬레이터에서 먼저 검증하는 것이 가장 안정적)
  2) App Store Connect에 실제 구독 상품 미등록 상태이므로 서버 경로에서는 Product 0이 정상.
- 조치
  A) 단기(로컬): Xcode > File > New > StoreKit Configuration File로 DeepSleep.storekit를 ‘Xcode에서’ 재생성(구독 그룹/월·연/7일 Intro 포함) 후 스킴 저장. 우선 ‘시뮬레이터’에서 가격/Trial 배지 표시 확인 → 필요 시 실기기에서도 Xcode StoreKit Testing 동작 확인.
  B) 병행(서버): App Store Connect에서 구독 그룹/상품 생성, Cleared for Sale, 7일 Intro(그룹 1회) 설정, 앱 버전에 IAP 연결. 샌드박스 계정으로 실기기 테스트.
- ASC 체크리스트(제품 0건 대응)
  - Product IDs 일치(com.emozleep.pro.monthly/yearly, com.emozleep.max.monthly/yearly)
  - Cleared for Sale
  - 로캘(ko-KR/en-US) 및 스크린샷 등록
  - 앱 버전 메타데이터에 IAP 연결
  - 상태가 유효(대기/승인)하고 그룹 1회 Trial 정책 적용

---

## 2025-08-25 업데이트 로그 (알림 설정 UX/옵트아웃)
- 설정 > 앱 설정 > 알림 설정 화면을 실제 구현했습니다.
  • 항목: 전체 알림 허용, 타이머 알림, 할 일 미리 알림 스위치 제공
  • 동작: 전체/개별 스위치 변경 시 즉시 영속화(UserDefaults), 상태 브로드캐스트(Notification.notificationSettingsChanged)
  • 권한: 미허용/미결정 상태에서 켜면 권한 요청 후 "설정으로 이동" 안내 제공
  • 안전: 스위치 OFF 시 관련 알림만 안전 취소(타이머 1건, 할 일은 ID 별 제거) – 다른 알림에는 영향 없음(DRY)
  • 중앙화: 모든 스케줄링은 CentralNotificationScheduler로 단일화, 해당 스케줄러가 사용자 설정을 재검증
- 사용자 결정사항 반영
  • 알림은 수면을 방해하지 않도록 최소 사용 및 명확한 목적 고지
  • 앱 내 옵트아웃 경로 제공(설정 화면 + iOS 설정 이동 버튼)
- 코드 변경 요약
  • SettingsManager: notificationsMasterEnabled/TimerEnabled/TodoEnabled 3개 플래그 추가 + notificationSettingsChanged 노티 추가
  • CentralNotificationScheduler: 스케줄링 전 사용자 플래그 확인(마스터/개별)
  • NotificationSettingsViewController: 스텁 → 실제 구현(스택 뷰 UI, 권한 안내, 시스템 설정 이동)
- 심사 체크리스트 업데이트 메모
  • "알림 안내/옵트아웃 경로" 항목 충족. 정책 허브와 문서에는 기존 원칙 유지.

## 2025-08-25 업데이트 로그 (스토리지 압축/내보내기/피드백)
- 스토리지 압축: 30일 이전 세션을 요약 메시지 1건으로 압축(SessionManager.compressOldSessions). UI에서 실행 시 통계 갱신 및 Chat 화면에 변경사항 브로드캐스트.
- 삭제 정책: 60일 이전 삭제(SessionManager.cleanupOldSessions). 보호 요일/서버 시간 병합은 추후(YAGNI).
- 내보내기 보안: SettingsManager.exportUserDataSanitized 추가. 이메일/전화/카드번호 등 PII 마스킹 후 내보내기.
- 개발자 피드백: FeedbackViewController를 실제 메일 작성 화면으로 구현(MFMailComposeViewController). 기본 본문에 앱/기기 정보 자동 포함, 메일 앱 미설치 시 mailto로 폴백.

⚠️ **중요 사전 요구사항 (2025-08-21 확인)**
**Apple Developer Program 가입 필수**
- 현재 상태: 무료 개발자 계정 사용 중
- 필요 조치: Apple Developer Program 가입 (연 $99 또는 ₩129,000)
- 가입 후 가능한 기능:
  - StoreKit 테스트 (시뮬레이터에서 .storekit 파일 사용)
  - App Store Connect 접근
  - Sandbox 테스터 생성 및 테스트
  - TestFlight 배포
  - 실제 App Store 출시

### 현재 코드 상태
- ✅ StoreKit 2 구현 완료 (StoreKitSubscriptionManager)
- ✅ Paywall UI 구현 완료
- ✅ 구독 상태 관리 시스템 구현 완료
- ✅ .storekit 테스트 파일 준비 완료
- ❌ 실제 테스트 불가 (Apple Developer Program 미가입)

---

2025-08-21 문서 업데이트: 정책 모음집(Policy Hub) 반영
- 설정 화면 정책 접근 경로를 단일 허브로 일원화: “정책 모음집(Privacy/Terms/구독관리/면책)”.
- 코드 경로: SettingsViewController.swift (항목 교체), DeepSleepApp/Settings/PolicyHubViewController.swift (신규).
- 심사 대응: 개인정보/약관 링크는 앱 내에서 쉽게 접근 가능해야 하며, 구독 관리는 설정 앱 딥링크 제공.
- 원칙 준수: DRY(정책 링크 산재 금지), KISS(단일 허브), YAGNI(불필요 항목 추가 보류), SOLID(책임 분리).

# IAP 도입 로드맵 (무료/유료 분기 + 실제 결제 플로우)

목표
- 현재 Mock 기반 SubscriptionManager를 StoreKit2 기반 실제 구독으로 교체
- 무료/유료 분기(Feature gating)와 일일 한도(UsageLimitManager) 연계를 통해 유료 혜택을 명확히 제공
- 심사 리스크(3.1.1 모의 결제 금지) 제거 및 메타데이터/앱 내 문구 정합성 확보

현황 (2025-08-20)
- SubscriptionManager.swift: Mock 구매/복원/무료체험, UserDefaults 저장, MemoryManager 티어 업데이트

## Master Task Checklist (Single Source)
- [O] Policy Hub: 앱 내 텍스트 표시 전환 (외부 URL 불요) — 2025-08-21 완료
  • 관련 코드: DeepSleepApp/PolicyHubViewController.swift (privacy/terms 텍스트 내장, 구독 관리는 iOS 설정 딥링크 유지)
  • 심사 메모: 앱 내에서 쉽게 접근 가능하면 URL 필수 아님. 메타데이터 문구와 일치 유지
- [O] Privacy Manifest 추가 — 2025-08-21 완료
  • 파일/경로: DeepSleepApp/Privacy/PrivacyInfo.xcprivacy (NSPrivacyTracking=false, 수집/민감 API 기본 비사용)
  • 주의: Xcode Target > Build Phases > Copy Bundle Resources 포함 확인
- [O] StoreKit2 구독 매니저 구현 및 트랜잭션 스트림 연결 — 2025-08-20 완료
  • 관련 코드: DeepSleepApp/Subscription/StoreKitSubscriptionManager.swift, SubscriptionStatusCenter
  • 관련 문서: IOS_IAP_ROADMAP.md(결제 플로우), DEEPSLEEP_COMPREHENSIVE_GUIDE.md(5.0 스냅샷)
- [O] Paywall 화면 구성 및 중앙 표시(프리젠터) — 2025-08-20 완료
  • 관련 코드: DeepSleepApp/Paywall/PaywallViewController.swift, DeepSleepApp/Subscription/PaywallPresenter.swift
  • 관련 문서: IOS_IAP_ROADMAP.md(UI/UX), DEEPSLEEP_COMPREHENSIVE_GUIDE.md(5.0 스냅샷)
- [O] Paywall ↔ StoreKit2 결선(구매/복원/상태 반영, 가격/Trial 자동 주입) — 2025-08-20 완료
  • 관련 코드: PaywallViewController(구독 옵저버/기본 동작), PaywallPresenter(표시 후 주입)
  • 관련 문서: IOS_IAP_ROADMAP.md 업데이트 로그
- [O] Chat 진입부 게이트 적용(무료/유료 분기 + Paywall 노출) — 2025-08-20 완료
  • 관련 코드: DeepSleepApp/ChatViewController.swift, DeepSleepApp/Paywall/EntitlementUI.swift, Subscription/EntitlementGate.swift, Subscription/AppFeature.swift
  • 관련 문서: IOS_IAP_ROADMAP.md(Feature gating)
- [O] 사용량 한도 로더 개선(xcconfig/Info.plist 기반, Free/Premium 키 우선) — 2025-08-20 완료
  • 관련 코드: DeepSleepApp/AI/UsageLimitManager.swift
  • 관련 문서: IOS_IAP_ROADMAP.md(모델/한도 정책, KST 주간 1회)
- [O] KST 주간 1회 정책 유틸 — 2025-08-20 완료
  • 관련 코드: DeepSleepApp/Core/KSTDatePolicy.swift
  • 관련 문서: IOS_IAP_ROADMAP.md(월간 통계 주간 제한)
- [O] Feature Flags(롤백/토글) — 2025-08-20 완료
  • 관련 코드: DeepSleepApp/Core/FeatureFlags.swift
- [O] .storekit 구성 및 스킴 연결 안내 — 2025-08-20 완료(구성), 연결은 스킴에서 완료됨
  • 관련 파일: DeepSleepApp/StoreKit/DeepSleep.storekit
  • 관련 문서: DEEPSLEEP_COMPREHENSIVE_GUIDE.md(스킴 설정)
- [O] Premium D-N 배지 UI(무지개 효과) — 2025-08-20 완료
  • 관련 코드: DeepSleepApp/UI/PremiumBadgeView.swift
- [O] 문서 동기화(로드맵/종합 가이드) — 2025-08-20 완료
  • 관련 문서: IOS_IAP_ROADMAP.md, DEEPSLEEP_COMPREHENSIVE_GUIDE.md
- [O] EntitlementUI에서 가격/Trial 자동 주입 — 대체 구현 완료
  • 현재 구현: Paywall 측에서 StoreKitSubscriptionManager로부터 가격/Trial을 자동 로딩하여 주입(EntitlementUI 단계의 별도 주입 불필요)
  • 메모: EntitlementUI.require 시 별도 주입은 YAGNI로 보류(필요 시에만 추가)
  • 관련 코드: DeepSleepApp/Paywall/EntitlementUI.swift, PaywallPresenter, StoreKitSubscriptionManager
- [O] 구독 상태 변경 전역 UI 반영(메인/설정/분석/프리셋/챗) — 2025-08-21 적용 완료(SubscriptionUIBinder 패턴)
  • 관련 코드: ChatViewController, SettingsViewController, EmotionAnalysisChatViewController, UsageAnalyticsViewController, PresetListViewController — SubscriptionUIBinder.attach 사용
  • 계획: 주요 화면별 subscriptionStatusChanged 옵저버 추가 및 버튼/배지/문구 갱신
- [O] 환불/만료/유예 상태 모델/기본 UX — 2025-08-21 1차 반영(상태 enum/문구/설정 타이틀)
  • 상태 enum 추가: SubscriptionLifecycleState(active/grace/refunded/expired/free)
  • 상태 갱신: StoreKitSubscriptionManager.refreshEntitlements()에서 환불(구매일+30일 유지)/만료/활성 판정
  • UI 반영: SettingsViewController 타이틀을 SubscriptionUIMessageFormatter로 상태별 문구 표기
  • 후속: 각 화면 배지/토스트 세부 카피 확대는 필요 시 점진 반영(YAGNI)
  • 설계 초안: 아래 “환불/만료 UX 세분화 설계(초안)” 섹션 참조
  • 계획: refreshEntitlements에서 환불/만료 상태 세분화 → UI 토스트/배지 반영
- [O] IOS_GUIDE.md 심사 체크리스트 업데이트(IAP 상태, Trial 1회, 롤백, Privacy/Info 키) — 2025-08-20 반영됨
  • 계획: Must-fix 항목 상태 조정 및 체크리스트 추가
- [∙] .storekit 기반 QA 시나리오 수립/수행(Trial→Convert→Refund→Expire, Re-subscribe no-trial, 지역별 가격, 오프라인/복원) — 체크리스트 문서 존재, 실행/기록 진행 필요
  • 문서: STOREKIT_QA_CHECKLIST.md
  • 계획: 체크리스트에 따라 수기/자동 테스트 수행 후 결과 기록
- [X] PrivacyManifest.json 및 Info.plist 필수 키 점검(Background Audio, ATT 필요 시) — 미확인
  • 계획: 최소 템플릿 추가 및 Info 키 정합성 점검

## 개발 원칙과 실행 규율 (반드시 준수)

## 사용자 결정사항(고정)
- [사용자 결정사항] 출시 지역: 1차 대한민국(KR) 한정, 이후 확장
- [사용자 결정사항] 무료체험: 월/연 모두 7일 무료체험 표기, 동일 구독 그룹 단 1회 제공(이중 혜택 불가)
- [사용자 결정사항] 할인 정책: 연간은 월 환산 대비 20% 절약(“2개월 무료” 또는 “20% 절약” 중 택1 카피)
- [사용자 결정사항] 최소 iOS 타겟: 17.0(StoreKit2 기준)
- [사용자 결정사항] 환불 정책: 환불 감지 시에도 결제일로부터 1개월간 프리미엄 유지, 이후 무료 전환
- [사용자 결정사항] 취소 정책: 체험/구독 취소 시 해당 기간 종료까지 프리미엄 유지 후 무료 전환
- [사용자 결정사항] 모델 정책: 무료는 freeModel + gemini만 선택 가능, 프리미엄/Trial은 전체 모델 선택 허용 (testModel은 프로덕션 UI 비노출)
- [사용자 결정사항] 월간 통계 사용: KST 기준 월요일 00:00에 초기화되는 주간 1회 제한, 소진 시 버튼 비활성+툴팁 명시
- [사용자 결정사항] 메인 배지 UX: 상단 중앙 “D‑남은일수” 무지개 그라디언트 일렁임 + 대각선 하이라이트(성능 수칙 준수)
- [사용자 결정사항] 플래그/롤백: IAP_ENABLED/PAYWALL_ENABLED/PREMIUM_LIMITS_ENABLED, 장애/심사 시 Paywall OFF로 무료 롤백

### 체험/자동갱신 정책(사용자 결정사항)
- [사용자 결정사항] 체험 기간: 7일 무료(“찍먹”). 체험 종료 시 사용자가 선택한 상품으로 자동 갱신(결제)됨.
  - 월간 상품 선택 시: 7일 종료와 함께 월간 1개월 결제 자동 진행.
  - 연간 상품 선택 시: 7일 종료와 함께 연간 결제 자동 진행.
- [사용자 결정사항] 체험 중 취소하면 결제가 진행되지 않으며, 남은 체험 기간까지 프리미엄 권한 유지 후 무료로 전환.
- 구현 메모: App Store Connect의 Introductory Offer(Free Trial)로 7일 설정. 지역/티어별 지원 옵션을 재확인.
- 주의: 본 정책은 OS/스토어 정책을 따르므로, 실제 갱신/청구 타이밍은 트랜잭션 스트림(Transaction.updates)으로 실시간 반영한다.
- 중복 금지(DRY): 동일/유사 로직은 단일 진입점으로만 구현 (구독 권리 판단=EntitlementGate, 사용량=UsageLimitManager, AI 호출=SessionManager.sendMessage)
- 두더지식 금지: 컴파일러 경고/에러를 개별로 때우지 않고, 근본 원인 중심의 구조적 수정만 허용
- KISS/YAGNI/SOLID: 단순성, 현재 필요에 집중, 단일 책임·개방폐쇄·의존 역전 원칙 준수
- 단일 소스 오브 트루스: 구독 권리=StoreKit2 트랜잭션, 한도=Secrets.xcconfig→Info.plist, 모델 정책=EntitlementGate

## 진행 관리/변경 통제
- 변경 단위: Phase별 PR(브랜치)로 격리, 문서(IOS_IAP_ROADMAP.md)와 코드 동시 갱신
- 기능 플래그: IAP_ENABLED/PAYWALL_ENABLED/PREMIUM_LIMITS_ENABLED 상태를 PR 본문과 함께 기록
- 체크리스트(매 커밋 전):
  1) DRY 위반 신규 경로 없는가? 2) 기존 단일 진입점 훼손 없는가? 3) 테스트/시나리오 갱신했는가?
- 롤백 전략: PAYWALL_ENABLED OFF로 즉시 무료 동작 전환, Mock는 DEBUG 전용 유지

## 검증 계획(트리플 검증)
- 정적 검증: 타입/컴파일·린트·의존성·플래그 상태 일치 확인
- 동적 검증: .storekit 샌드박스 시나리오(월/연/Trial/복원/환불/유예/오프라인)
- 문서 검증: 본 로드맵과 실제 코드 차이점 diff 문서화, 사용자 스펙(한국/KST/20%할인/7일 체험 1회) 재확인
- UsageLimitManager.swift: 일일 한도 중앙관리(Info.plist 매핑). 프리미엄 여부는 SubscriptionStatusCenter 기반으로 resolvedDailyLimit에서 반영됨
- ChatViewController 등: 주요 진입점에서 EntitlementGate.canAccess 적용(차단 시 Paywall 표시), 한도 체크는 UsageLimitManager로 단일화
- IOS_GUIDE.md: IAP 상태 ‘StoreKit2 기본 플로우 연결됨’으로 갱신 완료

핵심 결정 사항
- 옵션 A(권장): StoreKit2 자동갱신 구독(월/년) 도입, 영수증 검증은 클라이언트 우선 + 서버(Optional)
- 옵션 B(임시): 이번 제출에서 구독/복원/무료체험 UI 비활성 + 전면 무료 동작. 스토어 메타데이터도 일치 처리

설계 지침
1) Entitlement 모델
- MemoryTier.free / .premium 유지. Entitlement: hasPremium = activeTransaction(for: productId) 존재 여부
- 앱 부팅 시 Transaction.updates 백그라운드 수신 → SubscriptionState 업데이트
- UI는 상태 변화를 Notification(Name.subscriptionStatusChanged)로 구독

2) 무료/유료 분기(Feature gating)
- 공통 게이트 함수: EntitlementGate.canAccess(feature: AppFeature) -> Bool
  • 내부에서: if hasPremium return true else check UsageLimitManager
- AppFeature 예: chatUnlimited, diaryAnalysisUnlimited, premiumSounds, offlineCacheSizeXL 등
- ChatViewController 등 진입 시 게이트 평가 → 실패 시 Paywall 표시

3) 결제 플로우(StoreKit2)
- 제품 구성: com.emozleep.pro.monthly, com.emozleep.pro.yearly, com.emozleep.max.monthly, com.emozleep.max.yearly
- 구매: try await product.purchase() → Transaction 검증 → 상태 저장 → Notification 전파
- 복원: await AppStore.sync() 후 Transaction.currentEntitlements 재평가
- 영수증/검증:
  • 클라이언트: StoreKit2 Transaction.verification로 기본 검증
  • 서버(Optional): 최초 런칭은 생략 가능. 추후 서버 영수증 검증/서버 권한 캐시 도입
- 무료체험:
  • StoreKit의 Introductory Offer(Free Trial)로 전환. 기존 Mock startFreeTrial 제거

4) 상태 저장
- SubscriptionState: struct { isPremium: Bool, expiration: Date? }
- SecureStorage(Keychain) 우선, UserDefaults 보조 캐시. 소스 오브 트루스는 StoreKit2 트랜잭션

5) UI/UX
- PaywallViewController: 제품 가격, 무료체험(공식 Intro Offer), 복원 버튼
- 설정 화면: 구독 상태 뱃지/만료일/복원, 개인정보처리방침/약관 링크

6) 정책/설정
- Info.plist: UIBackgroundModes=audio 추가(별도 Must-fix), NSUserTrackingUsageDescription(ATT 사용 시), HealthKit 사용 시 설명키
- PrivacyManifest.json: 최소 템플릿 추가 (tracking=false 등)

단계별 작업 목록 (업데이트 2025-08-21)
- 상태: Policy Hub 텍스트 내장, Privacy Manifest, 상태 enum/UX, 전역 옵저버 패턴 — 완료
- 남은 핵심: .storekit QA 실행/기록, PolicyHub 텍스트 최종 문구 확정(필요 시)
Phase 0: 안전가드 (당장 제출 급한 경우)
- [옵션 B] Mock UI/코드 비활성 플래그(빌드 설정)로 제출 빌드에서 구독/복원/체험 숨김
- App Store 메타데이터에서 관련 문구/이미지 제거

Phase 1: 기반 구축
- [ ] Pod/패키지 추가 없음(StoreKit2는 시스템 프레임워크)
- [ ] DeepSleepApp/Subscription/StoreKitSubscriptionManager.swift 신규 생성
- [ ] ProductID 상수/구성(AppConfig or SubscriptionConfig)
- [ ] SubscriptionState + Notification 통합 (기존 .subscriptionStatusChanged 재사용)
- [ ] 앱 시작 시 entitlement 로드 + Transaction.updates 구독

Phase 2: 게이트 도입
- [ ] AppFeature enum 정의 및 EntitlementGate 구현
- [ ] ChatViewController 등 주요 진입점에 canAccess(...) 훅 추가
- [ ] 실패 시 Paywall 표시 흐름 연결
- [ ] UsageLimitManager와의 연계: 프리미엄이면 제한 무시 또는 상향(설정값)

Phase 3: 구매/복원
- [ ] 제품 fetch → 가격 표시(현지화)
- [ ] 구매 처리(purchase) → 검증 → 상태 저장/브로드캐스트
- [ ] 복원 처리(AppStore.sync) → 상태 재계산
- [ ] 에러/취소/환불 시나리오 UX

Phase 4: 정합성/심사 대응
- [ ] Mock SubscriptionManager 전면 제거 또는 디버그 전용 분리
- [ ] 무료체험은 StoreKit Intro Offer로만 제공 (startFreeTrial 제거)
- [ ] Info.plist/PrivacyManifest 반영, 앱 내 정책/면책/링크 추가
- [ ] 스크린샷/설명 정합성 점검

테스트 계획

실행 가이드(.storekit)
- Xcode > Scheme > Run > Options: StoreKit Configuration = DeepSleepApp/StoreKit/DeepSleep.storekit 설정
- 시뮬레이터/실기기에서 실행 후 Paywall 진입 → 가격/Trial 배지 확인
- 상세 시나리오와 체크 포인트는 STOREKIT_QA_CHECKLIST.md 참고
- 샌드박스 계정 준비, Xcode StoreKit Configuration(.storekit) 파일로 로컬 시뮬레이션
- 시나리오: 신규 구매, 복원, 만료/환불(테스트 가능 범위), 오프라인 복귀, 재설치 후 복원
- 게이트 동작: 무료 사용자가 한도 도달 시 Paywall, 유료 사용자는 무제한/상향
- 회귀: UsageLimitManager 정상 동작, MemoryManager 티어 업데이트, 알림 전파

예상 리스크와 대응
- 결제 실패/환불/가족 공유: StoreKit2 트랜잭션 스트림 재평가로 상태 동기화
- 서버 검증 부재: 1차는 로컬 검증으로 진행, 추후 서버 추가 시 인터페이스 유지
- 기존 Mock 코드 충돌: 빌드 플래그로 격리 후 제거

파일/모듈 변경 요약
- 추가: DeepSleepApp/Subscription/StoreKitSubscriptionManager.swift
- 추가: DeepSleepApp/Subscription/EntitlementGate.swift, AppFeature.swift
- 변경: ChatViewController 등 주요 화면에 canAccess 훅 + Paywall 연결
- 변경: SubscriptionManager.swift (Mock) 제거 또는 DEBUG 전용으로 한정
- 변경: UsageLimitManager와 통합 로직 추가(프리미엄 시 제한 무시/상향)
- 추가: PrivacyManifest.json(프로젝트 루트 또는 Target 리소스)
- 변경: Info.plist(UIBackgroundModes=audio, 필요시 기타 UsageDescription)

다음 액션 제안
- 바로 Phase 1 구현 브랜치 생성 후 StoreKit2 매니저 뼈대 파일 추가 → 페이월 더미 화면 연결
- 병행: Info.plist/PrivacyManifest 반영, Settings 화면에 정책 링크 추가
- 완료 후 smoke: xcodebuild 빌드 + 기본 UI 탐색, StoreKit 시뮬레이터로 구매/복원 테스트

---

## 💰 구독 가격 책정 분석 보고서 (2025-08-20)

### 🎯 최종 결정 가격
- Pro: 월 ₩6,600 / 연 ₩66,000 (연간 약 17% 할인)
- Max: 월 ₩11,000 / 연 ₩99,000 (연간 약 25% 할인)

### 📊 가격 책정 근거

#### 1. 사용자 페르소나별 비용 분석
**무료 사용자 (평균적 사용):**
- 월간 AI 비용: $0.24 (Gemini 고정, 프롬프트 캐싱 적용)
- 서버 비용: $0.03
- 총 비용: $0.27 (₩365)

**무료 사용자 (최악 - 모든 제한 사용):**
- 월간 AI 비용: $0.31
- 서버 비용: $0.03  
- 총 비용: $0.34 (₩459)

**프리미엄 사용자 (평균적 사용):**
- 월간 AI 비용: $1.45 (Claude 15회/일, 프롬프트 캐싱으로 60% 절감)
- 서버 비용: $0.05
- 총 비용: $1.50 (₩2,025)

**프리미엄 사용자 (최악 - 파워 유저):**
- 월간 AI 비용: $1.87 (Claude 20회/일, 모든 기능 최대 사용)
- 서버 비용: $0.05
- 총 비용: $1.92 (₩2,592)

#### 2. 수익성 분석 (개인사업자 기준)

**세금 구조:**
- 애플 앱스토어 수수료: 30% (첫 해) → 15% (2년차)
- 부가세: 10%
- 종합소득세: 15% (평균 구간)
- 지방소득세: 1.5%

**₩6,500 기준 수익성:**

**1년차:**
- 총 매출: $4.81
- 애플 수수료 (30%): $1.44
- 부가세 (7%): $0.24
- 소득세 (15%): $0.47
- 지방소득세 (1.5%): $0.05
- **세후 순수익: $2.61**
- AI+서버 비용: $1.92 (최악 시나리오)
- **최종 순이익: $0.69 (14% 마진)**

**2년차:**
- 세후 순수익: $2.96
- **최종 순이익: $1.04 (21% 마진)**

#### 3. 시장 포지셔닝 분석

**경쟁사 가격 비교:**
- Noisli: ₩2,900 (기본 사운드 앱)
- Sleep Cycle: ₩4,900 (수면 추적)
- **EmoZleep Pro: ₩6,600** / EmoZleep Max: ₩11,000
- Headspace: ₩7,900 (명상 앱)
- Calm: ₩8,900 (프리미엄 웰니스)

**포지셔닝:** AI 특화 기능을 고려한 중간 가격대로 접근성과 가치를 균형잡음

#### 4. 핵심 기술적 고려사항

**프롬프트 캐싱 시스템 (3시간):**
- Claude 비용 90% 절감 효과
- Write $1/MTok → Read $0.08/MTok
- 시스템 프롬프트 재사용으로 대폭 비용 절감

**프록시 서버 필요성:**
- API 키 보안 위험 해결 (필수)
- 실시간 사용량 모니터링
- 동적 정책 변경 가능
- 월 서버 비용: $30-50 (사용자당 $0.03-0.05)

#### 5. 위험 요소 및 대응책

**재무적 위험:**
- 낮은 전환율 (8% 미만) 시 적자 위험
- 파워 유저 집중으로 인한 비용 급증
- API 가격 인상 외부 요인

**대응책:**
- 실시간 사용량 모니터링 시스템 구축
- 강제 토큰 컷오프 기능 구현
- 다중 AI 모델 전략으로 리스크 분산

#### 6. 가격 결정 이유

**₩6,600(프로) 선택 근거:**

1. **접근성 우선**: 초기 시장 진입을 위한 매력적 가격
2. **최소 수익성 확보**: 14% 마진으로 기본적 지속가능성 보장
3. **성장 여력**: 2년차 21% 마진으로 개선 여지 확보
4. **경쟁력**: 경쟁사 대비 합리적 포지셔닝
5. **심리적 가격**: "6천원대"로 부담 없는 가격 인식

**전략적 고려사항:**
- 초기 3개월 프로모션 가격으로 활용 가능
- 사용자 확보 후 단계적 인상 여지 보유
- 연간 구독 17% 할인으로 고객 유지율 향상

#### 7. 성공 지표 및 모니터링

**목표 지표:**
- 프리미엄 전환율: 10% 이상
- 월간 이탈률: 5% 이하
- 평균 사용자당 수익: $2.5 이상

**모니터링 항목:**
- 실시간 AI 비용 추적
- 사용자별 사용 패턴 분석
- 프록시 서버 성능 및 비용
- 경쟁사 가격 변동 추적

### 🚀 결론

₩6,600(프로)은 **공격적 시장 진입 전략**을 위한 가격입니다. 최소한의 수익성을 확보하면서도 높은 접근성을 제공하여 초기 사용자 확보에 집중하는 전략적 선택입니다. 

프롬프트 캐싱 시스템과 프록시 서버 구축을 통해 비용 효율성과 보안을 동시에 확보하며, 실제 사용 데이터를 바탕으로 향후 가격 최적화를 진행할 예정입니다.

---

## 정책 업데이트 요약(사용자 확정 반영)

### Trial Eligibility 최소 정책(2025-08-21)
- 중앙 진입점: StoreKitSubscriptionManager.isTrialEligible
- 판별 기준(최소): 앱 번들 구독 상품군에 대해 과거 거래가 단 하나도 관찰되지 않으면 eligible(true)
- 반영 범위:
  - Paywall: trialDaysRemaining 정보가 없더라도 isTrialEligible을 활용해 무료체험 안내 카피 분기
  - Badge/기타: 활성 trial이 있을 때만 D-n 표기. 활성 trial이 없으면 Free/Pro만 표기 유지
- 확장 계획: 서버 검증 또는 Intro Offer 자격 API를 사용할 때도 동일 진입점만 보완(DRY)
- 월간/연간 구독 모두 7일 무료체험(Intro Offer) 표기. 단, 동일 구독 그룹 내 단 1회 제공(이중 혜택 불가)
- 초기 릴리스는 StoreKit2 로컬 검증만 사용(서버 검증은 후속 단계)
- 무료 사용자는 Gemini 고정 + 무료 한도, 프리미엄/Trial 사용자는 한도 해제 또는 상향(Secrets.xcconfig 값에 따름)
- 프리미엄 사운드팩/오프라인 캐시: 현재 범위 제외(후속)

## 월간 통계 → 주간 1회 제한 설계(월요일 00:00 기준)
- 현재 코드: xcconfig의 WEEKLY_* 키를 직접 사용하지 않으며, 코드 유틸(WeekAnchor.kstMonday)로 주간 앵커를 계산하여 관리
- 정책 표기: UI/툴팁·문서에서는 “주 1회, 월요일 00:00에 초기화”를 명확히 안내하되, 구현은 코드 유틸 중심(DRY/KISS)
- 주간 앵커: 사용자의 지역 또는 KST 정책에 맞는 캘린더 기준 월요일 00:00(본 앱은 KST 고정 정책 섹션 참고)
- 역행 방지: UserDefaults에 lastExecutionWeekAnchor(예: 2025-W35[-KST])와 lastSeenWallClock 저장
  - 현재 시각이 lastSeen보다 과거로 이동한 경우 카운트/리셋 금지
  - 주간 경계(월요일 00:00)를 넘어갈 때만 0으로 리셋
- 한계: 완전한 시간 변조 방지는 서버 시간 필요. 후속 단계에서 영수증 signedDate/서버 시간을 신뢰 소스로 병합

## 가격/프로모션 메모
- 연간은 월 환산 대비 통상 15~25% 할인(권장 20%)을 유지. 월/연 모두 Intro Trial 7일 표기(그룹 단 1회)
- 구체 가격/근거는 본 파일 하단의 "구독 가격 책정 분석 보고서" 및 IOS_GUIDE.md의 항목을 근거로 유지/보완

## App Store Connect 설정(초안)
- Subscription Group 이름: EmoZleep Premium (ID 권장: emozleep.premium)
- Product IDs: com.emozleep.pro.monthly, com.emozleep.pro.yearly, com.emozleep.max.monthly, com.emozleep.max.yearly
- SKU 제안: emozleep_pro_month_001, emozleep_pro_year_001, emozleep_max_month_001, emozleep_max_year_001
- 판매 지역: 대한민국(KR) 우선 출시, 이후 전 지역 확대 [사용자 결정사항]
- 무료체험: 7일(월/연 모두 노출, 그룹 1회 제공) [사용자 결정사항]
- 주요 통화: KRW, USD (기타 지역은 추후 티어 자동 매핑)

## 최소 iOS 타겟 확인
- 프로젝트 설정상 IPHONEOS_DEPLOYMENT_TARGET = 17.0 (StoreKit2 사용 요건 충족) [사용자 결정사항]

## 구독 상태 세부 정책(UX 동작)
- 갱신 유예/청구 재시도: 재시도 기간 동안 프리미엄 권한 유지(UX 친화)
- 환불 처리: 환불 감지 시에도 결제일로부터 1개월 동안 프리미엄 권한 유지, 이후 무료로 전환 [사용자 결정사항]
- 취소 처리: 체험/구독 취소 시, 체험/결제 주기 종료까지 프리미엄 유지 후 무료 전환 [사용자 결정사항]
- Trial 비대상 사용자: Paywall에서 "첫 구독자에게 제공되는 7일 무료체험" 안내로 카피 대체(배지 숨김) [사용자 결정사항]

## 월간 통계 → 주간 1회 제한(대한민국 KST 기준 월요일 00:00)
- 현재 코드: WEEKLY_* 구성 키는 사용하지 않음. KSTDatePolicy + UsageLimitManager 내 주간 유틸로 계산/관리(DRY/KISS)
- 주간 앵커: 대한민국 표준시(KST) 기준 월요일 00:00 고정 [사용자 결정사항]
- 역행 방지: UserDefaults에 lastExecutionWeekAnchor(예: 2025-W35-KST)와 lastSeenWallClock 저장
  - 현재 시각이 lastSeen보다 과거로 이동하면 카운트/리셋 금지
  - 주간 경계(월요일 00:00 KST) 통과 시에만 0으로 리셋
- UI/UX: 주간 1회 사용 소진 시 버튼 비활성화 + 툴팁 "일주일에 1회, 월요일 00:00(KST) 초기화" 명시 [사용자 결정사항]
- 한계: 완전한 조작 방지는 서버 시간 필요(후속 단계에서 영수증 signedDate/서버 시간 병합)

## 모델/한도 정책 고정
- 무료 사용자는 freeModel + gemini 제한적 선택 + 무료 한도 적용 [사용자 결정사항]
- 프리미엄/Trial 사용자는 한도 해제 또는 상향(Secrets.xcconfig 등급별 키 적용: DAILY_*_FREE / DAILY_*_PREMIUM)
- 등급 판단은 StoreKit2 권리(Entitlement)를 단일 소스로 삼고, EntitlementGate에서 중앙 분기(DRY)

## UI/UX 사양(페이월/배지)
- Paywall: 월/연 토글, Product.displayPrice, 7일 Trial 배지/남은일수, 복원(AppStore.sync), "구독 관리" 딥링크, 설명 카피에 "Pro에는 대나무숲 친구 선택 가능" 포함
- 메인 화면 상단 배지: 중앙 정렬 "D‑남은일수" 형태, 무지개 그라디언트 일렁임 + 대각선 하이라이트 애니메이션(성능 수칙 준수) [사용자 결정사항] • Trial 상태에서는 5초 간격으로 "7일 무료체험"과 D‑카운트다운을 토글 표시
- 설정: 구독 상태/만료·갱신일 표기, 복원, 정책 링크(개인정보/약관)

## 릴리즈/플래그/롤백
- 런타임/빌드 플래그: IAP_ENABLED, PAYWALL_ENABLED, PREMIUM_LIMITS_ENABLED [사용자 결정사항]
- 장애/심사 대응: PAYWALL_ENABLED 임시 비활성화로 무료 동작 롤백, IAP 플로우 진입 차단
- Mock: SubscriptionManager(Mock)는 DEBUG 전용, Release/AdHoc에서는 제외

---

## 2025-08-25 업데이트 로그 (AI 모델 선택 게이팅/카피/배지)
- 모델 선택 게이팅: 무료는 freeModel + gemini만 선택 가능, Pro/Trial은 전체 모델 선택 가능. testModel은 프로덕션 UI에서 비노출
  • 파일: DeepSleepApp/Views/AIModelSettingsView.swift, DeepSleepApp/AIModelSelectionViewController.swift
- 무료 모델 설명 경고 업데이트: freeModel은 응답 지연/오류/한국어 부정확 가능성 안내
  • 파일: DeepSleepApp/SharedModels.swift (AIModelType.freeModel.description)
- Paywall 설명 카피에 "Pro에는 대나무숲 친구 선택 가능" 추가
  • 파일: DeepSleepApp/Paywall/PaywallViewController.swift
- 프리미엄 배지: Trial 상태 5초 토글("7일 무료체험" ↔ D-카운트다운), Pro/Trial 무지개 그라데이션, Free 그레이스케일
  • 파일: DeepSleepApp/UI/PremiumBadgeView.swift
- 선택 저장 경로 정리: SettingsManager.updateSelectedModelAtomically 사용, UserDefaults("selectedLLM") 키 일치

# 2025-08-21 업데이트 로그 (구현 완료 사항)

## 주요 구현 완료
- ✅ StoreKit2 무한 루프 버그 수정 (Transaction.updates 백그라운드 Task.detached 처리)
- ✅ 네비게이션 바 중앙 Trial 배지 구현 (navigationItem.titleView 활용)
- ✅ SubscriptionTierSelectionViewController 완성 (Free/Pro/Max 티어 선택 UI)
- ✅ PaywallViewController → StoreKit 결제 플로우 정상 연결
- ✅ SubscriptionUIBinder를 통한 전역 UI 상태 관리 완성
- ✅ 설정 화면 타이틀 고정 ("설정" 유지, 프로모션 문구 제거)

## 배지 UI 최종 사양
- 위치: 네비게이션 바 중앙 (navigationItem.titleView)
- 표시 조건: 비프리미엄 + 사운드 탭에서만
- 스타일: systemPink 배경, 둥글게 처리 (cornerRadius: 14)
- 터치 동작: SubscriptionTierSelectionViewController 오픈

# 2025-08-20 업데이트 로그 (정책 고정 사항 반영 + 코드 결선)

변경 요약(파일/경로 정확 표기)
- 추가: DeepSleepApp/Subscription/StoreKitSubscriptionManager.swift
  - StoreKit2 제품 로드/구매/복원/트랜잭션 스트림 구독, SubscriptionStatusCenter.shared로 isPremium 상태 브로드캐스트
- 추가: DeepSleepApp/Core/FeatureFlags.swift
  - IAP_ENABLED/PAYWALL_ENABLED/MONTHLY_STATS_STRICT_WINDOW 등 런타임 토글 진입점
- 추가: DeepSleepApp/Core/KSTDatePolicy.swift
  - isKSTMonday00(now:) 제공 (KST 월요일 00:00 창 검증)
- 추가: DeepSleepApp/UI/PremiumBadgeView.swift
  - 메인 상단 중앙 D-N 배지(무지개 번쩍임) 구현
- 추가: DeepSleepApp/StoreKit/DeepSleep.storekit
  - 구독 그룹 primary, Pro/Max 월간/연간 + 7일 Intro(그룹 1회) 시나리오 포함. 스킴 Run > Options에 연결 필요
- 변경: DeepSleepApp/AI/UsageLimitManager.swift
  - 등급별/공통 키 모두 지원하도록 해석 로직 개선
    • 무료/프리미엄 분기: DAILY_CHAT_LIMIT_FREE/DAILY_CHAT_LIMIT_PREMIUM 우선
    • 공통/대체 키: DAILY_CHAT_LIMIT, AI_LIMITS_CHAT 폴백
    • 주간 1회 제한은 기존 KST 앵커 로직 유지

Secrets.xcconfig 경로 고정(중요)
- 사용 경로: DeepSleepApp/Secrets.xcconfig (스킴/빌드 설정에 연결됨)
- Config/Secrets.xcconfig는 사용하지 않음. 혼선 방지를 위해 프로젝트 참조에서 제거 권장

결선 작업 체크리스트(이 스프린트 상태)
- [✅] PaywallViewController ↔ StoreKitSubscriptionManager 결선
  • PaywallVC 기본 동작/델리게이트에서 purchase(.monthly/.yearly), restore() 호출
  • 구매/복원 성공 시 SubscriptionStatusCenter 변경 → Notification.subscriptionStatusChanged 수신하여 Paywall 자동 dismiss 및 UI 갱신
- [O] PaywallPresenter 가격/Trial 정보 주입 — 대체 구현 완료
  • 현재는 Paywall 측 자동 로딩으로 대체. Presenter 주입은 YAGNI로 보류
- [O] EntitlementGate와 UsageLimitManager 연계(구조 반영)
  • 프리미엄/Trial → resolvedDailyLimit에서 상향/무시 반영, 무료 → xcconfig 기반 일일 한도 적용
- [O] DeepSleepApp/StoreKit/DeepSleep.storekit 스킴 연결 점검 (Run > Options)
- [O] IOS_GUIDE.md 상태 갱신: “StoreKit2 구현됨(기본 흐름)” 반영

환불/만료 UX 세분화 설계(초안)
- 목표: 환불/만료/유예 상태에 따라 사용자 혼란 없이 자연스러운 상태 전환/안내 제공
- 단일 판단 소스: StoreKit2 Transaction 상태(SubscriptionStatusCenter가 요약)
- 상태 모델(예시):
  • active(paid/trial), gracePeriod, refunded(graceUntil=paidAt+30d), expired
- UX 정책:
  • refunded: “환불 처리되었습니다. 결제일로부터 30일간 프리미엄이 유지되며 이후 무료로 전환됩니다.” 토스트/설정 배지
  • expired: “구독이 만료되었습니다. 계속 이용하려면 구독을 갱신하세요.” Paywall 자연 유도
  • gracePeriod: “결제 재시도 중입니다. 기존 혜택이 유지됩니다.” 설정 배지
- UI 반영 지점:
  • Paywall: 상태 변화 시 자동 dismiss/표시
  • 설정 화면: 상태/만료일/안내 배지
  • 메인/분석: 프리미엄 UI 요소 활성/비활성
- 구현 계획(요약):
  1) SubscriptionStatusCenter: 상태 enum 확장(above) 및 상태 전파(Notification)
  2) Paywall/설정/메인 화면: subscriptionStatusChanged 옵저버에서 상태별 카피/표시 로직 반영
  3) UsageLimitManager: 프리미엄 판단은 isPremium로만, 환불/유예/만료 텍스트는 UI 계층에서 처리(DRY)

전역 화면별 subscriptionStatusChanged 옵저버 적용 계획(파일/라인 가이드)
- 공통 규칙
  • 적용 위치: 각 화면의 viewDidLoad 말미 또는 viewWillAppear에서 등록, deinit에서 해제
  • 메인 스레드 보장: NotificationCenter 콜백에서 @MainActor 또는 DispatchQueue.main 보장
  • 처리 내용: 배지/버튼/문구/게이트 평가 결과를 즉시 갱신(updateUI() 호출)
- 대상 화면 및 가이드
  1) DeepSleepApp/ChatViewController.swift
     • viewDidLoad 하단: subscriptionStatusChanged 옵저버 추가 → { self.updateUI(); }
     • updateUI 내: EntitlementGate.canAccess(AppFeature.chatUnlimited) 결과로 입력창/전송 버튼 활성/비활성
  2) DeepSleepApp/SettingsViewController.swift
     • viewDidLoad 하단: 옵저버 추가 → { self.updateSubscriptionBadge(); }
     • 설정 배지: isPremium/만료일/유예/환불 카피 반영(상태 문자열 포맷터 유틸 활용 예정)
  3) DeepSleepApp/EmotionAnalysisChatViewController.swift (또는 해당 분석 메인 화면)
     • viewDidLoad 하단: 옵저버 추가 → { self.updateUI(); }
     • 분석 실행 버튼/제한 문구 갱신: EntitlementGate + UsageLimitManager 상태 기반
  4) DeepSleepApp/UsageAnalyticsViewController.swift
     • viewDidLoad 하단: 옵저버 추가 → { self.reloadData(); }
     • 프리미엄 시 한도 표기 상향/무제한 텍스트 반영
  5) DeepSleepApp/PresetListViewController.swift
     • viewDidLoad 하단: 옵저버 추가 → { self.updateUI(); }
     • 프리미엄 프리셋/사운드 잠금 해제 시 UI 즉시 반영
- 구현 노트
  • 옵저버 토큰은 화면 프로퍼티로 보관(private var subscriptionObserver: NSObjectProtocol?)
  • deinit에서 토큰 해제(if let token = subscriptionObserver { NotificationCenter.default.removeObserver(token) })
  • 기존 PaywallViewController 구현 패턴을 그대로 재사용하여 DRY 유지

릴리즈 노트 문구 가이드(스토어 메타데이터 동기화)
- 7일 무료체험(동일 구독 그룹 1회) / 연간은 월 대비 약 20% 할인
- 무료 사용자는 Gemini 2.0 Flash‑Lite 모델 고정, 프리미엄/체험은 상향 한도 적용
- 월간 통계는 대한민국 표준시(KST) 기준 월요일 00:00에 주 1회만 실행 가능

---
