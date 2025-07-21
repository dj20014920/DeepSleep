import SwiftUI

public struct AIModelSettingsView: View {
    
    @StateObject private var viewModel = AIModelSettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 헤더
                VStack(spacing: 8) {
                    Text("대나무숲 친구 선택")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("대화에 사용할 친구를 선택해주세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // AI 모델 선택 카드들
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.availableModels, id: \.self) { model in
                        AIModelSelectionCard(
                            model: model,
                            isSelected: viewModel.isModelSelected(model),
                            features: getFeaturesForModel(model)
                        ) {
                            viewModel.selectModel(model)
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // iOS 18 이상에서만 온디바이스 설정 섹션을 표시
                if #available(iOS 18.0, *) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "iphone")
                                .foregroundColor(.blue)
                            Text("온디바이스 우선 사용")
                                .font(.headline)
                            Spacer()
                            Toggle("", isOn: $viewModel.useOnDeviceModel)
                        }
                        
                        Text(viewModel.onDeviceSectionFooter)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                }
                
                Spacer(minLength: 40)
            }
        }
        .navigationTitle("대나무숲 친구 선택")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // 각 모델별 특징 정의
    private func getFeaturesForModel(_ model: LLMServiceType) -> [String] {
        switch model {
        case .claude:
            return ["깊은 공감", "철학적 사고", "세심한 분석", "윤리적 조언"]
        case .gemini:
            return ["창의적 발상", "재미있는 대화", "유연한 사고", "상상력 풍부"]
        case .naver:
            return ["친근한 말투", "한국 문화", "현실적 조언", "정겨운 소통"]
        case .openAI:
            return ["빠른 응답", "논리적 분석", "체계적 정리", "명확한 설명"]
        case .onDevice:
            return ["빠른 처리", "개인정보 보호", "오프라인 사용", "배터리 효율"]
        }
    }
}

// MARK: - AI 모델 선택 카드 컴포넌트
struct AIModelSelectionCard: View {
    let model: LLMServiceType
    let isSelected: Bool
    let features: [String]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 헤더: 모델 아이콘 + 모델명
                HStack {
                    // 모델 아이콘을 앞에 배치
                    Image(systemName: getIconForModel(model))
                        .foregroundColor(isSelected ? .blue : .gray)
                        .font(.title2)
                        .frame(width: 30, height: 30)
                    
                    Text(model.displayName)
                        .font(.title3)  // 더 큰 폰트 사이즈
                        .fontWeight(.bold)  // 더 강한 폰트 웨이트
                        .foregroundColor(isSelected ? .blue : .primary)
                    
                    Spacer()
                }
                
                // 특징 버블/태그들 - 4개가 한 줄에 들어가도록 최적화
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 8) {
                    ForEach(features, id: \.self) { feature in
                        Text(feature)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                            )
                            .foregroundColor(isSelected ? .blue : .secondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                            .minimumScaleFactor(0.8)  // 텍스트가 길면 자동으로 축소
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 각 모델별 아이콘
    private func getIconForModel(_ model: LLMServiceType) -> String {
        switch model {
        case .claude: return "brain.head.profile"
        case .gemini: return "sparkles"
        case .naver: return "person.badge.shield.checkmark.fill"  // 네이버는 한국 기업이니 보안/신뢰 아이콘
        case .openAI: return "bolt.fill"
        case .onDevice: return "iphone"
        }
    }
}

struct AIModelSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AIModelSettingsView()
        }
    }
}
