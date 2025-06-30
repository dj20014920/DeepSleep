# DeepSleep - AI 수면 동반자 앱 🌙

> **사용자가 짧게 말해도 AI가 길고 정성스럽게 대화하는 수면/휴식 특화 iOS 앱**

## 🎯 프로젝트 현황 (2025.06.23)

### ✅ 완료된 작업
- **대규모 데이터셋 확보**: 150,822개 고품질 한국어 대화 데이터
- **iOS 앱 빌드 안정화**: BUILD SUCCEEDED 달성
- **채팅 시스템 통합**: 7개 분산 파일을 단일 ChatViewController로 통합
- **파인튜닝 준비 완료**: 종합 데이터셋 및 스크립트 준비

### 📊 데이터셋 현황
- **총 대화 수**: 150,822개
- **평균 사용자 입력**: 37.3자 (짧은 입력)
- **평균 AI 응답**: 168.2자 (긴 도움 응답)
- **고품질 데이터**: 55,337개 (36.7%)
- **프리미엄 데이터**: 33,662개 (22.3%)

## 🚀 핵심 기능

### 1. 지능형 AI 대화
```
사용자: "잠이 안 와"
AI: "잠이 안 오시는군요. 마음이 복잡하거나 스트레스 때문일 수 있어요. 
     먼저 깊게 숨을 들이쉬고 천천히 내쉬어보세요. 
     수면에 도움되는 자연 소리는 어떠세요? 
     빗소리나 파도소리 같은 것들이 마음을 진정시켜줄 거예요. 
     어떤 소리를 들어보고 싶으신가요?"
```

### 2. 수면 최적화 사운드
- 🌧️ 자연음 (빗소리, 파도소리, 새소리)
- 🎵 화이트노이즈 (팬소리, 키보드 소리)
- 🧘 명상음악 (피아노, 환경음)

### 3. 감정 분석 & 일기
- 일일 감정 상태 분석
- AI 기반 맞춤 추천
- 수면 패턴 트래킹

## 📱 기술 스택

### iOS 앱
- **언어**: Swift 5.9
- **UI**: SwiftUI + UIKit 하이브리드
- **아키텍처**: MVVM + Clean Architecture
- **데이터**: Core Data + UserDefaults

### AI/ML
- **베이스 모델**: polyglot-ko-5.8b
- **파인튜닝**: LoRA/QLoRA 기법
- **데이터셋**: 150,822개 한국어 대화
- **특화**: 긴 응답 생성 최적화

### 데이터 파이프라인
- **수집**: HuggingFace Datasets API
- **전처리**: Python + Pandas
- **품질 관리**: 자동 필터링 + 수동 검증
- **형식**: Alpaca 표준 (instruction-input-output)

## 🏗️ 프로젝트 구조

```
DeepSleep/
├── DeepSleepApp/                    # iOS 앱 소스
│   ├── AI/                         # AI 엔진
│   ├── Chat/                       # 채팅 시스템
│   ├── Sound/                      # 사운드 관리
│   └── Views/                      # UI 컴포넌트
├── comprehensive_finetuning/        # 파인튜닝 데이터
│   ├── deepsleep_comprehensive_dataset_*.jsonl  # 150K 데이터셋
│   └── start_comprehensive_finetuning.py        # 파인튜닝 스크립트
├── massive_korean_datasets/         # 대규모 데이터
└── scripts/                        # 유틸리티 스크립트
```

## 🚀 시작하기

### 1. iOS 앱 빌드
```bash
# 프로젝트 클론
git clone https://github.com/dj20014920/DeepSleep.git
cd DeepSleep

# Xcode에서 열기
open DeepSleep.xcodeproj

# 시뮬레이터에서 실행
xcodebuild -project DeepSleep.xcodeproj \
  -scheme DeepSleep \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  build
```

