# 🎯 CompilerFixStubs.swift 정리 작업 계획

> **작성일**: 2025년 7월 6일
> **목표**: 596줄의 CompilerFixStubs.swift를 체계적으로 정리하여 프로덕션 코드로 전환
> **기준**: DeepSleep_AI_Development_Guide.md v10.0 - '진정한 감성 지능' 구현

---

## 📊 현재 상태 분석

### 파일 정보
- **총 라인 수**: 596줄
- **역할**: 컴파일 오류 해결을 위한 임시 스텁 모음
- **영향도**: 앱 전체 안정성에 직접적 영향

### 주요 스텁 카테고리
1. **설정 모델**: UserSettings, UsageStats
2. **컨텍스트 모델**: SoundRecommendationContext, FeedbackContext, SessionFeedback
3. **분석 모델**: UserProfileVector, HarmonyWeights
4. **UI 컴포넌트**: PresetRecommendationResponse
5. **유틸리티 함수**: 감정 관련 텍스트 생성 함수들

---

## 🎯 작업 목표 및 원칙

### 핵심 원칙
1. **기능 손실 방지**: 모든 UI/UX 기능은 그대로 유지
2. **점진적 마이그레이션**: 한 번에 하나씩 안전하게 이동
3. **빌드 안정성 유지**: 각 단계마다 빌드 성공 확인
4. **성능 최적화**: 메모리 누수, 배터리 효율 고려

### 최종 목표
- CompilerFixStubs.swift 파일 완전 제거
- 모든 스텁을 적절한 위치의 실제 구현으로 전환
- Clean Architecture 원칙 준수

---

## 📋 상세 작업 계획

### Phase 1: 설정 및 통계 모델 정리 (Day 1)

#### 1.1 UserSettings 마이그레이션
- **현재**: CompilerFixStubs.swift (13-26줄)
- **목표 위치**: `Models/Settings/UserSettings.swift`
- **작업 내용**:
  - UserDefaults 래퍼 추가
  - 설정 변경 Notification 시스템 구현
  - 기본값 관리 로직 추가

#### 1.2 UsageStats 마이그레이션
- **현재**: CompilerFixStubs.swift (28-43줄)
- **목표 위치**: `Models/Analytics/UsageStats.swift`
- **작업 내용**:
  - Core Data 엔티티로 전환
  - 일별/주별/월별 통계 집계 로직 추가
  - 프라이버시 고려한 데이터 수집 정책 구현

### Phase 2: 컨텍스트 모델 정리 (Day 2)

#### 2.1 SoundRecommendationContext
- **현재**: CompilerFixStubs.swift (48-60줄)
- **목표 위치**: `Models/AI/SoundRecommendationContext.swift`
- **작업 내용**:
  - 시스템 상태 자동 감지 통합
  - 컨텍스트 직렬화/역직렬화 개선
  - AI 모델 입력용 특징 벡터 변환 메서드 추가

#### 2.2 FeedbackContext & SessionFeedback
- **현재**: CompilerFixStubs.swift (62-90줄)
- **목표 위치**: `Models/Feedback/` 폴더
- **작업 내용**:
  - 피드백 큐잉 시스템 구현
  - 오프라인 동기화 지원
  - 피드백 분석 대시보드용 집계 로직

### Phase 3: AI 분석 모델 정리 (Day 3)

#### 3.1 UserProfileVector
- **현재**: CompilerFixStubs.swift (94-193줄)
- **목표 위치**: `Models/AI/UserProfileVector.swift`
- **작업 내용**:
  - 벡터 정규화 로직 개선
  - 유사도 계산 메서드 추가
  - 벡터 DB 저장용 직렬화 구현

#### 3.2 HarmonyWeights & Models
- **현재**: CompilerFixStubs.swift (195-200줄)
- **목표 위치**: 적절한 위치 검토 후 통합 또는 제거

### Phase 4: UI 및 유틸리티 정리 (Day 4)

#### 4.1 PresetRecommendationResponse
- **현재**: CompilerFixStubs.swift (583-596줄)
- **목표 위치**: `Models/Response/PresetRecommendationResponse.swift`
- **작업 내용**:
  - ChatViewController와의 연동 최적화
  - 응답 캐싱 로직 추가

#### 4.2 감정 관련 유틸리티 함수들
- **현재**: 여러 유틸리티 함수들
- **목표 위치**: `Utils/EmotionTextGenerator.swift`
- **작업 내용**:
  - 다국어 지원 추가
  - 감정별 텍스트 커스터마이징 시스템

### Phase 5: 최종 검증 및 정리 (Day 5)

#### 5.1 종속성 검증
- 모든 참조하는 파일들의 import 문 업데이트
- 빌드 및 런타임 테스트

#### 5.2 CompilerFixStubs.swift 제거
- 파일 삭제
- Xcode 프로젝트에서 참조 제거
- 최종 빌드 검증

---

## ⚠️ 주의사항

### 검증 체크리스트
- [ ] 각 마이그레이션 후 빌드 성공 확인
- [ ] 기존 기능 동작 테스트
- [ ] 메모리 프로파일링 (Instruments)
- [ ] 배터리 효율성 테스트

### 위험 요소
1. **순환 참조**: 모델 간 의존성 주의
2. **타입 호환성**: Core 모듈과의 타입 일치 확인
3. **성능 저하**: 새 구현이 기존보다 느려지지 않도록 주의

---

## 📈 예상 효과

1. **코드 품질 향상**
   - Clean Architecture 준수
   - 유지보수성 대폭 개선

2. **앱 안정성 강화**
   - 임시 코드 제거로 잠재적 버그 감소
   - 타입 안정성 향상

3. **개발 효율성 증대**
   - 명확한 코드 구조
   - 새 기능 추가 용이

---

## 🚀 다음 단계

CompilerFixStubs.swift 정리 완료 후:
1. Vector DB 통합 (장기 기억 기능)
2. LLM 성능 모니터링 시스템 구축
3. 4대 AI 모델 API 연동 완성

---

*이 계획은 DeepSleep의 '진정한 감성 지능' 구현이라는 최종 목표를 달성하기 위한 필수 단계입니다.*
