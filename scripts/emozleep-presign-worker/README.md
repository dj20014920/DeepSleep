# emozleep-presign Cloudflare Worker

Minimal presign endpoint for DeepSleep app on-device model downloads.

## Requirements
- Node 18+
- Cloudflare Wrangler CLI

## Quick Start
```bash
cd scripts/emozleep-presign-worker
npm init -y && npm i -D wrangler typescript @cloudflare/workers-types
npx wrangler login
npx wrangler publish
```

The worker exposes:
- GET /presign?file=<filename.gguf>
- Optional query: mode=redirect (to return 302 to CDN URL)
- Env vars: CDN_BASE (defaults to https://cdn.emozleep.space/models), PRESIGN_TOKEN (optional)

## Deploy notes
- Set account_id in wrangler.toml or rely on `wrangler login` selection
- Set bindings in Cloudflare dashboard if needed
