# AI Todo 고도화 작업 계획 (AITODO_ENHANCEMENT_PLAN)

> **기준 문서**: `DeepSleep_AI_Development_Guide.md` (v9.2)
> **최종 목표**: '기능 기반 라우팅' 및 '장기 기억'을 핵심으로 하는 AI 시스템 구축 완료
> **상태**: 🔧 Phase 1 진행 중 (핵심 아키텍처 안정화 70% 완료)

---

## 📌 Phase 1: 🔥 코어 아키텍처 전환 (1-2주) - **70% 완료**
**목표**: '기능 기반' 아키텍처의 기반 마련

- [x] **Core 모듈 타입 중복 해결**: SubscriptionTier, LLMResponse 등 중복 정의 문제 해결 완료
- [x] **기본 구조 안정화**: 주요 UI 컨트롤러들의 컴파일 오류 해결 및 기본 구조 정리
- [x] **PresetManager 기능 구현**: 누락된 getPreset() 메서드 구현 완료
- [x] **import 구조 정리**: Core 모듈과 메인 앱 간의 의존성 정리 완료
- [ ] **LLMRouter 로직 수정**: 사용자 등급 분기 로직을 **요청 의도 분석 및 모델 조합** 로직으로 변경
- [ ] **4대 핵심 모델 API 연동**:
    - [ ] Claude 3.5 Haiku 연동
    - [ ] GPT-4o mini 연동
    - [ ] Gemini 2.0 Flash-Lite 연동
    - [ ] HyperCLOVA X (HCX-DASH-002) 연동
- [ ] **API 키 관리 강화**: Keychain을 활용하여 모든 API 키를 안전하게 저장 및 관리
- [x] **빌드 경고 해결 (부분 완료)**:
    - [x] Core 모듈 관련 주요 컴파일 오류 해결
    - [ ] `EmotionAnalysisChatViewController.swift`의 남은 구조적 문제 완전 해결
- [ ] **삭제된 기능 재구현 (1차)**:
    - [ ] AI 기반 투두 추천 (`AddEditTodoViewController`) 재설계 및 구현

## Phase 1: LLMRouter 로직 수정 및 4대 핵심 모델 API 연동

### 1. LLMRouter 개선

#### 1.1 벡터 DB 연동
- Pinecone 벡터 DB 통합
- 메모리 인덱싱 및 검색 로직 구현
- 구독 레벨에 따른 메모리 접근 제어

#### 1.2 서비스 선택 로직 고도화
- 컨텍스트 기반 동적 라우팅
- 부하 분산 및 장애 복구
- 비용 최적화 로직

#### 1.3 에러 처리 강화
- 상세한 에러 타입 정의
- 재시도 메커니즘 구현
- 폴백 전략 수립

#### 1.4 성능 모니터링
- 응답 시간 추적
- 토큰 사용량 모니터링
- 에러율 추적
- 비용 분석

### 2. 4대 핵심 모델 API 연동

#### 2.1 Claude 3.5 Haiku (The Core Empath)
- 감성 대화 최적화
- 일기 분석 기능 강화
- 컨텍스트 이해도 향상

#### 2.2 GPT-4o mini (The Intelligent Orchestrator)
- 복잡한 지시 처리
- 다단계 추론 구현
- 지능형 조율 로직

#### 2.3 Gemini 2.0 Flash-Lite (The Efficient Worker)
- 빠른 응답 최적화
- 비용 효율적 처리
- 실시간 추천 개선

#### 2.4 HyperCLOVA X (The True Korean Friend)
- 한국어 처리 강화
- 문화적 맥락 이해
- 로컬라이제이션 개선

### 3. 구현 우선순위

1. 에러 처리 강화
2. 성능 모니터링 구축
3. 서비스 선택 로직 고도화
4. 벡터 DB 연동

### 4. 테스트 계획

#### 4.1 단위 테스트
- 각 서비스 연동 테스트
- 에러 처리 테스트
- 성능 측정 테스트

