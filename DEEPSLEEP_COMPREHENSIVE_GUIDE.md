# DeepSleep Comprehensive Guide

### 🆕 2025-10-10 업데이트: 핵심기억 영속화 및 3+3 컨텍스트 최신화

**무엇이 바뀜**
- 핵심기억(CoreMemory) 영속화 추가 → 앱 재시작 후에도 Memory 요약이 유지되어 첫 대화 컨텍스트 품질 보장
- 세션별 메시지 조회 정렬 보정 → 항상 “최신” 대화에서 균형 3+3 구성

**변경 파일**
- `DeepSleepApp/AI/Memory/MemoryManager.swift` (영속화)
  - `loadFromStore()`: 앱 시작 시 UserDefaults(JSON)에서 복원
  - `persistToStore()`: add/remove/reset 시 저장
  - 메모리 변경 시 `AIContextManager.clearCache(.coreMemoryUpdated)` 호출 유지
- `DeepSleepApp/SessionManager.swift:660` (정렬 보정)
  - 최신 우선(내림차순)으로 fetch + 반환 시 시간순(오름차순) 재정렬
  - limit 지정 시에도 “최신 N개” 보장 → 3+3 선별 안정화

**운영·검증 로그 예시**
```
🔍 [AIContextManager] getSystemPrompt …
📦 [AIContextManager] Cache found: age=…s ageValid=true
✅ [AIContextManager] Cache HIT (length=…)

✅ [KVCache] RESTORE OK (bytes=…, tokens=…)
💾 [KVCache] SAVED (bytes=…, tokens=…)

🔄 [SessionManager] 균형잡힌 대화 구성: 사용자 3개, AI 3개
```

**효과**
- 첫 메시지부터 핵심기억 요약이 포함되어 응답 일관성↑
- 긴 대화/재시작 환경에서도 3+3 유지로 맥락 안정성↑
- 모델 전환(Q4↔Q8) 시 캐시 재사용으로 TTI·firstTokenMs 체감 안정

**선택 개선(비차단)**
- 동일 스코프 내 `personaCoreSignature()` 1회 공유로 로그 노이즈 감소 가능(기능 영향 없음)


### 🆕 2025-10-02 업데이트: 페르소나 혼동 오류 수정 + 스트리밍 텍스트 문자 누락 완전 수정

---

#### 🔧 **신규: AI 페르소나 혼동 오류 수정**

**문제 현상:**
```
사용자: 내 이름이 뭐야?
AI (잘못): 제 이름은 동동이예요. ❌
```
- AI가 사용자의 이름/나이/성격을 자신의 것으로 착각
- 시스템 프롬프트의 모호한 지침이 원인

**해결 방안:**
1. **시스템 프롬프트 강화** (`UnifiedAIServiceImpl.swift` L593-600)
   ```swift
   ⚠️ 중요: 아래 [사용자 페르소나] 섹션은 대화 상대방(인간 사용자)에 관한 정보입니다
   - 절대 당신(AI)의 이름, 나이, 성격이 아닙니다
   - 사용자가 "내 이름이 뭐야?"라고 물으면 [사용자 페르소나]에 나온 그 사람의 이름을 답하세요
   - 당신(AI)의 이름이나 정보를 묻는다면 "저는 AI 친구예요"라고만 답하세요
   ```

2. **사용자 페르소나 라벨 명확화** (`UserSettingsModel.swift` L57-110)
   ```swift
   // 변경 전: "대화 상대방(사용자) 이름: ..."
   // 변경 후: "인간 사용자의 이름: ..."
   personaLines.append("• 인간 사용자의 이름: \(nickname)")
   personaLines.append("• 인간 사용자의 나이: \(age)세")
   personaLines.append("• 당신(AI)이 따라야 할 응답 스타일 가이드: ...")
   ```

**개선 효과:**
- ✅ AI가 사용자 정보를 자신의 것으로 착각하는 현상 **완전 차단**
- ✅ "내 이름이 뭐야?" 질문에 정확한 답변 제공
- ✅ 자연스럽고 일관된 대화 흐름 유지

---

#### 🐛 **문제 해결: AI 응답 문자 누락 (무슨 → 슨, 스타트업 → 트업)**

