import UIKit

/// 2025년 보안 강화 버전의 UserBasicInfoViewController 확장
/// SecureStorageManager + InputValidationManager를 통한 고도화된 보안 적용
extension UserBasicInfoViewController {
    
    // MARK: - 보안 강화된 저장 메서드
    
    /// 보안 강화된 사용자 데이터 저장
    func saveUserDataSecurely() async {
        do {
            // 1단계: 입력 검증
            let (isValid, validationErrors) = performInputValidation()
            
            guard isValid else {
                showValidationError(errors: validationErrors)
                return
            }
            
            // 2단계: 데이터 수집 및 살균
            let sanitizedUserInfo = sanitizeUserData()
            
            // 3단계: 보안 저장소에 저장 (생체인증 포함)
            let userProfile = UserProfile(
                nickname: sanitizedUserInfo.nickname,
                age: sanitizedUserInfo.age ?? 0,
                preferences: convertToSecurePreferences(sanitizedUserInfo)
            )
            
            try await SecureStorageManager.shared.saveUserProfile(userProfile)
            
            // 4단계: 메모리 최적화
            MemoryOptimizationManager.shared.optimizeMemory(rule: .balancedOptimization)
            
            // 5단계: 성공 피드백
            await MainActor.run {
                showSuccessMessage()
                onInfoUpdated?(sanitizedUserInfo)
            }
            
            print("✅ 보안 강화된 사용자 데이터 저장 완료")
            
        } catch {
            await MainActor.run {
                showSecurityError(error)
            }
            print("❌ 보안 저장 실패: \(error.localizedDescription)")
        }
    }
    
