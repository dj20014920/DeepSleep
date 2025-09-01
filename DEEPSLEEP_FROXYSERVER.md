# DeepSleep 프록시 서버(Cloudflare Workers) — 운영 가이드 (프로덕션)

최종 업데이트: 2025-09-01

이 문서는 iOS 앱이 프록시 모드에서 사용하는 Cloudflare Workers 기반 AI 프록시의 단일 진실(SSOT) 가이드입니다. 아키텍처, 엔드포인트, 인증(HMAC+Nonce), 환경 변수/시크릿, KV 바인딩, 배포/테스트, 트러블슈팅을 모두 포함합니다. 서버 코드와 iOS 연동이 변경되면 본 문서도 반드시 동기화합니다.


# 2025-09-01 배포/운영 동기화: 프록시 & 모델별 캐싱

현재 상태(프로덕션)
- 워커: emozleep (Cloudflare Workers)
- URL: https://emozleep-production.vinny4920-081.workers.dev
- Version ID: c18d6a9c-f4ad-43ed-9689-dce0210e60b5

핵심 기능
- /v1/chat: providerCaching 스키마 수용 및 공급자별 캐시 적용
- 응답 헤더: X-Cache-Provider/Action/TTL/Tokens
- 무효화: X-Context-Invalidation 헤더 1회성 처리

공급자 정책
- Anthropic: ephemeral cache_control 3600s, 30분 경과 write
- Gemini: caches.create + PATCH ttl=3600s로 최대 3시간 운용
- OpenAI: 시스템 프리픽스 해시/길이 KV 기록(관측)
- Naver: 캐싱 불가 → bypass

iOS 연동
- AIContextManager: 무효화 사유 보관/소비
- UnifiedAIServiceImpl: providerCaching 전송, X-Cache-* 파싱, 무효화 헤더 전송

운영 팁
- 로그: wrangler tail emozleep --format pretty
- 재배포: wrangler deploy --env production
- 검증 체크리스트
  - X-Cache-Action: miss→write 이후 hit/read로 전환
  - Gemini PATCH 응답 200 확인
  - OpenAI prefix hash 변동 0 유지

추가 과제
- /v1/metrics 구현 및 대시보드 연계
- NAVER 키 단일화 마이그레이션 완료

---

1) 현재 상태(요약)
- 워커 이름: emozleep
- 프로덕션 URL: https://emozleep-production.vinny4920-081.workers.dev
- 리포지토리 경로: /Users/dj20014920/Desktop/DeepSleep/emozleep
- 설정 파일: /Users/dj20014920/Desktop/DeepSleep/emozleep/wrangler.toml
- KV 바인딩: USAGE_KV (바인딩 완료)
- iOS: 프록시 모드 활성화, /v1/enroll + /v1/chat 사용


2) 아키텍처 개요
- iOS 앱 → Cloudflare Worker(프록시) → 제공자(Anthropic, OpenAI, Google, Naver, OpenRouter)
- 워커가 담당하는 중앙 기능
  - HMAC(+Nonce) 인증
  - 티어 게이팅(무료/free, pro, max)
  - 일일 한도 및 레이트 리미팅
  - 모델 라우팅 및 서버 사이드 폴백
  - CORS 처리, 관측성, 통일된 응답 형식
- iOS 앱에는 공급자 API 키가 포함되지 않습니다. 모든 키는 워커의 시크릿으로 관리합니다.


3) 엔드포인트
- POST /v1/enroll
  - 기기(UID)별 HMAC 서명용 시크릿 발급
  - 필수 헤더: X-Emozleep-UID
  - 응답: { "secret": "<device_secret>" }

- POST /v1/chat
  - 통합 대화 엔드포인트(라우팅/폴백/정책 적용)
  - 요청 JSON
    {
      "model": "gemini" | "openai" | "claude" | "naver" | "openrouter" | "free",
      "messages": [{"role":"system|user|assistant","content":"..."}],
      "mode": "general_conversation" | "presetRecommendation" | ...,
      "temperature"?: number,
      "maxTokens"?: number
    }
  - 응답 JSON: { "provider": "gemini|openai|claude|naver|openrouter", "content": "..." }
