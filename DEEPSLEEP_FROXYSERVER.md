# DeepSleep 프록시 서버(Cloudflare Workers) — 운영 가이드 (프로덕션)

최종 업데이트: 2025-09-08

## 2025-09-08 동기화: 인증 워밍 · 일반대화 토큰 상한 · 스트리밍 현황
- 클라이언트(App): 앱 기동 시 ProxyAuthClient.loadSecretOrEnroll 1회 호출로 프록시 시크릿 메모리 캐시 워밍(목표: auth;dur P50 0.2~0.4s). 운영 계약(/v1/enroll, HMAC 원문, X-Emozleep-*) 불변.
- 클라이언트(App): 일반 대화(general_conversation) 기본 maxTokens를 256으로 타이트화(구성 키가 있으면 우선). 목적은 provider 처리시간 단축과 체감 응답 가속. 장문이 필요한 화면은 Info/xcconfig 키로 상향 가능(SSoT 유지).
- 서버(Workers): 현재 text/event-stream(SSE) 미배포 상태. §14 스트리밍 계획에 따라 스테이징에서 구현/검증 후 단계적 롤아웃 예정.
- 관측 정합성: X-Cache-Action=bypass, X-Cache-Error=too-small(1024)은 안정 프리픽스 길이(≥1024 토큰) 미달 시 공급자 캐시 생략이 의도대로 동작하는 것임. 비용·지연 최적화에는 영향 없음(앱 캐시와 무관).
- KPI 리마인드: first_token_ui(P50)<800ms(향후 SSE 적용 시), total(P50)<4.0s, auth;dur 평균<300ms, provider;dur 지속 모니터링.

이 문서는 iOS 앱이 프록시 모드에서 사용하는 Cloudflare Workers 기반 AI 프록시의 단일 진실(SSOT) 가이드입니다. 아키텍처, 엔드포인트, 인증(HMAC+Nonce), 환경 변수/시크릿, KV 바인딩, 배포/테스트, 트러블슈팅을 모두 포함합니다. 서버 코드와 iOS 연동이 변경되면 본 문서도 반드시 동기화합니다.

## 2025-09-05 동기화: 캐시 임계/경로/폴백/헤더 정리
- 동적 임계 T 적용: 일반=1024(장세션 512 시도 가능), 프리셋=2048(STRICT JSON), 분석/월간=1536. 공급자 바닥으로 클램프(Gemini=1024, Anthropic=512).
- countTokens 경로: Vertex/GL 모두 `:countTokens` 리소스 사용(오류 404/405 방지).
- 헤더 추가: `X-Cache-Policy-Min`(적용된 바닥)과 `X-Cache-Client-Override`(클라이언트 하향 요청값) 노출.
- 폴백 순서(일반): gemini → openai → naver → claude → openrouter.
- 폴백 순서(엄격 JSON): gemini → openai → naver → claude(OPENROUTER는 스킵; `STRICT_JSON_SKIP_OPENROUTER=1`).
- 버스트 프리캐시: preset needCount=1, general needCount=2로 빠른 write 유도(이후 바닥/임계 정책 적용).

