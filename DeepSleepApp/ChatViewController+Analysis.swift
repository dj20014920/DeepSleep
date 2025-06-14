import UIKit

// MARK: - ChatViewController Analysis Extension
extension ChatViewController {
    
    // MARK: - ✅ 일기 분석 메소드 - intent 정확히 설정
    func requestDiaryAnalysisWithTracking(diary: DiaryContext) {
        appendChat(ChatMessage(type: .loading, text: "분석하고 있어요..."))
        
        let analysisPrompt = """
        당신은 전문 심리상담사이자 감정 코치입니다. 다음 일기를 보고 진심어린 대화를 나누어주세요.
        
        📝 일기 정보:
        감정 상태: \(diary.emotion)
        작성 날짜: \(diary.formattedDate)  
        일기 내용: \(diary.content)
        
        🤗 대화 가이드라인:
        1. **진심어린 공감**: 마치 가장 친한 친구처럼 따뜻하게 공감해주세요
        2. **구체적 반응**: 일기의 구체적 상황과 감정에 대해 세밀하게 반응해주세요
        3. **자연스러운 대화**: 분석보다는 자연스러운 대화체로 소통해주세요
        4. **개인적 경험 공유**: 때로는 비슷한 경험이나 관점을 부드럽게 나눠주세요
        5. **실용적 조언**: 강요하지 않는 선에서 도움이 될만한 작은 제안들을 해주세요
        6. **희망과 격려**: 긍정적 측면을 발견하고 용기를 북돋아주세요
        
        💝 톤앤매너:
        - 친근하고 따뜻한 존댓말 사용
        - 판단하지 않는 수용적 태도
        - 적절한 이모지 사용으로 감정 표현
        - 길고 풍부한 응답 (최소 300자 이상)
        
        이것은 하루 1회의 소중한 대화입니다. 충분히 깊이 있고 의미 있는 대화를 나누어주세요.
        """
        
        #if DEBUG
        let estimatedTokens = TokenTracker.shared.estimateTokens(for: analysisPrompt)
        print("📝 [DIARY-ANALYSIS] 예상 토큰: \(estimatedTokens) (2000토큰 허용)")
        #endif
        
        // ✅ intent를 "diary_analysis"로 정확히 설정 (2000토큰 사용)
        ReplicateChatService.shared.sendPrompt(
            message: analysisPrompt,
            intent: "diary_analysis"  // 이 intent가 2000토큰을 사용함
        ) { [weak self] response in
            DispatchQueue.main.async {
                self?.removeLastLoadingMessage()
                
                if let analysis = response {
                    self?.appendChat(ChatMessage(type: .bot, text: analysis))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: analysisPrompt,
                        intent: "diary_analysis_success",
                        response: analysis
                    )
                    
                    // ✅ 분석 완료 후 추가 안내
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.appendChat(ChatMessage(type: .bot, text: "💡 이 분석 결과에 대해 더 궁금한 점이 있으면 언제든 질문해주세요!"))
                    }
                } else {
                    self?.appendChat(ChatMessage(type: .bot, text: "❌ 분석 실패. 직접 대화로 도와드릴게요."))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: analysisPrompt,
                        intent: "diary_analysis_failed"
                    )
                }
            }
        }
    }
    
    // MARK: - ✅ 패턴 분석 메소드 - 기존 유지
    func requestPatternAnalysisWithTracking(patternData: String) {
        let analysisPrompt = """
        감정패턴분석 전문가입니다.
        
        데이터: \(patternData)
        
        분석 요청:
        1. 패턴 해석
        2. 긍정적 변화 포인트
        3. 개선 필요 부분
        4. 실용적 조언
        5. 관리 전략
        
        따뜻하고 전문적으로 분석해주세요.
        """
        
        #if DEBUG
        let estimatedTokens = TokenTracker.shared.estimateTokens(for: analysisPrompt)
        print("📊 [PATTERN-ANALYSIS] 예상 토큰: \(estimatedTokens) (2000토큰 허용)")
        #endif
        
        // ✅ intent를 "pattern_analysis"로 정확히 설정 (2000토큰 사용)
        ReplicateChatService.shared.sendPrompt(
            message: analysisPrompt,
            intent: "pattern_analysis"  // 이 intent가 2000토큰을 사용함
        ) { [weak self] response in
            DispatchQueue.main.async {
                self?.removeLastLoadingMessage()
                
                if let analysis = response {
                    self?.appendChat(ChatMessage(type: .bot, text: analysis))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: analysisPrompt,
                        intent: "pattern_analysis_success",
                        response: analysis
                    )
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.appendChat(ChatMessage(type: .bot, text: "💡 더 궁금한 점이 있으면 언제든 물어보세요!"))
                    }
                } else {
                    self?.appendChat(ChatMessage(type: .bot, text: "❌ 분석 실패. 질문해주시면 도움드릴게요!"))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: analysisPrompt,
                        intent: "pattern_analysis_failed"
                    )
                }
            }
        }
    }
    
    // MARK: - Prompt Building
    func buildChatPrompt(userMessage: String, isDiary: Bool) -> String {
        var prompt = userMessage
        
        if let diary = diaryContext {
            let diaryContent = diary.content.count > 200 ?
                String(diary.content.prefix(200)) + "..." : diary.content
            
            prompt = """
            📖 **대화 배경**: 사용자가 \(diary.formattedDate)에 '\(diary.emotion)' 감정으로 작성한 일기를 바탕으로 대화 중입니다.
            
            일기 내용: "\(diaryContent)"
            
            👤 **사용자 메시지**: \(userMessage)
            
            🤗 **대화 가이드**:
            - 일기 내용을 자연스럽게 연결하여 대화해주세요
            - 사용자의 감정과 상황을 깊이 이해하고 공감해주세요  
            - 친근하고 따뜻한 대화체를 사용해주세요
            - 필요시 구체적이고 실용적인 조언을 해주세요
            - 사용자가 안전하고 편안하게 느낄 수 있도록 도와주세요
            
            마치 가장 친한 친구나 믿을 수 있는 상담사처럼 자연스럽고 따뜻하게 대화해주세요.
            """
        } else if let patternData = emotionPatternData {
            let patternSummary = String(patternData.prefix(150))
            
            prompt = """
            감정패턴: \(patternSummary)
            
            사용자: \(userMessage)
            
            패턴을 참고하여 맞춤 대화해주세요.
            """
        }
        
        if isDiary {
            prompt += "\n\n긴 이야기를 충분히 들어주세요."
        }
        
        return prompt
    }
    
    // MARK: - Emotional Response
    func getEmotionalGreeting(for emoji: String) -> String {
        switch emoji {
        case "😢", "😞", "😔":
            return "힘든 하루였나 봐요... 😔\n괜찮아요, 여기서 마음껏 털어놓으세요. 제가 들어드릴게요."
        case "😰", "😱", "😨":
            return "많이 불안하셨겠어요 😰\n깊게 숨을 쉬어보세요. 천천히 이야기해주시면 도움이 될 거예요."
        case "😴", "😪":
            return "많이 피곤하신 것 같네요 😴\n편안한 사운드로 마음을 달래드릴게요."
        case "😊", "😄", "🥰":
            return "좋은 기분이시네요! 😊\n오늘의 기쁜 순간들을 더 들려주세요."
        case "😡", "😤":
            return "화가 많이 나셨나 봐요 😤\n속상한 마음을 충분히 표현해보세요. 들어드릴게요."
        default:
            return "지금 기분을 더 자세히 말해주세요 💝\n어떤 하루를 보내셨는지 궁금해요."
        }
    }
}
