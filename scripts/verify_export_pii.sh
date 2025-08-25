#!/usr/bin/env bash
# verify_export_pii.sh
# 목적: Swift 코드에서 UIActivityViewController로 텍스트를 공유/내보내기 하는 모든 경로가
#       SettingsManager.maskPIIForExport 또는 exportUserDataSanitized/sanitizePII를 거쳤는지 정적 검사합니다.
# 사용법:
#   bash scripts/verify_export_pii.sh
# CI:
#   - GitHub Actions 등에서 빌드 전 단계에 실행하여 위반 시 실패(exit 1) 처리하세요.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
cd "$ROOT_DIR"

# 검색 대상: Swift 소스 전체
# git이 없거나 워킹트리가 아닐 경우 find로 대체
SWIFT_FILES=$(git ls-files '*.swift' 2>/dev/null || true)
if [[ -z "$SWIFT_FILES" ]]; then
  SWIFT_FILES=$(find . -type f -name '*.swift')
fi

if [[ -z "$SWIFT_FILES" ]]; then
  echo "No Swift files found. Skipping PII export verification."
  exit 0
fi

# 허용되는 마스킹 함수 패턴(근처에 존재해야 함)
MASK_ALLOW_REGEX='maskPIIForExport\(|exportUserDataSanitized\(|sanitizePII\('

# UIActivityViewController 생성 패턴
UI_ACTIVITY_REGEX='UIActivityViewController\s*\(\s*activityItems:\s*\['

# iOS 16+ UIEditMenuInteraction 내 공유도 동일 규칙 적용됨(이미 동일 생성자 사용)

VIOLATIONS=()

# 각 Swift 파일에서 UIActivityViewController 사용 라인 추출 후, 주변 40줄 범위 내 마스킹 함수 호출 확인

# macOS 기본 bash(3.2) 호환: mapfile/arrays 미사용
VIOLATIONS=""

for file in $SWIFT_FILES; do
  match_lines=$(grep -nE "$UI_ACTIVITY_REGEX" "$file" | cut -d: -f1 || true)
  if [[ -z "$match_lines" ]]; then
    continue
  fi
  for line_no in $match_lines; do
    start=$(( line_no > 40 ? line_no - 40 : 1 ))
    end=$(( line_no + 40 ))
    snippet=$(sed -n "${start},${end}p" "$file")
    if ! printf "%s" "$snippet" | grep -Eq "$MASK_ALLOW_REGEX"; then
      if ! printf "%s" "$snippet" | grep -Eq "//[[:space:]]*PII_OK"; then
        VIOLATIONS="$VIOLATIONS $file:$line_no"
      fi
    fi
  done
done

if [[ -n "$VIOLATIONS" ]]; then
  echo "❌ PII export verification failed. The following locations use UIActivityViewController without nearby PII masking:"
  for v in $VIOLATIONS; do
    echo "  - $v"
  done
  echo "\nFix guidance: Ensure the shared text is passed through SettingsManager.shared.maskPIIForExport(...), exportUserDataSanitized(...), or sanitizePII(...)."
  echo "If this is a safe non-PII case (e.g., deterministic static string), add a local comment // PII_OK in the nearby lines as an explicit waiver."
  exit 1
else
  echo "✅ PII export verification passed: all UIActivityViewController text exports are masked."
fi