## 2025-09-04 동기화: GL API(Key) 고정 + 캐싱 정책 정리
- Prod vars: CANARY_PERCENT=100, STRICT_JSON_ONLY=1, STRICT_JSON_SKIP_OPENROUTER=1
- 인증: Generative Language API + API Key(x-goog-api-key). 시크릿 이름은 `GEMINI_VERTEX_API_KEY`로 일원화(서버 전용).
- 주의: Vertex REST(aiplatform)는 OAuth만 허용 → 워커에서는 사용하지 않음. GL API를 Enable하고, API Key 제한에 "Generative Language API"를 반드시 포함해야 403(API_KEY_SERVICE_BLOCKED)을 피할 수 있음.
- 캐싱: cachedContents TTL=3600s, 동적 임계(T) 적용(일반=1024, 프리셋=2048, 분석=1536). generateContent에는 cachedContent만 전달(프리픽스 재전송 금지). 공급자 바닥(Gemini=1024, Anthropic=512)로 클램프.
- 폴백: preset_recommendation(Strict JSON)은 gemini→openai→naver→claude, 일반 대화도 gemini 우선.
- Dev 배포 URL: https://emozleep.vinny4920-081.workers.dev
- Current Version ID: 647eacbc-d70e-49a9-81d4-1df423ee49f3
- Dev vars: CANARY_PERCENT=100, STRICT_JSON_ONLY=1, STRICT_JSON_SKIP_OPENROUTER=1
- Dev/Prod vars는 wrangler.toml에 정의. 프로덕션은 CANARY_PERCENT=100으로 캐싱 전면 적용.
- 엄격 JSON(Strict JSON) 집행: mode === 'preset_recommendation' && STRICT_JSON_ONLY=1이면 responseMimeType을 application/json으로 강제. 클라이언트가 responseSchema를 보내면 OpenAI/Anthropic에 JSON Schema 기반 구조화 출력 강제. 응답 헤더 X-Strict-JSON=(schema|json;mime=application/json) 노출.
- 폴백 체인(엄격 JSON 시): gemini → openai → claude → naver (openrouter는 스킵)
- 다음 액션: prod 배포(wrangler deploy --env production) + 캐나리 5%로 시작 후 지표 안정 시 점진 상향(10→25→50→100)


# 2025-09-03 업데이트: 캐나리 배포와 멱등성(idempotency)

용어 정의
- 캐나리(Canary) 배포: 전체 사용자에게 한 번에 반영하지 않고, 일부 비율(예: 5%→10%→50%→100%)의 요청만 새로운 기능/정책을 적용해 안정성을 검증하는 점진적 롤아웃 방식입니다. 문제 발생 시 즉시 비율을 낮추거나 0%로 꺼서 영향 범위를 최소화할 수 있습니다.
- 멱등성(Idempotency): 동일한 요청이 네트워크 재시도/중복 탭 등으로 여러 번 도착하더라도 서버에서 한 번만 처리하고 동일한 결과를 반환하는 성질입니다. 비용 낭비/중복 생성/지연을 방지합니다.

구현 요약(서버)
- 헤더 추가: X-Idempotency-Key를 수신하면 KV에 idemp:{uid}:{key}로 30초 inflight 마킹 후, 성공 시 120초간 결과(JSON) 저장 → 중복 도착 시 409(inflight) 또는 200(cached result)로 즉시 응답. 응답 헤더 X-Idempotency-Status=hit|inflight|stored.
- 캐나리 비율: env CANARY_PERCENT=0..100. uid+날짜 기반 해시로 0~99 버킷에 매핑하여 providerCaching.enable을 샘플링 적용. 응답 헤더 X-Canary=hit(pct%)|miss(pct%).
- CORS 노출: Access-Control-Expose-Headers에 X-Idempotency-Status, X-Canary 추가.
- 코드 경로: worker.js(handleChat, baseCORSHeaders, inCanary).

구현 요약(클라이언트 iOS)
- 멱등성 키: mode + PersonaCoreSignature + SHA256(content)에서 64자 prefix로 생성하여 X-Idempotency-Key로 전송.
- 동시 중복 방지: UnifiedAIServiceImpl 내부 isSending 플래그와 inflightKeys Set으로 중복 호출 차단.
- 로깅: AICallSummary에 canary/idempotency 헤더를 포함 출력.

운영/설정
- wrangler.toml / 대시보드 Variables
  - CANARY_PERCENT: "5"부터 시작해 10→50→100으로 단계 적용 권장.
- 시크릿/키/KV
  - USAGE_KV 이미 사용 중(레이틀리밋/캐시). 동일 네임스페이스 사용.

검증 체크리스트
- X-Idempotency-Key 동일 값으로 2회 연속 호출
  - 1회차: 200 + X-Idempotency-Status=stored
  - 2회차(즉시): 200 + X-Idempotency-Status=hit, 본문 provider/content 동일
- 캐나리
  - CANARY_PERCENT=5 설정 시 /v1/chat 응답 헤더 X-Canary=hit(5%) 또는 miss(5%) 분포 관측
  - hit인 요청에서만 X-Cache-Provider/Action이 활성화되고 miss에서는 bypass 동작(정책 그대로)

