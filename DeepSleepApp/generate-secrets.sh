#!/bin/bash

echo "Enter your Claude API Key:"
read -s CLAUDE_API_KEY
echo "Enter your Naver Cloud API Key:"
read -s NAVER_CLOUD_API_KEY

cat << EOF > "$SECRETS_FILE"
// Secrets configuration for DeepSleep project

GEMINI_API_KEY = $GEMINI_API_KEY
CLAUDE_API_KEY = $CLAUDE_API_KEY
NAVER_CLOUD_API_KEY = $NAVER_CLOUD_API_KEY
EOF

echo "✅ Secrets.xcconfig 파일이 생성되었습니다!"