- 응답 헤더(정책/관측)
    - X-Provider: 실제 사용된 제공자
    - X-Policy-Tier: 적용된 티어
    - X-Policy-ResetAt: 일일 한도 리셋(KST 00:00, +09:00) ISO 시각(예: 2025-09-01T00:00:00+09:00)
    - X-Policy-Claude-Remaining: Claude 잔여 일일 횟수(프리미엄 기준)

- POST /v1/subscription/report
  - 구독 상태 리포트 수신(예약)
  - 인증: /v1/chat과 동일한 HMAC(+Nonce) 서명 사용. iOS 2025-08-31 패치로 적용됨
  - 필수 헤더: X-Emozleep-UID/Tier/Timestamp/(Nonce?)/Sig
  - 바디 예: { "productId": "com.emozleep.pro.monthly", "expiresAtMs": 1754340000000 }

- OPTIONS (CORS 프리플라이트)
  - CORS 헤더 반환 + 커스텀 응답 헤더 노출(Expose-Headers)


4) 인증 — HMAC(+Nonce)
- /v1/chat 필수 헤더
  - X-Emozleep-UID: iOS 기기 식별자(identifierForVendor)
  - X-Emozleep-Tier: free | pro | max
  - X-Emozleep-Timestamp: epoch milliseconds (±5분 허용)
  - X-Emozleep-Nonce: 임의의 소문자 hex(uuid에서 대시 제거) — 선택(클라이언트 플래그)
  - X-Emozleep-Sig: HMAC-SHA256 hex
- 서명 원문(base)
  - Nonce 사용 시: "{ts}:{uid}:{tier}:{nonce}"
  - Nonce 미사용 시: "{ts}:{uid}:{tier}"
- 검증 순서(서버)
  1) USAGE_KV에서 기기 시크릿 조회(/v1/enroll 발급)
  2) 없으면 EDGE_SIGNING_SECRET로 검증
- iOS 동작
  - /v1/enroll로 기기 시크릿 발급 → 키체인 저장
  - DEBUG에서만 최후Fallback: CLIENT_PROXY_HMAC_SECRET


5) 라우팅/폴백 정책
- 티어 적용(routePolicy)
  - free가 claude 요청 시 gemini로 강등 라우팅
  - 유료 티어에서 Claude는 일일 상한 내에서만 허용
- 기본 모델(wrangler.toml [vars])
  - DEFAULT_GEMINI_MODEL = "gemini-2.0-flash-lite"
  - DEFAULT_OPENAI_MODEL = "gpt-4o-mini"
  - DEFAULT_CLAUDE_MODEL = "claude-3-5-haiku-latest"
  - DEFAULT_NAVER_MODEL = "HCX-DASH-002"
- 서버 폴백 체인(현행 구현)
  - openrouter(무료) → gemini → openai → naver → claude
  - 클라이언트가 claude를 지정해 실패해도 위 순서로 폴백 시도
- Claude 일일 상한(프리미엄)
  - 키: claude:{uid}:{YYYY-MM-DD}
  - TTL: 자정까지(Cloudflare 정책상 최소 60초 이상 보장)


6) 레이트/쿼터/정책 헤더
- 레이트: checkRateLimit(uid) 선행 확인(서버 구현)
- 일일 카운터: USAGE_KV 사용(현재는 Claude 카운트 우선)
- 응답 정책 헤더(클라이언트는 있으면 파싱)
  - X-Provider, X-Policy-Tier, X-Policy-ResetAt(KST 자정, +09:00)
  - X-Policy-Claude-Remaining(프리미엄에서 유효)
  - 일반 ‘남은 횟수’(기능별)는 서버 집계 확장 시 추가 예정(YAGNI 원칙으로 현재 미도입)


