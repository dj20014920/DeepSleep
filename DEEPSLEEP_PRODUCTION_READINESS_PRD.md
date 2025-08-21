# DeepSleep 프로덕션 준비 PRD (Product Requirements Document)

> **문서 버전**: v1.0  
> **작성일**: 2025년 8월 21일  
> **목표**: Critical Issue 해결 및 프로덕션 출시 준비  
> **우선순위**: P0 (최고 우선순위)

---

## 📋 **Executive Summary**

DeepSleep 프로젝트의 종합 검증 결과, 핵심 아키텍처와 기능은 우수하나 프로덕션 출시를 위해 **반드시 해결해야 할 Critical Issue들**이 식별되었습니다. 본 PRD는 이러한 문제들을 체계적으로 해결하여 안전하고 신뢰할 수 있는 상용 앱으로 출시하기 위한 로드맵을 제시합니다.

### **현재 상태**
- **전체 완성도**: 75/100
- **기술적 아키텍처**: 우수 (85/100)
- **보안 준비도**: 미흡 (60/100)
- **프로덕션 준비도**: 미흡 (65/100)

### **목표 상태**
- **전체 완성도**: 95/100
- **기술적 아키텍처**: 우수 유지 (90/100)
- **보안 준비도**: 우수 (90/100)
- **프로덕션 준비도**: 우수 (95/100)

---

## 🎯 **핵심 목표 (Goals)**

### **Primary Goals**
1. **보안 강화**: API 키 노출 위험 완전 제거
2. **코드 품질 향상**: 임시방편 코드 및 중복 코드 완전 제거
3. **안정성 확보**: 프로덕션 환경에서의 안정적 운영 보장
4. **문서 일관성**: 개발팀 협업을 위한 신뢰할 수 있는 문서화

### **Secondary Goals**
1. **성능 최적화**: 사용자 경험 개선
2. **테스트 커버리지**: 핵심 기능 안정성 보장
3. **규정 준수**: 2025년 앱스토어 요구사항 완전 대응

---

## 🚨 **Critical Issues (P0 - 즉시 해결 필요)**

### **Issue #1: CompilerFixStubs 제거**
**문제**: 임시방편 코드로 인한 프로덕션 안정성 위험
**영향도**: Critical
**비즈니스 리스크**: 앱 크래시, 사용자 이탈

**요구사항**:
- [ ] CompilerFixStubs.swift 파일 완전 삭제
- [ ] ModuleFixHeader.swift 등 임시 파일 제거
- [ ] 근본 원인 해결 (빌드 오류의 실제 원인 수정)
- [ ] 모든 스텁 코드를 실제 구현체로 교체

**성공 기준**:
- 임시 파일 0개
- 빌드 성공률 100% (스텁 없이)
- 모든 기능 정상 작동

### **Issue #2: API 키 보안 강화**
**문제**: 클라이언트 사이드 API 키 노출로 인한 비용 폭탄 위험
**영향도**: Critical
**비즈니스 리스크**: 월 수만 달러 비용 발생 가능

**요구사항**:
- [ ] 프록시 서버 구축 (AWS Lambda + API Gateway)
- [ ] 클라이언트에서 모든 API 키 제거
- [ ] 서버 사이드 API 호출로 전환
- [ ] Rate Limiting 및 사용량 모니터링 구현

**성공 기준**:
- 클라이언트 코드에 API 키 0개
- 프록시 서버 응답 시간 < 500ms
- 월 API 비용 예측 가능 ($50 이하)

### **Issue #3: 중복 코드 완전 제거**
**문제**: DRY 원칙 위반으로 인한 유지보수 위험
**영향도**: High
**비즈니스 리스크**: 버그 증가, 개발 속도 저하

**요구사항**:
- [ ] EmotionAnalysisService_backup.swift 삭제
- [ ] 모든 _backup, _old 파일 제거
- [ ] 중복 로직 통합
- [ ] Single Source of Truth 확립

**성공 기준**:
- 중복 파일 0개
- 코드 중복률 < 5%
- 단일 진실 공급원 확립

---

## 📊 **High Priority Issues (P1 - 2주 내 해결)**

### **Issue #4: 문서 일관성 확보**
**요구사항**:
- [ ] GEMINI.md를 최상위 문서로 통일
- [ ] 모든 로드맵 문서 현실 반영
- [ ] 과장된 "완료" 선언 수정
- [ ] 개발자 온보딩 가이드 작성

### **Issue #5: 테스트 커버리지 확대**
**요구사항**:
- [ ] SessionManager 단위 테스트 (커버리지 80% 이상)
- [ ] AIContextManager 테스트 작성
- [ ] UnifiedAIServiceImpl 통합 테스트
- [ ] 핵심 비즈니스 로직 테스트

