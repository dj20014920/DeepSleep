# DeepSleep Comprehensive Guide

### 🆕 2025-09-24 업데이트: 캐시/세션 풀/운영 키/모니터링

#### 🆕 온디바이스 입력 포맷/STOP/샘플링 동기화
- 입력 포맷(템플릿만 사용, 마크다운 헤더 금지)
  - Gemma 3:
    - user 턴: `<start_of_turn>user\n{content}<end_of_turn>\n<start_of_turn>model\n`
    - assistant 턴: `<start_of_turn>model\n{content}<end_of_turn>\n`
  - Qwen2.5:
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