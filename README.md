🔑 API 토큰 설정법
1. `.gitignore`에 의해 API 키는 포함되어 있지 않습니다.
2. 프로젝트 루트에서 아래 명령어 실행:
```bash
1. export REPLICATE_API_TOKEN=r8_관리자에게 토큰 문의
2. ./generate-secrets.sh


# 🌙 EmoZleep (DeepSleep) - AI 기반 감정 맞춤형 사운드 수면 앱

> **AI와 함께하는 개인 맞춤형 수면 사운드 경험**  
> 당신의 감정과 건강 데이터를 분석하여 최적의 수면 환경을 제공하는 iOS 앱

[![iOS](https://img.shields.io/badge/iOS-18.4+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-16.0+-blue.svg)](https://developer.apple.com/xcode/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📱 프로젝트 개요

**EmoZleep**은 사용자의 감정 상태와 건강 데이터를 AI로 분석하여 개인 맞춤형 수면 사운드를 제공하는 혁신적인 iOS 앱입니다. 단순한 수면 앱을 넘어서 사용자의 일상과 감정을 이해하고, 최적의 휴식 환경을 조성하는 종합 웰니스 플랫폼을 목표로 합니다.

## ✨ 주요 기능

### 🎵 **스마트 사운드 시스템**
- **13가지 고품질 자연 사운드**: 파도, 비, 새소리, 바람, 불타는 소리 등
- **다중 버전 지원**: 각 사운드마다 여러 버전 제공으로 개인 취향 반영
- **실시간 믹싱**: 여러 사운드를 동시에 재생하여 나만의 조합 생성
- **백그라운드 재생**: 앱이 백그라운드에 있어도 지속적인 사운드 제공

### 🤖 **AI 기반 개인화**
- **Claude 3.5 Haiku 통합**: Replicate API를 통한 고급 AI 대화
- **감정 기반 추천**: 현재 감정 상태에 맞는 최적의 사운드 프리셋 제안
- **건강 데이터 분석**: HealthKit 연동으로 심박수, 활동량, 수면 패턴 분석
- **학습형 AI**: 사용 패턴을 학습하여 점점 더 정확한 추천 제공

### 📖 **감정 일기 & 분석**
- **감정 추적**: 일상의 감정 변화를 기록하고 패턴 분석
- **AI 대화**: 감정 상태에 대해 AI와 자연스러운 대화
- **인사이트 제공**: 감정 패턴 분석을 통한 개인 맞춤형 조언
- **프리셋 자동 생성**: 일기 내용 기반으로 맞춤형 사운드 프리셋 생성

### 📅 **스마트 일정 관리**
- **할 일 관리**: 감정 상태와 연계된 지능형 할 일 관리
- **AI 조언**: 각 할 일에 대한 AI의 실용적인 조언 제공
- **캘린더 통합**: iOS 기본 캘린더와 완벽한 동기화
- **알림 시스템**: 적절한 타이밍의 스마트 알림

### 🔗 **소셜 기능**
- **프리셋 공유**: QR 코드나 링크를 통한 사운드 프리셋 공유
- **커뮤니티**: 다른 사용자들과 수면 경험 공유
- **내보내기/가져오기**: 설정을 JSON 형태로 백업 및 복원

## 🏗 기술 아키텍처

### **프론트엔드**
```
Swift 5.0 + UIKit
├── MVC 패턴 기반 아키텍처
├── SceneDelegate로 최신 Scene 생명주기 관리
├── Auto Layout 기반 반응형 UI
├── 다크모드 완벽 지원
├── SwiftData 모델링
└── URLScheme 기반 딥링크 지원
```

### **AI 및 외부 서비스**
```
Replicate API (Claude 3.5 Haiku)
├── 실시간 AI 대화
├── 감정 분석 및 추천
├── 토큰 사용량 최적화
├── 네트워크 오류 복구
└── 개인정보 보호 강화
```

### **데이터 관리**
```
UserDefaults + Core Data
├── 프리셋 버전 관리 시스템
├── 감정 일기 영구 저장
├── 사용자 설정 동기화
├── 캐시 최적화
└── 백업/복원 지원
```

### **오디오 시스템**
```
AVFoundation
├── 다중 AVAudioPlayer 관리
├── 백그라운드 재생 지원
├── 제어 센터 통합
├── 오디오 세션 최적화
└── 배터리 효율성 고려
```

## 📋 시스템 요구사항

| 구분 | 요구사항 |
|------|----------|
| **iOS 버전** | iOS 18.4 이상 |
| **기기** | iPhone, iPad 모두 지원 |
| **Xcode** | Xcode 16.0 이상 |
| **Swift** | Swift 5.0 이상 |
| **네트워크** | AI 기능 사용 시 인터넷 연결 필요 |
| **권한** | 캘린더, 알림, HealthKit (선택사항) |

## 🚀 설치 및 실행

### **1. 프로젝트 클론**
```bash
git clone https://github.com/dj20014920/DeepSleep.git
cd DeepSleep
```

### **2. API 키 설정**
```bash
# Secrets.xcconfig 파일 생성
echo "REPLICATE_API_TOKEN = YOUR_API_KEY_HERE" > DeepSleep/Secrets.xcconfig

