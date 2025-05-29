import UIKit

// MARK: - ChatViewController Analysis Extension
extension ChatViewController {
    
    // MARK: - ✅ 일기 분석 메소드 - intent 정확히 설정
    func requestDiaryAnalysisWithTracking(diary: DiaryContext) {
        appendChat(.bot("일기 분석 중... 💭"))
        
        let analysisPrompt = """
        감정:\(diary.emotion) 날짜:\(diary.formattedDate)
        일기:\(diary.content)
        
        깊이 있는 일기 분석을 해주세요:
        1. 감정과 상황에 대한 깊은 공감
        2. 감정 배경과 원인 이해
        3. 긍정적 측면 발견
        4. 실용적 조언과 격려
        5. 감정 관리 방향 제시
        
        하루 1회의 소중한 분석이므로 충분히 길고 깊이 있게 분석해주세요.
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
                if let analysis = response {
                    self?.appendChat(.bot(analysis))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: analysisPrompt,
                        intent: "diary_analysis_success",
                        response: analysis
                    )
                    
                    // ✅ 분석 완료 후 추가 안내
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.appendChat(.bot("💡 이 분석 결과에 대해 더 궁금한 점이 있으면 언제든 질문해주세요!"))
                    }
                } else {
                    self?.appendChat(.bot("❌ 분석 실패. 직접 대화로 도와드릴게요."))
                    
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
                if let analysis = response {
                    self?.appendChat(.bot(analysis))
                    
                    TokenTracker.shared.logAndTrack(
                        prompt: analysisPrompt,
                        intent: "pattern_analysis_success",
                        response: analysis
                    )
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.appendChat(.bot("💡 더 궁금한 점이 있으면 언제든 물어보세요!"))
                    }
                } else {
                    self?.appendChat(.bot("❌ 분석 실패. 질문해주시면 도움드릴게요!"))
                    
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
            일기컨텍스트- 감정:\(diary.emotion) 내용:\(diaryContent)
            
            사용자: \(userMessage)
            
            위 일기를 참고하여 따뜻하게 대화해주세요.
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