7) CORS
- ALLOWED_ORIGINS로 허용 Origin 제어(콤마 구분). 비어 있으면 모두 허용.
- iOS 네이티브는 기본적으로 Origin 헤더를 보내지 않지만, 본 앱은 일관성을 위해 Origin: https://emozleep.app 를 항상 전송합니다. 반드시 ALLOWED_ORIGINS에 https://emozleep.app 를 포함하세요.
- 웹에서 커스텀 헤더를 읽을 수 있도록 Access-Control-Expose-Headers에 정책/프로바이더 헤더를 명시했습니다.
- 클라이언트는 ProxyAuthConfig.origin 상수를 통해 동일 Origin을 사용합니다(하드코딩 분산 금지, DRY).


8) 환경 변수/시크릿
- 변수(wrangler.toml [vars])
  - ALLOW_EDGE_FALLBACK = "0|1"
  - CLAUDE_DAILY_LIMIT_PREMIUM = "30"
  - DEFAULT_GEMINI_MODEL, DEFAULT_OPENAI_MODEL, DEFAULT_CLAUDE_MODEL, DEFAULT_NAVER_MODEL
  - ALLOWED_ORIGINS
- 시크릿(대시보드 또는 `wrangler secret put`)
  - EDGE_SIGNING_SECRET
  - CLAUDE_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY
  - NAVER_CLOUD_API_KEY  ← 단일 키로 통일 (형식: key:secret)
  - OPENROUTER_API_KEY
- KV 바인딩
  - 이름: USAGE_KV (wrangler.toml에 선언)
  - 대시보드: Workers & Pages → emozleep → Settings → Bindings → KV Namespace


9) Cloudflare 대시보드 설정(버튼 경로)
A. 워커 열기
- https://dash.cloudflare.com → Workers & Pages → emozleep

B. KV 바인딩
- Settings → Bindings → KV Namespace → Add binding
  - Variable name: USAGE_KV
  - 기존 네임스페이스 선택 또는 새로 생성(emozleep-usage-kv)

C. Variables(일반 변수)
- Settings → Variables → Add variable
  - ALLOW_EDGE_FALLBACK, CLAUDE_DAILY_LIMIT_PREMIUM, DEFAULT_* 모델, ALLOWED_ORIGINS(웹 사용 시)

D. Secrets(시크릿)
- Settings → Variables → Add → Set as Secret
  - EDGE_SIGNING_SECRET, CLAUDE_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY, NAVER_CLOUD_API_KEY, OPENROUTER_API_KEY
  - 주의: 기존 NAVER_API_KEY/NAVER_API_SECRET 사용 중이면, 서버 코드 업데이트 전까지 병행 유지 가능. 최종적으로는 NAVER_CLOUD_API_KEY=key:secret 단일 형태로 이관합니다.

E. 라우트/커스텀 도메인(선택)
- Triggers → Custom domains → Add custom domain
  - 예: api.emozleep.app → 본 워커 라우팅

F. 로그/테일
- 워커 상세의 Logs 탭
- 또는 CLI: `wrangler tail --env production`


10) wrangler.toml 주요 항목
- 경로: /Users/dj20014920/Desktop/DeepSleep/emozleep/wrangler.toml
- 중요한 설정
  name = "emozleep"
  main = "worker.js"   # 실제 파일 경로와 일치(수정 완료)
  account_id = "081a9810680543ee912eb54ae15876a3"
  [[kv_namespaces]] binding = "USAGE_KV" ...
  [env.production.vars] ...
  [[env.production.kv_namespaces]] ...


11) wrangler CLI(로컬)
- 전제: wrangler 설치 및 환경 변수 안전 설정(시크릿 값은 명령줄에 직접 노출 금지)

