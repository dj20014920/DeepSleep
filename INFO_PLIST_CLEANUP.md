# 🧹 Info.plist 정리 가이드

> DeepSleep 프로젝트의 Info.plist 중복 문제 해결
> 작성일: 2025-07-28
> 최종 수정: 2025-07-28 (불필요 항목 제거)

## 📋 완료된 작업 (2025-07-28)

### ✅ 1. 불필요한 항목 제거
- **카카오 로그인 설정 제거**: LSApplicationQueriesSchemes (kakaokompassauth, kakaolink)
- **Face ID 권한 제거**: NSFaceIDUsageDescription

### ✅ 2. Info.plist 통합 완료
- **Info.plist**: 유일한 설정 파일로 유지
- **AppInfo.plist**: 삭제 완료

### ✅ 3. APIKeyDiagnostics.swift 제거
- 파일 삭제 완료
- SceneDelegate에서 관련 코드 제거

## 🔍 차이점 분석

### Info.plist에만 있는 항목:
- ✅ UIRequiredDeviceCapabilities (디바이스 요구사항)
- ✅ UISupportedInterfaceOrientations~ipad (iPad 방향)
- ✅ NAVER_CLOUD_API_SECRET (Naver API 시크릿)

### AppInfo.plist에만 있는 항목:
- ⚠️ LSApplicationQueriesSchemes (Kakao 연동)
- ⚠️ NSFaceIDUsageDescription (Face ID 권한)
- ❌ REPLICATE_API_TOKEN (사용 안함)

## 🔧 해결 방법

### 1단계: Info.plist에 필요한 항목 병합 (완료 ✅)
```xml
<!-- 이미 Info.plist에 추가됨 -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>kakaokompassauth</string>
    <string>kakaolink</string>
</array>
<key>NSFaceIDUsageDescription</key>
<string>안전한 개인정보 보호를 위해 Face ID 인증이 필요합니다.</string>
```

### 2단계: Xcode에서 AppInfo.plist 제거

1. Xcode 열기
2. 프로젝트 네비게이터에서 AppInfo.plist 찾기
3. 우클릭 → Delete → "Remove Reference" 선택
4. Target → Build Settings → Info.plist File 확인
   - "DeepSleepApp/Info.plist"로 설정되어 있는지 확인

### 3단계: 파일 시스템에서 삭제
```bash
cd /Users/dj20014920/Desktop/DeepSleep/DeepSleepApp
rm AppInfo.plist
```

### 4단계: 프로젝트 클린 빌드
```
Xcode → Product → Clean Build Folder (⌘⇧K)
Xcode → Product → Build (⌘B)
```

## ⚠️ 주의사항

- Info.plist는 iOS 앱의 핵심 설정 파일
- 하나의 Info.plist만 사용해야 함
- 중복 파일은 설정 충돌과 빌드 문제 유발 가능

## ✅ 최종 확인

Info.plist에 다음 항목들이 모두 있는지 확인:
- [ ] 기본 앱 정보 (Bundle ID, Version 등)
- [ ] Scene 설정 (UIApplicationSceneManifest)
- [ ] API 키 매핑 (CLAUDE_API_KEY 등)
- [ ] 권한 설명 (NSFaceIDUsageDescription)
- [ ] URL 스키마 (LSApplicationQueriesSchemes)

---

**결론**: AppInfo.plist는 중복 파일이므로 제거하고, Info.plist만 사용하는 것이 올바른 방법입니다.