# DeepSleep AI Proxy Roadmap (Q3–Q4 2025)

Principles: KISS, DRY, YAGNI, SOLID. No duplicated logic across client/server. No whack-a-mole fixes. No stub-only quick hacks.

## Completed
- Proxy-first architecture enabled (USE_PROXY=YES)
- Cloudflare Worker SSE + policy headers (X-Policy-*)
- KV TTL min(60s) safety for rate-limit and daily counters
- iOS client parses policy headers and disables local Claude daily cap when proxy is on (SSOT)
- wrangler.toml: account_id set
- Deployment helper script: scripts/cf_deploy.sh
- EmoZleep Worker README updated for token-based deployment

## Pending (requires secrets/token in your shell)
1) Set KV IDs in wrangler.toml
   - wrangler kv:namespace list
   - Set USAGE_KV_ID and run scripts/cf_deploy.sh (will patch wrangler.toml)
2) Put production secrets via wrangler:
   - GEMINI_API_KEY, OPENAI_API_KEY, CLAUDE_API_KEY, OPENROUTER_API_KEY
   - NAVER_API_KEY/NAVER_API_SECRET (optional)
   - EDGE_SIGNING_SECRET
3) Deploy to production and smoke-test endpoints

## Short-term
- Add wrangler tail-based log collection recipe
- Add automated canary check Github Action (OPTIONS/POST negative auth)
- Document iOS enroll/nonce/signature flows in a short ADR

## Mid-term
- Provider error taxonomy → normalized error codes for client UX
- Tiered routing table in KV (editable without code deploy)
- Optional Durable Object for strict atomic counters (if KV drift matters)

## Long-term
- Regional routing (US/EU) Workers for data residency
- Fine-grained per-mode cost budgets (KV-backed)
- Provider health scoring and adaptive routing

