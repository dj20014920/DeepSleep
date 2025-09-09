import CryptoKit
import Foundation

/// Represents a single correction or definition taught by the user.
/// This structure is `Codable` to allow for easy saving/loading to/from a file.
struct UserDefinedRule: Codable, Hashable, Identifiable {
    let id: UUID
    let userInput: String
    let correctedMeaning: String
    let timestamp: Date

    init(userInput: String, correctedMeaning: String) {
        self.id = UUID()
        self.userInput = userInput
        self.correctedMeaning = correctedMeaning
        self.timestamp = Date()
    }
}

/// Persona 서명 캐시 엔트리 (extension 밖으로 이동하여 access level 충돌 방지)
private struct CachedPersonaSignature {
    let signature: String
    let coreSignature: String
    let timestamp: Date
    let settingsHash: String
}

// MARK: - Persona Signature (캐시/무효화 전용 해시)
extension UserRulesManager {

    // 세분화된 페르소나/모델/모드/톤 구성요소 (캐시 미스 이유 세분화 용도)
    struct PersonaSignatureComponents {
        let composite: String
        let coreHash: String
        let modeHash: String
        let modelHash: String
        let toneHash: String
    }

    /// 새 세분화 컴포넌트 계산 (모드/모델/톤 독립 해시)
    /// - Parameters:
    ///   - currentMode: AIMode (채팅/일기 등)
    ///   - model: AIModel (선택된 LLM)
    ///   - conversationTones: 현재 설정된 톤 목록
    /// - Returns: PersonaSignatureComponents (composite = core + mode + model + tone 결합 해시)
    public func personaSignatureComponents(currentMode: AIMode, model: AIModel, conversationTones: [String]) -> PersonaSignatureComponents {
        let coreHash = personaCoreSignature()
        let sortedTones = conversationTones.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.sorted()
        let toneBase = "tones:" + sortedTones.joined(separator: ",")
        let toneHash = sha256(toneBase)
        let modeHash = sha256("mode:\(currentMode.rawValue)")
        let modelHash = sha256("model:\(model.rawValue)")
        let composite = sha256(coreHash + ":" + modeHash + ":" + modelHash + ":" + toneHash)
        #if DEBUG
        print("🧩 [UserRulesManager] personaSignatureComponents 생성: core=\(coreHash.prefix(8)) mode=\(modeHash.prefix(8)) model=\(modelHash.prefix(8)) tone=\(toneHash.prefix(8)) composite=\(composite.prefix(12))")
        #endif
        return PersonaSignatureComponents(composite: composite, coreHash: coreHash, modeHash: modeHash, modelHash: modelHash, toneHash: toneHash)
    }

