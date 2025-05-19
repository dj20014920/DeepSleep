import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
import coremltools as ct

# 1. 모델 로드
model = AutoModelForCausalLM.from_pretrained("lcw99/ko-dialoGPT-Korean-Chit-Chat")
tokenizer = AutoTokenizer.from_pretrained("lcw99/ko-dialoGPT-Korean-Chit-Chat")
model.eval()

# 2. 입력 샘플 생성
example_input = tokenizer("안녕?", return_tensors="pt")
input_ids = example_input["input_ids"]

# 3. forward 함수 단순화
traced_model = torch.jit.trace(model, input_ids)

# 4. CoreML 변환
mlmodel = ct.convert(
    traced_model,
    inputs=[ct.TensorType(shape=input_ids.shape, name="input_ids", dtype=int)],
    convert_to="mlprogram",
    compute_units=ct.ComputeUnit.CPU_AND_NE,
    minimum_deployment_target=ct.target.iOS13,
)

# 5. 저장
mlmodel.save("ko_dialogpt_8bit.mlpackage")
print("✅ CoreML 변환 성공: ko_dialogpt_8bit.mlpackage")