### **Issue #6: Privacy Manifest 완성**
**요구사항**:
- [ ] PrivacyInfo.xcprivacy 완성
- [ ] 데이터 수집 정책 명시
- [ ] 서드파티 SDK 데이터 사용 선언
- [ ] 2025년 앱스토어 요구사항 100% 준수

---

## 🔧 **Medium Priority Issues (P2 - 1개월 내 해결)**

### **Issue #7: 성능 최적화**
**요구사항**:
- [ ] 메모리 사용량 최적화
- [ ] 배터리 소모 최소화
- [ ] 앱 시작 시간 < 3초
- [ ] AI 응답 시간 < 5초

### **Issue #8: 파일 구조 정리**
**요구사항**:
- [ ] 기능별 모듈화 강화
- [ ] 최상위 파일 수 < 20개
- [ ] 명확한 디렉토리 구조
- [ ] 네이밍 컨벤션 통일

---

## 📅 **Implementation Timeline**

### **Week 1-2: Critical Issues 해결**
```
Day 1-3: CompilerFixStubs 제거
Day 4-7: API 키 보안 강화 (프록시 서버 구축)
Day 8-10: 중복 코드 제거
Day 11-14: 통합 테스트 및 검증
```

### **Week 3-4: High Priority Issues**
```
Day 15-18: 문서 일관성 확보
Day 19-21: 테스트 커버리지 확대
Day 22-28: Privacy Manifest 및 규정 준수
```

### **Week 5-8: Medium Priority Issues**
```
Week 5-6: 성능 최적화
Week 7-8: 파일 구조 정리 및 최종 검증
```

---

## 🎯 **Success Metrics**

### **Technical Metrics**
- **빌드 성공률**: 100% (스텁 없이)
- **테스트 커버리지**: 핵심 모듈 80% 이상
- **코드 중복률**: < 5%
- **보안 스캔**: Critical 이슈 0개

### **Business Metrics**
- **API 비용**: 월 $50 이하 예측 가능
- **앱스토어 승인**: 1회 승인 (리젝 없음)
- **크래시율**: < 0.1%
- **사용자 만족도**: 4.5/5.0 이상

### **Process Metrics**
- **문서 신뢰도**: 개발팀 만족도 90% 이상
- **온보딩 시간**: 신규 개발자 < 1일
- **배포 주기**: 주 1회 안정적 배포

---

## 🔒 **Security Requirements**

### **Data Protection**
- [ ] 모든 개인정보 기기 내 처리
- [ ] PII 필터링 100% 적용
- [ ] 암호화된 로컬 저장소 사용

### **API Security**
- [ ] 서버 사이드 API 호출
- [ ] JWT 기반 인증
- [ ] Rate Limiting 적용
- [ ] 실시간 사용량 모니터링

### **Code Security**
- [ ] 정적 코드 분석 통과
- [ ] 의존성 취약점 스캔
- [ ] 코드 난독화 적용

---

## 📱 **App Store Compliance**

### **2025년 필수 요구사항**
- [ ] Privacy Manifest 완성
- [ ] App Tracking Transparency 구현
- [ ] 데이터 수집 정책 명시
- [ ] 서드파티 SDK 선언

### **품질 기준**
- [ ] 메모리 사용량 < 100MB
- [ ] 앱 크기 < 50MB
- [ ] 시작 시간 < 3초
- [ ] 크래시율 < 0.1%

---

## 🎉 **Definition of Done**

### **Critical Issues 완료 기준**
1. ✅ 모든 임시 파일 제거 완료
2. ✅ 프록시 서버 운영 중
3. ✅ 중복 코드 0개
4. ✅ 보안 스캔 통과
5. ✅ 통합 테스트 100% 통과

### **프로덕션 준비 완료 기준**
1. ✅ 앱스토어 제출 가능 상태
2. ✅ 모든 규정 준수 완료
3. ✅ 성능 기준 달성
4. ✅ 문서화 완성
5. ✅ 팀 승인 완료

---

## 👥 **Stakeholders & Responsibilities**

### **개발팀**
- **Lead Developer**: 전체 진행 관리 및 아키텍처 결정
- **Backend Developer**: 프록시 서버 구축
- **iOS Developer**: 클라이언트 보안 강화
- **QA Engineer**: 테스트 커버리지 확대

### **비즈니스팀**
- **Product Manager**: 우선순위 관리 및 일정 조율
- **Security Officer**: 보안 요구사항 검토
- **Legal Team**: 규정 준수 확인

---

## 📞 **Communication Plan**

### **Daily Standups**
- 매일 오전 10시
- Critical Issues 진행 상황 공유
- 블로커 및 리스크 식별

