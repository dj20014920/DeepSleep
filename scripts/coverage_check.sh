#!/bin/bash
# Usage: ./scripts/coverage_check.sh 80
set -e
THRESHOLD=${1:-80}
REPORT="$(find . -name "*.xcresult" | head -n1)"
if [[ -z "$REPORT" ]]; then
  echo "No .xcresult found. Run tests first."
  exit 1
fi
COVERAGE=$(xcrun xccov view --report --json "$REPORT" | grep -o '"lineCoverage"[^"]*:[^0-9]*[0-9.]*' | head -n1 | grep -o '[0-9.]*$')
COVERAGE_INT=$(echo "$COVERAGE * 100 / 1" | bc)
echo "Current coverage: $COVERAGE_INT% (threshold: $THRESHOLD%)"
if [ "$COVERAGE_INT" -lt "$THRESHOLD" ]; then
  echo "❌ Coverage below threshold!"
  exit 1
else
  echo "✅ Coverage OK"
fi 