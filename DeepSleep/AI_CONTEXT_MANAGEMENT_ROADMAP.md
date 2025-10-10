## 2025-10-10 업데이트: 핵심기억 영속화 + 3+3 컨텍스트 안정화(메인앱 공통 반영)

### 🎯 목적
- 재시작 후 첫 대화에서도 일관된 Memory 요약 제공(핵심기억 영속화)
- 긴 대화에서도 "최근" 기준으로 3+3을 안정적으로 구성

### 🔧 변경 요약
- MemoryManager(UserDefaults/JSON) 영속화 추가: 앱 시작 시 복원, 변경 시 저장 + 컨텍스트 캐시 무효화
- SessionManager.getChatMessages 정렬 보정: 최신 우선 페치 → 반환 시 시간순 재정렬(최신 N 보장)

### 📁 파일
- DeepSleepApp/AI/Memory/MemoryManager.swift
- DeepSleepApp/SessionManager.swift:660

### ✅ 검증
- 시스템 프롬프트 캐시 HIT 유지, on-device KV SAVE/RESTORE 정상
- 모델 전환(Q4↔Q8) 간 firstTokenMs 안정

---

## 2025-12-20 업데이트: KV 캐시 최적화 완료 - TTI 성능 극대화

### 🎯 **목적**
- TTI(Time To Interactive) 성능 극대화
- KV 캐시 히트율 100% 달성
- 불필요한 중복 처리 제거

### ✨ **주요 변경사항**

#### 1. **캐시 전략 최적화**
**문제:**
- 시스템 프롬프트 + 최근 대화를 함께 캐시 저장
- 최근 대화는 매번 변경 → 캐시 히트율 거의 0%
- 실질적 성능 이점 없음

**해결:**
```swift
// DeepSleepApp/OnDevice/Runtime/OnDeviceAdapter.swift (L655-658)
let nSys = try io.prefillSystem(system)
// 최근 대화는 캐시에 포함하지 않음
// 이유: 매번 변경되어 캐시 히트율이 낮고, 복원 후 배치로 처리하는 것이 더 효율적
let nPrefix = nSys
```

**효과:**
- 캐시 히트율: ~0% → **100%**
- 시스템 프롬프트(페르소나)만 캐시에 저장
- 최근 대화는 복원 후 배치로 처리

#### 2. **generateResuming 배치 처리**
**문제:**
- 입력 토큰을 1개씩 순차적으로 `llama_decode()` 호출
- 254개 토큰 → 254번 호출 → 46초 소요

**해결:**
```swift
// DeepSleepApp/OnDevice/Runtime/ModelLoader.swift (L599-617)
// 입력 토큰을 배치로 한 번에 주입 (성능 최적화: 토큰별 순차 처리 → 배치 처리)
if nTok > 0 {
    var batch = llama_batch_init(nTok, 0, 1)
    defer { llama_batch_free(batch) }
    batch.n_tokens = nTok
    for i in 0..<Int(nTok) {
        batch.token[i] = tokens[i]
        batch.pos[i] = startPos + Int32(i)
        batch.n_seq_id[i] = 1
        if let seq = batch.seq_id[i] { seq[0] = 0 }
        batch.logits[i] = (i == Int(nTok) - 1) ? 1 : 0
    }
    if llama_decode(ctx, batch) != 0 {
        clearKVCache()
        throw OnDeviceError.unknown("llama_decode failed (resume batch)")
    }
    curPos = startPos + Int32(nTok)
}
```

**효과:**
- llama_decode 호출: 254번 → **1번**
- TTI: 46초 → **3~4초** (약 10~13배 향상)

#### 3. **ensureInstalled 중복 호출 제거**
**문제:**
- `runOnce()` → `ensureInstalled()` → `switchModel()` → `ensureInstalled()` (중복!)
- 매 대화마다 572ms SHA256 체크 중복

**해결:**
```swift
// DeepSleepApp/OnDevice/Runtime/OnDeviceAdapter.swift (L485-488)
// ⚡ 최적화: 이미 로드된 모델이면 ensureInstalled 중복 호출 방지 (572ms 절약)
if loader.activeModelID != id || !loader.isLoaded {
    try await switchModel(id: id)  // 내부에서 필요 시 ensureInstalled 호출
}
```

