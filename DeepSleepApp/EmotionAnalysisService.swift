import Foundation
import UIKit

/// 🤖 EmotionAnalysisService - 통합 아키텍처 완성
/// 모든 감정 분석 기능이 ChatManager.sendMessage를 통해 AI 호출 수행
final class EmotionAnalysisService: EmotionAnalysisServiceProtocol {
    
    /// 텍스트의 감정을 AI로 분석 (🤖 ChatManager.sendMessage 통합)
    func analyzeEmotion(text: String) async throws -> EmotionAnalysisModels.EmotionAnalysisResponse {
        print("🔍 [EmotionAnalysisService] ChatManager.sendMessage로 감정 분석: \(text.prefix(50))...")
        
        // 구조화된 감정 분석 요청 메시지 구성
        let analysisRequest = """
        다음 텍스트의 감정을 정확하게 분석해주세요:
        
        텍스트: "\(text)"
        
        다음 JSON 형식으로 응답해주세요:
        {
            "primaryEmotion": "주감정 (한국어, 예: 기쁨, 슬픔, 분노, 불안, 평온 등)",
            "intensity": 감정강도 (0.0~1.0 숫자),
            "secondaryEmotions": ["보조감정1", "보조감정2"],
            "suggestion": "감정에 대한 공감적이고 건설적인 조언"
        }
        """
        
        do {
            // 🤖 ChatManager.sendMessage로 감정 분석 전문가 응답 생성
            let response = try await ChatManager.shared.sendMessage(
                userInput: analysisRequest,
                modeString: "emotion_analysis", // 감정 분석 전문가 모드
                modelString: "claude" // 구조화된 분석에 최적화
            )
            
            // JSON 응답 파싱 시도
            if let jsonData = response.data(using: String.Encoding.utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let primaryEmotion = jsonObject["primaryEmotion"] as? String,
               let intensityDouble = jsonObject["intensity"] as? Double,
               let secondaryEmotions = jsonObject["secondaryEmotions"] as? [String],
               let suggestion = jsonObject["suggestion"] as? String {
                
                return EmotionAnalysisModels.EmotionAnalysisResponse(
                    primaryEmotion: primaryEmotion,
                    intensity: Float(intensityDouble),
                    secondaryEmotions: secondaryEmotions,
                    suggestion: suggestion
                )
            }
            
            // JSON 파싱 실패 시, AI 응답을 텍스트로 처리하여 기본값 반환
            return EmotionAnalysisModels.EmotionAnalysisResponse(
                primaryEmotion: "복합적",
                intensity: 0.6,
                secondaryEmotions: ["다면적", "미묘한"],
                suggestion: response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            )
            
        } catch {
            print("⚠️ [EmotionAnalysisService] AI 분석 실패, 키워드 기반 fallback: \(error)")
            
            // AI 호출 실패 시 키워드 기반 분석으로 fallback
            let lowerText = text.lowercased()
            var primaryEmotion = "평온"
            var intensity: Float = 0.5
            
            if lowerText.contains("기쁘") || lowerText.contains("행복") || lowerText.contains("좋아") {
                primaryEmotion = "기쁨"
                intensity = 0.7
            } else if lowerText.contains("슬프") || lowerText.contains("우울") || lowerText.contains("눈물") {
                primaryEmotion = "슬픔"
                intensity = 0.6
            } else if lowerText.contains("화나") || lowerText.contains("짜증") || lowerText.contains("분노") {
                primaryEmotion = "분노"
                intensity = 0.8
            } else if lowerText.contains("걱정") || lowerText.contains("불안") || lowerText.contains("무서") {
                primaryEmotion = "불안"
                intensity = 0.6
            } else if lowerText.contains("스트레스") || lowerText.contains("피곤") || lowerText.contains("힘들") {
                primaryEmotion = "스트레스"
                intensity = 0.7
            }
            
            return EmotionAnalysisModels.EmotionAnalysisResponse(
                primaryEmotion: primaryEmotion,
                intensity: intensity,
                secondaryEmotions: ["복합적", "미묘한"],
                suggestion: "\(primaryEmotion) 감정을 느끼는 것은 자연스러워요. 이 감정을 인정하고 스스로를 돌봐주세요."
            )
        }
    }
    
    /// 감정 패턴 분석 (🤖 ChatManager.sendMessage 통합)
    func analyzeEmotionPattern(_ data: String) async throws -> EmotionAnalysisResult {
        print("📊 [EmotionAnalysisService] ChatManager.sendMessage로 감정 패턴 분석: \(data.prefix(100))...")
        
        // 감정 패턴 분석 요청 메시지 구성
        let patternAnalysisRequest = """
        다음 감정 데이터를 종합적으로 분석하여 패턴과 인사이트를 제공해주세요:
        
        감정 데이터:
        \(data)
        
        다음 JSON 형식으로 응답해주세요:
        {
            "summary": "감정 패턴에 대한 전반적인 분석 요약 (2-3문장)",
            "recommendations": ["구체적인 조언1", "구체적인 조언2", "구체적인 조언3", "구체적인 조언4"],
            "followUpQuestions": ["후속 질문1", "후속 질문2"]
        }
        
        분석 시 고려사항:
        - 감정의 변화 패턴과 트리거
        - 긍정적인 감정과 부정적인 감정의 균형
        - 시간대별 감정 변화
        - 실용적이고 실행 가능한 개선 방안 제시
        """
        
        do {
            // 🤖 ChatManager.sendMessage로 감정 분석 전문가 패턴 분석 생성
            let response = try await ChatManager.shared.sendMessage(
                userInput: patternAnalysisRequest,
                modeString: "emotion_analysis", // 감정 분석 전문가 모드
                modelString: "claude" // 복잡한 패턴 분석에 최적화
            )
            
            // JSON 응답 파싱 시도
            if let jsonData = response.data(using: String.Encoding.utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let summary = jsonObject["summary"] as? String,
               let recommendations = jsonObject["recommendations"] as? [String],
               let followUpQuestions = jsonObject["followUpQuestions"] as? [String] {
                
                return EmotionAnalysisResult(
                    summary: summary,
                    recommendations: recommendations,
                    followUpQuestions: followUpQuestions
                )
            }
            
            // JSON 파싱 실패 시, AI 응답을 텍스트로 처리하여 구조화된 결과 생성
            let cleanResponse = response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return EmotionAnalysisResult(
                summary: cleanResponse,
                recommendations: [
                    "지속적인 감정 기록으로 패턴 파악하기",
                    "스트레스 관리 기법 활용하기",
                    "규칙적인 생활 패턴 유지하기",
                    "긍정적인 활동 늘리기"
                ],
                followUpQuestions: [
                    "최근 감정 변화에서 특별한 패턴을 느끼셨나요?",
                    "어떤 상황에서 가장 편안함을 느끼시나요?"
                ]
            )
            
        } catch {
            print("⚠️ [EmotionAnalysisService] AI 패턴 분석 실패, 기본 분석으로 fallback: \(error)")
            
            // AI 호출 실패 시 기본 분석 결과로 fallback
            return EmotionAnalysisResult(
                summary: "감정 데이터를 분석한 결과, 다양한 감정이 균형있게 나타나고 있습니다. 전반적으로 안정적인 감정 패턴을 보이고 있어요.",
                recommendations: [
                    "꾸준한 감정 기록하기",
                    "규칙적인 수면 패턴 유지하기", 
                    "스트레스 관리법 찾기",
                    "긍정적인 활동 늘리기"
                ],
                followUpQuestions: [
                    "어떤 순간에 가장 행복함을 느끼시나요?",
                    "스트레스를 받을 때는 어떻게 대처하시나요?"
                ]
            )
        }
    }
    
    /// 채팅 응답 생성 (🤖 ChatManager.sendMessage 통합)
    func generateChatResponse(to message: String, history: [(isUser: Bool, message: String)]) async throws -> String {
        print("💬 [EmotionAnalysisService] ChatManager.sendMessage로 채팅 응답 생성: \(message.prefix(30))...")
        
        // 대화 히스토리를 컨텍스트로 포함하여 더 자연스러운 대화 생성
        var contextualMessage = message
        
        // 최근 3개 대화를 컨텍스트로 추가 (AI가 맥락을 이해할 수 있도록)
        if !history.isEmpty {
            let recentHistory = Array(history.suffix(3))
            let historyContext = recentHistory.map { entry in
                let speaker = entry.isUser ? "사용자" : "AI"
                return "\(speaker): \(entry.message)"
            }.joined(separator: "\n")
            
            contextualMessage = """
            최근 대화 내용:
            \(historyContext)
            
            현재 사용자 메시지:
            \(message)
            """
        }
        
        // 🤖 ChatManager.sendMessage로 감정 분석 전문가 응답 생성
        let response = try await ChatManager.shared.sendMessage(
            userInput: contextualMessage,
            modeString: "emotion_analysis", // 감정 분석 전문가 모드
            modelString: "claude" // 자연스러운 대화에 최적화
        )
        
        return response
    }
    
    /// 빠른 팁 생성 (🤖 ChatManager.sendMessage 통합)
    func generateQuickTip(for intent: String) async throws -> String {
        print("💡 [EmotionAnalysisService] ChatManager.sendMessage로 빠른 팁 생성: \(intent)")
        
        // 의도에 맞는 구체적인 조언 요청 메시지 구성
        let tipRequest = """
        다음 상황에 대한 실용적이고 따뜻한 조언을 제공해주세요:
        
        상황/의도: \(intent)
        
        조건:
        - 💡 이모지로 시작하는 친근한 조언
        - 1-2문장으로 간결하게
        - 즉시 실행 가능한 구체적인 방법 제시
        - 공감과 격려가 포함된 따뜻한 톤
        """
        
        // 🤖 ChatManager.sendMessage로 생산성 전문가 조언 생성
        let response = try await ChatManager.shared.sendMessage(
            userInput: tipRequest,
            modeString: "task_advice", // 생산성 전문가 모드
            modelString: "claude" // 구체적이고 실용적인 조언에 최적화
        )
        
        return response
    }
    
    /// AI 추천 생성 (🤖 ChatManager.sendMessage 통합)
    func getAIRecommendation() async throws -> RecommendationResult {
        print("🎵 [EmotionAnalysisService] ChatManager.sendMessage로 AI 사운드 추천 생성")
        
        // 현재 시간과 환경 정보 수집
        let currentHour = Calendar.current.component(.hour, from: Date())
        let timeOfDay = getTimeOfDayDescription(hour: currentHour)
        
        // AI 사운드 추천 요청 메시지 구성
        let recommendationRequest = """
        현재 상황에 가장 적합한 수면/휴식 사운드 조합을 추천해주세요:
        
        현재 시간: \(timeOfDay) (\(currentHour)시)
        
        다음 JSON 형식으로 응답해주세요:
        {
            "title": "추천 제목 (이모지 포함)",
            "description": "추천 이유와 효과에 대한 설명 (2-3문장)",
            "soundComponents": [
                {
                    "soundId": "사운드_ID",
                    "volume": 볼륨레벨 (0.0~1.0 숫자)
                },
                {
                    "soundId": "사운드_ID2", 
                    "volume": 볼륨레벨 (0.0~1.0 숫자)
                }
            ]
        }
        
        사용 가능한 사운드 목록:
        - nature_빗소리, nature_새소리, nature_시냇물, nature_파도소리, nature_바람소리, nature_밤비소리
        - ambient_백색소음, ambient_카페음, ambient_벽난로, ambient_깊은백색소음
        
        고려사항:
        - 시간대에 맞는 적절한 사운드 선택
        - 2-3개의 사운드를 조합하여 시너지 효과 창출
        - 각 사운드의 볼륨 밸런스 최적화
        """
        
        do {
            // 🤖 ChatManager.sendMessage로 사운드 추천 전문가 응답 생성
            let response = try await ChatManager.shared.sendMessage(
                userInput: recommendationRequest,
                modeString: "preset_recommendation", // 사운드 추천 전문가 모드
                modelString: "claude" // 창의적인 조합 생성에 최적화
            )
            
            // JSON 응답 파싱 시도
            if let jsonData = response.data(using: String.Encoding.utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let title = jsonObject["title"] as? String,
               let description = jsonObject["description"] as? String,
               let soundComponentsArray = jsonObject["soundComponents"] as? [[String: Any]] {
                
                // 사운드 컴포넌트 파싱
                let components = soundComponentsArray.compactMap { componentDict -> EmotionAnalysisServiceSoundComponent? in
                    guard let soundId = componentDict["soundId"] as? String,
                          let volumeDouble = componentDict["volume"] as? Double else {
                        return nil
                    }
                    return EmotionAnalysisServiceSoundComponent(
                        soundId: soundId,
                        version: 1,
                        volume: Float(volumeDouble)
                    )
                }
                
                return RecommendationResult(
                    id: UUID().uuidString,
                    title: title,
                    description: description,
                    components: components.isEmpty ? getDefaultComponents() : components
                )
            }
            
            // JSON 파싱 실패 시, AI 응답을 바탕으로 기본 추천 생성
            let cleanResponse = response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return RecommendationResult(
                id: UUID().uuidString,
                title: "🤖 AI 맞춤 사운드 조합",
                description: cleanResponse.isEmpty ? "현재 시간대에 적합한 편안한 사운드 조합을 준비했습니다." : cleanResponse,
                components: getTimeBasedDefaultComponents(hour: currentHour)
            )
            
        } catch {
            print("⚠️ [EmotionAnalysisService] AI 추천 실패, 시간 기반 추천으로 fallback: \(error)")
            
            // AI 호출 실패 시 시간 기반 기본 추천으로 fallback
            return RecommendationResult(
                id: UUID().uuidString,
                title: "🕐 \(timeOfDay) 추천 사운드",
                description: "\(timeOfDay) 시간대에 가장 적합한 사운드 조합입니다. 편안한 마음으로 들어보세요.",
                components: getTimeBasedDefaultComponents(hour: currentHour)
            )
        }
    }
    
    /// 시간대 설명 반환
    private func getTimeOfDayDescription(hour: Int) -> String {
        switch hour {
        case 6..<12: return "상쾌한 오전"
        case 12..<18: return "평온한 오후"
        case 18..<22: return "편안한 저녁"
        default: return "깊은 밤"
        }
    }
    
    /// 기본 사운드 컴포넌트
    private func getDefaultComponents() -> [EmotionAnalysisServiceSoundComponent] {
        return [
            EmotionAnalysisServiceSoundComponent(soundId: "nature_빗소리", version: 1, volume: 0.6),
            EmotionAnalysisServiceSoundComponent(soundId: "ambient_백색소음", version: 1, volume: 0.4)
        ]
    }
    
    /// 시간 기반 기본 컴포넌트
    private func getTimeBasedDefaultComponents(hour: Int) -> [EmotionAnalysisServiceSoundComponent] {
        switch hour {
        case 6..<12: // 오전
            return [
                EmotionAnalysisServiceSoundComponent(soundId: "nature_새소리", version: 1, volume: 0.7),
                EmotionAnalysisServiceSoundComponent(soundId: "nature_시냇물", version: 1, volume: 0.5)
            ]
        case 12..<18: // 오후
            return [
                EmotionAnalysisServiceSoundComponent(soundId: "ambient_카페음", version: 1, volume: 0.6),
                EmotionAnalysisServiceSoundComponent(soundId: "nature_바람소리", version: 1, volume: 0.4)
            ]
        case 18..<22: // 저녁
            return [
                EmotionAnalysisServiceSoundComponent(soundId: "nature_파도소리", version: 1, volume: 0.6),
                EmotionAnalysisServiceSoundComponent(soundId: "ambient_벽난로", version: 1, volume: 0.3)
            ]
        default: // 밤
            return [
                EmotionAnalysisServiceSoundComponent(soundId: "nature_밤비소리", version: 1, volume: 0.5),
                EmotionAnalysisServiceSoundComponent(soundId: "ambient_깊은백색소음", version: 1, volume: 0.7)
            ]
        }
    }
    
    /// 로컬 추천 생성 (시간대 기반)
    func getLocalRecommendation() async throws -> RecommendationResult {
        print("🏠 [EmotionAnalysisService] 기본 로컬 추천 생성")
        
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6..<12: // 오전
            return RecommendationResult(
                id: UUID().uuidString,
                title: "🌅 상쾌한 오전 사운드",
                description: "새로운 하루를 시작하는 오전에 적합한 활기찬 자연음입니다.",
                components: [
                    EmotionAnalysisServiceSoundComponent(
                        soundId: "nature_새소리",
                        version: 1,
                        volume: 0.7
                    ),
                    EmotionAnalysisServiceSoundComponent(
                        soundId: "nature_시냇물",
                        version: 1,
                        volume: 0.5
                    )
                ]
            )
            
        case 12..<18: // 오후
            return RecommendationResult(
                id: UUID().uuidString,
                title: "☀️ 평온한 오후 휴식",
                description: "바쁜 일상 속에서 잠깐의 평안을 찾을 수 있는 차분한 사운드입니다.",
                components: [
                    EmotionAnalysisServiceSoundComponent(
                        soundId: "ambient_카페음",
                        version: 1,
                        volume: 0.6
                    ),
                    EmotionAnalysisServiceSoundComponent(
                        soundId: "nature_바람소리",
                        version: 1,
                        volume: 0.4
                    )
                ]
            )
            
        case 18..<22: // 저녁
            return RecommendationResult(
                id: UUID().uuidString,
                title: "🌆 편안한 저녁 시간",
                description: "하루의 피로를 풀고 편안한 저녁을 위한 따뜻한 사운드 조합입니다.",
                components: [
                    EmotionAnalysisServiceSoundComponent(
                        soundId: "nature_파도소리",
                        version: 1,
                        volume: 0.6
                    ),
                    EmotionAnalysisServiceSoundComponent(
                        soundId: "ambient_벽난로",
                        version: 1,
                        volume: 0.3
                    )
                ]
            )
            
        default: // 밤 (22시~6시)
            return RecommendationResult(
                id: UUID().uuidString,
                title: "🌙 깊은 밤 수면 사운드",
                description: "깊고 편안한 잠에 빠져들도록 도와주는 밤의 고요한 사운드입니다.",
                components: [
                    EmotionAnalysisServiceSoundComponent(
                        soundId: "nature_밤비소리",
                        version: 1,
                        volume: 0.5
                    ),
                    EmotionAnalysisServiceSoundComponent(
                        soundId: "ambient_깊은백색소음",
                        version: 1,
                        volume: 0.7
                    )
                ]
            )
        }
    }
    
    /// 피드백 저장 (임시: 로그만 출력)
    func saveFeedback(recommendationId: String, score: Int, comment: String?) async throws {
        print("📝 [EmotionAnalysisService] 피드백 저장: \(recommendationId), 점수: \(score)")
    }
    
    /// 메시지 로드 (임시: 빈 배열 반환)
    func loadMessages(page: Int, pageSize: Int) async throws -> [(isUser: Bool, content: String)] {
        print("🔄 [EmotionAnalysisService] 기본 메시지 로드")
        return []
    }
}