예시
  export CLOUDFLARE_ACCOUNT_ID=081a9810680543ee912eb54ae15876a3
  export CF_API_TOKEN={{CF_API_TOKEN}}

  # 아래 명령은 대화형 입력으로 값을 받습니다
  wrangler secret put EDGE_SIGNING_SECRET
  wrangler secret put CLAUDE_API_KEY
  wrangler secret put OPENAI_API_KEY
  wrangler secret put GEMINI_API_KEY
  wrangler secret put NAVER_API_KEY
  wrangler secret put NAVER_API_SECRET
  wrangler secret put OPENROUTER_API_KEY

배포
  wrangler deploy --env production

로그 테일
  wrangler tail --env production


12) iOS 연동(요약)
- Info.plist(xcconfig 경유)
  - USE_PROXY = YES
  - PROXY_BASE_URL = https://emozleep-production.vinny4920-081.workers.dev
  - PROXY_AUTH_USE_NONCE = YES(선택)
  - CLIENT_PROXY_HMAC_SECRET(디버그용 Fallback)
- UnifiedAIServiceImpl.swift
  - /v1/chat로 프록시 우선 경로, 헤더: Origin, X-Emozleep-UID/Tier/Timestamp/Nonce?, X-Emozleep-Sig
  - /v1/enroll 호출 후 기기 시크릿을 키체인 저장
  - X-Policy-* 헤더가 있으면 남은 횟수/리셋 시각 등 UI에 반영


13) 스모크 테스트(curl)
- 스크립트: /Users/dj20014920/Desktop/DeepSleep/scripts/proxy_smoke_test.sh
- 시크릿은 절대 명령줄에 직접 쓰지 마세요. 환경 변수로 주입하세요.
- CI 정책 헤더 점검 스크립트: scripts/ci_proxy_policy_check.sh (성공 응답에서 X-Provider/X-Policy-* 포함 확인)

A. 프리플라이트(CORS/웹 테스트용)
  curl -i -X OPTIONS \
    "${PROXY_BASE_URL}/v1/chat" \
    -H 'Origin: https://emozleep.app' \
    -H 'Access-Control-Request-Method: POST'

B. Enroll(시크릿 발급)
  export UID=$(uuidgen)
  curl -sS -X POST "${PROXY_BASE_URL}/v1/enroll" \
    -H "X-Emozleep-UID: ${UID}" \
    -H 'Origin: https://emozleep.app'
  # 응답의 secret을 안전하게 보관 → SECRET_FROM_ENROLL

C. 서명된 채팅(비스트리밍)
  export TIER=free
  export TS_MS=$(($(date +%s)*1000))
  export NONCE=$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')
  export BASE="${TS_MS}:${UID}:${TIER}:${NONCE}"
  export SIG=$(printf "%s" "$BASE" | openssl dgst -sha256 -hmac "$SECRET_FROM_ENROLL" | awk '{print $2}')

  BODY='{"model":"gemini","mode":"general_conversation","messages":[{"role":"system","content":"You are a helpful assistant."},{"role":"user","content":"안녕!"}]}'

  curl -i -X POST "${PROXY_BASE_URL}/v1/chat" \
    -H 'Content-Type: application/json' \
    -H 'Origin: https://emozleep.app' \
    -H "X-Emozleep-UID: ${UID}" \
    -H "X-Emozleep-Tier: ${TIER}" \
    -H "X-Emozleep-Timestamp: ${TS_MS}" \
    -H "X-Emozleep-Nonce: ${NONCE}" \
    -H "X-Emozleep-Sig: ${SIG}" \
    --data "$BODY"

예상: 200 {provider, content}. free에서 claude 요청 시 gemini로 라우팅된 provider 확인.

부정 테스트
  - 서명 오류 → 401
  - 타임스탬프 오래됨(>5분) → 401
  - messages 누락 → 400
  - 레이트 초과 → 429


14) 스트리밍(SSE) 계획(필요 시 도입)
- 클라이언트: "stream": true 플래그 도입
- 서버: Content-Type: text/event-stream, 아래 이벤트 전송
  - event: message / data: {"delta":"..."}
  - event: done / data: {"finishReason":"stop"}
