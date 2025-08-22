# App Store Connect 인앱 구매 설정 가이드

## 🎯 현재 문제
실제 디바이스에서 앱을 실행하면 App Store Connect에서 상품을 찾으려고 하는데, 아직 등록되지 않아서 로드 실패

## ✅ 해결 방법

### 방법 1: 시뮬레이터 사용 (즉시 가능) ⭐️ 권장
```bash
# 터미널에서 실행
./test_simulator.sh
```

### 방법 2: App Store Connect에 상품 등록 (유료 개발자 계정 필요)

#### 1. App Store Connect 접속
- https://appstoreconnect.apple.com 로그인
- 내 앱 > DeepSleep 선택

#### 2. 인앱 구매 상품 생성
앱 정보 > 기능 > 인앱 구매에서 다음 2개 상품 생성:

##### 상품 1: 월간 구독
- **제품 ID**: `com.deepsleep.premium.monthly`
- **참조 이름**: DeepSleep Premium Monthly
- **구독 유형**: 자동 갱신 구독
- **가격**: ₩9,900
- **구독 기간**: 1개월
- **무료 체험**: 7일 (신규 구독자만)

##### 상품 2: 연간 구독
- **제품 ID**: `com.deepsleep.premium.yearly`
- **참조 이름**: DeepSleep Premium Yearly
- **구독 유형**: 자동 갱신 구독
- **가격**: ₩99,000
- **구독 기간**: 1년
- **무료 체험**: 7일 (신규 구독자만)

#### 3. 구독 그룹 설정
- **그룹 이름**: DeepSleep Premium
- **그룹 ID**: com.deepsleep.subscriptions
- 월간과 연간 상품을 같은 그룹에 포함

#### 4. 심사용 정보 제출
- 스크린샷 업로드
- 설명 텍스트 작성
- 심사 노트 작성

#### 5. 상태 확인
- 상품 상태가 "심사 대기 중" 또는 "판매 준비 완료"인지 확인
- TestFlight 테스트에서는 "심사 대기 중" 상태도 테스트 가능

## 🔧 문제 해결 체크리스트

### 시뮬레이터에서 여전히 상품이 로드되지 않는 경우:

1. **Scheme 설정 확인**
   - Product > Scheme > Edit Scheme
   - Run > Options > StoreKit Configuration
   - "DeepSleep.storekit" 파일 선택 확인

2. **시뮬레이터 리셋**
   ```bash
   # 모든 시뮬레이터 종료 및 초기화
   xcrun simctl shutdown all
   xcrun simctl erase all
   ```

3. **Xcode 캐시 정리**
   - Product > Clean Build Folder (⇧⌘K)
   - Derived Data 삭제: ~/Library/Developer/Xcode/DerivedData

4. **프로젝트 설정 확인**
   - Target > Signing & Capabilities
   - "In-App Purchase" capability 추가되었는지 확인

### 실제 디바이스에서 테스트하는 경우:

1. **개발자 계정 상태**
   - 유료 Apple Developer Program 가입 필요 ($99/년)
   - 무료 계정으로는 인앱 구매 테스트 불가

2. **TestFlight 설정**
   - 앱을 TestFlight에 업로드
   - 테스터 초대
   - TestFlight 앱에서 테스트

3. **Sandbox 테스터 계정**
   - App Store Connect > 사용자 및 액세스 > Sandbox 테스터
   - 테스트용 Apple ID 생성
   - 기기 설정 > App Store > Sandbox 계정으로 로그인

## 📱 현재 권장 테스트 방법

**시뮬레이터를 사용하세요!** 
- 즉시 테스트 가능
- .storekit 파일로 완전한 구매 플로우 시뮬레이션
- 개발자 계정 불필요

```bash
# 시뮬레이터 테스트 실행
./test_simulator.sh
```

Xcode에서:
1. 디바이스를 "iPhone 16 Pro" 시뮬레이터로 변경
2. Edit Scheme > Run > Options > StoreKit Configuration에서 "DeepSleep.storekit" 선택
3. ⌘R로 실행

## 🎉 성공 확인
시뮬레이터에서 다음 로그가 나오면 성공:
```
[IAP] Running in Simulator - using StoreKit Configuration
[IAP] Found product: com.deepsleep.premium.monthly - ...
[IAP] Found product: com.deepsleep.premium.yearly - ...
[IAP] loadProducts finished. count=2
```
