# EmoZleep 구독/결제 정책 가이드(SSOT)

본 문서는 EmoZleep의 구독/결제/환불/복원/무료 체험(7일) 정책을 단일 진실의 원천(SSOT)으로 정의합니다. 앱 내 모든 UI/문구/동작은 이 문서를 기준으로 설계·구현·검증합니다.

## 0. 범위 및 원칙
- 범위: App Store 정기구독(자동갱신형) — Pro/Max 티어, 월/연 상품 및 7일 무료 체험.
- 단일 진입점: StoreKit 2 + StoreKitSubscriptionManager(앱 클라이언트). 서버 보고는 ProxyTierReporter(수동/수집형).
- SSOT: 본 문서의 정책/문구/링크가 최신이며, UI 문자열은 가능한 한 본문 카피를 재사용합니다.
- 법령/플랫폼 우선: Apple App Store/지역 법령이 상위 규범이며, 본 문서와 상충 시 상위 규범을 따릅니다.

## 1. 구독 티어 및 상품
- 티어: Free / Pro / Max
  - Free: 기본 기능, 일부 사용량/기능 제한
  - Pro: 확장 한도
  - Max: 고급 분석/독점 사운드팩/우선 지원(점진 도입)
- 상품(Product IDs)
  - Pro 월간: `com.emozleep.pro.monthly`
  - Pro 연간: `com.emozleep.pro.yearly`
  - Max 월간: `com.emozleep.max.monthly`
  - Max 연간: `com.emozleep.max.yearly`
- 가격(예시, 지역/세금에 따라 변동)
  - Pro: 월 ₩6,600 / 연 ₩66,000
  - Max: 월 ₩11,000 / 연 ₩99,000
  - 연간은 월 대비 할인 제공(정확 비율은 지역/세금에 따라 차이)

### 1-b. 사용 한도(SSOT)
- 모든 한도는 Secrets.xcconfig의 `AI_LIMITS_*_{FREE,PRO,MAX}` 키로만 관리합니다(DAILY_* 미사용).
- 기본값(앱 표기 기준):
  - 일일 채팅: Free 50 / Pro 130 / Max 250
  - 프리셋 추천: Free 5 / Pro 30 / Max 50
  - 할일 조언(개별): Free 5 / Pro 20 / Max 50
  - 할일 조언(오늘 전체): Free 1 / Pro 3 / Max 5
  - 감정 일기 분석(“이 일기 이야기하기”): Free 5 / Pro 7 / Max 10
  - 기타: 월간 통계 1(주간 게이트 병행), 운세/감정분석/리포트는 0(미사용)

키 목록(예):
- `AI_LIMITS_CHAT`, `AI_LIMITS_CHAT_PRO`, `AI_LIMITS_CHAT_MAX`
- `AI_LIMITS_PRESET_RECOMMENDATION_{FREE,PRO,MAX}`
- `AI_LIMITS_DIARY_ANALYSIS_{FREE,PRO,MAX}`
- `AI_LIMITS_TODO_ADVICE_{FREE,PRO,MAX}`, `AI_LIMITS_TODO_ADVICE_EACH`
- (하위호환) `AI_LIMITS_TODO_ADVICE_PREMIUM = $(AI_LIMITS_TODO_ADVICE_PRO)`
- `AI_LIMITS_TODO_OVERALL_ADVICE_{FREE,PRO,MAX}`

## 2. 무료 체험(7일 Free Trial)
- 제공 조건: 계정당 1회 제공될 수 있음(Apple 정책). 과거 구독/환불 이력에 따라 제공되지 않을 수 있음.
- 시작 시점: 구독 시작과 함께 자동 부여. 체험 기간 중 언제든 취소 가능.
- 체험 종료: 체험 종료 24시간 전까지 취소하지 않으면 선택한 구독으로 자동 전환 및 과금.
- 미사용 기간: 구독 구매 시 무료 체험의 미사용 기간은 소멸될 수 있음(Apple 정책 준수).
- UI 표기: “7일 무료체험” 배지 표시(대상자), “D-N | 7일 무료체험” 가능.

## 3. 자동갱신·취소·관리
- 자동갱신: 사용자가 취소하지 않는 한 구독은 자동으로 갱신됩니다.
- 과금 시점: 현재 주기 종료 24시간 전 갱신 프로세스가 시작되며, Apple ID로 결제 청구.
- 취소/관리: iOS 설정 > Apple ID > 구독에서 관리/취소 가능합니다.
- 지역 가격: 가격은 국가/지역/세금/환율에 따라 다를 수 있습니다.

### [KO] 하단 고지(앱 표준 카피)
구독은 사용자가 취소하지 않는 한 자동으로 갱신됩니다. 체험 기간 종료 24시간 전까지 취소하지 않으면 결제가 발생합니다. 결제는 Apple ID로 청구되며, 구독 및 자동 갱신은 iOS 설정 > Apple ID > 구독에서 관리/취소할 수 있습니다. 무료 체험은 계정당 1회 제공될 수 있으며, 구독 구매 시 미사용 체험 기간은 소멸될 수 있습니다. 가격은 국가/지역에 따라 다를 수 있습니다.

### [EN] Footer Disclosure (App Standard Copy)
Subscriptions auto-renew unless canceled at least 24 hours before the end of the period. Payment is charged to your Apple ID. Manage/cancel in Settings > Apple ID > Subscriptions. Free trial may be offered once per account; any unused portion is forfeited upon purchase. Prices vary by region.

