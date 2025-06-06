import UIKit

// MARK: - ChatViewController Actions Extension (중앙 관리 로직 적용)
extension ChatViewController {
    
    // MARK: - 메시지 전송
    @objc func sendButtonTapped() {
        guard let text = inputTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        
        // UI 즉시 업데이트
        inputTextField.text = ""
        let userMessage = ChatMessage(type: .user, text: text)
        appendChat(userMessage)
        
        // AI 응답 요청
        requestAIChatResponse(for: text)
    }
    
    // MARK: - AI 응답 요청 및 처리
    private func requestAIChatResponse(for text: String) {
        // 1. 사용량 제한 확인
        guard AIUsageManager.shared.canUse(feature: .chat) else {
            let limitMessage = ChatMessage(type: .error, text: "하루 채팅 사용량을 모두 사용했어요. 내일 다시 만나요! 😊")
            appendChat(limitMessage)
            return
        }

        // 2. 로딩 메시지 추가
        appendChat(ChatMessage(type: .loading, text: "고민을 듣고 있어요..."))
        
        // 3. 캐시 기반 프롬프트 생성 (간소화)
        _ = messages.suffix(10).map { "\($0.type.rawValue): \($0.text)" }.joined(separator: "\n") // context 미사용
        
        // 4. AI 서비스 호출
        ReplicateChatService.shared.sendPrompt(
            message: text,
            intent: "chat"
        ) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 5. 로딩 메시지 제거
                self.removeLastLoadingMessage()
                
                // 6. 응답 처리
                if let msg = response, !msg.isEmpty {
                    let botMessage = ChatMessage(type: .bot, text: msg)
                    self.appendChat(botMessage)
                    
                    // 성공 시 사용량 기록
                    AIUsageManager.shared.recordUsage(for: .chat)
                    
                } else {
                    // 7. 에러 처리
                    let errorMessage = ChatMessage(type: .error, text: "응답을 불러올 수 없어요. 네트워크 연결을 확인하고 다시 시도해주세요.")
                    self.appendChat(errorMessage)
                }
            }
        }
    }

    // MARK: - 프리셋 추천
    @objc func presetButtonTapped() {
        guard AIUsageManager.shared.canUse(feature: .presetRecommendation) else {
            let limitMessage = ChatMessage(type: .error, text: "오늘의 추천 횟수를 모두 사용했어요. 내일 새로운 추천을 받아보세요! ✨")
            appendChat(limitMessage)
            return
        }
        
        let userMessage = ChatMessage(type: .user, text: "🎵 지금 기분에 맞는 사운드 추천받기")
        appendChat(userMessage)

        appendChat(ChatMessage(type: .loading, text: "최적의 사운드를 찾는 중..."))

        // 프리셋 추천 API 호출
        ReplicateChatService.shared.sendPrompt(
            message: "지금 기분에 맞는 사운드 프리셋을 추천해주세요",
            intent: "preset_recommendation"
        ) { [weak self] response in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 로딩 메시지 제거
                self.removeLastLoadingMessage()
                
                if let msg = response, !msg.isEmpty {
                    // 프리셋 추천 메시지로 생성
                    var presetMessage = ChatMessage(type: .presetRecommendation, text: msg)
                    
                    // 프리셋 적용 콜백 설정
                    presetMessage.onApplyPreset = { [weak self] in
                        self?.applyPresetFromRecommendation(msg)
                    }
                    
                    self.appendChat(presetMessage)
                    
                    // 성공 시 사용량 기록
                    AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                    
                } else {
                    // 에러 처리 - 임시 테스트용 하드코딩 응답
                    let testPresetResponse = "[편안한 저녁] Rain:70,Thunder:0,Ocean:30,Fire:25,Steam:40,WindowRain:35,Forest:55,Wind:20,Night:60,Lullaby:45,Fan:50,WhiteNoise:30,Cat:0"
                    
                    var presetMessage = ChatMessage(type: .presetRecommendation, text: testPresetResponse)
                    presetMessage.onApplyPreset = { [weak self] in
                        self?.applyPresetFromRecommendation(testPresetResponse)
                    }
                    
                    self.appendChat(presetMessage)
                    AIUsageManager.shared.recordUsage(for: .presetRecommendation)
                }
            }
        }
    }
    
    // MARK: - 프리셋 적용 기능
    private func applyPresetFromRecommendation(_ recommendationText: String) {
        // 1. 프리셋 이름과 볼륨 설정 파싱
        guard let (presetName, volumeSettings) = parsePresetRecommendation(recommendationText) else {
            showAlert(title: "적용 실패", message: "프리셋 형식을 인식할 수 없습니다.")
            return
        }
        
        // 2. SoundManager에 볼륨 적용
        applySoundVolumes(volumeSettings)
        
        // 3. 사용자에게 적용 완료 알림
        let successMessage = ChatMessage(type: .bot, text: "✅ '\(presetName)' 프리셋이 적용되었습니다! 지금 바로 편안한 사운드를 즐겨보세요. 🎵")
        appendChat(successMessage)
        
        // 4. 메인 화면으로 이동하는 옵션 제공
        let backToMainMessage = ChatMessage(type: .postPresetOptions, text: "🏠 메인 화면으로 이동해서 사운드를 확인해보세요!")
        appendChat(backToMainMessage)
    }
    
    // MARK: - 프리셋 추천 파싱
    private func parsePresetRecommendation(_ text: String) -> (String, [String: Float])? {
        // [프리셋명] 형식에서 이름 추출
        guard let nameMatch = text.range(of: "\\[(.+?)\\]", options: .regularExpression) else {
            return nil
        }
        
        let presetName = String(text[nameMatch]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        
        // 볼륨 설정 파싱 (Rain:70,Thunder:0,Ocean:30 형식)
        var volumeSettings: [String: Float] = [:]
        
        let volumePattern = "(\\w+):(\\d+)"
        let regex = try? NSRegularExpression(pattern: volumePattern, options: [])
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: text.count)) ?? []
        
        for match in matches {
            let soundName = (text as NSString).substring(with: match.range(at: 1))
            let volumeString = (text as NSString).substring(with: match.range(at: 2))
            if let volume = Float(volumeString) {
                volumeSettings[soundName] = volume / 100.0 // 0-1 범위로 변환
            }
        }
        
        return volumeSettings.isEmpty ? nil : (presetName, volumeSettings)
    }
    
    // MARK: - 사운드 볼륨 적용
    private func applySoundVolumes(_ volumeSettings: [String: Float]) {
        // 실제 SoundManager의 카테고리 매핑으로 볼륨 설정
        for (soundName, volume) in volumeSettings {
            let categoryIndex = mapSoundNameToIndex(soundName)
            if categoryIndex >= 0 && categoryIndex < SoundManager.shared.categoryCount {
                SoundManager.shared.setVolume(for: categoryIndex, volume: volume)
                print("✅ \(soundName) → 카테고리 \(categoryIndex): \(volume)")
            } else {
                print("⚠️ 알 수 없는 사운드: \(soundName)")
            }
        }
        
        // 🆕 메인 화면 UI 업데이트 알림
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("SoundVolumesUpdated"),
                object: nil,
                userInfo: ["volumeSettings": volumeSettings]
            )
        }
        
        // 사운드 재생 시작 (자동 재생)
        SoundManager.shared.playAll()
    }
    
    // MARK: - 사운드 이름 → 카테고리 인덱스 매핑
    private func mapSoundNameToIndex(_ soundName: String) -> Int {
        switch soundName.lowercased() {
        case "cat", "고양이":
            return 0  // 고양이
        case "wind", "바람":
            return 1  // 바람
        case "night", "밤":
            return 2  // 밤
        case "fire", "불1", "fire1":
            return 3  // 불1
        case "rain", "비":
            return 4  // 비
        case "stream", "시냇물":
            return 5  // 시냇물
        case "pencil", "연필":
            return 6  // 연필
        case "space", "우주":
            return 7  // 우주
        case "fan", "쿨링팬", "coolingfan":
            return 8  // 쿨링팬
        case "keyboard", "키보드":
            return 9  // 키보드
        case "wave", "파도", "ocean":
            return 10 // 파도
        case "bird", "새":
            return 11 // 새
        case "snow", "발걸음-눈", "footstep":
            return 12 // 발걸음-눈
        default:
            return -1 // 존재하지 않는 사운드
        }
    }
    
    // MARK: - 알림 표시
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