### **Weekly Reviews**
- 매주 금요일 오후 3시
- 주간 목표 달성도 검토
- 다음 주 우선순위 조정

### **Milestone Reviews**
- Critical Issues 완료 시점
- High Priority Issues 완료 시점
- 프로덕션 준비 완료 시점

---

**이 PRD는 DeepSleep 프로젝트의 안전하고 성공적인 프로덕션 출시를 위한 필수 로드맵입니다. 모든 Critical Issues의 해결 없이는 상용 서비스 출시를 진행하지 않습니다.**
---


## 🛠️ **Technical Implementation Details**

### **Critical Issue #1: CompilerFixStubs 제거 상세 계획**

#### **Phase 1: 현황 파악 (1일)**
```bash
# 모든 스텁 파일 식별
find . -name "*Stub*" -o -name "*Fix*" -o -name "*Temp*"
grep -r "TODO\|FIXME\|STUB" --include="*.swift"
```

#### **Phase 2: 근본 원인 분석 (1일)**
- 빌드 오류의 실제 원인 파악
- 의존성 문제 해결
- 모듈 간 순환 참조 제거

#### **Phase 3: 실제 구현 (1일)**
- 스텁 메서드를 실제 로직으로 교체
- 단위 테스트 작성
- 통합 테스트 실행

### **Critical Issue #2: API 키 보안 강화 상세 계획**

#### **서버 아키텍처**
```
Client App → AWS API Gateway → Lambda Function → External AI APIs
```

#### **Lambda Function 구조**
```typescript
// 예시 구조
export const handler = async (event) => {
  // 1. 인증 확인
  const userId = validateJWT(event.headers.authorization);
  
  // 2. Rate Limiting 체크
  await checkRateLimit(userId);
  
  // 3. 요청 검증
  const request = validateRequest(event.body);
  
  // 4. AI API 호출
  const response = await callAIService(request);
  
  // 5. 사용량 기록
  await logUsage(userId, request.model, response.tokens);
  
  return response;
};
```

#### **비용 관리**
- **예상 비용**: 월 $30-50 (Lambda + API Gateway)
- **절약 효과**: 월 수만 달러 위험 제거
- **모니터링**: CloudWatch 알람 설정

### **Critical Issue #3: 중복 코드 제거 상세 계획**

#### **중복 파일 매핑**
```
EmotionAnalysisService.swift ← 유지
EmotionAnalysisService_backup.swift ← 삭제

ChatManager.swift ← 확인 후 처리
LegacyChatViewController.swift ← 검토 필요
```

#### **코드 통합 전략**
1. **기능 비교**: 두 버전의 차이점 분석
2. **최신 버전 선택**: 더 완성도 높은 버전 유지
3. **테스트 이전**: 기존 테스트를 새 버전에 적용
4. **점진적 제거**: 단계별로 레거시 코드 제거

---

## 📋 **Detailed Task Breakdown**

### **Week 1: Critical Issues Sprint**

#### **Day 1-2: CompilerFixStubs 제거**
- [ ] **Task 1.1**: 모든 스텁 파일 목록 작성
- [ ] **Task 1.2**: 각 스텁의 원래 목적 파악
- [ ] **Task 1.3**: 빌드 오류 근본 원인 분석
- [ ] **Task 1.4**: 첫 번째 스텁 파일 제거 및 테스트
- [ ] **Task 1.5**: 나머지 스텁 파일 순차 제거

#### **Day 3-5: 프록시 서버 구축**
- [ ] **Task 2.1**: AWS 계정 설정 및 IAM 역할 생성
- [ ] **Task 2.2**: Lambda 함수 개발 및 배포
- [ ] **Task 2.3**: API Gateway 설정
- [ ] **Task 2.4**: 클라이언트 코드 수정
- [ ] **Task 2.5**: 통합 테스트 및 성능 검증

#### **Day 6-7: 중복 코드 제거**
- [ ] **Task 3.1**: 중복 파일 완전 목록 작성
- [ ] **Task 3.2**: 각 파일의 사용 현황 분석
- [ ] **Task 3.3**: 안전한 제거 순서 결정
- [ ] **Task 3.4**: 백업 파일 제거 실행
- [ ] **Task 3.5**: 전체 빌드 및 테스트 검증

### **Week 2: 검증 및 안정화**

#### **Day 8-10: 통합 테스트**
- [ ] **Task 4.1**: 전체 기능 회귀 테스트
- [ ] **Task 4.2**: 성능 벤치마크 실행
- [ ] **Task 4.3**: 보안 스캔 실행
- [ ] **Task 4.4**: 메모리 누수 검사
- [ ] **Task 4.5**: 배터리 사용량 측정

