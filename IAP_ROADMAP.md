# IAP 도입 로드맵 (무료/유료 분기 + 실제 결제 플로우)

목표
- 현재 Mock 기반 SubscriptionManager를 StoreKit2 기반 실제 구독으로 교체
- 무료/유료 분기(Feature gating)와 일일 한도(UsageLimitManager) 연계를 통해 유료 혜택을 명확히 제공
- 심사 리스크(3.1.1 모의 결제 금지) 제거 및 메타데이터/앱 내 문구 정합성 확보

현황 (2025-08-20)
- SubscriptionManager.swift: Mock 구매/복원/무료체험, UserDefaults 저장, MemoryManager 티어 업데이트
- UsageLimitManager.swift: 일일 한도 중앙관리(Info.plist 매핑). 현재 구독 상태와의 연동은 없음
- ChatViewController 등: 유료 기능(대화/분석 등) 사용 시 한도 체크만 수행, 구독 체크 훅 없음
- IOS_GUIDE.md: Must-fix로 IAP 미구현 명시. 제출 빌드에서 모의 결제 흔적 제거 또는 StoreKit2 구현 요구

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
- 제품 구성: com.deepsleep.premium.monthly, com.deepsleep.premium.yearly
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

단계별 작업 목록
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