장애 대응
- 캐나리: 문제가 보이면 CANARY_PERCENT를 즉시 0으로 내려 신규 기능을 비활성화(롤백). 기존 요청에는 영향 없음.
- 멱등성: inflight TTL(30s) 내 반복 요청이 계속 inflight이면 클라이언트 중복 전송을 의심 → 앱 로그에서 isSending/inflightKeys 경고 확인.

프로덕션 상태(요약)
- 프록시: Vertex OAuth(aiplatform) 경로 기본, GL API(Key)는 폴백. 캐시 적합성 자동 판단, 타임아웃/폴백, X-Cache-* 헤더 안정 동작.
- 신규: 멱등성(서버/클라이언트) 활성, 캐나리=100%로 캐시 전면 적용.

---

# 2025-09-02 배포/운영 동기화: 프록시 & 모델별 캐싱

현재 상태(프로덕션)
- 워커: emozleep (Cloudflare Workers)
- URL: https://emozleep-production.vinny4920-081.workers.dev
- Version ID: c6b8424e-13e5-4c42-a52f-de033faf3bf3

핵심 기능(변경점 포함)
- /v1/chat: providerCaching 스키마 수용 및 공급자별 캐시 적용
- 응답 헤더: X-Cache-Provider/Action/TTL/Tokens + X-Fallback-Chain + X-Last-Error
- 무효화: X-Context-Invalidation 헤더 1회성 처리

공급자 정책(정정)
- Gemini: v1beta/cachedContents(create) + PATCH cachedContents/{name}?updateMask=ttl, 인증은 x-goog-api-key 헤더. TTL 3600s, 읽기 시 연장. 토큰 계산은 `:countTokens` 경로 사용.
- Anthropic: cache_control.ephemeral 3600s(운영 30분 정책), 30분 경과 write.
- OpenAI: 프리픽스 관측만(bypass).
- Naver: 캐싱 불가 → bypass.

iOS 연동(변경점)
- UnifiedAIServiceImpl: providerCaching.cacheKey=PersonaCoreSignature 전송(안정 키).
- assembledPrompt 경로에서도 최근 16턴 원본 포함.
- X-Cache-* 파싱/로깅 및 Server-Timing 파싱 유지.

운영 팁
- 로그: wrangler tail emozleep --format pretty --env production
- 재배포: wrangler deploy --env production
- 검증 체크리스트
  - 1회차 bypass → 2회차 read, X-Cache-TTL≈3600, tokens.cachedContentTokenCount 증가
  - PATCH 200(or 204) 응답 확인
  - X-Fallback-Chain과 X-Last-Error로 실패 사유 추적

추가 과제
- /v1/metrics: providers.gemini.{writes,reads,hitRate,savings} 집계(미구현)
- NAVER 키 단일화 문서/코드 정합성 재검증

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
      "maxTokens"?: number,
      "topP"?: number,
      "frequencyPenalty"?: number,
      "presencePenalty"?: number,
      "responseFormat"?: "json" | "text" | "markdown"
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
  - gemini → openai → naver → claude → openrouter
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
  - X-Cache-Policy-Min(공급자 바닥), X-Cache-Client-Override(클라이언트 하향 요청값)
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
  - 시스템 프롬프트 단일 소스(SSOT): makeSystemPrompt(for:model:) 공개 래퍼로 통일
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
- 폴백 체인: gemini → openai → naver → claude → openrouter (서버 구현과 문서 일치)
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

### 신규: 할 일 조언 정책(티어/일일/지문) — 클라이언트/서버 동기화

- 목적: Free/Premium 티어에 따라 “할 일 개별 조언” 일일 횟수와 “항목별 1회/일”을 서버에서 보조 집행합니다. “오늘 전체 조언”은 일일 1회로 서버에서 병행 집행합니다.
- 요청 계약(추가):
  - 헤더 `X-Emozleep-Mode`: iOS 클라이언트가 전송하는 AI 모드(raw), 예) `task_advice`, `task_advice_overall`.
  - 바디 `policy` 오브젝트(선택):
    - 개별 조언(`task_advice`): `{ "feature": "task_advice", "fingerprint": "<32hex>" }`
    - 전체 조언(`task_advice_overall`): `{ "keyedFeature": "todo_overall_advice" }` (클라이언트는 생략 가능; 서버는 모드 기반으로 처리)