    /// 페르소나/설정/환경을 요약하여 생성하는 해시 지문.
    /// - 목적: 캐시 키/무효화 트리거 전용. 외부 LLM에 절대 전달하지 않음.
    /// - 원칙: 온디바이스에서 간단 PII 필터링을 적용하고 의미 보존형 특성만 요약에 사용.
    public func personaSignature() -> String {
        return cacheQueue.sync {
            // 1) 현재 설정 해시 계산 (캐시 유효성 검증용)
            let currentSettingsHash = computeSettingsHash()

            // 2) 캐시 유효성 체크
            if let cached = cachedSignature,
                cached.settingsHash == currentSettingsHash,
                Date().timeIntervalSince(cached.timestamp) < signatureCacheTTL
            {

                #if DEBUG
                    print("🎯 [UserRulesManager] PersonaSignature 캐시 히트")
                #endif
                return cached.signature
            }

            // 3) 캐시 미스 또는 만료 - 새로 생성
            print("🆔 [UserRulesManager] Generating personaSignature...")

            // 원천 데이터 안전 수집
            let settings = UserSettingsModel.loadFromUserDefaults()
            let selectedLLM = SettingsManager.shared.selectedLLM
            let locale = Locale.current.identifier

            print("👤 [UserRulesManager] Settings loaded:")
            print("   - Nickname: \(settings.nickname.isEmpty ? "empty" : settings.nickname)")
            print("   - Age: \(settings.age ?? 0)")
            print(
                "   - Personality desc: \(settings.personalityDescription.isEmpty ? "empty" : "\(settings.personalityDescription.count) chars")"
            )
            print("   - Personality traits: \(settings.personalityTraits)")
            print("   - Conversation tones: \(settings.conversationTones)")
            print("   - Music preferences: \(settings.musicPreferences.map { $0.rawValue })")
            print("   - LLM: \(selectedLLM.rawValue) (normalized)")
            print("   - Locale: \(locale)")

            // 2) 의미 보존형 특성 요약 (PII 제거 후)
            var traits: [String] = []
            if let age = settings.age, age > 0 { traits.append("age:\(age)") }
            if !settings.conversationTones.isEmpty {
                let tones = settings.conversationTones.prefix(3).map { sanitizePII($0) }.joined(
                    separator: ",")
                traits.append("tones:\(tones)")
            }
            // 친구 톤 프리셋(최대 3개 요약)
            if !settings.preferredFriendTones.isEmpty {
                let tones = settings.preferredFriendTones.prefix(3).map { $0.rawValue }.joined(
                    separator: ",")
                traits.append("friendTones:\(tones)")
            }
            if !settings.personalityTraits.isEmpty {
                let pers = settings.personalityTraits.prefix(3).map { sanitizePII($0) }.joined(
                    separator: ",")
                traits.append("traits:\(pers)")
            }
            // MBTI 다이얼 요약(선택된 축만)
            let mbtiBrief = settings.mbti.briefString()
            if !mbtiBrief.isEmpty { traits.append("mbti:\(mbtiBrief)") }
            if !settings.personalityDescription.isEmpty {
                // 길이 과다 방지: 앞부분만 사용
                let desc = String(sanitizePII(settings.personalityDescription).prefix(64))
                if !desc.isEmpty { traits.append("desc:\(desc)") }
            }
            if !settings.musicPreferences.isEmpty {
                let music = settings.musicPreferences.prefix(3).map { $0.rawValue }.joined(
                    separator: ",")
                traits.append("music:\(music)")
            }

            // 사용자 정의 규칙(요약)
            let rulesDigest = getAllRules().prefix(10)
                .map { "\(sanitizePII($0.userInput))=>\(sanitizePII($0.correctedMeaning))" }
                .joined(separator: "|")
            if !rulesDigest.isEmpty { traits.append("rules:\(rulesDigest)") }

            // 3) 환경 정보 추가 (개인화 핵심 외 변동 요소 포함)
            traits.append("llm:\(selectedLLM.rawValue)")
            traits.append("locale:\(locale)")

            // 4) 결합 후 SHA-256 해시
            let joined = traits.joined(separator: ";")
            let hash = sha256(joined)

            // 5) Core signature 생성 (모델 무관)
            let coreHash = generateCoreSignatureInternal(settings: settings, locale: locale)

            // 6) 캐시 저장
            cachedSignature = CachedPersonaSignature(
                signature: hash,
                coreSignature: coreHash,
                timestamp: Date(),
                settingsHash: currentSettingsHash
            )

            print("🔐 [UserRulesManager] PersonaSignature generated:")
            print("   - Traits combined: \(joined.prefix(200))...")
            print("   - SHA256 hash: \(String(hash.prefix(32)))...")

            return hash
        }
    }

