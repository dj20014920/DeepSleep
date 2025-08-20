# IAP 도입 로드맵 (무료/유료 분기 + 실제 결제 플로우)

목표
- 현재 Mock 기반 SubscriptionManager를 StoreKit2 기반 실제 구독으로 교체
- 무료/유료 분기(Feature gating)와 일일 한도(UsageLimitManager) 연계를 통해 유료 혜택을 명확히 제공
- 심사 리스크(3.1.1 모의 결제 금지) 제거 및 메타데이터/앱 내 문구 정합성 확보

현황 (2025-08-20)
- SubscriptionManager.swift: Mock 구매/복원/무료체험, UserDefaults 저장, MemoryManager 티어 업데이트

## 개발 원칙과 실행 규율 (반드시 준수)

## 사용자 결정사항(고정)
- [사용자 결정사항] 출시 지역: 1차 대한민국(KR) 한정, 이후 확장
- [사용자 결정사항] 무료체험: 월/연 모두 7일 무료체험 표기, 동일 구독 그룹 단 1회 제공(이중 혜택 불가)
- [사용자 결정사항] 할인 정책: 연간은 월 환산 대비 20% 절약(“2개월 무료” 또는 “20% 절약” 중 택1 카피)
- [사용자 결정사항] 최소 iOS 타겟: 17.0(StoreKit2 기준)
- [사용자 결정사항] 환불 정책: 환불 감지 시에도 결제일로부터 1개월간 프리미엄 유지, 이후 무료 전환
- [사용자 결정사항] 취소 정책: 체험/구독 취소 시 해당 기간 종료까지 프리미엄 유지 후 무료 전환
- [사용자 결정사항] 모델 정책: 무료는 Gemini 2.0 Flash‑Lite 고정, 프리미엄/Trial은 모델 선택 허용
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

---

## 💰 구독 가격 책정 분석 보고서 (2025-08-20)

### 🎯 최종 결정 가격
- **월간 구독**: ₩6,500 ($4.81)
- **연간 구독**: ₩65,000 ($48.1) - 17% 할인 (2개월 무료)

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
- **DeepSleep: ₩6,500** (AI 기반 개인화 서비스)
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

**₩6,500 선택 근거:**

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

₩6,500은 **공격적 시장 진입 전략**을 위한 가격입니다. 최소한의 수익성을 확보하면서도 높은 접근성을 제공하여 초기 사용자 확보에 집중하는 전략적 선택입니다. 

프롬프트 캐싱 시스템과 프록시 서버 구축을 통해 비용 효율성과 보안을 동시에 확보하며, 실제 사용 데이터를 바탕으로 향후 가격 최적화를 진행할 예정입니다.

---

## 정책 업데이트 요약(사용자 확정 반영)
- 월간/연간 구독 모두 7일 무료체험(Intro Offer) 표기. 단, 동일 구독 그룹 내 단 1회 제공(이중 혜택 불가)
- 초기 릴리스는 StoreKit2 로컬 검증만 사용(서버 검증은 후속 단계)
- 무료 사용자는 Gemini 고정 + 무료 한도, 프리미엄/Trial 사용자는 한도 해제 또는 상향(Secrets.xcconfig 값에 따름)
- 프리미엄 사운드팩/오프라인 캐시: 현재 범위 제외(후속)

## 월간 통계 → 주간 1회 제한 설계(월요일 00:00 기준)
- DAILY_MONTHLY_STATISTICS_LIMIT(일일) 제거, WEEKLY_MONTHLY_STATISTICS_LIMIT = 1로 대체(Secrets.xcconfig/Info.plist 매핑)
- 주간 앵커: 사용자의 지역 달력 기준 월요일 00:00
- 역행 방지: UserDefaults에 lastExecutionWeekAnchor(예: 2025-W35)와 lastSeenWallClock 저장
  - 현재 시각이 lastSeen보다 과거로 이동한 경우 카운트/리셋 금지
  - 주간 경계(월요일 00:00)를 넘어갈 때만 0으로 리셋
- 한계: 완전한 시간 변조 방지는 서버 시간 필요. 후속 단계에서 영수증 signedDate/서버 시간을 신뢰 소스로 병합

## 가격/프로모션 메모
- 연간은 월 환산 대비 통상 15~25% 할인(권장 20%)을 유지. 월/연 모두 Intro Trial 7일 표기(그룹 단 1회)
- 구체 가격/근거는 본 파일 하단의 "구독 가격 책정 분석 보고서" 및 IOS_GUIDE.md의 항목을 근거로 유지/보완