#### **Day 11-14: 문서화 및 최종 검토**
- [ ] **Task 5.1**: 변경사항 문서화
- [ ] **Task 5.2**: 새로운 아키텍처 다이어그램 작성
- [ ] **Task 5.3**: 개발팀 코드 리뷰
- [ ] **Task 5.4**: 스테이징 환경 배포
- [ ] **Task 5.5**: 최종 승인 및 다음 단계 계획

---

## 🔍 **Quality Assurance Plan**

### **테스트 전략**

#### **Unit Tests (단위 테스트)**
```swift
// 예시: SessionManager 테스트
class SessionManagerTests: XCTestCase {
    func testSendMessageWithoutStubs() {
        // Given: 실제 구현체만 사용
        let sessionManager = SessionManager()
        
        // When: 메시지 전송
        let result = sessionManager.sendMessage("test")
        
        // Then: 스텁 없이 정상 작동
        XCTAssertNotNil(result)
        XCTAssertFalse(result.isStub)
    }
}
```

#### **Integration Tests (통합 테스트)**
- API 프록시 서버 연동 테스트
- Core Data 통합 테스트
- AI 서비스 통합 테스트
- 사용자 플로우 End-to-End 테스트

#### **Security Tests (보안 테스트)**
- API 키 노출 검사
- 네트워크 트래픽 분석
- 정적 코드 분석
- 의존성 취약점 스캔

### **성능 기준**

#### **앱 성능 KPI**
- **시작 시간**: < 3초 (콜드 스타트)
- **메모리 사용량**: < 100MB (피크 시)
- **배터리 소모**: < 5% per hour (일반 사용)
- **네트워크 사용량**: < 10MB per session

#### **서버 성능 KPI**
- **응답 시간**: < 500ms (95th percentile)
- **가용성**: > 99.9%
- **처리량**: > 1000 requests/minute
- **비용**: < $50/month

---

## 🚨 **Risk Management**

### **High Risk Items**

#### **Risk #1: API 마이그레이션 중 서비스 중단**
- **확률**: Medium
- **영향도**: High
- **완화 방안**: 
  - Blue-Green 배포 전략
  - 롤백 계획 수립
  - 단계적 트래픽 전환

#### **Risk #2: 스텁 제거 시 예상치 못한 버그**
- **확률**: Medium
- **영향도**: Medium
- **완화 방안**:
  - 철저한 단위 테스트
  - 스테이징 환경 검증
  - 점진적 제거 전략

#### **Risk #3: 프록시 서버 비용 초과**
- **확률**: Low
- **영향도**: Medium
- **완화 방안**:
  - CloudWatch 알람 설정
  - 사용량 제한 구현
  - 비용 모니터링 대시보드

### **Contingency Plans**

#### **Plan A: 일정 지연 시**
- Critical Issues만 우선 해결
- High Priority Issues는 다음 스프린트로 연기
- 최소 기능으로 프로덕션 출시

#### **Plan B: 기술적 문제 발생 시**
- 외부 전문가 컨설팅
- 대안 기술 스택 검토
- 단계적 해결 방안 수립

---

## 📊 **Monitoring & Analytics**

### **실시간 모니터링**

#### **앱 성능 모니터링**
```swift
// 예시: 성능 메트릭 수집
class PerformanceMonitor {
    static func trackAPICall(endpoint: String, duration: TimeInterval) {
        Analytics.track("api_call", properties: [
            "endpoint": endpoint,
            "duration": duration,
            "timestamp": Date()
        ])
    }
}
```

#### **서버 모니터링**
- CloudWatch 메트릭
- 사용량 대시보드
- 비용 추적
- 오류율 모니터링

### **비즈니스 메트릭**

#### **사용자 경험 지표**
- 앱 크래시율
- 응답 시간 만족도
- 기능 사용률
- 사용자 피드백 점수

#### **운영 효율성 지표**
- 배포 성공률
- 버그 발견율
- 해결 시간
- 개발 속도

---

## 🎯 **Success Celebration Plan**

### **Milestone 달성 시 보상**
- **Critical Issues 완료**: 팀 디너
- **High Priority Issues 완료**: 팀 빌딩 활동
- **전체 PRD 완료**: 프로젝트 성공 파티

### **개인 기여도 인정**
- 우수 기여자 표창
- 기술 블로그 포스팅 기회
- 컨퍼런스 발표 기회

---

**이 상세 계획을 통해 DeepSleep 프로젝트가 안전하고 성공적으로 프로덕션에 출시될 수 있도록 하겠습니다. 모든 단계는 검증 가능하고 측정 가능한 기준으로 관리됩니다.**