    /// 보안 강화된 사용자 데이터 로드
    func loadUserDataSecurely() async {
        do {
            // 1단계: 보안 저장소에서 데이터 로드 (생체인증 포함)
            guard let userProfile = try await SecureStorageManager.shared.loadUserProfile() else {
                print("ℹ️ 저장된 사용자 프로필이 없습니다")
                return
            }
            
            // 2단계: 보안 데이터를 UI 모델로 변환
            let userSettings = convertFromSecureProfile(userProfile)
            
            // 3단계: UI 업데이트 (메인 스레드에서)
            await MainActor.run {
                updateUIWithSecureData(userSettings)
            }
            
            print("✅ 보안 강화된 사용자 데이터 로드 완료")
            
        } catch SecureStorageManager.SecureStorageError.biometricAuthenticationFailed {
            await MainActor.run {
                showBiometricAuthError()
            }
        } catch {
            await MainActor.run {
                showSecurityError(error)
            }
            print("❌ 보안 로드 실패: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 입력 검증
    
    private func performInputValidation() -> (isValid: Bool, errors: [String]) {
        let validator = InputValidationManager.shared
        
        // 닉네임 검증
        let nicknameResult = validator.validate(nameTextField.text ?? "", against: .nickname)
        
        // 나이 검증 (선택사항이므로 빈 문자열 허용)
        let ageText = ageTextField.text ?? ""
        let ageResult = ageText.isEmpty ? 
            InputValidationManager.ValidationResult(isValid: true, sanitizedValue: "", errorMessage: nil, securityIssues: []) :
            validator.validate(ageText, against: .age)
        
        // 자기소개 검증 (XSS 방지)
        let personalityResult = validator.validate(personalityTextView.text ?? "", against: .searchQuery)
        
        // 보안 이슈 로깅
        validator.logSecurityIncident(nicknameResult, input: nameTextField.text ?? "", context: "UserBasicInfo.nickname")
        validator.logSecurityIncident(ageResult, input: ageText, context: "UserBasicInfo.age")
        validator.logSecurityIncident(personalityResult, input: personalityTextView.text ?? "", context: "UserBasicInfo.personality")
        
        // 에러 수집
        var errors: [String] = []
        
        if !nicknameResult.isValid {
            errors.append(nicknameResult.errorMessage ?? "닉네임이 유효하지 않습니다")
        }
        
        if !ageResult.isValid {
            errors.append(ageResult.errorMessage ?? "나이가 유효하지 않습니다")
        }
        
        if !personalityResult.isValid {
            errors.append("자기소개에 허용되지 않는 내용이 포함되어 있습니다")
        }
        
        // UI 피드백 적용
        applyValidationFeedbackToUI(
            nickname: nicknameResult.isValid,
            age: ageResult.isValid,
            personality: personalityResult.isValid
        )
        
        return (errors.isEmpty, errors)
    }
    
    private func sanitizeUserData() -> UserSettingsModel {
        let validator = InputValidationManager.shared
        var sanitizedInfo = userInfo
        
        // 닉네임 살균
        let nicknameResult = validator.validate(nameTextField.text ?? "", against: .nickname)
        sanitizedInfo.nickname = nicknameResult.sanitizedValue ?? ""
        
        // 나이 살균
        let ageText = ageTextField.text ?? ""
        if !ageText.isEmpty {
            let ageResult = validator.validate(ageText, against: .age)
            sanitizedInfo.age = Int(ageResult.sanitizedValue ?? "")
        }
        
        // 자기소개 살균 (XSS 방지)
        let personalityResult = validator.validate(personalityTextView.text ?? "", against: .searchQuery)
        sanitizedInfo.personalityDescription = personalityResult.sanitizedValue ?? ""
        
        return sanitizedInfo
    }
    
    // MARK: - UI 검증 피드백
    
    private func applyValidationFeedbackToUI(nickname: Bool, age: Bool, personality: Bool) {
        // 닉네임 필드 피드백
        nameTextField.layer.borderColor = nickname ? UIColor.systemGreen.cgColor : UIColor.systemRed.cgColor
        nameTextField.layer.borderWidth = 1.0
        nameTextField.layer.cornerRadius = 8.0
        
        // 나이 필드 피드백
        ageTextField.layer.borderColor = age ? UIColor.systemGreen.cgColor : UIColor.systemRed.cgColor
        ageTextField.layer.borderWidth = 1.0
        ageTextField.layer.cornerRadius = 8.0
        
        // 자기소개 필드 피드백
        personalityTextView.layer.borderColor = personality ? UIColor.systemGreen.cgColor : UIColor.systemRed.cgColor
        personalityTextView.layer.borderWidth = 2.0
    }
    
    // MARK: - 데이터 변환
    
    private func convertToSecurePreferences(_ userInfo: UserSettingsModel) -> [String: Any] {
        return [
            "personalityTraits": userInfo.personalityTraits,
            "musicPreferences": userInfo.musicPreferences.map { $0.rawValue },
            "conversationTones": userInfo.conversationTones,
            "personalityDescription": userInfo.personalityDescription,
            "lastUpdated": Date().timeIntervalSince1970
        ]
    }
    
    private func convertFromSecureProfile(_ profile: UserProfile) -> UserSettingsModel {
        var userSettings = UserSettingsModel()
        userSettings.nickname = profile.nickname
        userSettings.age = profile.age == 0 ? nil : profile.age
        
        // preferences에서 데이터 복원
        if let personalityTraits = profile.preferences["personalityTraits"] as? [String] {
            userSettings.personalityTraits = personalityTraits
        }
        
        if let musicPreferenceStrings = profile.preferences["musicPreferences"] as? [String] {
            userSettings.musicPreferences = musicPreferenceStrings.compactMap { MusicStyle(rawValue: $0) }
        }
        
        if let conversationTones = profile.preferences["conversationTones"] as? [String] {
            userSettings.conversationTones = conversationTones
        }
        
        if let personalityDescription = profile.preferences["personalityDescription"] as? String {
            userSettings.personalityDescription = personalityDescription
        }
        
        return userSettings
    }
    
    private func updateUIWithSecureData(_ userSettings: UserSettingsModel) {
        userInfo = userSettings
        nameTextField.text = userSettings.nickname
        ageTextField.text = userSettings.age != nil ? "\(userSettings.age!)" : ""
        personalityTextView.text = userSettings.personalityDescription
        updatePlaceholderVisibility()
        restoreQuickSelections()
    }
    
    // MARK: - 에러 처리 및 사용자 피드백
    
    private func showValidationError(errors: [String]) {
        let alert = UIAlertController(
            title: "입력 오류",
            message: "다음 문제를 해결해주세요:\n\n" + errors.joined(separator: "\n"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    private func showSecurityError(_ error: Error) {
        let alert = UIAlertController(
            title: "보안 오류",
            message: "데이터 저장 중 보안 문제가 발생했습니다.\n\n\(error.localizedDescription)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
    
    private func showBiometricAuthError() {
        let alert = UIAlertController(
            title: "생체인증 필요",
            message: "안전한 데이터 접근을 위해 Face ID 또는 Touch ID가 필요합니다.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "다시 시도", style: .default) { [weak self] _ in
            Task {
                await self?.loadUserDataSecurely()
            }
        })
        
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showSuccessMessage() {
        // Toast 스타일 성공 메시지
        let alert = UIAlertController(
            title: "저장 완료",
            message: "보안 강화된 저장소에 안전하게 저장되었습니다.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
        
        // 성공 시 UI 피드백 초기화
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.resetValidationFeedback()
        }
    }
    
    private func resetValidationFeedback() {
        nameTextField.layer.borderWidth = 0
        ageTextField.layer.borderWidth = 0
        personalityTextView.layer.borderWidth = 1.0
        personalityTextView.layer.borderColor = UIColor.systemGray4.cgColor
    }
    
    // MARK: - 메모리 최적화된 액션 오버라이드
    
    /// 기존 saveButtonTapped을 보안 강화 버전으로 교체
    @objc func saveButtonTappedSecure() {
        // 메모리 누수 방지를 위한 weak self 패턴
        Task { [weak self] in
            await self?.saveUserDataSecurely()
        }
    }
    
    /// 뷰 로드 시 보안 데이터 로드
    func viewDidLoadSecure() {
        Task { [weak self] in
            await self?.loadUserDataSecurely()
        }
    }
    
    // MARK: - 실시간 입력 검증
    
    /// TextField 실시간 검증 (메모리 최적화됨)
    @objc func textFieldChangedSecure(_ textField: UITextField) {
        // 디바운스를 통한 성능 최적화
        NSObject.cancelPreviousPerformRequests(target: self, selector: #selector(performDelayedValidation), object: textField)
        perform(#selector(performDelayedValidation), with: textField, afterDelay: 0.5)
    }
    
    @objc private func performDelayedValidation(_ textField: UITextField) {
        autoreleasepool { [weak self] in
            guard let self = self else { return }
            
            let validator = InputValidationManager.shared
            let rule: InputValidationManager.ValidationRule = (textField == nameTextField) ? .nickname : .age
            
            let isValid = validator.validateTextField(textField, rule: rule, showAlert: false)
            
            // UI 피드백 적용
            textField.layer.borderColor = isValid ? UIColor.systemGreen.cgColor : UIColor.systemRed.cgColor
            textField.layer.borderWidth = 1.0
            textField.layer.cornerRadius = 8.0
        }
    }
}

// MARK: - 보안 강화된 메모리 관리
extension UserBasicInfoViewController {
    
    /// 뷰 컨트롤러 해제 시 메모리 정리
    func performSecureCleanup() {
        // 민감한 텍스트 필드 클리어
        nameTextField.text = nil
        ageTextField.text = nil
        personalityTextView.text = nil
        
        // 버튼 상태 초기화
        for button in personalityButtons + musicPreferenceButtons + tonePreferenceButtons {
            button.isSelected = false
        }
        
        // 메모리 최적화 수행
        MemoryOptimizationManager.shared.optimizeMemory(rule: .aggressiveCleanup)
        
        print("🧹 UserBasicInfoViewController 보안 정리 완료")
    }
    
    /// 백그라운드 진입 시 민감 정보 숨김
    func hideSecureContentForBackground() {
        // 민감한 정보를 임시로 숨김 (스크린샷 방지)
        nameTextField.isSecureTextEntry = true
        personalityTextView.alpha = 0.0
    }
    
    /// 포그라운드 복귀 시 민감 정보 복원
    func showSecureContentForForeground() {
        nameTextField.isSecureTextEntry = false
        personalityTextView.alpha = 1.0
    }
}

// MARK: - 생체인증 상태 모니터링
extension UserBasicInfoViewController {
    
    /// 생체인증 가용성 체크 및 UI 업데이트
    func updateBiometricAvailability() {
        let isAvailable = SecureStorageManager.shared.checkBiometricAvailability()
        
        if !isAvailable {
            // 생체인증 불가능한 경우 사용자에게 안내
            showBiometricUnavailableWarning()
        }
    }
    
    private func showBiometricUnavailableWarning() {
        let alert = UIAlertController(
            title: "보안 설정 권장",
            message: "더 안전한 데이터 보호를 위해 Face ID 또는 Touch ID를 설정하시는 것을 권장합니다.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "설정으로 이동", style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        })
        
        alert.addAction(UIAlertAction(title: "나중에", style: .cancel))
        present(alert, animated: true)
    }
}