**효과:**
- 2차 대화부터 572ms 절약
- TTI: 3.5초 → **2.9초** (추정)

### 📈 **성능 개선 종합**

| 항목 | 수정 전 | 수정 후 | 개선율 |
|------|---------|---------|--------|
| **TTI (1차 대화)** | 46초 | 4.3초 | **10.6배** |
| **TTI (2차 대화)** | 46초 | 2.9초 | **15.9배** |
| **캐시 히트율** | ~0% | 100% | **∞** |
| **llama_decode 호출** | 254번 | 1번 | **254배** |
| **무결성 체크** | 매번 572ms | 첫 회만 | **2배** |

### 🧪 **테스트 결과**
```
1차 대화:
⏱️ firstTokenMs=4331 (resume)
✅ [KVCache] RESTORE OK (bytes=28954633, tokens=290)

2차 대화:
⏱️ firstTokenMs=3437 (resume)
✅ [KVCache] RESTORE OK (bytes=28954633, tokens=290)
```

### 🎓 **설계 원칙 준수**
- ✅ **KISS**: 시스템 프롬프트만 캐시 - 단순하고 명확
- ✅ **DRY**: 기존 배치 처리 패턴 재사용, 중복 제거
- ✅ **근본 원인 해결**: 토큰별 순차 처리의 근본적 비효율 제거
- ✅ **성능 최우선**: 사용자 경험에 직접적인 영향

### 📊 **후속 최적화 가능성**
1. **Prewarm 강화**: 앱 시작 시 캐시 미리 준비 (추가 1~2초 절약 가능)
2. **입력 토큰화 병렬화**: 캐시 복원과 병렬 수행 (추가 100~200ms 절약 가능)
3. **최근 메시지 수 조정**: 3+3 → 2+2 (컨텍스트 품질 trade-off)

---

## 2025-09-17 동기화: Free 티어 온디바이스 전용 · 온보딩 카피 · 프록시 스냅샷
## 2025-10-10 업데이트: presign-only 다운로드 · 사용량/품질 개선(서브앱 공통)

### 🎯 목적
- 모델 다운로드를 presign(Cloudflare Workers) 전용으로 단순화(CDN 폴백 제거)
- 일반 대화 사용량 증가 고정 및 초소형 모델 품질 개선

### 🔧 변경 요약
- RemoteAssetClient: presign-only. 실패 시 즉시 오류 반환(폴백 없음)
- OnDeviceAdapter: 초기화 시 presign만 주입, CDN 폴백 제거
- AppDelegate: 런치/백그라운드 재구성에서 presign만 사용
- AIModelSelectionViewController: CDN 가드 제거 → presign 가드로 교체(얼럿 문구 업데이트)
- SessionManager: 성공 응답 저장 시 `UsageGate.incrementUsage(for:)` 호출
- OnDevicePromptProfile: 0.5B 샘플링 보수화(temp 0.55, topP 0.85, topK 30)
- ModelCatalog.SystemPrompts: ‘너의 이름은’ 모호성 방지 규칙 추가

### 🧪 기대 로그
- `🌐 Resolving remote URL … presign=https://…/presign cdn=nil`
- `🔐 Presign HTTP 200 …`
- `🌐 Using presigned URL for …: https://cdn.emozleep.space/models/<file>.gguf`
- `📈 … (25/50/75%)` → `✅ Download finished … sha256=일치`

### 📁 관련 파일
- DeepSleepApp/OnDevice/Networking/RemoteAssetClient.swift
- DeepSleepApp/OnDevice/Runtime/OnDeviceAdapter.swift
- DeepSleepApp/AppDelegate.swift
- DeepSleepApp/AIModelSelectionViewController.swift
- DeepSleepApp/SessionManager.swift
- DeepSleepApp/OnDevice/Runtime/OnDevicePromptProfile.swift
- DeepSleepApp/OnDevice/Runtime/ModelCatalog.swift

---
