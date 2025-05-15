# chat_service.py
from flask import Flask, request, jsonify
from textblob import TextBlob
import random
import requests

app = Flask(__name__)

# 1) Wit.ai 설정
WIT_AI_TOKEN = "YOUR_WIT_AI_SERVER_ACCESS_TOKEN"
WIT_API_URL   = "https://api.wit.ai/message"

# 2) 감정별 프리셋 & 운세 문구 매핑 (예시)
PRESETS = {
    "positive": ["SunnyMorning", "JoyfulBreeze", "BrightForest"],
    "neutral":  ["CalmRain", "WhiteNoise", "SoftWind"],
    "negative": ["WarmFire", "DeepOcean", "GentleNight"]
}
FORTUNES = {
    "positive": ["오늘은 좋은 일이 가득할 거예요!", "행운이 당신 곁에 있습니다."],
    "neutral":  ["평범한 하루, 소소한 행복을 찾아보세요.", "안정된 하루가 되길 바랍니다."],
    "negative": ["내일은 더 나은 날이 될 거예요.", "당신의 노력이 곧 빛을 발할 거예요."]
}

@app.route("/recommend", methods=["POST"])
def recommend():
    data = request.json or {}
    user_text = data.get("text", "")

    # ➊ 감정 분석 (TextBlob)
    polarity = TextBlob(user_text).sentiment.polarity
    if polarity > 0.2:
        sentiment = "positive"
    elif polarity < -0.2:
        sentiment = "negative"
    else:
        sentiment = "neutral"

    # ➋ Wit.ai 로 추가 Entity/Intent 추출 (선택적)
    wit_resp = requests.get(
        WIT_API_URL,
        params={"q": user_text},
        headers={"Authorization": f"Bearer {WIT_AI_TOKEN}"}
    ).json()
    # (예: wit_resp["entities"] 활용 가능)

    # ➌ AI 스타일 공감 메시지 생성 (템플릿+랜덤)
    empathy_templates = {
        "positive": [
            "좋은 하루 보내셨군요! 당신의 미소가 인상적이에요.",
            "행복이 느껴져요! 그 기운 그대로 이어가길 바랍니다."
        ],
        "neutral": [
            "오늘은 특별한 일 없이 지나갔네요. 소소한 힐링이 필요할 때예요.",
            "평온한 하루, 마음의 안정을 느껴보세요."
        ],
        "negative": [
            "힘든 하루를 보내셨네요. 잘 견뎌내셨어요.",
            "마음이 무거웠다면 이 음악이 작은 위로가 되길 바랍니다."
        ]
    }
    empathy = random.choice(empathy_templates[sentiment])

    # ➍ 오늘의 운세 문구
    fortune = random.choice(FORTUNES[sentiment])

    # ➎ 프리셋 이름 + 볼륨(랜덤)
    preset_name = random.choice(PRESETS[sentiment])
    volumes = [round(random.uniform(20, 80), 1) for _ in range(12)]

    # ➏ 버튼 프롬프트
    prompt = "이 프리셋 적용해보기"

    return jsonify({
        "empathy": empathy,
        "fortune": fortune,
        "presetName": preset_name,
        "volumes": volumes,
        "prompt": prompt
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
