# 🔍 DeepSleep 앱 배포 후 로그 확인 가이드

## 📱 1. Xcode Console (테스트 기기 연결)

### 준비사항
- 개발자 계정에 등록된 테스트 기기
- USB 케이블로 Mac과 연결

### 단계별 가이드
```bash
1. Xcode 열기
2. Window > Devices and Simulators (⇧⌘2)
3. 왼쪽에서 테스트 기기 선택
4. "Open Console" 버튼 클릭
5. 앱 실행 후 실시간 로그 확인
```

### 필터링 방법
```
# DeepSleep 앱 로그만 보기
process:DeepSleep

# 에러 로그만 보기  
category:ERROR

# AI 관련 로그만 보기
category:AI
```

---

## ☁️ 2. Firebase Crashlytics (추천 방법)

### 설정 방법
1. **Firebase 콘솔에서 프로젝트 생성**
   ```
   https://console.firebase.google.com/
   → "프로젝트 추가" → "DeepSleep-Logs"
   ```

2. **iOS 앱 등록**
   ```
   Bundle ID: com.yourcompany.deepsleep
   앱 이름: DeepSleep
   ```

3. **GoogleService-Info.plist 다운로드**
   ```
   Xcode 프로젝트에 추가
   Target Membership 체크
   ```

4. **Podfile 추가**
   ```ruby
   # Podfile
   target 'DeepSleep' do
     pod 'Firebase/Analytics'
     pod 'Firebase/Crashlytics'
     pod 'Firebase/RemoteConfig'
   end
   ```

5. **설치 및 초기화**
   ```bash
   cd /path/to/project
   pod install
   ```

### 사용법
```swift
// AppDelegate.swift
import Firebase

func application(_ application: UIApplication, 
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    FirebaseApp.configure()
    return true
}
```

### 대시보드 확인
```
Firebase Console → Crashlytics → 실시간 로그 및 크래시 리포트
```

---

## 📊 3. TestFlight Internal Testing 로그

### 설정
1. **App Store Connect**
   ```
   앱 → TestFlight → 내부 테스팅 그룹 생성
   테스터 초대 (최대 100명)
   ```

2. **빌드 업로드**
   ```bash
   # Archive 생성
   Product → Archive

   # App Store Connect 업로드
   Window → Organizer → Distribute App
   ```

3. **로그 수집**
   ```swift
   // 테스트 빌드에서만 활성화
   #if DEBUG || INTERNAL_BUILD
   RemoteLogger.shared.logLevel = .debug
   #else  
   RemoteLogger.shared.logLevel = .warning
   #endif
   ```

---

## 🌐 4. 원격 로깅 서버 구축

### 간단한 Node.js 로그 서버
```javascript
// server.js
const express = require('express');
const app = express();

app.use(express.json({ limit: '10mb' }));

app.post('/api/logs', (req, res) => {
    const logs = req.body;
    
    // 로그를 파일이나 데이터베이스에 저장
    console.log(`📱 [${new Date().toISOString()}] 로그 수신:`, logs);
    
    // 파일로 저장
    const fs = require('fs');
    fs.appendFileSync('deepsleep-logs.json', JSON.stringify(logs) + '\n');
    
    res.status(200).json({ success: true });
});

app.listen(3000, () => {
    console.log('🔍 로그 서버가 포트 3000에서 실행 중...');
});
```

### 배포
```bash
# Heroku 배포
heroku create deepsleep-logs
git push heroku main

# 또는 Railway 배포  
railway deploy
```

### 앱에서 서버 URL 업데이트
```swift
// RemoteLogger.swift 에서
private func sendLogsToServer(_ logs: [LogEntry]) {
    guard let url = URL(string: "https://your-app-name.herokuapp.com/api/logs") else { return }
    // ... 나머지 코드
}
```

---

## 📈 5. 실시간 모니터링 대시보드

### Grafana + InfluxDB 구축
```yaml
# docker-compose.yml
version: '3'
services:
  influxdb:
    image: influxdb:1.8
    environment:
      - INFLUXDB_DATABASE=deepsleep_logs
      
  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

### 대시보드 설정
1. **InfluxDB 데이터소스 추가**
2. **패널 생성:**
   - 실시간 사용자 수
   - 에러 발생 빈도
   - AI 요청 성공률
   - 앱 크래시 리포트

---

## 🔧 6. 로컬 개발 시 실시간 로그 확인

### Mac에서 iOS 디바이스 로그 스트리밍
```bash
# 연결된 기기 확인
xcrun simctl list devices

# 실시간 로그 스트리밍
log stream --device --predicate 'subsystem == "com.yourcompany.deepsleep"'

# 특정 카테고리만 필터링
log stream --device --predicate 'category == "AI" OR category == "UserAction"'
```

### 터미널에서 필터된 로그 보기
```bash
# AI 관련 로그만
log stream --device | grep "\[AI\]"

# 에러 로그만  
log stream --device | grep "ERROR"

# 실시간으로 파일에 저장
log stream --device > deepsleep_logs_$(date +%Y%m%d_%H%M%S).log
```

---

## 📱 7. 배포된 앱 사용자 피드백 수집

### 앱 내 피드백 시스템
```swift
// FeedbackManager.swift
class FeedbackManager {
    static func sendFeedback(message: String, logs: [String]) {
        let feedback = [
            "message": message,
            "logs": logs,
            "timestamp": Date().timeIntervalSince1970,
            "device": UIDevice.current.model,
            "os": UIDevice.current.systemVersion
        ]
        
        // 서버로 전송
        RemoteLogger.shared.sendFeedback(feedback)
    }
}
```

### 사용법
```swift
// 설정 화면에 "피드백 보내기" 버튼 추가
@IBAction func sendFeedbackTapped() {
    let alert = UIAlertController(title: "피드백", message: "의견을 남겨주세요", preferredStyle: .alert)
    
    alert.addTextField { textField in
        textField.placeholder = "피드백 내용..."
    }
    
    alert.addAction(UIAlertAction(title: "전송", style: .default) { _ in
        let message = alert.textFields?.first?.text ?? ""
        let recentLogs = RemoteLogger.shared.getRecentLogs()
        FeedbackManager.sendFeedback(message: message, logs: recentLogs)
    })
    
    present(alert, animated: true)
}
```

---

## 🎯 추천 설정

### 개발/테스트 단계
1. **Xcode Console** - 즉시 디버깅
2. **TestFlight** - 베타 테스터 피드백

### 배포 후 운영
1. **Firebase Crashlytics** - 크래시 및 성능 모니터링
2. **원격 로깅 서버** - 상세한 사용자 행동 분석
3. **앱 내 피드백** - 직접적인 사용자 의견

### 비용 효율적인 시작
1. **Firebase 무료 플랜** - 기본 모니터링
2. **Heroku 무료 티어** - 간단한 로그 서버
3. **TestFlight** - 베타 테스트

이렇게 설정하시면 배포된 앱의 상황을 실시간으로 모니터링할 수 있습니다! 🚀 