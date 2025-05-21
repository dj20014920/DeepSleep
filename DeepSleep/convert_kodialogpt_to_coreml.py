import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import numpy as np
import onnx
from onnx_coreml import convert

# 설정
model_path = "./models/KoDialoGPT"
onnx_path = "kodialogpt_fp32.onnx"
coreml_output_path = "./models/KoDialoGPT_CoreML.mlmodel"
max_length = 128

# 1. Load tokenizer & model
tokenizer = AutoTokenizer.from_pretrained(model_path, use_fast=False)
model = AutoModelForCausalLM.from_pretrained(model_path).eval()

# 2. Wrapper 클래스 정의
class Wrapper(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, input_ids, attention_mask):
        outputs = self.model(input_ids=input_ids, attention_mask=attention_mask, use_cache=False)
        return outputs.logits

wrapped = Wrapper(model)

# 3. Dummy Input 준비
dummy_input_ids = torch.ones((1, max_length), dtype=torch.long)
dummy_attention_mask = torch.ones((1, max_length), dtype=torch.long)

# 4. ONNX Export
torch.onnx.export(
    wrapped,
    (dummy_input_ids, dummy_attention_mask),
    onnx_path,
    input_names=["input_ids", "attention_mask"],
    output_names=["logits"],
    dynamic_axes={"input_ids": {1: "seq_len"}, "attention_mask": {1: "seq_len"}},
    opset_version=13
)

# 5. ONNX → Core ML 변환
onnx_model = onnx.load(onnx_path)
mlmodel = convert(
    model=onnx_model,
    minimum_ios_deployment_target='16',
    inputs=[
        ('input_ids', [1, 128]),
        ('attention_mask', [1, 128])
    ]
)

# 6. 메타데이터 추가
mlmodel.user_defined_metadata["tokenizer_config"] = str({
    "vocab_size": tokenizer.vocab_size,
    "pad_token_id": tokenizer.pad_token_id,
    "eos_token_id": tokenizer.eos_token_id,
    "bos_token_id": tokenizer.bos_token_id,
    "unk_token_id": tokenizer.unk_token_id,
    "max_length": max_length
})

# 7. Core ML 모델 저장
mlmodel.save(coreml_output_path)
print(f"✅ Core ML 모델 변환 완료: {coreml_output_path}")
