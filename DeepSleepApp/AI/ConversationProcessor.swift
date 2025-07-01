import Foundation

// MARK: - 대화 처리기

///
/// 대화의 전처리와 후처리 전체를 조율합니다.
/// 이 클래스는 중앙 파이프라인 역할을 하여, 다양한 처리 단계를 연결해
/// 사용자 입력을 AI 모델에 보내기 전에 정제하고, 모델의 출력을 사용자에게
/// 보여주기 전에 향상시킵니다.
///
/// 이 아키텍처는 모듈성과 확장성을 고려하여 설계되었으므로,
/// 처리 단계를 쉽게 추가, 제거 또는 재정렬할 수 있습니다.
///
final class ConversationProcessor {
    
    private let preProcessingPipeline: [PreProcessingStep]
    private let postProcessingPipeline: [PostProcessingStep]
    
    /// 일련의 처리 단계로 처리기를 초기화합니다.
    /// - Parameters:
    ///   - preProcessingPipeline: 순서대로 실행될 `PreProcessingStep` 객체의 배열입니다.
    ///   - postProcessingPipeline: 순서대로 실행될 `PostProcessingStep` 객체의 배열입니다.
    init(
        preProcessingPipeline: [PreProcessingStep] = [],
        postProcessingPipeline: [PostProcessingStep] = []
    ) {
        self.preProcessingPipeline = preProcessingPipeline
        self.postProcessingPipeline = postProcessingPipeline
    }
    
    /// 사용자의 원본 입력을 전처리 파이프라인을 통해 처리합니다.
    /// - Parameter rawInput: 사용자의 원본 메시지입니다.
    /// - Returns: AI 모델을 위해 처리되고 정제된 문자열입니다.
    func process(rawInput: String) async -> String {
        var processedInput = rawInput
        for step in preProcessingPipeline {
            processedInput = await step.process(input: processedInput)
        }
        return processedInput
    }
    
    /// AI 모델의 원본 출력을 후처리 파이프라인을 통해 처리합니다.
    /// - Parameters:
    ///   - rawOutput: 언어 모델의 원본 출력입니다.
    ///   - originalInput: 문맥을 위한 원본 사용자 입력입니다.
    /// - Returns: 사용자에게 보여주기 위해 다듬어진 사용자 친화적인 문자열입니다.
    func process(rawOutput: String, originalInput: String) async -> String {
        var processedOutput = rawOutput
        for step in postProcessingPipeline {
            processedOutput = await step.process(output: processedOutput, context: originalInput)
        }
        return processedOutput
    }
} 