- 서버 집행(Cloudflare Worker):
  - 일일 카운터 키: `task_advice:<uid>:YYYY-MM-DD`, `todo_overall_advice:<uid>:YYYY-MM-DD` (KST 기준)
  - 개별 지문 키: `fp:todo_individual_advice:<uid>:YYYY-MM-DD:<fingerprint>`
  - 한도(ENV, 기본값):
    - `TODO_ADVICE_LIMIT_FREE=3`, `TODO_ADVICE_LIMIT_PREMIUM=7`, `TODO_OVERALL_ADVICE_LIMIT=1`
  - 응답 헤더:
    - 공통: `X-Policy-ResetAt`(KST 자정), `X-Policy-Tier`
    - 개별: `X-Policy-TaskAdvice-Remaining`(남은 횟수)
  - 초과 시: `429 usage_exceeded`(일일), `409 fingerprint_reused`(지문 재사용) 반환
- 모델 정책: 감정일기 분석(emotion_diary_analysis)은 iOS에서 model=gemini로 고정 전송하며, 서버는 해당 선호를 우선 적용합니다.
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
- 2025-09-02: Gemini cachedContents(create, patch) 적용, 진단 헤더(X-Fallback-Chain, X-Last-Error) 추가, Version ID 업데이트
- 2025-09-03: 캐나리 배포 및 멱등성(idempotency) 도입, 관련 헤더 및 환경 변수 추가, 검증 체크리스트 업데이트

## 18) 모델별 캐싱 시스템 설계/구현(비용 최적화) — 2025-09-01

### 18.1 캐시 적합성 자동판단 — 2025-09-03

요약
- Gemini explicit cache는 공급자 최소 토큰 바닥(1024)을 만족해야 합니다. 임계 미만에서 create를 호출하면 400(too small/create_400)로 실패합니다.
- 서버는 캐시 생성 전에 countTokens로 토큰 수를 계산하고, 임계 미달이면 캐시 생성을 우회(bypass)합니다. 이때 헤더로 사유를 표준화해 전파합니다.
- Anthropic(Claude)는 ephemeral 캐시의 운영 쿨다운(30분) 외에 최소 길이(≈1024 토큰 미만)에서는 write를 금지합니다.

임계치/쿨다운 표
- Gemini min_cache_tokens: 1024 (공급자 바닥)
- Claude min_cache_tokens: 512 (근사치), write_cooldown_minutes: 30
- OpenAI/Naver: 공급자 캐시 미지원 → 항상 bypass

결정 트리(간단)
1) providerCaching.enable=false → 공급자 캐시 미사용(bypass)
2) provider=gemini → countTokens(prefix)
   - tokens ≥ 1024 → caches.create → generateContent(cachedContent=name) → TTL 연장 시 PATCH
   - tokens < 1024 → bypass, 헤더 X-Cache-Error=too-small(1024), X-Cache-Policy-Min=1024
3) provider=anthropic → approxTokens(prefix) ≈ ceil(chars/4)
   - approxTokens < 512 → bypass
   - approxTokens ≥ 512 → lastWriteAt+30m 이전 read, 이후 write(ephemeral 1h)
4) provider=openai/naver → bypass

응답 헤더(추가)
- X-Cache-Error: 캐시 우회 사유 코드(예: too-small(4096))
- 기존: X-Cache-Provider/Action/TTL/Tokens, X-Fallback-Chain, X-Last-Error 유지

타임박스/폴백/SLA
- 공급자별 타임아웃: 기본 6초(PROVIDER_TIMEOUT_MS)
- 전체 SLA: 기본 12초(SLA_MS)
- 폴백 깊이: 최대 2단계(총 3회 시도). 체인 예: target→gemini→openai (naver/claude는 두 단계 내에서 가용성/티어에 따라 배치)

메트릭 확장
- /v1/metrics에 errors.gemini.cacheCreateErrors.tooSmall 카운트 노출
- 추후 필요 시 /providers.{gemini,anthropic}.tokens(누계)로 절감액 추정 정밀도 개선 가능(YAGNI에 따라 지연)

