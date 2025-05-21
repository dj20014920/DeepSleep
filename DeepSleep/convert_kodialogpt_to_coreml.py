import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import coremltools as ct
import os

# ✅ 설정값
MODEL_NAME = "lcw99/ko-dialoGPT-korean-chit-chat"
MAX_LENGTH = 128
BATCH_SIZE = 1

# ✅ 모델 및 토크나이저 로드
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = AutoModelForCausalLM.from_pretrained(MODEL_NAME)

# ✅ FP16 양자화
model.half()
model.eval()

# ✅ 입력 샘플 정의
dummy_input_ids = torch.ones((BATCH_SIZE, MAX_LENGTH), dtype=torch.long)
dummy_attention_mask = torch.ones((BATCH_SIZE, MAX_LENGTH), dtype=torch.long)

# ✅ TorchScript 추적 (주의: GPT2 계열은 trace 시 제한적 → ONNX 경로가 더 안정적임)
traced_model = torch.jit.trace(
    model,
    (dummy_input_ids, dummy_attention_mask),
    strict=False
)

# ✅ CoreML 변환
mlmodel = ct.convert(
    traced_model,
    inputs=[
        ct.TensorType(name="input_ids", shape=(BATCH_SIZE, MAX_LENGTH), dtype=torch.int64),
        ct.TensorType(name="attention_mask", shape=(BATCH_SIZE, MAX_LENGTH), dtype=torch.int64)
    ],
    convert_to="mlprogram",  # 반드시 ML Program (MLPackage) 사용
    compute_units=ct.ComputeUnit.ALL,
    minimum_deployment_target=ct.target.iOS16,
    compute_precision=ct.precision.FLOAT16,  # FP16
    skip_model_load=False,
    package_dir="./models/KoDialoGPT_CoreML"
)

# ✅ 메타데이터 추가
mlmodel.user_defined_metadata.update({
    "model": "DialoGPT-Ko",
    "source": MODEL_NAME,
    "max_length": str(MAX_LENGTH),
    "tokenizer": "included_separately"
})

# ✅ 모델 저장
mlmodel.save("./models/KoDialoGPT.mlpackage")

# ✅ tokenizer 저장 (Swift와 연동 시 필요)
tokenizer.save_pretrained("./models/coreml_tokenizer")

print("✅ Core ML 변환 완료: KoDialoGPT.mlpackage + tokenizer 저장됨")
