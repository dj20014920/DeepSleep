import Foundation
import SwiftUI

/// `AIModelSettingsView`의 상태와 로직을 관리하는 뷰모델
@MainActor
public class AIModelSettingsViewModel: ObservableObject {
    
    @Published public var availableModels: [LLMServiceType] = LLMServiceType.allCases.filter { $0 != .onDevice }
    @Published public var selectedModel: LLMServiceType = .claude {
        didSet {
            // UserDefaults에 직접 저장 (임시 해결책)
            UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedLLM")
        }
    }
    
    @Published var useOnDeviceModel: Bool = false
    
    // MARK: - Initialization
    public init() {
        // UserDefaults에서 선택된 모델 로드
        if let savedModel = UserDefaults.standard.string(forKey: "selectedLLM"),
           let model = LLMServiceType(rawValue: savedModel) {
            self.selectedModel = model
        }
        loadAvailableModels()
    }
    
    // MARK: - Public Methods
    
    public func loadAvailableModels() {
        // iOS 18 이상에서만 온디바이스 모델 추가
        availableModels = LLMServiceType.allCases.filter { model in
            if model == .onDevice {
                if #available(iOS 18.0, *) {
                    return true
                } else {
                    return false
                }
            }
            return true
        }
    }
    
    public func selectModel(_ model: LLMServiceType) {
        selectedModel = model
    }
    
    public func isModelSelected(_ model: LLMServiceType) -> Bool {
        return selectedModel == model
    }
    
    /// 모델 선택 섹션의 제목
    public var selectionSectionTitle: String {
        "사용할 AI 모델 선택"
    }
    
    /// 온디바이스 모델 설정 섹션의 설명
    public var onDeviceSectionFooter: String {
        "활성화 시, iOS 18 이상을 사용하는 기기에서는 일부 간단한 요청을 인터넷 연결 없이 기기 내에서 처리하여 응답 속도를 높이고 개인정보를 보호합니다."
    }
}

// MARK: - 2025 최적화: 메모리 관리
extension AIModelSettingsViewModel {
    public func cleanup() {
        // 필요시 메모리 정리
    }
} 