# 🔧 DeepSleep 앱 TODO & Stub 정리 우선순위 목록

## 📊 현재 상태 요약
- **총 TODO 항목**: 30개
- **Stub 파일**: 1개 (CompilerFixStubs.swift)
- **임시 구현**: 15개
- **우선순위**: 🔴 높음 / 🟡 중간 / 🟢 낮음

## 🔍 **발견된 주요 TODO 항목들**

### ChatViewController.swift (8개 TODO)
```
- TODO: 실제 AI 티칭 뷰 구현
- TODO: 실제 규칙 생성 로직 구현  
- TODO: 실제 티칭 저장 로직 구현
- TODO: AITask에 .analyzeEmotionPattern(data: String) 케이스 추가
- TODO: AITask에 .recommendSoundFromHistory(prompt: String) 케이스 추가
- TODO: Implement actual toast view
- TODO: ComprehensiveRecommendationEngine의 recommendSound 메서드 사용
```

### ComprehensiveUserAnalysisEngine.swift (6개 TODO)
```
- TODO: EmotionalTrend 타입 변환 필요
- TODO: diary의 실제 감정 필드 사용 (현재 "중립" 하드코딩)
- TODO: diary의 실제 content 필드 사용
```

### SoundManager.swift (2개 TODO)
```
- TODO: LLM의 텍스트 응답을 SoundPreset 객체로 파싱하는 로직 구현 필요
- TODO: 로컬 추천 로직 구현. 현재는 nil 반환.
```

### BatteryOptimizationManager.swift (4개 TODO)
```
- TODO: SoundManager.shared.setQualityLevel(.high)
- TODO: SoundManager.shared.setQualityLevel(.medium) 
- TODO: SoundManager.shared.setQualityLevel(.low)
```

---

## 🔴 **높은 우선순위 (즉시 수정 필요)**

### 1. **CompilerFixStubs.swift 전체 정리** 
- **파일**: `DeepSleepApp/CompilerFixStubs.swift`
- **문제**: 670라인의 임시 구현들이 프로덕션 코드에 포함됨
- **영향도**: 전체 앱 안정성에 영향
- **작업량**: 대 (3-5일)

### 2. **ChatViewController AI 기능 구현**
- **파일**: `DeepSleepApp/ChatViewController.swift`
- **TODO 항목들**:
  - 실제 AI 티칭 뷰 구현
  - 실제 규칙 생성 로직 구현  
  - 실제 티칭 저장 로직 구현
  - AITask에 .analyzeEmotionPattern 케이스 추가
  - AITask에 .recommendSoundFromHistory 케이스 추가
- **영향도**: 핵심 AI 기능
- **작업량**: 대 (4-6일)

### 3. **ComprehensiveUserAnalysisEngine 데이터 연동**
- **파일**: `DeepSleepApp/ComprehensiveUserAnalysisEngine.swift`
- **TODO 항목들**:
  - EmotionalTrend 타입 변환 구현
  - diary의 실제 감정 필드 사용 (현재 하드코딩 "중립")
  - diary의 실제 content 필드 사용
- **영향도**: 감정 분석 정확도
- **작업량**: 중 (2-3일)

---

## 🟡 **중간 우선순위 (단계적 개선)**

### 4. **SoundManager 추천 로직 완성**
- **파일**: `DeepSleepApp/SoundManager.swift`
- **TODO 항목들**:
  - LLM 텍스트 응답을 SoundPreset 객체로 파싱하는 로직
  - 로컬 추천 로직 구현 (현재 nil 반환)
- **영향도**: 사운드 추천 기능
- **작업량**: 중 (2-3일)

### 5. **BatteryOptimizationManager 실제 구현**
- **파일**: `DeepSleepApp/BatteryOptimizationManager.swift`
- **TODO 항목들**:
  - SoundManager.shared.setQualityLevel 연동
  - 실제 배터리 최적화 로직
- **영향도**: 배터리 성능
- **작업량**: 소 (1-2일)

### 6. **FeedbackCollectionViewController 완성**
- **파일**: `DeepSleepApp/FeedbackCollectionViewController.swift`
- **TODO**: SoundManager에서 현재 조합 가져오기
- **영향도**: 사용자 피드백 수집
- **작업량**: 소 (1일)

---

## 🟢 **낮은 우선순위 (추후 개선)**

### 7. **ViewController 온디바이스 학습**
- **파일**: `DeepSleepApp/ViewController.swift`
- **TODO**: 온디바이스 학습 기능 구현
- **영향도**: 고급 기능
- **작업량**: 대 (5-7일)