#### 4.2 통합 테스트
- 전체 라우팅 플로우
- 장애 복구 시나리오
- 부하 테스트

#### 4.3 성능 테스트
- 응답 시간 측정
- 리소스 사용량 분석
- 비용 효율성 검증

---

## 📌 Phase 2: ⭐ 핵심 가치 구현: 장기 기억 (3-5주)
**목표**: 유료 플랜의 핵심 기능인 '장기 기억' 시스템 구축

- [ ] **Vector DB 기술 선정**: 온디바이스 vs. 클라우드 기반 Vector DB 기술 최종 선정
- [ ] **기억 저장/조회 파이프라인 설계**: 대화 요약, 벡터화, 저장 및 조회 로직 구체화
- [ ] **Vector DB 연동**: `LLMRepository`와 선택된 Vector DB 연동 구현
- [ ] **기능 분기 로직 구현**: 무료(단기 기억) / 유료(장기 기억) 사용자 경험 분기 처리

---

## 📌 Phase 3: 📈 프로덕션 준비 및 최적화 (6-8주)
**목표**: 프로덕션 수준의 안정성, 보안, 성능 확보

- [ ] **보안 및 프라이버시 강화**: '장기 기억' 데이터 종단 간 암호화 및 비식별화 처리
- [ ] **성능 최적화**: Vector DB 조회 속도, 메모리 사용량 등 핵심 성능 지표(KPI) 기반 최적화
- [ ] **인앱 결제 연동**: App Store Connect 및 StoreKit을 사용한 구독 관리 시스템 연동
- [ ] **모니터링 시스템 강화**: '장기 기억' 관련 로그 추가
- [ ] **테스트 커버리지 80% 달성**: 단위/통합 테스트, 특히 '장기 기억' 관련 시나리오 집중 테스트

---

## ⚙️ 기타 TODO 항목 (코드베이스 스캔 기반)

*아래는 코드베이스 스캔을 통해 발견된 `TODO` 항목들입니다. 각 항목은 우선순위와 관련성을 판단하여 위의 로드맵 단계에 재배치하거나 여기서 직접 처리합니다.*

### Phase 1: 🔥 코어 아키텍처 전환
- [x] **`CompilerFixStubs.swift` 정리**: 컴파일 오류 해결을 위한 임시 스텁들 정리 완료
- [ ] **`EmotionAnalysisChatViewController` 리팩토링**: `LLMRouter`를 사용하도록 로직 전면 재검토 및 수정.
    - [ ] `AITask`에 신규 케이스 추가: `.analyzeEmotionPattern`, `.requestAdvancedRecommendation`, `.getHelpfulTip` 등 가이드에 맞는 Task 정의
    - [x] 로딩 인디케이터(`showLoading`) 등 UI 로직 기본 구현 (스텁 형태)
    - [ ] 레거시 의도 분석 및 감정 분석 로직을 `LLMRouter` 호출로 대체
- [ ] **`ComprehensiveRecommendationModels.swift` 리팩토링**: `Core` 모듈의 `SharedModels.swift`와 중복 여부 확인 후 통합 또는 제거.

### Phase 3: 📈 프로덕션 준비 및 최적화
- [ ] **Fastlane 설정**: `Fastfile`에 TestFlight 및 App Store 배포 자동화 스크립트 추가.

### ⚙️ 설정 및 기타
- [ ] **`spm_xcodegen_reset.sh`**: 스크립트 내 `TEAM_ID` 설정 (사용자 확인 필요) 

---

## 📊 진행 상황 요약

- **Phase 1**: 70% 완료 (핵심 아키텍처 안정화 완료, LLMRouter 로직 및 API 연동 대기)
- **Phase 2**: 대기 중 (Phase 1 완료 후 시작)
- **Phase 3**: 대기 중 (Phase 2 완료 후 시작)

**현재 집중 영역**: `EmotionAnalysisChatViewController.swift`의 남은 구조적 문제 해결 및 LLMRouter 기반 로직 구현 