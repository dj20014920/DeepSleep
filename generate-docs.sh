#!/bin/bash
# DocC 문서 자동 생성 스크립트 (macOS/Xcode 16)
set -e
SCHEME="DeepSleep"
OUT_DIR="Documentation"

# DerivedData 경로 자동 추출
DERIVED_DATA=$(mktemp -d)

xcodebuild doc \
  -scheme "$SCHEME" \
  -derivedDataPath "$DERIVED_DATA" \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -skipPackagePluginValidation \
  -quiet

# DocC 결과 복사
DOC_ARCHIVE=$(find "$DERIVED_DATA" -name '*.doccarchive' | head -n1)
if [[ -z "$DOC_ARCHIVE" ]]; then
  echo "❌ DocC archive not found."
  exit 1
fi
mkdir -p "$OUT_DIR"
cp -R "$DOC_ARCHIVE" "$OUT_DIR/"
echo "✅ DocC 문서가 $OUT_DIR/에 생성되었습니다." 