- 동일 인증/티어/레이트 정책 유지, 위반 시 연결 종료
- 현재는 비스트리밍 경로가 표준이며, 필요해질 때만 최소 구현(YAGNI)


15) 체크리스트/정합성
- 폴백 체인: openrouter → gemini → openai → naver → claude (서버 구현과 문서 일치)
- 정책 헤더: X-Provider/X-Policy-*, CORS Expose-Headers 포함(웹에서도 읽기 가능)
- wrangler.toml main=worker.js(실제 파일과 일치)
- KV TTL: Cloudflare 최소 60초 준수(자정 만료는 secondsUntilKSTMidnight())
- Nonce 재사용 방지(권장): nonce:{uid}:{nonce} 키를 KV에 300초 TTL로 저장(Set if not exists). 중복 감지 시 401/409 반환


15.1) 절대 변경 금지(Immutable Contract) — 반드시 준수
- 헤더 명세: X-Emozleep-UID/Tier/Timestamp/(Nonce?)/Sig — 철자/대소문자/콜론 구분 포함
- 서명 원문: "{ts}:{uid}:{tier}:{nonce?}" — Nonce 사용 여부만 분기, 순서 변경 금지
- Origin: https://emozleep.app — 클라이언트 상수화(ProxyAuthConfig.origin), 서버 ALLOWED_ORIGINS에 반드시 포함
- 엔드포인트 경로/메서드: POST /v1/enroll, POST /v1/chat, POST /v1/subscription/report, OPTIONS /v1/chat — 오타/경로 변경 금지
- 정책 헤더: X-Provider, X-Policy-Tier, X-Policy-ResetAt(+09:00), X-Policy-Claude-Remaining — 노출 이름 고정
- Naver 시크릿: NAVER_CLOUD_API_KEY=key:secret 단일 형태 — 이전 NAVER_API_KEY/NAVER_API_SECRET 병행 사용 금지(이관 완료 후 제거)

15.2) 왜 이렇게 고정하나요?(배경/이유)
- 클라이언트와 서버 간 서명·헤더는 프로토콜 계약입니다. 작은 오타/순서 변경도 인증 실패를 유발합니다.
- Origin은 CORS/정책 노출(Expose-Headers)의 전제이며, 다중 하드코딩은 유지보수 리스크입니다. 중앙 상수화로 오탈자/누락 방지.
- Naver 키 단일화는 설정/문서/대시보드의 중복을 제거하여 운영 위험을 낮춥니다.
- 정책 헤더 명세 고정은 iOS UI 싱크(남은 횟수/리셋 시각)와 로그/모니터링의 일관성을 보장합니다.

15.3) 감정일기 분석 플로우 SSoT (iOS)
- 진입점: ChatRouter.chatViewController(context: .diaryAnalysis(diary:))
- 라우팅: Router가 chatContext(.emotionDiaryAnalysis)와 diaryContext를 설정하고 isEphemeralSession = true로 진입(저장소 복원/재개 알림 차단)
- 트리거 SSoT: ChatViewController.requestDiaryAnalysisWithTracking(diary:)
- 보정: Router가 diaryContext를 설정하여 ChatViewController 경로로 통합(legacy initialDiaryData만으로는 트리거 안 되는 오류 예방)
- 중복 방지: didStartDiaryAnalysis 플래그로 다중 호출 차단
- 서버 호출: /v1/chat (프록시) 고정, HMAC(+Nonce) 헤더, 정책 헤더 UI 반영
- 적용 화면: DiaryWriteViewController/ EditDiaryViewController 모두 Router(.diaryAnalysis)로 통일
- 클라이언트와 서버 간 서명·헤더는 프로토콜 계약입니다. 작은 오타/순서 변경도 인증 실패를 유발합니다.
- Origin은 CORS/정책 노출(Expose-Headers)의 전제이며, 다중 하드코딩은 유지보수 리스크입니다. 중앙 상수화로 오탈자/누락 방지.
- Naver 키 단일화는 설정/문서/대시보드의 중복을 제거하여 운영 위험을 낮춥니다.
- 정책 헤더 명세 고정은 iOS UI 싱크(남은 횟수/리셋 시각)와 로그/모니터링의 일관성을 보장합니다.