## 4. 환불(Refund)
- 경로: App Store/Apple 고객지원 정책을 따릅니다(개발사 직접 환불 불가). 사용자는 Apple 지원 채널을 통해 환불을 요청할 수 있습니다.
- 앱 처리: 영수증/엔타이틀먼트에 환불/취소가 반영되면 구독 상태를 갱신합니다.
  - 상태 매핑(SubscriptionStatusCenter.state):
    - `.active(premiumUntil:)` — 유료/체험 활성
    - `.gracePeriod(retryUntil:)` — 결제 재시도 유예
    - `.refunded(graceUntil:)` — 환불 처리되었으나 정책상 기한까지 혜택 유지
    - `.expired(expiredAt:)` — 만료
    - `.free` — 무료
- UX 가이드: 환불 직후 사용성 충격을 줄이기 위해 `.refunded` 기간 중에는 혜택 유지 및 안내 텍스트 표기.

## 5. 복원(Restore Purchases)
- 동작: iOS 설정과 무관하며, 앱 내 “구매 복원” 버튼 → `AppStore.sync()` 실행 → `Transaction.currentEntitlements` 반영.
- 네트워크: Apple 서버 응답 필요. 실패 시 재시도 버튼·토스트 제공.
- 서버 보고(선택): `ProxyTierReporter`가 `POST /v1/subscription/report`로 수동 보고(프록시 모드 운영 시).

## 6. 구매 시트(간편 결제) 화면 요건
- 한 화면에 노출: 플랜(Pro/Max)·기간(월/연)·가격·7일 무료체험(대상 시)·복원·정책 링크(Privacy/Privacy Choices/Trial)·자동갱신 고지·닫기
- 가격/버튼: 항상 활성(로딩만 보이는 상태 금지). 실패 시 폴백 제공.
- 접근성: 버튼 라벨에 가격 포함, 링크/배지에 접근성 라벨 지정.
- 링크(내부):
  - 구독/체험 안내: `https://emozleep.space/legal/trial/`
  - 개인정보 처리방침: `https://emozleep.space/legal/privacy/`
  - 개인정보 선택사항: `https://emozleep.space/legal/privacy-choices/`

### 6-b. 간단 설명(앱 표준 카피)
- 요약(예):
  - 일일 채팅: 무료 50회 · Pro 130회 · Max 250회
  - 프리셋 5→30/50, 할일조언 5→20/50
  - 오늘 전체 조언 1→3/5, 일기 이야기 5→7/10

## 7. 개발/운영 설정
- 로컬(시뮬레이터/개발): Xcode Scheme → StoreKit Configuration=`DeepSleep.storekit`
- 실기기/ASC: 실제 상품(Product) 조회·결제
- 스크린샷 모드(촬영 전용): 환경변수 `IAP_SCREENSHOT=1`
  - 가격/버튼 강제 활성(예시 가격 노출)
  - 심사용 촬영에서 로딩/비활성 화면 금지 조건 충족
 - API 버전: StoreKit 2(Product) 사용 — SKProduct 계열은 Deprecated. 현지화 가격은 `Product.displayPrice` 사용.

## 8. 분석/로그(표준 이벤트)
- 노출: `paywall_view`
- 선택: `paywall_select_plan {pro|max}`, `paywall_select_term {monthly|yearly}`
- 복원: `paywall_restore`
- 구매: `purchase_started {productId}`, `purchase_success`, `purchase_fail {error}`

## 9. 에러 처리/엣지 케이스
- 제품=0개: 토스트 + 재시도 버튼 제공(스크린샷 모드에서는 폴백 가격 노출로 가려짐)
- 네트워크 오류: 구매/복원 실패 시 UIAlert(확인/재시도). 로그 기록.
- 트라이얼 판정: 기본 휴리스틱(Transaction.currentEntitlements) 사용. 정밀 검증은 영수증/서버 검증 도입 권장(후속).
- 지역/세금 변동: 표시 가격은 StoreKit의 현지화 가격(`Product.displayPrice`) 사용. Doc상의 예시는 참고값.

## 10. UI 표준 카피(재사용)
- 혜택 요약(KO): “일일 대화 상한 • 프리셋 • 할 일 조언 • 모델 선택”
- 하단 고지: 상기 KO/EN 문구를 그대로 사용. UI 컴포넌트는 해당 카피를 SSOT로 참조.

## 11. 구현 포인터(코드 정합성)
- StoreKit 2 단일 매니저: `StoreKitSubscriptionManager`
  - `loadProducts()`, `displayPrice(for:)`, `purchase(_:)`, `restore()`, `isTrialEligible`
  - 알림: `Notification.Name.iapProductsUpdated`
- 구독 상태: `SubscriptionStatusCenter` (전역 브로드캐스트)
- 정책 카피: `SubscriptionUIMessageFormatter`(구독/상태) + 확장(페이월 고지/혜택 요약)
- 구매 시트 구성: `PurchaseOptionSheetViewController` + `PaywallPresenter.present(from:)`
- 외부 링크: Trial/Privacy/Privacy Choices(위 6장 참조)

## 12. 검증 체크리스트(배포 전)
- [ ] Pro/Max · 월/연 · 가격 · 7일 무료체험(대상) · 복원 · 정책 링크 · 자동갱신 고지가 한 화면에 표시됨
- [ ] 스크린샷 모드에서 가격/버튼 강제 활성 동작
- [ ] 로컬(StoreKit Configuration)/실기기(ASC)에서 가격 표시 정상
- [ ] 복원 동작 후 상태 반영(프리미엄/무료 전환) 확인
- [ ] 로그 이벤트가 기대대로 발생
- [ ] 하단 고지 문구/링크 철자·URL 정확

## 13. 변경 이력 & 책임자
- 2025-09-11: 최초 SSOT 정리(Paywall/StoreKit 2/스크린샷 모드 반영). 책임: 모바일 iOS 오너.