### 8. **AutomaticLearningModels 훈련 로직**
- **파일**: `DeepSleepApp/AutomaticLearningModels.swift`
- **TODO**: 고급 학습 시스템을 위한 훈련 로직 구현
- **영향도**: 고급 기능
- **작업량**: 대 (4-6일)

### 9. **MemoryOptimizationManager 캐시 정리**
- **파일**: `DeepSleepApp/MemoryOptimizationManager.swift`
- **TODO**: 캐시 항목 나이 기반 정리 구현
- **영향도**: 성능 최적화
- **작업량**: 소 (1일)

### 10. **UserRulesManager 피드백 연동**
- **파일**: `DeepSleepApp/Managers/UserRulesManager.swift`
- **TODO**: FeedbackManager와 연동하여 업로드 큐 구현
- **영향도**: 사용자 규칙 관리
- **작업량**: 소 (1일)

---

## 📁 **Stub 파일들**

### 주요 Stub 구현들:
1. **SectionHeaderView** ✅ (이미 수정 완료)
2. **PresetManager.getPreset()** - 실제 프리셋 로드 로직 필요
3. **LLMService** - 실제 LLM 서비스 연동 필요
4. **EnhancedAIRecommendationService** - AI 추천 서비스 구현 필요

---

## 🎯 **권장 작업 순서**

### Phase 1 (1주차): 핵심 기능 안정화
1. CompilerFixStubs.swift 정리 시작
2. ChatViewController AI 기능 기본 구현
3. ComprehensiveUserAnalysisEngine 데이터 연동

### Phase 2 (2주차): 기능 완성
1. SoundManager 추천 로직 완성
2. BatteryOptimizationManager 구현
3. 남은 CompilerFixStubs 정리

### Phase 3 (3주차): 최적화 및 고급 기능
1. 메모리 최적화
2. 피드백 시스템 완성
3. 온디바이스 학습 (선택사항)

---

## 📈 **예상 효과**

- **안정성 향상**: CompilerFixStubs 정리로 크래시 위험 감소
- **기능 완성도**: AI 추천 및 분석 기능 실제 동작
- **사용자 경험**: 실제 데이터 기반 개인화 서비스
- **성능 최적화**: 배터리 및 메모리 효율성 개선

---

## 🚨 **즉시 처리 권장 항목 TOP 5**

1. **🔴 CompilerFixStubs.swift 정리** (3-5일)
   - 670라인의 임시 구현이 프로덕션에 포함됨
   - 앱 전체 안정성에 직접적 영향

2. **🔴 ChatViewController AI 티칭 기능** (2-3일)
   - 핵심 AI 기능이 stub 상태
   - 사용자 경험에 직접적 영향

3. **🔴 ComprehensiveUserAnalysisEngine 데이터 연동** (2일)
   - 감정 분석이 하드코딩된 "중립"만 반환
   - 개인화 기능 무력화

4. **🟡 SoundManager 추천 로직** (2일)
   - 사운드 추천이 nil만 반환
   - 핵심 기능 미완성

5. **🟡 BatteryOptimizationManager 구현** (1일)
   - 배터리 최적화 기능 미작동
   - 성능 이슈 가능성

## 📋 **완료 체크리스트**

### Phase 1: 핵심 안정화 (1주)
- [ ] CompilerFixStubs.swift에서 실제 구현으로 이동
  - [ ] PresetManager 실제 구현
  - [ ] LLMService 실제 구현  
  - [ ] EnhancedAIRecommendationService 실제 구현
- [ ] ChatViewController AI 기능 기본 구현
  - [ ] AITask enum에 필요한 케이스 추가
  - [ ] AI 티칭 뷰 기본 구현
  - [ ] 규칙 생성/저장 로직 구현
- [ ] ComprehensiveUserAnalysisEngine 데이터 연동
  - [ ] EmotionDiary 모델에서 실제 감정 필드 사용
  - [ ] 하드코딩된 "중립" 제거

### Phase 2: 기능 완성 (1주)  
- [ ] SoundManager 추천 로직 완성
  - [ ] LLM 응답 파싱 로직 구현
  - [ ] 로컬 추천 알고리즘 구현
- [ ] BatteryOptimizationManager 실제 연동
- [ ] FeedbackCollectionViewController 완성

### Phase 3: 최적화 (1주)
- [ ] MemoryOptimizationManager 캐시 정리 로직
- [ ] UserRulesManager 피드백 연동
- [ ] 온디바이스 학습 기능 (선택사항)

---

*마지막 업데이트: 2025년 7월 6일*
*총 발견된 TODO: 30개, Stub 구현: 15개*