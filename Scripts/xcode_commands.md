# Xcode 파일 동기화 해결 방법

## 문제
Xcode 외부에서 파일을 생성/삭제하면 Xcode가 자동으로 인식하지 못하는 문제

## 해결 방법들

### 1. 수동 새로고침 (가장 간단)
Xcode에서 다음 단축키 사용:
- **`Cmd + Option + U`** : 프로젝트 전체 새로고침
- **`Cmd + Shift + K`** : Clean Build Folder
- **`Cmd + B`** : 다시 빌드

### 2. 자동 감시 스크립트 실행
```bash
# fswatch 설치 (처음 한번만)
brew install fswatch

# 스크립트 실행
./Scripts/xcode_refresh.sh
```

### 3. 터미널에서 Xcode 새로고침 명령어
```bash
# Xcode 새로고침 함수 추가 (.zshrc 또는 .bash_profile에 추가)
xcode-refresh() {
    osascript -e 'tell application "Xcode"
        if (count of windows) > 0 then
            tell application "System Events"
                tell process "Xcode"
                    keystroke "u" using {command down, option down}
                end tell
            end tell
        end if
    end tell'
    echo "Xcode refreshed!"
}

# 사용법
xcode-refresh
```

### 4. 파일 추가 시 자동 스크립트
```bash
# 파일 생성 후 자동으로 Xcode 새로고침
xcode-add() {
    local file="$1"
    touch "$file"
    xcode-refresh
}

# 사용 예
xcode-add "NewFile.swift"
```

### 5. Xcode 프로젝트 설정 개선
1. Xcode > Preferences > General
2. "Show live issues" 활성화
3. "Continue building after errors" 활성화

### 6. 파일 시스템 이벤트 강제 트리거
```bash
# 프로젝트 디렉토리 터치 (타임스탬프 갱신)
touch DeepSleep.xcodeproj

# 또는 프로젝트 파일 직접 터치
touch DeepSleep.xcodeproj/project.pbxproj
```

## 권장 워크플로우

1. **개발 중**: 터미널과 Xcode를 함께 사용할 때
   - 파일 생성/삭제 후 `Cmd + Option + U` 단축키 사용
   - 또는 터미널에서 `xcode-refresh` 명령어 실행

2. **대량 파일 작업**: 많은 파일을 한번에 추가/삭제할 때
   - 작업 완료 후 Xcode에서 프로젝트 닫고 다시 열기
   - 또는 `Product > Clean Build Folder` 실행

3. **자동화 필요 시**: 
   - `./Scripts/xcode_refresh.sh` 백그라운드 실행
   - 작업 완료 후 Ctrl+C로 종료

### 7. 누락된 파일을 프로젝트에 추가하기
파일이 존재하지만 Xcode에서 보이지 않는 경우:

```bash
# 모든 누락된 Swift 파일을 자동 감지하여 추가
python3 Scripts/add_missing_files.py

# 특정 파일만 추가
python3 Scripts/add_missing_files.py "NewFile.swift" "AnotherFile.swift"

# 그 후 Xcode 새로고침
xcode-refresh
```

**수동으로 추가하는 방법**:
1. Xcode에서 `File > Add Files to "DeepSleep"...` 선택
2. 추가하려는 파일/폴더 선택 
3. **중요**: `Copy items if needed` 체크 **해제** (이미 프로젝트 내부에 있으므로)
4. `Add to targets`에서 `DeepSleep` 선택
5. `Add` 클릭

### 8. 프로젝트 파일 백업 및 복구
```bash
# 백업 생성 (스크립트가 자동으로 생성함)
cp DeepSleep.xcodeproj/project.pbxproj DeepSleep.xcodeproj/project.pbxproj.backup

# 문제 발생 시 복구
cp DeepSleep.xcodeproj/project.pbxproj.backup DeepSleep.xcodeproj/project.pbxproj
```

## 추가 팁

- Xcode 15 이상에서는 파일 시스템 감시가 개선되었지만 여전히 완벽하지 않음
- Swift Package Manager를 사용하는 경우 `.package.resolved` 파일도 함께 새로고침 필요
- 큰 프로젝트의 경우 인덱싱 시간이 걸릴 수 있으므로 잠시 대기 필요
- **파일이 존재하지만 Xcode에서 안 보이는 경우**: `add_missing_files.py` 스크립트 사용
