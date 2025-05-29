import UIKit

// MARK: - ChatViewController Preset Extension
extension ChatViewController {
    
    // MARK: - Preset Recommendation
    func buildEmotionalPrompt(emotion: String, recentChat: String) -> String {
        return """
        당신은 감정을 이해하고 위로해주는 AI 사운드 큐레이터입니다.
        현재 사용자 감정: \(emotion)
        최근 대화 내용:
        \(recentChat)
        위 정보를 바탕으로 12가지 사운드의 볼륨을 0-100으로 추천해주세요.
        사운드 목록 (순서대로): Rain, Thunder, Ocean, Fire, Steam, WindowRain, Forest, Wind, Night, Lullaby, Fan, WhiteNoise
        각 사운드 설명:
        - Rain: 빗소리 (평온, 집중)
        - Thunder: 천둥소리 (강렬함, 드라마틱)
        - Ocean: 파도소리 (자연, 휴식)
        - Fire: 모닥불소리 (따뜻함, 포근함)
        - Steam: 증기소리 (부드러움)
        - WindowRain: 창가 빗소리 (아늑함)
        - Forest: 숲새소리 (자연, 생동감)
        - Wind: 찬바람소리 (시원함, 청량함)
        - Night: 여름밤소리 (로맨틱, 평화)
        - Lullaby: 자장가 (수면, 위로)
        - Fan: 선풍기소리 (집중, 화이트노이즈)
        - WhiteNoise: 백색소음 (집중, 차단)
        응답 형식: [감정에 맞는 프리셋 이름] Rain:80, Thunder:10, Ocean:60, Fire:0, Steam:20, WindowRain:40, Forest:70, Wind:30, Night:50, Lullaby:0, Fan:20, WhiteNoise:30
        사용자의 감정에 진심으로 공감하며, 그 감정을 달래거나 증진시킬 수 있는 사운드 조합을 추천해주세요.
        """
    }
    
    func getEncouragingMessage(for emotion: String) -> String {
        switch emotion {
        case let e where e.contains("😢") || e.contains("😞"):
            return "이 소리들이 마음을 달래줄 거예요. 천천히 들어보세요 💙"
        case let e where e.contains("😰") || e.contains("😱"):
            return "불안한 마음이 점점 편안해질 거예요. 깊게 숨 쉬어보세요 🌿"
        case let e where e.contains("😴") || e.contains("😪"):
            return "편안한 잠에 빠져보세요. 꿈 속에서도 평온하시길 ✨"
        default:
            return "지금 이 순간을 온전히 느껴보세요 🎶"
        }
    }
    
    // MARK: - Preset Parsing
    func parseRecommendation(from response: String) -> RecommendationResponse? {
        let pattern = #"\[([^\]]+)\]\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)) else {
            return parseBasicFormat(from: response)
        }
        
        let presetName = String(response[Range(match.range(at: 1), in: response)!])
        let valuesString = String(response[Range(match.range(at: 2), in: response)!])
        
        var volumes: [Float] = Array(repeating: 0, count: 12)
        
        let soundMapping: [String: Int] = [
            "Rain": 0, "Thunder": 1, "Ocean": 2, "Fire": 3,
            "Steam": 4, "WindowRain": 5, "Forest": 6, "Wind": 7,
            "Night": 8, "Lullaby": 9, "Fan": 10, "WhiteNoise": 11,
            "Wave": 2, "Bonfire": 3, "ColdWind": 7, "SummerNight": 8,
            "BrownNoise": 11, "PinkNoise": 11, "Noise": 11
        ]
        
        let pairs = valuesString.components(separatedBy: ",")
        for pair in pairs {
            let components = pair.trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
            if components.count == 2,
               let soundName = components.first?.trimmingCharacters(in: .whitespaces),
               let index = soundMapping[soundName],
               let value = Float(components[1].trimmingCharacters(in: .whitespaces)) {
                volumes[index] = min(100, max(0, value))
            }
        }
        
        return RecommendationResponse(volumes: volumes, presetName: presetName)
    }
    
    private func parseBasicFormat(from response: String) -> RecommendationResponse? {
        let emotion = initialUserText ?? "😊"
        
        switch emotion {
        case "😢", "😞", "😔":
            return RecommendationResponse(
                volumes: [60, 10, 70, 0, 0, 20, 80, 30, 25, 60, 20, 40],
                presetName: "위로의 소리"
            )
        case "😰", "😱", "😨":
            return RecommendationResponse(
                volumes: [80, 0, 40, 0, 0, 30, 70, 20, 30, 50, 30, 60],
                presetName: "안정의 소리"
            )
        case "😴", "😪":
            return RecommendationResponse(
                volumes: [40, 0, 30, 0, 0, 60, 40, 40, 50, 90, 50, 70],
                presetName: "깊은 잠의 소리"
            )
        case "😊", "😄", "🥰":
            return RecommendationResponse(
                volumes: [50, 10, 50, 20, 20, 20, 70, 40, 40, 40, 20, 30],
                presetName: "기쁨의 소리"
            )
        case "😡", "😤":
            return RecommendationResponse(
                volumes: [70, 30, 60, 10, 0, 40, 50, 60, 30, 30, 40, 50],
                presetName: "마음 달래는 소리"
            )
        default:
            return RecommendationResponse(
                volumes: [50, 10, 40, 10, 10, 30, 60, 40, 50, 40, 30, 40],
                presetName: "평온의 소리"
            )
        }
    }
}
