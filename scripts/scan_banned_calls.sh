#!/usr/bin/env bash
set -euo pipefail

# Scan for banned API usages and summarize results.
# - UnifiedAIServiceImpl.shared direct calls outside SessionManager
# - MessageStore.write-path usages

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT_DIR"

FOUND=0

printf "\n== Scan: UnifiedAIServiceImpl.shared (outside SessionManager) ==\n"
matches=$(git grep -n "UnifiedAIServiceImpl\\.shared" -- ':*.swift' || true)
if [[ -n "$matches" ]]; then
  # Filter out SessionManager.swift
  filtered=$(echo "$matches" | grep -v "/SessionManager.swift:" || true)
  if [[ -n "$filtered" ]]; then
    echo "$filtered"
    FOUND=1
  else
    echo "OK (only used inside SessionManager.swift)"
  fi
else
  echo "OK (no matches)"
fi

printf "\n== Scan: MessageStore deprecated write-paths ==\n"
ms=$(git grep -n "MessageStore\\.saveMessage|MessageStore\\.saveSystemMessage" -- ':*.swift' || true)
if [[ -n "$ms" ]]; then
  echo "$ms"
  FOUND=1
else
  echo "OK (no deprecated MessageStore write-paths found)"
fi

printf "\n== Scan: Direct sendMessage outside SessionManager (heuristic) ==\n"
# Heuristic: literal search for "sendMessage(" and filter out approved or harmless cases
sm=$(git grep -n -F "sendMessage(" -- ':*.swift' \
  | grep -v "SessionManager\\.shared\\.sendMessage(" \
  | grep -v "sessionManager\\.sendMessage(" \
  | grep -v "self\\.sessionManager\\.sendMessage(" \
  | grep -vE "^[^:]+:.*func[[:space:]]+sendMessage[[:space:]]*\(" \
  | grep -vE "^DeepSleepApp/AI/Services/" \
  | grep -vE "UnifiedAIService\\.swift:" \
  | grep -vE "^DeepSleepUITests/" \
  | grep -vE "^DeepSleepApp/SessionManager\\.swift:" \
  | grep -vE "^DeepSleepApp/AI/UsageLimitManager\\.swift:" \
  | grep -vE "ChatManager\\.shared\\.sendMessage\(" \
  || true)
if [[ -n "$sm" ]]; then
  echo "$sm"
  FOUND=1
else
  echo "OK (no suspicious sendMessage calls)"
fi

if [[ "$FOUND" -eq 0 ]]; then
  echo "\nAll checks passed."
else
  echo "\nSome issues found. Please fix the above matches."
  exit 1
fi

