# KoDialoGPT 모델 파일 다운로드 스크립트
# 실행 위치: 프로젝트 루트 (DeepSleep 폴더 기준)

mkdir -p DeepSleep/models/KoDialoGPT
mkdir -p DeepSleep/exported

# ✅ Core ML 모델
echo "\n📥 Model.mlpackage 다운로드 중..."
curl -L -o DeepSleep/exported/Model.mlpackage.zip \
  https://github.com/dj20014920/DeepSleep/releases/download/mlmodel-fp16/Model.mlpackage.zip

unzip -o DeepSleep/exported/Model.mlpackage.zip -d DeepSleep/exported/
rm DeepSleep/exported/Model.mlpackage.zip

# ✅ ONNX 변환 파일
echo "\n📥 kodialogpt_fp32.onnx 다운로드 중..."
curl -L -o DeepSleep/kodialogpt_fp32.onnx \
  https://github.com/dj20014920/DeepSleep/releases/download/mlmodel-fp16/kodialogpt_fp32.onnx

# ✅ PyTorch 모델 파라미터
echo "\n📥 model.safetensors 다운로드 중..."
curl -L -o DeepSleep/models/KoDialoGPT/model.safetensors \
  https://github.com/dj20014920/DeepSleep/releases/download/mlmodel-fp16/model.safetensors


# ✅ 완료 메시지
echo "\n✅ 모든 모델 파일 다운로드 완료!"
