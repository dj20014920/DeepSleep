# 🔐 DeepSleep API 키 보안 설정 가이드

## 🚨 중요: API 키 보안 문제 해결

GitHub에서 API 키가 감지되어 비활성화되는 문제를 **완전히 해결**하기 위한 단계별 가이드입니다.

## 📋 해결된 문제들

✅ **커밋 히스토리에서 API 키 완전 제거** (git filter-repo 완료)  
✅ **새로운 보안 환경 설정 시스템 구축**  
✅ **다중 보안 레이어 구현**  
✅ **.gitignore 강화**

## 🛠️ 1단계: 새로운 API 키 발급

1. [Replicate 계정](https://replicate.com/account/api-tokens)에서 **새로운 API 키 발급**
2. 기존 비활성화된 키는 완전히 삭제

## 🔐 2단계: 보안 설정 방법 (3가지 옵션)

### 옵션 A: 환경 변수 방식 (🌟 **권장**)

1. **Xcode에서 Scheme 설정:**
   ```
   Product > Scheme > Edit Scheme > Run > Environment Variables
   ```

2. **환경 변수 추가:**
   ```
   변수명: REPLICATE_API_TOKEN
   값: r8_your_new_api_key_here
   ```

3. **장점:**
   - 소스코드에 API 키 노출 없음
   - 각 개발자가 개별 설정
   - GitHub 업로드 시 완전 안전

### 옵션 B: xcconfig 파일 방식 (로컬용)

1. `DeepSleep/SecureSecrets.xcconfig` 파일에서:
   ```
   // 주석 해제하고 실제 키 입력
   REPLICATE_API_TOKEN = r8_your_new_api_key_here
   ```

2. **주의사항:**
   - 이 파일은 `.gitignore`에 포함됨
   - 절대 커밋하지 말 것

### 옵션 C: 키체인 방식 (향후 구현)

- iOS 키체인을 통한 보안 저장
- 현재 `EnvironmentConfig.swift`에 준비됨

## 🔧 3단계: 새로운 보안 시스템 작동 원리

### `EnvironmentConfig.swift`
```swift
var replicateAPIKey: String {
    // 1. 환경 변수 우선 확인
    if let envKey = ProcessInfo.processInfo.environment["REPLICATE_API_TOKEN"] {
        return envKey
    }
    
    // 2. Info.plist에서 확인 (xcconfig 주입)
    if let plistKey = Bundle.main.object(forInfoDictionaryKey: "REPLICATE_API_TOKEN") as? String,
       !plistKey.isEmpty && plistKey != "$(REPLICATE_API_TOKEN)" {
        return plistKey
    }
    
    // 3. 키체인에서 확인 (향후)
    if let keychainKey = getFromKeychain() {
        return keychainKey
    }
    
    return ""
}
```

## 🛡️ 4단계: 보안 검증

### 앱 시작 시 자동 검증
```swift
// AppDelegate.swift에서
EnvironmentConfig.shared.performSecurityCheck()
```

### 디버그 로그 확인
```
🔐 보안 검증 시작...
📱 API 키 상태: ✅ 유효
🔑 마스킹된 키: r8_a****xyz9
```

## 🚀 5단계: Git 작업

### 현재 상태
- ✅ 커밋 히스토리에서 모든 API 키 제거 완료
- ✅ 새로운 보안 시스템 구축 완료
- ✅ .gitignore 강화 완료

### 다음 단계
```bash
# 새로운 remote 추가 (기존 origin이 제거됨)
git remote add origin https://github.com/dj20014920/DeepSleep.git

# 강제 푸시 (히스토리 정리 후)
git push --force-with-lease origin main
```

## 📱 6단계: 테스트

1. **API 키 설정 확인:**
   - 앱 실행 시 디버그 로그 확인
   - "✅ 유효" 메시지 확인

2. **AI 기능 테스트:**
   - 채팅 기능 작동 확인
   - 할 일 조언 기능 확인

## ⚠️ 보안 주의사항

### 절대 하지 말 것
- ❌ API 키를 소스코드에 직접 입력
- ❌ 보안 설정 파일을 커밋
- ❌ API 키를 스크린샷이나 로그에 노출

### 반드시 할 것
- ✅ 환경 변수 또는 xcconfig 사용
- ✅ .gitignore 파일 유지
- ✅ 정기적인 API 키 갱신

## 🆘 문제 해결

### API 키가 여전히 감지되는 경우
1. **커밋 히스토리 재확인:**
   ```bash
   git log --all --full-history --grep="r8_"
   ```

2. **모든 브랜치 확인:**
   ```bash
   git branch -a
   git log --all --oneline | grep -i api
   ```

3. **완전 초기화 (최후 수단):**
   - 새 저장소 생성
   - 현재 소스코드만 복사

### 문의 사항
- 추가 보안 문제 발생 시 즉시 보고
- 새로운 보안 방법 제안 환영

---

## 🎯 최종 확인 체크리스트

- [ ] 새 API 키 발급 완료
- [ ] 환경 변수 또는 xcconfig 설정 완료
- [ ] 앱 실행 시 "✅ 유효" 로그 확인
- [ ] AI 채팅 기능 정상 작동 확인
- [ ] Git push 시 보안 경고 없음 확인

**🎉 모든 체크 완료 시 보안 설정 성공!** 