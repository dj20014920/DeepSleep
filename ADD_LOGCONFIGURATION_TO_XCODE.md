# LogConfiguration.swift를 Xcode 프로젝트에 추가하는 방법

## 개요
LogConfiguration.swift 파일이 생성되었지만 Xcode 프로젝트에 포함되지 않아 컴파일 오류가 발생합니다.
다음 단계를 따라 파일을 프로젝트에 추가하세요.

## 추가 방법

1. **Xcode에서 DeepSleep 프로젝트 열기**

2. **파일 추가**
   - 좌측 Navigator에서 `DeepSleepApp` 폴더 우클릭
   - "Add Files to DeepSleep..." 선택
   - `/Users/dj20014920/Desktop/DeepSleep/DeepSleepApp/LogConfiguration.swift` 파일 선택
   - 옵션 확인:
     - ✅ "Copy items if needed" (체크 해제 - 이미 올바른 위치에 있음)
     - ✅ "Add to targets: DeepSleep" (반드시 체크)
   - "Add" 클릭

3. **빌드 타겟 확인**
   - LogConfiguration.swift 파일 선택
   - 우측 Inspector에서 Target Membership 확인
   - "DeepSleep" 타겟이 체크되어 있는지 확인

4. **AppDelegate.swift 수정**
   ```swift
   // 현재 임시 코드를 다음으로 교체:
   
   // 기존 코드 (제거):
   #if DEBUG
   UnifiedLogger.shared.setMinimumLogLevel(.info)
   #else
   UnifiedLogger.shared.setMinimumLogLevel(.warning)
   #endif
   
   // 새 코드 (추가):
   _ = LogConfiguration.shared  // 싱글톤 초기화로 기본 설정 적용
   ```

## LogConfiguration 사용법

### 기본 설정 (자동 적용됨)
- DEBUG 빌드: info 레벨 이상 로그만 표시
- RELEASE 빌드: warning 레벨 이상만 표시
- performance, battery, memory 카테고리 자동 비활성화

### 런타임 설정 변경
```swift
// 모든 로그 활성화 (디버깅용)
LogConfiguration.shared.enableAllLogs()

// 성능 관련 로그만 활성화
LogConfiguration.shared.enablePerformanceLogs()

// 최소 로깅 모드
LogConfiguration.shared.setMinimalLogging()

// 특정 카테고리 활성화/비활성화
LogConfiguration.shared.setCategory(.performance, enabled: true)
LogConfiguration.shared.setCategory(.battery, enabled: false)

// 현재 설정 확인
LogConfiguration.shared.printCurrentConfiguration()
```

## 효과
- 콘솔에 표시되는 로그가 크게 감소
- 특히 반복적인 performance, battery, memory 로그 제거
- 필요시 특정 카테고리만 선택적으로 활성화 가능
- 앱 성능 향상 (불필요한 로그 처리 감소)