16) 트러블슈팅
- 401 Unauthorized
  - X-Emozleep-* 헤더 정확성 확인
  - 타임스탬프 스큐/서명 원문(Nonce 포함/미포함) 점검
  - enroll/기기 시크릿 발급 여부 확인
- 403 Forbidden
  - ALLOWED_ORIGINS 설정 오류(웹 전용). 네이티브 앱은 Origin 미포함도 인증 성공 시 허용
- 404 Not Found
  - 경로/메서드 확인(/v1/chat|/v1/enroll, POST)
- 429 Too Many Requests
  - 레이트/일일 한도 초과. X-Policy-ResetAt(KST 자정, +09:00) 기준으로 재시도
- 5xx Provider errors
  - 공급자 키/쿼터/호출 형식 점검, `wrangler tail`로 에러 본문 확인


17) 변경 이력
- 2025-08-31: 프록시 모드 프로덕션 전환, HMAC+Nonce 인증, 정책 헤더/폴백 체인 정비, wrangler.toml main 경로 수정
- 2025-09-01: 모델별 캐싱 설계/요청 스키마/헤더/KV 스키마/검증 체크리스트 추가

## 18) 모델별 캐싱 시스템 설계/구현(비용 최적화) — 2025-09-01

요약 결론
- 토큰 비용 절감은 “공급자 측 캐싱”에서만 발생합니다. 3시간 앱 내부 캐시는 UX/레이턴시 개선에 유의미하나 과금에는 영향이 없습니다.
- 권장안: 듀얼 레이어 유지(앱 3시간 캐시 + 서버 공급자 캐싱). 단, ‘캐시 소유권’은 서버로 단일화하여 프리픽스 안정화·무효화·메트릭을 서버에서 집행합니다.
- 통일 대안: 앱 캐시 제거(서버만 캐싱)는 가능하나, 네트워크 장애/프록시 재시도 시 UX 저하가 있어 권장하지 않습니다.

설계 원칙
- 안정 프리픽스 정의: [시스템 프롬프트 + 페르소나 규칙 + 핵심기억 요약]을 바이트 동일하게 유지(줄바꿈/공백 포함). 최근 대화/사용자 입력은 프리픽스에 포함하지 않음.
- 캐시 키: personaSignature(내부 해시) + 모델명. 해시는 외부 전송 금지. 서버에서만 식별자로 사용.
- 무효화 SSoT: 모델/페르소나/핵심기억 변경 시 iOS가 헤더 X-Context-Invalidation: <reason>를 전송 → 서버는 해당 키의 캐시 엔트리를 무효화.

요청 스키마 확장(/v1/chat)
- 요청 JSON에 선택 필드 추가
  {
    // ...existing fields...
    "providerCaching": {
      "enable": true,
      "strategy": "auto",    // auto|force-write|force-read
      "ttlSeconds": 3600,      // 공급자별 최대치 내에서 사용(없으면 기본)
      "cacheKey": "<personaSignature>"
    }
  }
- 서버는 enable=true일 때만 공급자 캐싱을 시도. ttlSeconds는 공급자 한도 내로 클램프.

응답/관측 헤더 추가
- X-Cache-Provider: anthropic|gemini|openai|naver|none
- X-Cache-Action: write|read|bypass|unsupported
- X-Cache-TTL: 남은 TTL(초) 또는 0
- X-Cache-Tokens: writeIn|readIn(예: "writeIn=1200;readIn=9800")

KV/스토리지 스키마
- 키: cache:{provider}:{model}:{personaKey}
- 값(JSON): {
    nameOrId: string,      // Gemini cache.name 등
    createdAt: epoch_ms,
    ttlSec: number,
    lastReadAt: epoch_ms,
    stats: { writes: n, reads: n }
  }

