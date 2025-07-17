import Testing
@testable import Core
@testable import DeepSleep
import Foundation

/// AITask 엔티티 테스트
/// AI 작업 정의 및 설정 검증
struct AITaskTests {
    
    // MARK: - AITask 타입 테스트
    
    @Test("AITask 타입 매핑 테스트", arguments: [
        (AITask.generalChat(message: "안녕", history: []), AITaskType.generalChat),
        (AITask.analyzeEmotion(text: "기쁨"), AITaskType.analyzeEmotion),
        (AITask.recommendPreset(emotion: "평온", context: SoundRecommendationContext(timeOfDay: "밤", isHeadphonesConnected: true)), AITaskType.recommendPreset),
        (AITask.summarizeDiary(entries: ["일기1"]), AITaskType.summarizeDiary),
        (AITask.analyzeEmotionDiary(diaryContent: "오늘 기분"), AITaskType.analyzeEmotionDiary),
        (AITask.recommendTodo(todos: ["할일1"]), AITaskType.recommendTodo),
        (AITask.generateFortune(userInfo: TestUserInfo(emotionalState: "긍정")), AITaskType.generateFortune),
        (AITask.recommendSound(emotion: "차분", situation: "수면"), AITaskType.recommendSound)
    ])
    func taskTypeMapping(task: AITask, expectedType: AITaskType) {
        #expect(task.type == expectedType, "AITask의 타입이 올바르게 매핑되어야 합니다")
    }
    
    // MARK: - 시스템 프롬프트 테스트
    
    @Test("시스템 프롬프트 존재 확인")
    func systemPromptExists() {
        let tasks: [AITask] = [
            .generalChat(message: "테스트", history: []),
            .analyzeEmotion(text: "테스트"),
            .recommendPreset(emotion: "테스트", context: createTestContext()),
            .summarizeDiary(entries: ["테스트"]),
            .analyzeEmotionDiary(diaryContent: "테스트"),
            .recommendTodo(todos: ["테스트"]),
            .generateFortune(userInfo: TestUserInfo(emotionalState: "테스트")),
            .recommendSound(emotion: "테스트", situation: "테스트")
        ]
        
        for task in tasks {
            #expect(!task.systemPrompt.isEmpty, "\(task.type) 작업의 시스템 프롬프트가 비어있지 않아야 합니다")
            #expect(task.systemPrompt.contains("한국어"), "시스템 프롬프트에 한국어 지시사항이 포함되어야 합니다")
        }
    }
    
    @Test("감정 분석 시스템 프롬프트 검증")
    func emotionAnalysisSystemPrompt() {
        let task = AITask.analyzeEmotion(text: "테스트")
        let prompt = task.systemPrompt
        
        #expect(prompt.contains("감정"), "감정 분석 프롬프트에 '감정' 키워드가 포함되어야 합니다")
        #expect(prompt.contains("분석"), "감정 분석 프롬프트에 '분석' 키워드가 포함되어야 합니다")
        #expect(prompt.contains("한국어"), "한국어 응답 지시사항이 포함되어야 합니다")
    }
    
    @Test("일기 분석 시스템 프롬프트 검증")
    func diaryAnalysisSystemPrompt() {
        let task = AITask.analyzeEmotionDiary(diaryContent: "테스트 일기")
        let prompt = task.systemPrompt
        
        #expect(prompt.contains("심리"), "일기 분석 프롬프트에 '심리' 키워드가 포함되어야 합니다")
        #expect(prompt.contains("공감"), "일기 분석 프롬프트에 '공감' 키워드가 포함되어야 합니다")
        #expect(prompt.contains("긍정적"), "긍정적 분석 지시사항이 포함되어야 합니다")
    }
    
    // MARK: - 요청 설정 테스트
    