# 또는 제공된 스크립트 사용
chmod +x DeepSleep/generate-secrets.sh
./DeepSleep/generate-secrets.sh
```

### **3. Xcode에서 빌드**
```bash
open DeepSleep.xcodeproj
# Xcode에서 타겟을 선택하고 ⌘+R로 실행
```

### **4. 의존성 자동 설치**
프로젝트는 Swift Package Manager를 사용하여 필요한 라이브러리를 자동으로 설치합니다:
- **FSCalendar**: 캘린더 UI 컴포넌트
- **기타 내장 프레임워크**: AVFoundation, HealthKit, UserNotifications

## 📚 사용 방법

### **기본 사용법**

1. **🎵 사운드 믹싱**
   - 메인 화면에서 13개 사운드 카테고리별 볼륨 조절
   - 여러 사운드를 동시에 재생하여 나만의 조합 생성
   - 프리셋 저장으로 자주 사용하는 설정 보관

2. **📝 감정 일기**
   - 일기 탭에서 오늘의 감정과 생각 기록
   - AI와의 대화를 통해 감정 상태 분석
   - 자동 생성되는 맞춤형 사운드 프리셋 활용

3. **📅 일정 관리**
   - 할 일 등록 시 AI의 실용적 조언 확인
   - 감정 상태와 연계된 우선순위 설정
   - iOS 캘린더와 자동 동기화

### **고급 기능**

4. **⌚ HealthKit 연동** (Apple Developer 계정 필요)
   ```swift
   // 건강 데이터 기반 자동 추천
   HealthKitManager.shared.analyzeTodayAndRecommend { wellness in
       // 스트레스 레벨, 활동량, 수면 질 분석
       // 맞춤형 프리셋 자동 추천
   }
   ```

5. **🔗 프리셋 공유**
   ```
   emozleep://import?code=ABC123DEF456
   ```

## 🏗 프로젝트 구조

```
DeepSleep/
├── 📱 Core/
│   ├── AppDelegate.swift          # 앱 생명주기 관리
│   ├── SceneDelegate.swift        # Scene 기반 UI 관리
│   └── LaunchViewController.swift # 스플래시 화면
│
├── 🎵 Audio/
│   ├── SoundManager.swift         # 오디오 재생 관리
│   ├── SoundPresetCatalog.swift   # 프리셋 카탈로그
│   └── Sound/                     # 오디오 파일들
│       ├── 파도.mp3
│       ├── 비.mp3
│       └── ... (22개 사운드 파일)
│
├── 🤖 AI/
│   ├── ReplicateChatService.swift    # Claude AI 통합
│   ├── ChatViewController.swift      # AI 대화 UI
│   ├── EmotionAnalysisChat*.swift    # 감정 분석 대화
│   └── AIUsageManager.swift          # AI 사용량 관리
│
├── 📖 Diary/
│   ├── Models.swift                  # 데이터 모델
│   ├── EmotionDiaryViewController.swift
│   ├── DiaryWriteViewController.swift
│   └── EditDiaryViewController.swift
│
├── 📅 Calendar/
│   ├── TodoCalendarViewController.swift
│   ├── AddEditTodoViewController.swift
│   ├── TodoManager.swift
│   └── TodoItem.swift
│
├── ⚙️ Settings/
│   ├── SettingsManager.swift         # 설정 관리
│   ├── PresetManager.swift           # 프리셋 관리
│   └── UserDefaults+Extensions.swift
│
├── 🔧 Utilities/
│   ├── EnvironmentConfig.swift       # 환경 설정
│   ├── RemoteLogger.swift            # 로깅 시스템
│   └── Constants.swift               # 상수 정의
│
└── 📱 UI/
    ├── ViewController.swift          # 메인 화면
    ├── ViewController+*.swift        # 기능별 확장
    └── PresetListViewController.swift