    /// 모델 변경과 무관한 페르소나 핵심 서명(캐시 공유용)
    /// - 주의: LLM 선택과 같은 변동 요소를 포함하지 않습니다.
    public func personaCoreSignature() -> String {
        return cacheQueue.sync {
            // 캐시된 core signature 사용
            if let cached = cachedSignature,
                Date().timeIntervalSince(cached.timestamp) < signatureCacheTTL
            {
                print("🎯 [UserRulesManager] PersonaCoreSignature 캐시 히트")
                return cached.coreSignature
            }

            // 캐시 미스 시 새로 생성
            print("🆔 [UserRulesManager] Generating personaCoreSignature (model-agnostic)...")
            let settings = UserSettingsModel.loadFromUserDefaults()
            let locale = Locale.current.identifier

            return generateCoreSignatureInternal(settings: settings, locale: locale)
        }
    }

    /// Core signature 생성 내부 메서드 (중복 제거)
    private func generateCoreSignatureInternal(settings: UserSettingsModel, locale: String)
        -> String
    {

        var traits: [String] = []
        if let age = settings.age, age > 0 { traits.append("age:\(age)") }
        if !settings.conversationTones.isEmpty {
            let tones = settings.conversationTones.prefix(3).map { sanitizePII($0) }.joined(
                separator: ",")
            traits.append("tones:\(tones)")
        }
        if !settings.preferredFriendTones.isEmpty {
            let tones = settings.preferredFriendTones.prefix(3).map { $0.rawValue }.joined(
                separator: ",")
            traits.append("friendTones:\(tones)")
        }
        if !settings.personalityTraits.isEmpty {
            let pers = settings.personalityTraits.prefix(3).map { sanitizePII($0) }.joined(
                separator: ",")
            traits.append("traits:\(pers)")
        }
        if !settings.personalityDescription.isEmpty {
            let desc = String(sanitizePII(settings.personalityDescription).prefix(64))
            if !desc.isEmpty { traits.append("desc:\(desc)") }
        }
        let mbtiBrief = settings.mbti.briefString()
        if !mbtiBrief.isEmpty { traits.append("mbti:\(mbtiBrief)") }
        if !settings.musicPreferences.isEmpty {
            let music = settings.musicPreferences.prefix(3).map { $0.rawValue }.joined(
                separator: ",")
            traits.append("music:\(music)")
        }
        // 사용자 정의 규칙 요약
        let rulesDigest = getAllRules().prefix(10)
            .map { "\(sanitizePII($0.userInput))=>\(sanitizePII($0.correctedMeaning))" }
            .joined(separator: "|")
        if !rulesDigest.isEmpty { traits.append("rules:\(rulesDigest)") }
        // 환경 중 안정 요소만 포함
        traits.append("locale:\(locale)")

        let joined = traits.joined(separator: ";")
        let hash = sha256(joined)
        print("🔐 [UserRulesManager] PersonaCoreSignature generated: \(String(hash.prefix(32)))...")
        return hash
    }

    /// 설정 해시 계산 (캐시 유효성 검증용)
    private func computeSettingsHash() -> String {
        let settings = UserSettingsModel.loadFromUserDefaults()
        let selectedLLM = SettingsManager.shared.selectedLLM
        let locale = Locale.current.identifier
        let rules = getAllRules()

        // 주요 설정들을 문자열로 결합
        var hashInputs: [String] = []
        hashInputs.append("age:\(settings.age ?? 0)")
        hashInputs.append("nick:\(settings.nickname)")
        hashInputs.append("desc:\(settings.personalityDescription)")
        hashInputs.append("traits:\(settings.personalityTraits.joined(separator: ","))")
        hashInputs.append("tones:\(settings.conversationTones.joined(separator: ","))")
        hashInputs.append(
            "friendTones:\(settings.preferredFriendTones.map { $0.rawValue }.joined(separator: ","))"
        )
        hashInputs.append(
            "music:\(settings.musicPreferences.map { $0.rawValue }.joined(separator: ","))")
        hashInputs.append("mbti:\(settings.mbti.briefString())")
        hashInputs.append("llm:\(selectedLLM.rawValue)")
        hashInputs.append("locale:\(locale)")
        hashInputs.append("rules:\(rules.count)")

        let combined = hashInputs.joined(separator: "|")
        return sha256(combined)
    }

