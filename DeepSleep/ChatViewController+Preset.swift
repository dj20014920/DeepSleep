import UIKit

// MARK: - ChatViewController Preset Extension (11개 카테고리)
extension ChatViewController {
    
    // MARK: - 새로운 11개 카테고리 프리셋 추천
    func buildEmotionalPrompt(emotion: String, recentChat: String) -> String {
        return """
        당신은 감정을 이해하고 위로해주는 AI 사운드 큐레이터입니다.
        현재 사용자 감정: \(emotion)
        최근 대화 내용:
        \(recentChat)
        
        위 정보를 바탕으로 11가지 사운드의 볼륨을 0-100으로 추천해주세요.
        
        사운드 목록 (순서대로): 고양이, 바람, 밤, 불, 비, 시냇물, 연필, 우주, 쿨링팬, 키보드, 파도
        
        각 사운드 설명:
        - 고양이: 부드러운 야옹 소리 (편안함, 따뜻함)
        - 바람: 자연스러운 바람 소리 (시원함, 청량함)
        - 밤: 고요한 밤의 소리 (평온, 수면)
        - 불: 타닥거리는 불소리 (따뜻함, 포근함)
        - 비: 빗소리 (평온, 집중) *2가지 버전: 일반 빗소리, 창문 빗소리
        - 시냇물: 흐르는 물소리 (자연, 휴식)
        - 연필: 종이에 쓰는 소리 (집중, 창작)
        - 우주: 신비로운 우주 소리 (명상, 깊은 사색)
        - 쿨링팬: 부드러운 팬 소리 (집중, 화이트노이즈)
        - 키보드: 타이핑 소리 (작업, 집중) *2가지 버전: 키보드1, 키보드2
        - 파도: 파도치는 소리 (휴식, 자연)
        
        응답 형식: [감정에 맞는 프리셋 이름] 고양이:값, 바람:값, 밤:값, 불:값, 비:값, 시냇물:값, 연필:값, 우주:값, 쿨링팬:값, 키보드:값, 파도:값
        중요: 프리셋 이름, 모든 사운드 카테고리와 해당 값, 그리고 필요한 경우 버전 정보(예: 비:값(V1))까지 모두 포함하여 반드시 한 줄로 응답해주세요. 응답에 줄바꿈 문자를 포함하지 마세요.
        
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
    
    // MARK: - 새로운 11개 카테고리 파싱
    func parseRecommendation(from response: String) -> EnhancedRecommendationResponse? {
        // AI 응답 전체를 사용 (줄바꿈이 있더라도 파싱 가능하도록)
        let mainResponsePart = response
        print("ℹ️ [AI Parse] 파싱 대상 문자열 (전체 응답 사용): \(mainResponsePart)")

        // 1. 프리셋 이름 추출 (정규식 사용)
        let namePattern = #"\s*\[([^\]]+)\]\s*(.*)"#
        guard let nameRegex = try? NSRegularExpression(pattern: namePattern, options: .dotMatchesLineSeparators),
              let nameMatch = nameRegex.firstMatch(in: mainResponsePart, range: NSRange(mainResponsePart.startIndex..., in: mainResponsePart)) else {
            print("🛑 [AI Parse] AI 응답 파싱 오류: 프리셋 이름 형식이 맞지 않음: \(mainResponsePart)")
            return nil
        }

        let presetName = String(mainResponsePart[Range(nameMatch.range(at: 1), in: mainResponsePart)!])
        var rawSettingsContent = String(mainResponsePart[Range(nameMatch.range(at: 2), in: mainResponsePart)!])
        print("  ➡️ [AI Parse] 추출된 이름: \(presetName)")
        print("  ➡️ [AI Parse] 추출된 설정 문자열 (원본 Regex Group 2): \(rawSettingsContent)")

        // 원본 Regex Group 2 내용에서 실제 설정 라인만 추출
        rawSettingsContent = rawSettingsContent.trimmingCharacters(in: .whitespacesAndNewlines)
        var finalSettingsLine = ""
        // AI가 설정 라인 이후에 설명을 붙이므로, 첫번째 줄에 설정이 있다고 가정하고 추출
        if let firstNewLineInRaw = rawSettingsContent.range(of: "\n") {
            finalSettingsLine = String(rawSettingsContent[..<firstNewLineInRaw.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            finalSettingsLine = rawSettingsContent // 개행이 없으면 전체를 설정 라인으로 간주
        }
        
        // 추출된 라인이 비어있거나 ':'를 포함하지 않으면, AI 응답 형식이 예상과 다를 수 있음을 의미.
        // 이 경우, 좀 더 관대하게 ':'를 포함하는 첫번째 줄을 찾으려고 시도 (안전장치).
        if finalSettingsLine.isEmpty || !finalSettingsLine.contains(":") {
            print("  ⚠️ [AI Parse] 초기 설정 라인 추출 실패 또는 유효하지 않음. 전체 내용에서 첫번째 유효 라인 재탐색...")
            for lineCandidate in rawSettingsContent.split(separator: "\n", omittingEmptySubsequences: true) {
                let trimmedLineCandidate = lineCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedLineCandidate.isEmpty && trimmedLineCandidate.contains(":") && trimmedLineCandidate.contains(",") {
                    finalSettingsLine = trimmedLineCandidate
                    print("  ✅ [AI Parse] 재탐색으로 유효 설정 라인 발견: '\(finalSettingsLine)'")
                    break
                }
            }
        }
        
        print("  🎯 [AI Parse] 최종 파싱 대상 설정 문자열: '\(finalSettingsLine)'")

        // MARK: - 설정 문자열 유효성 검사 추가
        if finalSettingsLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("🛑 [AI Parse] AI 응답 파싱 오류: 설정 문자열(finalSettingsLine)이 비어 있습니다. AI가 완전한 형식으로 응답했는지 확인 필요.")
            return nil
        }

        var volumes: [Float] = Array(repeating: 0.0, count: SoundPresetCatalog.categoryCount)
        var versions: [Int] = SoundPresetCatalog.defaultVersionSelection

        let settingsParts = finalSettingsLine.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        print("  ➡️ [AI Parse] 분리된 설정 파트 개수: \(settingsParts.count)")

        for (index, part) in settingsParts.enumerated() {
            print("    🔄 [AI Parse] Part \(index + 1)/\(settingsParts.count) 처리 시작: '\(part)'")
            let mainComponents = part.split(separator: ":").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard mainComponents.count == 2 else {
                print("    ⚠️ [AI Parse] AI 응답 파싱 경고: '\(part)'는 '카테고리:값' 형식이 아님. 건너뜁니다.")
                continue
            }

            let categoryName = String(mainComponents[0])
            var valueString = String(mainComponents[1])
            print("      🏷️ [AI Parse] 카테고리명: '\(categoryName)', 값 문자열: '\(valueString)'")

            // 개행 문자가 있다면, 그 이전 부분까지만 사용 (AI의 추가 설명 제거)
            if let newlineRange = valueString.rangeOfCharacter(from: .newlines) {
                valueString = String(valueString[..<newlineRange.lowerBound])
                print("ℹ️ [AI Parse] 개행 문자 이후 추가 텍스트 제거됨. 정제된 valueString: '\(valueString)'")
            }
            valueString = valueString.trimmingCharacters(in: .whitespaces) // 혹시 모를 앞뒤 공백 제거

            var versionMarker: String?
            var volumeFloat: Float?

            // 버전 정보 (V1, V2 등) 파싱 로직
            if let versionRangeStart = valueString.lastIndex(of: "("),
               let versionRangeEnd = valueString.lastIndex(of: ")"),
               versionRangeStart < versionRangeEnd {
                let versionStartIndex = valueString.index(after: versionRangeStart)
                let versionEndIndex = versionRangeEnd
                versionMarker = String(valueString[versionStartIndex..<versionEndIndex]).uppercased()
                let volumePartString = String(valueString[..<versionRangeStart])
                volumeFloat = Float(volumePartString.trimmingCharacters(in: .whitespacesAndNewlines)) // 공백 제거 추가
                print("        🔊 [AI Parse] 버전 마커 '\(versionMarker ?? "N/A")' 발견. 볼륨 부분: '\(volumePartString)', 파싱된 볼륨: \(String(describing: volumeFloat))")
            } else {
                volumeFloat = Float(valueString.trimmingCharacters(in: .whitespacesAndNewlines)) // 공백 제거 추가
                print("        🔊 [AI Parse] 버전 마커 없음. 볼륨 부분: '\(valueString)', 파싱된 볼륨: \(String(describing: volumeFloat))")
            }
            
            guard let finalVolume = volumeFloat else {
                print("    ⚠️ [AI Parse] AI 응답 파싱 경고: '\(part)'의 볼륨값 '\(valueString)'을 Float으로 변환 실패. 건너뜁니다.")
                continue
            }

            guard let categoryIndex = SoundPresetCatalog.findCategoryIndex(by: categoryName) else {
                print("    ⚠️ [AI Parse] AI 응답 파싱 경고: 카테고리명 '\(categoryName)'에 해당하는 인덱스를 SoundPresetCatalog에서 찾을 수 없음. 건너뜁니다. 응답 파트: '\(part)'")
                continue
            }
            print("      🔢 [AI Parse] 카테고리 '\(categoryName)'의 인덱스: \(categoryIndex)")
            
            guard categoryIndex < volumes.count else {
                print("    🛑 [AI Parse] AI 응답 파싱 오류: 카테고리 인덱스(\(categoryIndex))가 볼륨 배열 크기(\(volumes.count))를 벗어남. 응답 형식 재확인 필요: \(part)")
                continue // 원래는 return nil 이었으나, 다른 정상적인 값들은 처리하도록 continue로 변경
            }
            volumes[categoryIndex] = min(100, max(0, finalVolume))
            print("      💾 [AI Parse] 볼륨 저장: volumes[\(categoryIndex)] = \(volumes[categoryIndex]) (원시값: \(finalVolume))")

            if let marker = versionMarker {
                if SoundPresetCatalog.hasMultipleVersions(at: categoryIndex) {
                    if marker == "V1" { versions[categoryIndex] = 0 }
                    else if marker == "V2" { versions[categoryIndex] = 1 } // TODO: SoundPresetCatalog의 버전 인덱스와 일치하는지 확인 필요
                    else { 
                        print("      ⚠️ [AI Parse] AI 응답 파싱 경고: 카테고리 '\(categoryName)'의 버전 마커 '\(marker)' 인식 불가. 기본 버전 사용.")
                    }
                    print("        💾 [AI Parse] 버전 저장: versions[\(categoryIndex)] = \(versions[categoryIndex]) (마커: \(marker))")
                } else {
                    print("      ⚠️ [AI Parse] AI 응답 파싱 경고: 카테고리 '\(categoryName)'는 다중 버전 사운드가 아니나 버전(\(marker)) 명시됨.")
                }
            }
        }
        
        // MARK: - 파싱된 볼륨 유효성 검사 추가
        // 모든 볼륨이 0.0이고, settingsString에서 유효한 파싱이 하나도 이루어지지 않았는지 확인
        let allVolumesZero = volumes.allSatisfy { $0 == 0.0 }
        // 유효한 '카테고리:값' 쌍이 하나라도 있었는지 확인하기 위해, 성공적으로 categoryIndex를 찾은 경우를 카운트하는 방식이 더 정확할 수 있음
        // 현재는 settingsString 자체에 ':'가 있는지로 간접 판단
        let hasValidPairs = finalSettingsLine.contains(":")
        
        if allVolumesZero && (settingsParts.isEmpty || !hasValidPairs) {
             print("🛑 [AI Parse] AI 응답 파싱 오류: 설정 문자열에서 유효한 '카테고리:값' 쌍을 찾을 수 없거나, 모든 파싱 결과 볼륨이 0입니다. 원본 설정 문자열: '\(finalSettingsLine)'")
             return nil
        }
        
        #if DEBUG
        print("✅ [AI Parse] AI 파싱 완료 (수정된 로직): \(presetName)")
        print("  📊 [AI Parse] 최종 볼륨 (개수: \(volumes.count)): \(volumes)")
        print("  🔢 [AI Parse] 최종 버전 (개수: \(versions.count)): \(versions)")
        #endif

        guard volumes.count == SoundPresetCatalog.categoryCount,
              versions.count == SoundPresetCatalog.categoryCount else {
            print("🛑 [AI Parse] AI 파싱 최종 검증 실패: 볼륨/버전 배열 개수 불일치. 볼륨: \(volumes.count), 버전: \(versions.count), 기대값: \(SoundPresetCatalog.categoryCount)")
            return nil
        }

        return EnhancedRecommendationResponse(
            volumes: volumes,
            presetName: presetName,
            selectedVersions: versions
        )
    }
    
    // MARK: - 감정별 기본 프리셋 (11개 카테고리)
    private func parseBasicFormat(from response: String) -> EnhancedRecommendationResponse? {
        let emotion = initialUserText ?? "😊"
        
        switch emotion {
        case "😢", "😞", "😔":  // 슬픔
            return EnhancedRecommendationResponse(
                volumes: [40, 20, 70, 30, 60, 80, 0, 60, 20, 0, 50],  // 고양이, 바람, 밤, 불, 비, 시냇물, 연필, 우주, 쿨링팬, 키보드, 파도
                presetName: "🌧️ 위로의 소리",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]  // 모든 카테고리 기본 버전
            )
            
        case "😰", "😱", "😨":  // 불안
            return EnhancedRecommendationResponse(
                volumes: [60, 30, 50, 0, 70, 90, 0, 80, 40, 0, 60],
                presetName: "🌿 안정의 소리",
                selectedVersions: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]  // 비는 창문 빗소리 버전
            )
            
        case "😴", "😪":  // 졸림/피곤
            return EnhancedRecommendationResponse(
                volumes: [70, 40, 90, 20, 50, 60, 0, 80, 30, 0, 40],
                presetName: "🌙 깊은 잠의 소리",
                selectedVersions: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]  // 창문 빗소리
            )
            
        case "😊", "😄", "🥰":  // 기쁨
            return EnhancedRecommendationResponse(
                volumes: [80, 60, 40, 30, 20, 70, 40, 50, 20, 30, 80],
                presetName: "🌈 기쁨의 소리",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]  // 모든 기본 버전
            )
            
        case "😡", "😤":  // 화남
            return EnhancedRecommendationResponse(
                volumes: [30, 70, 60, 10, 80, 90, 0, 70, 50, 0, 70],
                presetName: "🌊 마음 달래는 소리",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
            
        case "😐", "🙂":  // 평온/무덤덤
            return EnhancedRecommendationResponse(
                volumes: [50, 40, 60, 20, 40, 60, 60, 70, 40, 50, 50],
                presetName: "⚖️ 균형의 소리",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
            
        default:  // 기본값
            return EnhancedRecommendationResponse(
                volumes: [40, 30, 50, 20, 30, 50, 40, 60, 30, 40, 40],
                presetName: "🎵 평온의 소리",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
        }
    }
    
    // MARK: - 기존 호환성 유지 (12개 → 11개 변환)
    
    /// 기존 12개 프리셋 추천을 11개로 변환 (레거시 지원)
    func convertLegacyRecommendation(volumes12: [Float], presetName: String) -> EnhancedRecommendationResponse {
        let convertedVolumes = SoundPresetCatalog.convertLegacyVolumes(volumes12)
        let defaultVersions = SoundPresetCatalog.defaultVersionSelection
        
        return EnhancedRecommendationResponse(
            volumes: convertedVolumes,
            presetName: presetName,
            selectedVersions: defaultVersions
        )
    }
    
    /// AI 추천 시 기존 12개 이름을 11개로 매핑
    func buildLegacyCompatiblePrompt(emotion: String, recentChat: String) -> String {
        return """
        당신은 감정을 이해하고 위로해주는 AI 사운드 큐레이터입니다.
        현재 사용자 감정: \(emotion)
        최근 대화 내용:
        \(recentChat)
        
        위 정보를 바탕으로 사운드 볼륨을 0-100으로 추천해주세요.
        
        다음 중 하나의 형식으로 응답해주세요:
        
        [새로운 11개 형식] 고양이:값, 바람:값, 밤:값, 불:값, 비:값, 시냇물:값, 연필:값, 우주:값, 쿨링팬:값, 키보드:값, 파도:값
        
        또는 기존 형식도 지원:
        [기존 12개 형식] Rain:값, Thunder:값, Ocean:값, Fire:값, Steam:값, WindowRain:값, Forest:값, Wind:값, Night:값, Lullaby:값, Fan:값, WhiteNoise:값
        
        사용자의 감정에 진심으로 공감하며 추천해주세요.
        """
    }
    
    // MARK: - 향상된 추천 로직 (감정별 특화)
    
    func getEmotionSpecificRecommendation(emotion: String, context: String = "") -> EnhancedRecommendationResponse {
        // 감정별로 더 정교한 추천 로직
        switch emotion {
        case "😢", "😞", "😔":  // 슬픔 - 위로와 따뜻함
            return EnhancedRecommendationResponse(
                volumes: [60, 20, 80, 40, 70, 90, 0, 70, 20, 0, 60],
                presetName: "💙 따뜻한 위로",
                selectedVersions: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]  // 창문 빗소리
            )
            
        case "😰", "😱", "😨":  // 불안 - 안정감과 진정
            return EnhancedRecommendationResponse(
                volumes: [70, 30, 60, 0, 80, 90, 0, 80, 40, 0, 70],
                presetName: "🌿 마음의 안정",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]  // 기본 빗소리
            )
            
        case "😴", "😪":  // 졸림 - 수면 유도
            return EnhancedRecommendationResponse(
                volumes: [80, 40, 90, 30, 60, 70, 0, 90, 50, 0, 50],
                presetName: "🌙 편안한 꿈나라",
                selectedVersions: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]  // 창문 빗소리
            )
            
        case "😊", "😄", "🥰":  // 기쁨 - 활기와 생동감
            return EnhancedRecommendationResponse(
                volumes: [90, 60, 30, 40, 20, 80, 50, 40, 20, 40, 90],
                presetName: "🌈 즐거운 하루",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
            
        case "😡", "😤":  // 화남 - 진정과 해소
            return EnhancedRecommendationResponse(
                volumes: [40, 80, 70, 20, 90, 90, 0, 60, 60, 0, 80],
                presetName: "🌊 마음의 평화",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
            
        case "😐", "🙂":  // 평온 - 균형과 조화
            return EnhancedRecommendationResponse(
                volumes: [60, 50, 70, 30, 50, 70, 70, 80, 50, 60, 60],
                presetName: "⚖️ 조화로운 순간",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]  // 키보드2
            )
            
        default:  // 기본값 - 중성적이고 편안한
            return EnhancedRecommendationResponse(
                volumes: [50, 40, 60, 30, 40, 60, 50, 70, 40, 50, 50],
                presetName: "🎵 고요한 순간",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
        }
    }
    
    // MARK: - 집중/작업 모드 특화 추천
    
    func getFocusRecommendation(workType: String = "general") -> EnhancedRecommendationResponse {
        switch workType.lowercased() {
        case "coding", "programming":
            return EnhancedRecommendationResponse(
                volumes: [20, 10, 30, 0, 40, 30, 80, 50, 70, 90, 20],
                presetName: "💻 코딩 집중모드",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]  // 키보드2
            )
            
        case "reading", "study":
            return EnhancedRecommendationResponse(
                volumes: [40, 20, 40, 0, 60, 70, 60, 60, 50, 40, 30],
                presetName: "📚 독서 집중모드",
                selectedVersions: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]  // 창문 빗소리
            )
            
        case "writing", "creative":
            return EnhancedRecommendationResponse(
                volumes: [60, 30, 50, 20, 50, 80, 90, 70, 30, 60, 40],
                presetName: "✍️ 창작 집중모드",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
            
        default:
            return EnhancedRecommendationResponse(
                volumes: [30, 20, 40, 0, 50, 60, 70, 60, 60, 70, 30],
                presetName: "🎯 일반 집중모드",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
        }
    }
    
    // MARK: - 시간대별 추천
    
    func getTimeBasedRecommendation() -> EnhancedRecommendationResponse {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6..<9:  // 아침
            return EnhancedRecommendationResponse(
                volumes: [70, 50, 20, 30, 40, 80, 40, 30, 30, 50, 70],
                presetName: "🌅 상쾌한 아침",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
            
        case 9..<12:  // 오전 작업시간
            return EnhancedRecommendationResponse(
                volumes: [40, 30, 30, 0, 50, 60, 80, 50, 50, 80, 40],
                presetName: "☀️ 오전 집중시간",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0]
            )
            
        case 12..<18:  // 오후
            return EnhancedRecommendationResponse(
                volumes: [60, 40, 40, 20, 60, 70, 60, 60, 40, 60, 50],
                presetName: "🌞 평온한 오후",
                selectedVersions: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
            )
            
        case 18..<22:  // 저녁
            return EnhancedRecommendationResponse(
                volumes: [80, 30, 60, 50, 50, 60, 40, 70, 40, 40, 60],
                presetName: "🌆 여유로운 저녁",
                selectedVersions: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
            )
            
        default:  // 밤 (22-6시)
            return EnhancedRecommendationResponse(
                volumes: [70, 20, 90, 40, 70, 60, 0, 90, 60, 0, 50],
                presetName: "🌙 고요한 밤",
                selectedVersions: [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]
            )
        }
    }
    
    // MARK: - 기존 API 호환성 보장
    
    /// 기존 RecommendationResponse 구조 유지를 위한 래퍼
    struct LegacyRecommendationResponse {
        let volumes: [Float]
        let presetName: String
        
        func toNewFormat() -> EnhancedRecommendationResponse {
            let convertedVolumes = volumes.count == 12 ?
                SoundPresetCatalog.convertLegacyVolumes(volumes) : volumes
            
            return EnhancedRecommendationResponse(
                volumes: convertedVolumes,
                presetName: presetName,
                selectedVersions: SoundPresetCatalog.defaultVersionSelection
            )
        }
    }
    
    /// 기존 코드와의 호환성을 위한 래퍼 메서드
    func getCompatibleRecommendation(emotion: String) -> EnhancedRecommendationResponse {
        // 기존 코드에서 호출할 수 있도록 인터페이스 유지
        return getEmotionSpecificRecommendation(emotion: emotion)
    }
    
    // MARK: - 디버그 및 테스트 지원
    
    #if DEBUG
    func testAllRecommendations() {
        let emotions = ["😊", "😢", "😡", "😰", "😴", "😐"]
        
        print("=== 감정별 추천 테스트 ===")
        for emotion in emotions {
            let recommendation = getEmotionSpecificRecommendation(emotion: emotion)
            print("\(emotion): \(recommendation.presetName)")
            print("  볼륨: \(recommendation.volumes)")
            print("  버전: \(recommendation.selectedVersions ?? [])")
        }
        
        print("\n=== 시간대별 추천 테스트 ===")
        let timeRecommendation = getTimeBasedRecommendation()
        print("현재시간: \(timeRecommendation.presetName)")
        print("  볼륨: \(timeRecommendation.volumes)")
        
        print("\n=== 집중모드 추천 테스트 ===")
        let focusTypes = ["coding", "reading", "writing"]
        for type in focusTypes {
            let focusRecommendation = getFocusRecommendation(workType: type)
            print("\(type): \(focusRecommendation.presetName)")
            print("  볼륨: \(focusRecommendation.volumes)")
        }
    }
    
    func validateRecommendation(_ recommendation: EnhancedRecommendationResponse) -> Bool {
        // 추천 결과 검증
        guard recommendation.volumes.count == SoundPresetCatalog.categoryCount else {
            print("❌ 잘못된 볼륨 배열 크기: \(recommendation.volumes.count)")
            return false
        }
        
        guard let versions = recommendation.selectedVersions,
              versions.count == SoundPresetCatalog.categoryCount else {
            print("❌ 잘못된 버전 배열 크기")
            return false
        }
        
        let validVolumes = recommendation.volumes.allSatisfy { $0 >= 0 && $0 <= 100 }
        guard validVolumes else {
            print("❌ 잘못된 볼륨 범위")
            return false
        }
        
        let validVersions = versions.enumerated().allSatisfy { (index, version) in
            let maxVersion = SoundPresetCatalog.getVersionCount(at: index) - 1
            return version >= 0 && version <= maxVersion
        }
        guard validVersions else {
            print("❌ 잘못된 버전 인덱스")
            return false
        }
        
        print("✅ 추천 결과 검증 완료: \(recommendation.presetName)")
        return true
    }
    #endif
}