```

## 🔧 주요 구현 기술

### **1. Scene State Management**
```swift
// SceneDelegate.swift - 앱 상태 변화 대응
func sceneDidBecomeActive(_ scene: UIScene) {
    SoundManager.shared.handleSceneStateChange(isActive: true)
    SoundManager.shared.restorePlaybackStateIfNeeded()
}
```

### **2. AI 토큰 최적화**
```swift
// ReplicateChatService.swift - 토큰 사용량 관리
private func optimizeTokenUsage(_ prompt: String) -> String {
    let tokenCount = TokenEstimator.roughCount(for: prompt)
    if tokenCount > 3500 {
        return truncatePrompt(prompt, targetTokens: 3500)
    }
    return prompt
}
```

### **3. 프리셋 버전 관리**
```swift
// Models.swift - 하위 호환성 보장
var compatibleVolumes: [Float] {
    if presetVersion == "v1.0" && volumes.count == 12 {
        return volumes + [0.0] // v2.0 호환을 위한 패딩
    }
    return volumes
}
```

### **4. 메모리 최적화**
```swift
// SoundManager.swift - AVAudioPlayer 재사용
private func reloadPlayer(at categoryIndex: Int) {
    if categoryIndex < players.count {
        players[categoryIndex].stop() // 기존 플레이어 정리
        players[categoryIndex] = try AVAudioPlayer(contentsOf: url)
    }
}
```

## 🔒 보안 및 개인정보

### **개인정보 보호**
- **로컬 우선**: 모든 감정 데이터는 기기에 우선 저장
- **투명한 AI 사용**: AI 전송 데이터에 대한 명확한 고지
- **최소 권한**: 필요한 권한만 요청
- **데이터 암호화**: 민감한 설정 데이터 암호화 저장

### **API 키 보안**
```bash
# .gitignore에 포함된 보안 파일들
Secrets.xcconfig
*.secret
.env.*
```

### **네트워크 보안**
- HTTPS 전용 통신
- 토큰 사용량 모니터링
- 네트워크 오류 복구 시스템

## 🧪 테스트

### **단위 테스트**
```bash
# Xcode에서 테스트 실행
⌘ + U
```

### **주요 테스트 영역**
- [ ] SoundManager 오디오 재생 기능
- [ ] AI 응답 파싱 및 오류 처리
- [ ] 프리셋 저장/로드 기능
- [ ] 감정 일기 데이터 무결성
- [ ] 메모리 누수 검사

### **시뮬레이터 테스트**
```bash
# 다양한 디바이스에서 테스트
- iPhone 15 Pro (iOS 18.4)
- iPad Air (iOS 18.4)
- 다크모드/라이트모드
- 저전력 모드
```

## 🚨 알려진 이슈 및 제한사항

### **현재 제한사항**
1. **Apple Developer 계정 필요**: HealthKit 기능은 유료 개발자 계정 필요
2. **네트워크 의존성**: AI 기능은 인터넷 연결 필수
3. **토큰 제한**: 일일 AI 사용량 제한 있음
4. **iOS 버전**: iOS 18.4 미만에서는 일부 기능 제한

### **해결된 문제들**
- ✅ Stop 버그: Scene 상태 관리로 해결
- ✅ 프리셋 이름 충돌: 자동 고유 이름 생성으로 해결
- ✅ 메모리 누수: AVAudioPlayer 재사용 풀로 해결
- ✅ AI 토큰 초과: 사용량 모니터링 및 로컬 fallback 구현

## 👥 개발팀

- **Lead Developer**: [@dj20014920](https://github.com/dj20014920)
- **AI Integration**: Claude 3.5 Haiku (Anthropic)
- **Design Consultant**: iOS Human Interface Guidelines

## 📞 연락처

- **GitHub Issues**: [프로젝트 이슈 페이지](https://github.com/dj20014920/DeepSleep/issues)
- **Email**: vinny4920@gmail.com
- **앱 스토어**: (출시 예정)

## 🎯 로드맵

### **v1.1 (예정)**
- [ ] Apple Watch 앱 개발
- [ ] 위젯 지원
- [ ] Siri Shortcuts 통합
- [ ] iCloud 동기화

### **v1.2 (계획 중)**
- [ ] 머신러닝 기반 로컬 추천
- [ ] 3D 사운드 지원
- [ ] 커뮤니티 기능 확장
- [ ] macOS 앱 개발

---

<div align="center">

**🌙 EmoZleep과 함께 더 나은 수면을 경험해보세요! 🌙**

[⭐ Star this repo](https://github.com/dj20014920/DeepSleep) • [🐛 Report Bug](https://github.com/dj20014920/DeepSleep/issues) • [💡 Request Feature](https://github.com/dj20014920/DeepSleep/issues)

</div> 
