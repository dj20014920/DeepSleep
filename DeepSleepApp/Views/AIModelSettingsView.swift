import SwiftUI

/// 🤖 AI 모델 선택 SwiftUI 뷰
/// 대나무숲 친구(AI 모델)를 선택하는 화면
@available(iOS 17.0, *)
struct AIModelSettingsView: View {
    @State private var selectedModel: AIModelType = SettingsManager.shared.selectedLLM
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 헤더
                VStack(spacing: 12) {
                    Text("🌳 대나무숲 친구 선택")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("당신과 대화할 AI 친구를 선택하세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // 모델 카드들
                VStack(spacing: 16) {
                    ForEach(AIModelType.allCases, id: \.self) { model in
                        ModelCard(
                            model: model,
                            isSelected: selectedModel == model,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedModel = model
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                // 저장 버튼
                Button(action: saveSelection) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("선택 완료")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("AI 모델 설정")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func saveSelection() {
        // SettingsManager에 저장
        SettingsManager.shared.selectedLLM = selectedModel
        
        // UserDefaults에 저장 - SettingsManager의 키와 통일
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "selectedLLM")
        
        // 화면 닫기
        dismiss()
    }
}

// MARK: - Model Card Component
private struct ModelCard: View {
    let model: AIModelType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 헤더
                HStack {
                    Text("\(model.icon) \(model.displayName)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // 설명
                Text(model.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                // 특징들
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.features, id: \.self) { feature in
                            FeatureChip(text: feature, isSelected: isSelected)
                        }
                    }
                }
                
                // 추가 정보 (온디바이스 모델의 경우)
                if model == .onDevice {
                    HStack {
                        Image(systemName: "lock.shield")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("모든 데이터가 기기에서만 처리됩니다")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(UIColor.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Feature Chip Component
private struct FeatureChip: View {
    let text: String
    let isSelected: Bool
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color(UIColor.systemGray5))
            )
            .foregroundColor(isSelected ? .blue : .secondary)
    }
}

// MARK: - Preview
@available(iOS 17.0, *)
struct AIModelSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AIModelSettingsView()
        }
    }
}