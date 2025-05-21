from transformers import AutoTokenizer, AutoModelForCausalLM

# ✅ 존재하는 모델 ID로 변경!
model_name = "lcw99/ko-dialoGPT-korean-chit-chat"

# 모델과 토크나이저 다운로드
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(model_name)

# 원하는 경로에 저장 (Core ML 변환용)
model.save_pretrained("./models/KoDialoGPT")
tokenizer.save_pretrained("./models/KoDialoGPT")
