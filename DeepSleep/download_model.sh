#!/bin/bash
echo "📥 KoDialoGPT Core ML 모델 다운로드 중..."

curl -L -o exported/Model.mlpackage.zip https://github.com/dj20014920/DeepSleep/releases/download/mlmodel-fp16/Model.mlpackage.zip

unzip -o exported/Model.mlpackage.zip -d exported/
rm exported/Model.mlpackage.zip

echo "✅ 다운로드 완료"