검증 체크리스트(업데이트)
- Gemini
  - 프리픽스 토큰 <4096: 200 + X-Cache-Action=bypass, X-Cache-Error=too-small(4096)
  - 프리픽스 토큰 ≥4096: 최초 write 이후 read, PATCH 200/204, usageMetadata.cachedContentTokenCount 증가
- Claude
  - approxTokens <1024: bypass
  - approxTokens ≥1024: 최초 write 후 30분 이전 read, 30분 경과 시 write 재수행
- 폴백/시간
  - tried 체인 길이 ≤3, 각 시도 6초 내 타임아웃, 전체 응답 12초 내
- 메트릭
  - /v1/metrics.errors.gemini.cacheCreateErrors.tooSmall 증가 확인

구성 변수(wrangler.toml)
- [vars]
  - PROVIDER_TIMEOUT_MS = "6000"
  - SLA_MS = "12000"
- [env.production.vars]
  - PROVIDER_TIMEOUT_MS = "6000"
  - SLA_MS = "12000"

변경 요약(코드)
- worker.js
  - fetchWithTimeout 도입, routeToProvider/각 provider 호출 타임아웃 적용
  - Gemini: geminiCountTokens 추가, create 전 임계 판단 → 미달 시 bypass 및 헤더/메트릭 반영, 패딩 재시도 제거
  - Anthropic: approxTokens 기반 min(512) 미만 write 금지 + 30분 쿨다운 엄수
  - 폴백 깊이 제한(3회), X-Cache-Error 헤더 노출
- wrangler.toml
  - PROVIDER_TIMEOUT_MS, SLA_MS 추가(기본 6s/12s)

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
- 추가 선택 필드(클라이언트 전송, 서버 수용 시 반영):
  - temperature, maxTokens, topP, frequencyPenalty, presencePenalty, responseFormat
  - 미수용 서버에서도 무해(no-op). 수용 시 공급자별 파라미터로 매핑(예: OpenAI: top_p/frequency_penalty/presence_penalty, Gemini: response_mime_type 등).

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

## 19) /v1/metrics 확장 — 캐나리·멱등성 지표 (2025-09-03)

응답 스키마(추가)
- canary: { percent, hit, miss }
- idempotency: { hit, inflight, stored }

의미
- canary.percent: 현재 CANARY_PERCENT 설정값(%)
- canary.hit/miss: 요청 기준 샘플링 결과 카운트(24h TTL)
- idempotency.hit: 동일 키 재요청에 대한 캐시 결과 반환 횟수
- idempotency.inflight: 동일 키가 처리 중일 때 재요청 감지 횟수(409)
- idempotency.stored: 최초 처리 완료 후 결과를 저장한 횟수

권장 대시보드 위젯
- 캐나리 히트율: hit / (hit+miss), 임계 5→10→50→100% 단계에서 급변 없는지 확인
- 멱등성 효과: hit / stored 비율(중복 재시도 억제율), inflight 추이(클라이언트 중복 전송 경고 지표)

롤아웃 가이드(UX/비용/유지보수 최적화)
- 초기값: CANARY_PERCENT=5 → 24~48시간 안정성 관찰
- 증분: 10% → 50% → 100%, 각 단계 최소 24시간 간격으로 지표 확인
- 중단 기준: 5xx/타임아웃/폴백 급증, idempotency.inflight 급증 시 원인 파악 후 유지/롤백
- 운영 팁: 캐나리 hit 구간에서만 X-Cache-Action(read/write) 비율이 상승하는지 확인해 비용 절감 기대치 검증

## 2025-09-03 핫픽스: 멱등 키 형식 통일 · generation 파라미터 매핑 · 캐나리 초기값

- 멱등성 키 형식(클라이언트→서버)
  - 형식: 64자 소문자 hex(서버 정규식 호환). 내부 구성: SHA256(mode + personaCore + SHA256(content))의 hex.
  - 효과: X-Idempotency-Key 헤더가 항상 서버에서 유효 처리되어 hit/inflight/stored 동작이 활성화.