## App Store Connect 설정(초안)
- Subscription Group 이름: DeepSleep Premium (ID: deepsleep.premium)
- Product IDs: com.deepsleep.premium.monthly, com.deepsleep.premium.yearly
- SKU 제안: deepsleep_month_001, deepsleep_year_001
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
- DAILY_MONTHLY_STATISTICS_LIMIT(일일) 제거, WEEKLY_MONTHLY_STATISTICS_LIMIT = 1로 대체(Secrets.xcconfig/Info.plist 매핑) [사용자 결정사항]
- 주간 앵커: 대한민국 표준시(KST) 기준 월요일 00:00 고정 [사용자 결정사항]
- 역행 방지: UserDefaults에 lastExecutionWeekAnchor(예: 2025-W35-KST)와 lastSeenWallClock 저장
  - 현재 시각이 lastSeen보다 과거로 이동하면 카운트/리셋 금지
  - 주간 경계(월요일 00:00 KST) 통과 시에만 0으로 리셋
- UI/UX: 주간 1회 사용 소진 시 버튼 비활성화 + 툴팁 "일주일에 1회, 월요일 00:00(KST) 초기화" 명시 [사용자 결정사항]
- 한계: 완전한 조작 방지는 서버 시간 필요(후속 단계에서 영수증 signedDate/서버 시간 병합)

## 모델/한도 정책 고정
- 무료 사용자는 Gemini 2.0 Flash‑Lite 고정 + 무료 한도 적용 [사용자 결정사항]
- 프리미엄/Trial 사용자는 한도 해제 또는 상향(Secrets.xcconfig 등급별 키 적용: DAILY_*_FREE / DAILY_*_PREMIUM)
- 등급 판단은 StoreKit2 권리(Entitlement)를 단일 소스로 삼고, EntitlementGate에서 중앙 분기(DRY)

## UI/UX 사양(페이월/배지)
- Paywall: 월/연 토글, Product.displayPrice, 7일 Trial 배지/남은일수, 복원(AppStore.sync), "구독 관리" 딥링크
- 메인 화면 상단 배지: 중앙 정렬 "D‑남은일수" 형태, 무지개 그라디언트 일렁임 + 대각선 하이라이트 애니메이션(성능 수칙 준수) [사용자 결정사항]
- 설정: 구독 상태/만료·갱신일 표기, 복원, 정책 링크(개인정보/약관)

## 릴리즈/플래그/롤백
- 런타임/빌드 플래그: IAP_ENABLED, PAYWALL_ENABLED, PREMIUM_LIMITS_ENABLED [사용자 결정사항]
- 장애/심사 대응: PAYWALL_ENABLED 임시 비활성화로 무료 동작 롤백, IAP 플로우 진입 차단
- Mock: SubscriptionManager(Mock)는 DEBUG 전용, Release/AdHoc에서는 제외

---

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
  - 구독 그룹 primary, 월간/연간 + 7일 Intro(그룹 1회) 시나리오 포함. 스킴 Run > Options에 연결 필요
- 변경: DeepSleepApp/AI/UsageLimitManager.swift
  - 등급별/공통 키 모두 지원하도록 해석 로직 개선
    • 무료/프리미엄 분기: DAILY_CHAT_LIMIT_FREE/DAILY_CHAT_LIMIT_PREMIUM 우선
    • 공통/대체 키: DAILY_CHAT_LIMIT, AI_LIMITS_CHAT 폴백
    • 주간 1회 제한은 기존 KST 앵커 로직 유지

Secrets.xcconfig 경로 고정(중요)
- 사용 경로: DeepSleepApp/Secrets.xcconfig (스킴/빌드 설정에 연결됨)
- Config/Secrets.xcconfig는 사용하지 않음. 혼선 방지를 위해 프로젝트 참조에서 제거 권장

결선 작업 체크리스트(이 스프린트에서 완료 예정)
- [ ] PaywallViewController ↔ StoreKitSubscriptionManager 결선
  • PaywallVC 델리게이트에서 purchase(.monthly/.yearly), restore() 호출
  • 구매/복원 성공 시 SubscriptionStatusCenter 변경 → Notification.subscriptionStatusChanged 수신하여 UI 갱신 및 배지 업데이트
- [ ] PaywallPresenter 가격/Trial 정보 주입
  • StoreKitSubscriptionManager.displayPrice(.monthly/.yearly)로 표시가, trialDaysRemaining(.monthly/.yearly)로 D-표시
- [ ] EntitlementGate와 UsageLimitManager 연계 검증
  • 프리미엄/Trial → 제한 상향 또는 무시, 무료 → xcconfig 기반 일일 한도 적용
- [ ] DeepSleepApp/StoreKit/DeepSleep.storekit 스킴 연결 점검 (Run > Options)
- [ ] IOS_GUIDE.md Must-fix 항목 중 IAP 미구현 리스크 항목 “StoreKit2 구현됨(기본 흐름)”으로 상태 갱신

릴리즈 노트 문구 가이드(스토어 메타데이터 동기화)
- 7일 무료체험(동일 구독 그룹 1회) / 연간은 월 대비 약 20% 할인
- 무료 사용자는 Gemini 2.0 Flash‑Lite 모델 고정, 프리미엄/체험은 상향 한도 적용
- 월간 통계는 대한민국 표준시(KST) 기준 월요일 00:00에 주 1회만 실행 가능

---