공급자별 구현 메모
- Anthropic(Claude) — 운영 30분 정책(1시간 TTL 기반)
  - 메시지 생성 시 안정 프리픽스에 cache_control: { type: "ephemeral", ttl: "1h" } 지정.
  - KV에 personaKey로 "작성 시각" 저장. 운영 30분 정책은 30분 경과 시 재작성(force-write)로 달성.
  - 사용량 필드(예: cache_creation_input_tokens, cache_read_input_tokens)로 히트율/절감 추적.
  - 최소 캐시 길이/브레이크포인트 제약에 대비하여 프리픽스가 짧을 경우 bypass 처리.
- Google Gemini — 1시간 TTL
  - 최초 요청 시 caches.create(ttl=3600s) → 반환된 cache.name을 KV에 저장 후 generateContent에 cachedContent 사용.
  - 3시간 운용은 1시간 단위로 caches.patch로 TTL 연장.
  - UsageMetadata(토큰 메타) 기반으로 절감 추정치 산출.
- OpenAI — 자동 프리픽스 캐싱
  - 별도 API 없음. 바이트 동일 프리픽스를 엄수. usage 내 캐시 관련 카운터(제공 시)를 로깅.
  - KV에는 마지막 프리픽스 해시와 길이만 기록해 프리픽스 안정성 점검.
- Naver HyperCLOVA X — 미지원
  - 캐싱 없음. 프리픽스 축약/요약으로 토큰 절감.

무효화/동기화
- iOS 트리거: 모델/페르소나/핵심기억 변경 시 X-Context-Invalidation로 알림.
- 서버 트리거: 공급자 오류/스키마 변경 감지 시 해당 키 강제 무효화.
- 앱 3시간 캐시는 계속 유지(UX/레이턴시). 단, 비용 분석 시 제외.

메트릭/절감 계산(서버 집계)
- per-provider: cache_write_tokens, cache_read_tokens, hit_rate, est_savings_usd.
- 헤더와 로그를 기준으로 주/월 단위 리포트 생성.

간단 의사코드(worker)
```js
// 안정 프리픽스 빌드(바이트 동일)
const prefix = buildStablePrefix(system, persona, coreMemorySummary);
const personaKey = sha256(prefix + model);

switch(provider){
  case 'anthropic':
    // write/read 선택
    const action = decideAnthropicAction(personaKey, req.providerCaching);
    const messages = withCacheControl(prefix, userParts, action, '1h');
    // 호출 및 usage 기반 로깅/헤더 세팅
    break;
  case 'gemini':
    const entry = await ensureGeminiCache(env, personaKey, req.providerCaching);
    const body = useCachedContent(entry.name, userParts);
    // 호출 및 UsageMetadata 로깅
    break;
  case 'openai':
    // 프리픽스 안정성만 보장, 호출/로깅
    break;
  case 'naver':
    // 캐싱 없음 → 프리픽스 경량화
    break;
}
```

비용 관점 비교(요약)
- 듀얼 레이어(앱 3h + 서버 캐싱): 비용 절감은 서버 캐싱이 전부 담당. UX/레이턴시 이점 존재 → 권장.
- 단일화(서버 캐싱만): 비용 측면 동일, 다만 앱 단 캐시 제거 시 UX 리스크 증가 → 비권장.

검증 체크리스트
- [ ] /v1/chat 요청에 providerCaching 전달 시 헤더 X-Cache-* 응답 반영
- [ ] Anthropic: 30분 후 재작성 동작, 1시간 미만에서도 read 히트율 80%+
- [ ] Gemini: create→generate→patch 연장 루프에서 캐시 유효 3시간 운용
- [ ] OpenAI: 프리픽스 바이트 동일 검증 로그(샘플 100건, 변동 0)
- [ ] Naver: 프리픽스 요약 길이 상한 정책 적용
- [ ] 무효화: 모델/페르소나/핵심기억 변경 시 서버·앱 캐시 모두 미스 확인

