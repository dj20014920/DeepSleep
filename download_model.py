from transformers import AutoModelForCausalLM, AutoTokenizer

model_name = "lcw99/ko-dialoGPT-Korean-Chit-Chat"

# 모델과 토크나이저 다운로드 및 저장
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForCausalLM.from_pretrained(model_name)

model.save_pretrained("ko_dialogpt_model")
tokenizer.save_pretrained("ko_dialogpt_model")

print("✅ 모델과 토크나이저가 ko_dialogpt_model 폴더에 저장되었습니다.")