- generation 파라미터 매핑(서버)
  - OpenAI: topP→top_p, frequencyPenalty→frequency_penalty, presencePenalty→presence_penalty, responseFormat=json→response_format: {type:"json_object"}.
  - Gemini: topP 지원, responseFormat=json→responseMimeType: application/json.
  - Anthropic: topP 지원, responseFormat=json→response_format: {type:"json"}.
  - 주: frequency/presence는 Gemini/Anthropic 공용 매핑이 없어 무시.

- 캐나리 초기값
  - CANARY_PERCENT=5 로 설정 후 24–48시간 관찰 → 10% → 50% → 100% 순.

검증 체크리스트(핵심)
- /v1/chat 2회 연속 같은 입력: 1회차 X-Idempotency-Status=stored, 2회차=hit.
- /v1/chat 바디의 topP/frequency/presence/responseFormat 전달 시, 공급자별 매핑이 반영됨(응답/로그 확인).
- /v1/metrics: canary.percent=5, hit/(hit+miss) 비율 유효.

# 2025-09-03 업데이트(2): 엄격 JSON(Structured Output) 강제 및 폴백 재정의

배경
- iOS 특정 모드에서 “정확히 하나의 JSON 객체”를 강제. 프리 경로(OpenRouter)에서는 형식이 깨질 수 있음.
- 기존 프록시는 responseFormat=json만 일부 반영했고, responseSchema/responseMimeType 전달은 미지원.

변경 사항(서버)
- /v1/chat 요청 본문 확장 필드 수용
  - responseFormat: "json" | "text" | "markdown"
  - responseMimeType: 예) "application/json"
  - responseSchema: JSON Schema 객체(크기 제한 20KB)
- 공급자별 매핑 강화
  - OpenAI: response_format = { type: "json_schema", json_schema: { name: "emozleep_schema", schema, strict: true } } 또는 { type: "json_object" }
  - Anthropic: response_format = { type: "json_schema", json_schema: { name: "emozleep_schema", schema, strict: true } } 또는 { type: "json" }
  - Gemini: generationConfig.responseMimeType/responseSchema 전달(스키마/미디어타입 모두 지원)
  - Naver/OpenRouter: 구조화 출력 파라미터 없음(프롬프트 의존)
- 폴백 순서 재정의(엄격 JSON 시)
  - 기본: openrouter → gemini → openai → naver → claude
  - 엄격 JSON(strictJson) 시: gemini → openai → claude → naver → openrouter
  - 환경 변수 STRICT_JSON_SKIP_OPENROUTER=1(기본): 엄격 JSON 모드에서 openrouter 제외
- 헤더 추가
  - X-Strict-JSON: "schema" | "json;mime=<type>" | "json"
- CORS 노출 헤더에 X-Strict-JSON 추가

변경 사항(구성)
- wrangler.toml
  - [vars]에 STRICT_JSON_SKIP_OPENROUTER 추가(기본 "1")
  - [env.production.vars]에 CANARY_PERCENT="5" 및 STRICT_JSON_SKIP_OPENROUTER="1" 설정

요청 계약(예시)
```json
{
  "model": "gemini",
  "mode": "presetRecommendation",
  "messages": [
    {"role":"system","content":"You are a structured JSON generator. Output only a single JSON object."},
    {"role":"user","content":"추천 5개"}
  ],
  "responseFormat": "json",
  "responseMimeType": "application/json",
  "responseSchema": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "properties": {
      "items": {"type":"array","items":{"type":"string"}}
    },
    "required": ["items"]
  }
}
```

검증 체크리스트
- 엄격 JSON 요청 시 응답 헤더에 X-Strict-JSON 존재
- OpenAI/Anthropic 경로에서 json_schema(strict:true) 전달 확인
- Gemini 경로에서 generationConfig.responseMimeType/responseSchema 확인
- 폴백 체인: X-Fallback-Chain에 gemini>openai(>claude) 우선 적용 확인

주의/제한
- responseSchema가 20KB를 초과하면 무시됩니다(서버가 방어적으로 드롭)
- OpenRouter/Naver는 스키마 강제가 없어 프롬프트만으로는 100% 보장 불가 → STRICT_JSON_SKIP_OPENROUTER=1 권장
