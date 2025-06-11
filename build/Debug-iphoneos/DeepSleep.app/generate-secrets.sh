#!/bin/bash

echo "🔐 Replicate API 키를 입력하세요:"
read -p "API 키: " TOKEN

cat <<EOF > Secrets.xcconfig
REPLICATE_API_TOKEN = $TOKEN
EOF

echo "✅ Secrets.xcconfig 파일이 생성되었습니다!"