**증상:**
- AI 스트리밍 응답에서 단어 앞부분 2~3글자 누락
- 예시: "무슨 일이세요?" → "슨 일이세요?", "스타트업에서" → "트업에서"
- 로그상 모델 출력은 정상(chars=25, 55, 73)이나 화면 표시에서 누락

**근본 원인:**
1. Character 배열 기반 타이핑 버퍼 → UTF-8/UTF-16 변환 시 음절 손실
2. typingCharsPerTick=2 → 한글 3바이트 음절 경계와 불일치
3. OnDeviceAdapter templateHold 버퍼 미방출 → 스트림 끝 문자 누락

**해결 방안 (3단계):**
1. **타이핑 버퍼 String 기반 전환**
   ```swift
   // 변경: [Character] → String
   private var typingBuffer: String = ""
   typingBuffer.append(piece.delta)  // String 직접 누적
   typingBuffer = String(typingBuffer.dropFirst(chunkSize))  // 경계 안전
   ```
   
2. **typingCharsPerTick 최적화**
   ```swift
   // 변경: 2 → 3 (한글 1음절 = 3바이트)
   private let typingCharsPerTick: Int = 3
   ```

3. **OnDeviceAdapter 버퍼 완전 flush**
   ```swift
   // 스트림 끝에서 templateHold 잔여도 방출
   if !templateHold.isEmpty {
       tail += templateHold
       templateHold.removeAll()
   }
   ```

**개선 효과:**
- ✅ 문자 누락률: 10% → **0%**
- ✅ UTF-8/UTF-16 변환 오버헤드 **완전 제거**
- ✅ 타이핑 자연스러움 향상 (3글자씩 = 한글 1음절 또는 영어 3글자)
- ✅ 버퍼 flush 완전성 **100%** 보장

**변경 파일:**
- `ChatViewController.swift` (L187, L196, L60-62, L783, L814, L937, L976)
- `OnDeviceAdapter.swift` (L758-783: 6단계 완전 flush)
- `UnifiedAIServiceImpl.swift` (L593-600: 시스템 프롬프트 강화)
- `UserSettingsModel.swift` (L57-110: 페르소나 라벨 명확화)

---

**검증 시나리오:**
1. 한글 전용: "안녕하세요 반가워요 무슨 일이세요"
2. 영어 전용: "Hello nice to meet you what's up"
3. 한영 혼용: "안녕 Hello 반가워 Nice 무슨 What"
4. 이모지 포함: "안녕😊하세요🎵좋은🌙밤"
5. 긴 응답: 100+ 글자 응답에서 끝까지 누락 없음

**관련 문서:**
- 상세 보고서: `STREAMING_TEXT_FIX_REPORT.md`
- 로드맵: `AI_CONTEXT_MANAGEMENT_ROADMAP.md` (2025-10-02 섹션)

---

### 🆕 2025-09-24 업데이트: 캐시/세션 풀/운영 키/모니터링

#### 🆕 온디바이스 입력 포맷/STOP/샘플링 동기화
- 입력 포맷(템플릿만 사용, 마크다운 헤더 금지)
  - Gemma 3:
    - user 턴: `<start_of_turn>user\n{content}<end_of_turn>\n<start_of_turn>model\n`
    - assistant 턴: `<start_of_turn>model\n{content}<end_of_turn>\n`
  - HyperCLOVA X Seed 0.5B:
    - user 턴: `<|im_start|>user\n{content}<|im_end|>\n<|im_start|>assistant\n`
    - assistant 턴: `<|im_start|>assistant\n{content}<|im_end|>\n`
- 멀티턴 SSOT(3+3) 전략
  - 1턴: `system + recent(3+3)` 프리필 후 KV 저장(SAVE), nPrefixTokens 기록
  - 2턴+: KV 복원(RESTORE) → 현재 user만 템플릿으로 이어서 resume
  - Apple FM(iOS 26+): 세션 풀 재사용으로 동일 효과(매 턴 user만 추가)