    @Test("요청 설정 기본값 검증")
    func requestConfigDefaults() {
        let tasks: [AITask] = [
            .generalChat(message: "테스트", history: []),
            .analyzeEmotion(text: "테스트"),
            .recommendSound(emotion: "테스트", situation: "테스트")
        ]
        
        for task in tasks {
            let config = task.requestConfig
            
            #expect(config.maxTokens > 0, "최대 토큰 수가 0보다 커야 합니다")
            #expect(config.temperature >= 0.0 && config.temperature <= 1.0, 
                   "Temperature가 0.0-1.0 범위에 있어야 합니다")
            #expect(config.topP >= 0.0 && config.topP <= 1.0, 
                   "TopP가 0.0-1.0 범위에 있어야 합니다")
        }
    }
    
    @Test("작업별 특화 설정 검증", arguments: [
        (AITask.analyzeEmotionDiary(diaryContent: "테스트"), 2000, 0.5), // 긴 응답, 낮은 창의성
        (AITask.generateFortune(userInfo: TestUserInfo(emotionalState: "테스트")), 800, 0.9), // 창의적 응답
        (AITask.recommendSound(emotion: "테스트", situation: "테스트"), 300, 0.6) // 짧은 응답
    ])
    func taskSpecificConfig(task: AITask, expectedMaxTokens: Int, expectedTemperature: Double) {
        let config = task.requestConfig
        
        #expect(config.maxTokens == expectedMaxTokens, 
               "\(task.type) 작업의 최대 토큰 수가 \(expectedMaxTokens)이어야 합니다")
        #expect(abs(config.temperature - expectedTemperature) < 0.1, 
               "\(task.type) 작업의 Temperature가 \(expectedTemperature) 근처여야 합니다")
    }
    
    // MARK: - 사용자 프롬프트 테스트
    
    @Test("사용자 프롬프트 생성 테스트")
    func userPromptGeneration() {
        let testMessage = "오늘 기분이 좋아요"
        let task = AITask.generalChat(message: testMessage, history: [])
        
        #expect(task.userPrompt == testMessage, "일반 채팅의 사용자 프롬프트가 메시지와 일치해야 합니다")
    }
    
    @Test("감정 분석 프롬프트 생성")
    func emotionAnalysisPrompt() {
        let testText = "슬픈 감정입니다"
        let task = AITask.analyzeEmotion(text: testText)
        
        #expect(task.userPrompt.contains(testText), "감정 분석 프롬프트에 원본 텍스트가 포함되어야 합니다")
        #expect(task.userPrompt.contains("emotion"), "영어 지시사항이 포함되어야 합니다")
    }
    
    @Test("일기 분석 프롬프트 한국어 검증")
    func diaryAnalysisKoreanPrompt() {
        let diaryContent = "오늘은 정말 힘든 하루였다"
        let task = AITask.analyzeEmotionDiary(diaryContent: diaryContent)
        
        #expect(task.userPrompt.contains(diaryContent), "일기 내용이 프롬프트에 포함되어야 합니다")
        #expect(task.userPrompt.contains("위로"), "위로 관련 지시사항이 포함되어야 합니다")
        #expect(task.userPrompt.contains("힘이 될만한"), "격려 관련 지시사항이 포함되어야 합니다")
    }
    
    // MARK: - 메타데이터 테스트
    
    @Test("메타데이터 생성 테스트")
    func metadataGeneration() {
        let emotion = "기쁨"
        let task = AITask.recommendPreset(emotion: emotion, context: createTestContext())
        let metadata = task.metadata
        
        #expect(metadata["emotion"] == emotion, "감정 정보가 메타데이터에 포함되어야 합니다")
    }
    
    @Test("작업 설명 생성")
    func taskDescription() {
        let tasks: [(AITask, String)] = [
            (.generalChat(message: "테스트", history: []), "General user chat"),
            (.analyzeEmotion(text: "테스트"), "Emotion analysis"),
            (.recommendSound(emotion: "테스트", situation: "테스트"), "Sound recommendation")
        ]
        
        for (task, expectedDescription) in tasks {
            #expect(task.taskDescription == expectedDescription, 
                   "작업 설명이 예상값과 일치해야 합니다")
        }
    }
    
    // MARK: - 메모리 사용 설정 테스트
    
    @Test("메모리 사용 여부 검증", arguments: [
        (AITask.generalChat(message: "테스트", history: []), true),
        (AITask.analyzeEmotionDiary(diaryContent: "테스트"), true),
        (AITask.analyzeEmotion(text: "테스트"), false),
        (AITask.recommendSound(emotion: "테스트", situation: "테스트"), false)
    ])
    func memoryUsageSettings(task: AITask, shouldUseMemory: Bool) {
        #expect(task.shouldUseMemory == shouldUseMemory, 
               "\(task.type) 작업의 메모리 사용 설정이 \(shouldUseMemory)이어야 합니다")
    }
    
    @Test("메모리 추가 기능 테스트")
    func memoryEnhancement() {
        let originalMessage = "오늘 기분이 어때?"
        let memory = "[과거 대화] 어제 운동을 했다고 했음"
        
        let originalTask = AITask.generalChat(message: originalMessage, history: [])
        let enhancedTask = originalTask.with(memory: memory)
        
        if case let .generalChat(enhancedMessage, _) = enhancedTask {
            #expect(enhancedMessage.contains(memory), "메모리가 메시지에 추가되어야 합니다")
            #expect(enhancedMessage.contains(originalMessage), "원본 메시지가 유지되어야 합니다")
        } else {
            #expect(false, "메모리 추가 후에도 같은 작업 타입이어야 합니다")
        }
    }
    
    @Test("메모리 미사용 작업 처리")
    func nonMemoryTaskHandling() {
        let originalTask = AITask.analyzeEmotion(text: "기쁨")
        let taskWithMemory = originalTask.with(memory: "테스트 메모리")
        
        // 메모리를 사용하지 않는 작업은 변경되지 않아야 함
        #expect(originalTask.userPrompt == taskWithMemory.userPrompt, 
               "메모리를 사용하지 않는 작업은 변경되지 않아야 합니다")
    }
}

// MARK: - 테스트 헬퍼

extension AITaskTests {
    
    private struct TestUserInfo {
        let emotionalState: String
    }
    
    private func createTestContext() -> SoundRecommendationContext {
        return SoundRecommendationContext(
            timeOfDay: "저녁",
            isHeadphonesConnected: true
        )
    }
}

// MARK: - 테스트용 모델

private struct SoundRecommendationContext {
    let timeOfDay: String
    let isHeadphonesConnected: Bool
}