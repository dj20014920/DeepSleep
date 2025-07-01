import Foundation

class EmotionResponseManager {
    static let shared = EmotionResponseManager()
    
    private init() {}
    
    // 이모지별 응답 데이터
    private let emotionResponses: [String: [EmotionResponse]] = [
        "😴": [ // 졸림
            EmotionResponse(
                messages: [
                    "졸린 하루네요! 편안한 잠자리로 안내해드릴게요 💤",
                    "잠이 솔솔 오는군요~ 달콤한 꿈나라로 떠나볼까요?",
                    "피곤하신가 봐요. 깊은 휴식을 위한 사운드를 준비했어요",
                    "졸음이 몰려오네요! 평화로운 밤을 위한 조합이에요"
                ],
                presets: [
                    PresetData(name: "꿀잠 조합", volumes: [0, 30, 0, 25, 35, 0, 0, 0, 0, 15, 0]),
                    PresetData(name: "달콤한 자장가", volumes: [0, 0, 0, 20, 40, 0, 0, 0, 0, 25, 0]),
                    PresetData(name: "편안한 휴식", volumes: [0, 25, 0, 0, 30, 0, 0, 0, 0, 20, 0]),
                    PresetData(name: "깊은 잠 유도", volumes: [0, 35, 0, 15, 25, 0, 0, 0, 0, 30, 0])
                ]
            )
        ],
        "😢": [ // 슬픔
            EmotionResponse(
                messages: [
                    "마음이 무거우시군요. 따뜻한 위로가 되는 소리를 들어보세요 🤗",
                    "슬픈 감정도 소중해요. 차분히 마음을 달래주는 사운드예요",
                    "힘든 하루였나요? 마음을 어루만져주는 조합을 준비했어요",
                    "괜찮아요, 모든 감정은 지나갑니다. 평온함을 찾아드릴게요"
                ],
                presets: [
                    PresetData(name: "마음의 위로", volumes: [0, 40, 0, 20, 0, 0, 0, 0, 0, 25, 0]),
                    PresetData(name: "따뜻한 포옹", volumes: [0, 30, 0, 25, 15, 0, 0, 0, 0, 20, 0]),
                    PresetData(name: "차분한 힐링", volumes: [0, 35, 0, 15, 20, 0, 0, 0, 0, 30, 0]),
                    PresetData(name: "감정 정화", volumes: [0, 25, 0, 30, 0, 0, 0, 0, 0, 35, 0])
                ]
            )
        ],
        "😠": [ // 화남
            EmotionResponse(
                messages: [
                    "화가 나셨군요! 마음을 진정시키는 소리로 안정감을 찾아보세요 🌊",
                    "분노의 감정이 느껴져요. 차가운 바람 소리로 마음을 식혀보세요",
                    "흥분된 마음을 달래드릴게요. 자연의 소리가 도움이 될 거예요",
                    "화난 마음, 이해해요. 평정심을 되찾는 사운드 조합이에요"
                ],
                presets: [
                    PresetData(name: "분노 해소", volumes: [15, 0, 30, 0, 0, 25, 0, 0, 0, 0, 20]),
                    PresetData(name: "마음 진정", volumes: [20, 0, 25, 0, 0, 30, 0, 0, 0, 0, 15]),
                    PresetData(name: "차가운 바람", volumes: [10, 0, 35, 0, 0, 20, 0, 0, 0, 0, 25]),
                    PresetData(name: "감정 정리", volumes: [25, 0, 20, 0, 0, 35, 0, 0, 0, 0, 10])
                ]
            )
        ],
        "😊": [ // 행복함
            EmotionResponse(
                messages: [
                    "기분이 좋으시네요! 즐거운 에너지를 더해줄 사운드예요 ✨",
                    "행복한 순간이군요~ 긍정적인 바이브의 조합을 준비했어요",
                    "좋은 하루인가 봐요! 밝은 에너지의 사운드로 더 기분 좋게 💫",
                    "미소가 보이는 것 같아요! 즐거운 시간을 위한 특별한 조합이에요"
                ],
                presets: [
                    PresetData(name: "행복한 순간", volumes: [25, 0, 0, 30, 0, 0, 20, 0, 0, 0, 15]),
                    PresetData(name: "긍정 에너지", volumes: [30, 0, 0, 25, 0, 0, 15, 0, 0, 0, 20]),
                    PresetData(name: "즐거운 시간", volumes: [20, 0, 0, 35, 0, 0, 25, 0, 0, 0, 10]),
                    PresetData(name: "밝은 하루", volumes: [35, 0, 0, 20, 0, 0, 30, 0, 0, 0, 5])
                ]
            )
        ],
        "😔": [ // 우울함
            EmotionResponse(
                messages: [
                    "우울한 기분이시군요. 따스한 감싸주는 소리로 위로받아보세요 💙",
                    "마음이 가라앉아 있나요? 부드러운 사운드로 마음을 어루만져드릴게요",
                    "힘이 없는 하루네요. 조용히 마음을 달래주는 조합이에요",
                    "우울한 감정도 괜찮아요. 천천히 회복할 수 있도록 도와드릴게요"
                ],
                presets: [
                    PresetData(name: "우울함 달래기", volumes: [0, 35, 0, 15, 25, 0, 0, 0, 0, 20, 0]),
                    PresetData(name: "마음의 안식", volumes: [0, 30, 0, 20, 30, 0, 0, 0, 0, 15, 0]),
                    PresetData(name: "부드러운 위로", volumes: [0, 40, 0, 10, 20, 0, 0, 0, 0, 25, 0]),
                    PresetData(name: "고요한 치유", volumes: [0, 25, 0, 25, 35, 0, 0, 0, 0, 10, 0])
                ]
            )
        ],
        "😐": [ // 평범함
            EmotionResponse(
                messages: [
                    "평범한 하루네요! 일상에 작은 특별함을 더해보세요 🎵",
                    "무난한 기분이군요. 적당히 기분 전환이 되는 사운드예요",
                    "그냥 그런 하루인가요? 은은한 배경 사운드로 분위기를 바꿔보세요",
                    "평온한 상태네요. 일상의 리듬감을 더해줄 조합이에요"
                ],
                presets: [
                    PresetData(name: "일상의 선율", volumes: [15, 15, 15, 15, 15, 15, 0, 0, 0, 0, 0]),
                    PresetData(name: "무난한 배경", volumes: [20, 10, 20, 10, 20, 10, 0, 0, 0, 0, 0]),
                    PresetData(name: "평범한 특별함", volumes: [10, 20, 10, 20, 10, 20, 0, 0, 0, 0, 0]),
                    PresetData(name: "균형잡힌 하루", volumes: [18, 12, 18, 12, 18, 12, 0, 0, 0, 0, 0])
                ]
            )
        ]
    ]
    
    // 랜덤 응답 가져오기
    func getRandomResponse(for emoji: String) -> EmotionResponse? {
        guard let responses = emotionResponses[emoji] else { return nil }
        return responses.randomElement()
    }
    
    // 특정 이모지의 모든 응답 가져오기
    func getAllResponses(for emoji: String) -> [EmotionResponse] {
        return emotionResponses[emoji] ?? []
    }
}

// MARK: - 데이터 모델
struct EmotionResponse {
    let messages: [String]
    let presets: [PresetData]
    
    // 랜덤 메시지 가져오기
    var randomMessage: String {
        return messages.randomElement() ?? "오늘 기분은 어떤가요?"
    }
    
    // 랜덤 프리셋 가져오기
    var randomPreset: PresetData {
        return presets.randomElement() ?? PresetData(name: "기본 조합", volumes: Array(repeating: 20, count: 11))
    }
}

struct PresetData {
    let name: String
    let volumes: [Int]
    
    // Float 배열로 변환
    var floatVolumes: [Float] {
        return volumes.map { Float($0) }
    }
} 