    /// 캐시 무효화 (설정 변경 시 호출)
    public func invalidatePersonaSignatureCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.cachedSignature = nil

            #if DEBUG
                print("🗑️ [UserRulesManager] PersonaSignature 캐시 무효화됨")
            #endif

            // AIContextManager 캐시도 무효화
            AIContextManager.shared.clearCache(reason: .personaChanged, caller: "UserRulesManager")
        }
    }

    // 간단 PII 필터: 이메일/전화번호 패턴 제거(마스킹)
    private func sanitizePII(_ s: String) -> String {
        var out = s
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        out = out.replacingOccurrences(of: emailPattern, with: "[이메일]", options: .regularExpression)
        let phonePattern = "(\\+?\\d{1,3}[ -]?)?(\\d{2,4}[ -]?){2,3}\\d{2,4}"
        out = out.replacingOccurrences(of: phonePattern, with: "[전화]", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sha256(_ text: String) -> String {
        let data = Data(text.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Manages the persistence (saving and loading) of user-defined rules.
/// This class acts as a centralized repository for all custom rules created by the user.
class UserRulesManager {

    // MARK: - Persona Signature Caching
    // (Stored properties were moved from extension; CachedPersonaSignature now file-private)
    private var cachedSignature: CachedPersonaSignature?
    private let signatureCacheTTL: TimeInterval = 3600  // 1시간 캐시
    private let cacheQueue = DispatchQueue(
        label: "persona.signature.cache.queue",
        attributes: .concurrent)

    static let shared = UserRulesManager()

    private var userRules: [UserDefinedRule] = []
    private let fileName = "user_defined_rules.json"

    private var fileURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent(fileName)
    }

    private init() {
        loadRules()
    }

    /// Adds a new rule and saves the updated list to the disk.
    /// - Parameters:
    ///   - userInput: The original text the user entered.
    ///   - correctedMeaning: The correct interpretation provided by the user.
    func addRule(userInput: String, correctedMeaning: String) {
        // To prevent duplicates, remove any old rule for the same user input.
        userRules.removeAll { $0.userInput.lowercased() == userInput.lowercased() }

        let newRule = UserDefinedRule(userInput: userInput, correctedMeaning: correctedMeaning)
        userRules.append(newRule)
        saveRules()

        // 컨텍스트 캐시 무효화 (DRY/일관성)
        AIContextManager.shared.clearCache(
            reason: .personaChanged, caller: "UserRulesManager.addRule")

        // TODO: Integrate with FeedbackManager to queue this for upload.
        print(
            "[UserRulesManager] Added new rule: '\(userInput)' -> '\(correctedMeaning)'. Total rules: \(userRules.count)"
        )
    }

    /// Retrieves all currently stored user rules.
    /// - Returns: An array of `UserDefinedRule`.
    func getAllRules() -> [UserDefinedRule] {
        return userRules
    }

    /// Provides a simple dictionary representation for quick lookups in the processing pipeline.
    /// - Returns: A dictionary mapping user input to its corrected meaning.
    func getRulesAsDictionary() -> [String: String] {
        return Dictionary(
            uniqueKeysWithValues: userRules.map { ($0.userInput, $0.correctedMeaning) })
    }

    /// Saves the current list of rules to a JSON file on the disk.
    private func saveRules() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(userRules)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[UserRules-Error] Failed to save rules: \(error.localizedDescription)")
        }
    }

    /// Loads rules from the JSON file on the disk.
    private func loadRules() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[UserRulesManager] No rule file found. Starting fresh.")
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            self.userRules = try decoder.decode([UserDefinedRule].self, from: data)
            print("[UserRulesManager] Successfully loaded \(userRules.count) user rules.")
        } catch {
            print("[User-RulesError] Failed to load rules: \(error.localizedDescription)")
        }
    }
}