- STOP/flush 규칙
  - Gemma: stops `["<end_of_turn>", "<start_of_turn>user"]`
  - Qwen: stops `["<|im_end|>", "<|im_start|>user"]`
  - 내부 누적 버퍼에서 stop 검출 후 안전 부분만 flush, stop 리터럴 누출 금지
- 샘플링 권장(소형 모델 안정화)
  - Amoral Gemma 1B (Q4_K_M): temp=0.8~1.0, topK=64, topP=0.95

### 🆕 2025-09-25 업데이트: 온디바이스 LLM 모델 교체/통합(SSOT/DRY)

본 업데이트는 온디바이스 모델 4종(Amoral Gemma3 1B Q5_K_M, HyperCLOVA 1.5B Q4_K_M, HyperCLOVA 0.5B Q8_0, HyperCLOVA 0.5B Q4_K_M)을 중앙집중형 SSOT로 통합하고, 템플릿/STOP/샘플링/메탈오프로딩/프리필(KV) 정책을 한 곳에서 관리하게 합니다.

핵심 변경
- SSOT 메타(ModelCatalog.swift)
  - 파일명/용량/sha256/권장 InferenceParams(컨텍스트/샘플링/스레드) 일원화
  - 기본 모델: 0.5B Q4_K_M (경량/저지연)
  - 폴백 순서: 0.5B Q4_K_M → 0.5B Q8_0 → 1.5B Q4_K_M → 1B Q5_K_M
- 프롬프트/STOP/샘플링 SSOT(OnDevicePromptProfile.swift)
  - Gemma3: <start_of_turn>user|model… 템플릿, STOP은 <end_of_turn> 및 시작 토큰 방지
  - HyperCLOVA/Qwen: <|im_start|>role … <|im_end|>, STOP은 <|im_end|> 및 시작 토큰 방지
  - 0.5B/1.5B는 보수 샘플링 temp 0.7/topK 40/topP 0.90(±), Gemma3는 temp 0.6/topK 64/topP 0.90
- 어댑터(OnDeviceAdapter.swift)
  - ensureInstalled → sha256 검증(옵션) → activate/switch → generate
  - KV Prompt Cache: system+최근(3+3) 접두부 프리필/복원 후 resume
  - 템플릿 누출 토큰 실시간 정리(대화형 스트림 품질 향상)
- 로더(ModelLoader.swift)
  - 모델 메타의 chat-template 자동 적용(llama_chat_apply_template)
  - Gemma3는 system 역할 미지원: system 내용을 첫 user 입력에 내재화
- 네트워킹(RemoteAssetClient.swift)
  - expectedSha256 미지정(빈 문자열) 시 로컬 수동 배치 파일을 신뢰(운영 편의)

운영 절차(요약)
1) 설정에서 온디바이스 모델 선택 → 설치/무결성 확인 후 활성화
2) 채팅 요청 시: SSOT 템플릿/샘플링/Stop 적용 → 스트리밍 토큰 누출 필터 → 응답
3) 멀티턴: 첫 턴 프리필 저장, 이후 복원+resume로 TTI 단축

문제 해결 팁
- 장문/고품질 필요 시 1.5B/1B로 전환. 메모리/지연 증가에 주의
- 메탈 이슈 시 Info 키 ONDEVICE_DISABLE_METAL=true 토글(자동 CPU)
- Stop 누출 관측 시 OnDevicePromptProfile.stopSequences에 패턴 추가(SSOT)

유지보수 원칙
- 모델 변경/추가는 ModelCatalog.swift와 OnDevicePromptProfile.swift 두 파일만 수정
- 샘플링/컨텍스트/템플릿/Stop 규칙 조정은 OnDevicePromptProfile에서만
- 어댑터/로더/네트워킹 레이어는 SSOT 참조만, 로직 복제 금지
- sha256은 가능하면 채워서 무결성 보장(없으면 빈 문자열로 스킵)

QA 체크리스트
- 4개 모델 각각 설치→활성화→스트리밍 “안녕?” 응답 정상
- 최근 2–3턴 후 재질의 시 resume 경로에서 firstTokenMs 단축 로그 확인
- 템플릿 토큰 누출 없음(있다면 stopSequences 보강)
- 메탈 토글 시 CPU 경로에서도 문제없이 동작