### 2. AI 모델 파인튜닝 (선택사항)
```bash
# 파인튜닝 디렉토리로 이동
cd comprehensive_finetuning

# 필요한 라이브러리 설치
pip install transformers datasets torch peft

# 파인튜닝 실행 (GPU 권장)
python start_comprehensive_finetuning.py
```

## 📈 성능 지표

### 데이터셋 품질
- **평균 품질 점수**: 0.854/1.0
- **데이터 다양성**: 7개 소스 통합
- **언어 자연성**: 메신저 스타일 대화

### 앱 성능
- **빌드 성공률**: 100% (경고 0개)
- **메모리 사용량**: 최적화 완료
- **UI 응답성**: 60fps 목표

## 🔮 로드맵

### Phase 1: 파인튜닝 완료 (진행 중)
- [x] 대규모 데이터셋 확보
- [ ] 모델 파인튜닝 실행
- [ ] 성능 검증 및 최적화

### Phase 2: 앱 완성도 향상
- [ ] AI 모델 iOS 앱 통합
- [ ] 사용자 인터페이스 개선
- [ ] 베타 테스트 진행

### Phase 3: 출시 준비
- [ ] 앱스토어 제출
- [ ] 마케팅 및 홍보
- [ ] 사용자 피드백 수집

## 🤝 기여하기

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 `LICENSE` 파일을 참조하세요.

## 📞 연락처

- **개발자**: DJ (dj20014920)
- **이메일**: [이메일 주소]
- **GitHub**: https://github.com/dj20014920/DeepSleep

---

**DeepSleep과 함께 더 나은 잠을 경험하세요! 🌙✨**

## 📦 빌드 & 테스트 배지

[![CI](https://github.com/dj20014920/DeepSleep/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/dj20014920/DeepSleep/actions/workflows/ios-ci.yml)
[![codecov](https://codecov.io/gh/dj20014920/DeepSleep/branch/ai_hybrid/graph/badge.svg?token=CODECOV_TOKEN)](https://codecov.io/gh/dj20014920/DeepSleep)

## 🚦 로컬 테스트/커버리지

```sh
# 전체 테스트 및 커버리지 측정
xcodebuild test -scheme DeepSleep -destination 'platform=iOS Simulator,name=iPhone 16' -enableCodeCoverage YES
# Fastlane 사용
bundle exec fastlane test
# 커버리지 80% 미만 시 실패 처리
./scripts/coverage_check.sh 80
```

## 🤖 CI 자동화
- GitHub Actions: `.github/workflows/ios-ci.yml` (iOS 16.4/17.4, codecov 연동)
- Fastlane: `fastlane test`, `fastlane beta`, `fastlane release` 지원
- 커버리지 80% 미만 시 워크플로 실패

## 🛠️ 환경 변수/Secrets
- `CODECOV_TOKEN` (codecov 업로드용)

## Full AI Pipeline Automation
We provide a one-command automated pipeline covering tokenizer update, tokenization tests, dataset generation, preprocessing, end-to-end integration, and iOS app build.

### Prerequisites
- macOS with Xcode 15.3
- Python 3.x

### Usage
```bash
# Install dependencies
make setup

# Download tokenizer and verify
make tokenizer

# Run tokenization tests (Python & Swift)
make test-python
make test-swift

# Generate and preprocess dataset
make dataset
make preprocess

# Run end-to-end integration tests (Python & Swift)
make test-e2e
make test-e2e-coreml
make test-e2e-swift

# Run LoRA and edge case tests
make test-lora
make test-edge

# Run snapshot tests
make snapshot

# Build iOS app
make build

# Send failure notifications
make notify

# Run entire pipeline
make all
```

### CI Integration (GitHub Actions)
The `.github/workflows/ci.yml` file runs `make all` on push and pull requests to `main` and uploads `logs/` as artifacts.

### Troubleshooting & Backup
See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common errors and recovery steps.

### Backup
```bash
bash scripts/backup_pipeline.sh
```

---

