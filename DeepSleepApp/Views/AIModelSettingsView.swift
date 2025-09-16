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

                    Text("당신과 대화할 대나무숲 친구를 선택하세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // 모델 카드들
                VStack(spacing: 16) {
                    // 구독 상태에 따른 모델 목록 제한 + "실험 친구" 제거
                    let isPremium = SubscriptionStatusCenter.shared.isPremium
                    let availableModels: [AIModelType] = {
                        let all = AIModelType.allCases.filter { $0 != .testModel }
                        // 온디바이스(.onDevice)는 모든 사용자에게 노출
                        if isPremium { return all }
                        return all.filter { $0 == .freeModel || $0 == .gemini || $0 == .onDevice }
                    }()
                    ForEach(availableModels, id: \.self) { model in
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
        .navigationTitle("대나무숲 친구 설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func saveSelection() {
        // 단일 진입점으로 원자 저장(+캐시 무효화 브로드캐스트)
        SettingsManager.shared.updateSelectedModelAtomically(selectedModel)

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

                    // 온디바이스 설치/진행률/관리 인라인 UI
                    OnDeviceInlineManagerView()
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

// MARK: - On-Device Inline Manager
private struct OnDeviceInlineManagerView: View {
    @State private var progress: Double = 0
    @State private var status: String = "설치되지 않음"
    @State private var installing: Bool = false
    @State private var installed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                ProgressView(value: (installing ? progress : (installed ? 1.0 : 0.0)))
                    .progressViewStyle(.linear)
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                if !installed && !installing {
                    Button {
                        startInstall()
                    } label: {
                        Label("설치", systemImage: "arrow.down.circle")
                    }
                }

                if installing {
                    Button(role: .destructive) {
                        OnDeviceAdapter.shared.cancelInstall(id: .gemma270_q8)
                        installing = false
                        progress = 0
                        status = "취소됨"
                    } label: {
                        Label("취소", systemImage: "xmark.circle")
                    }
                }

                if installed {
                    Button(role: .destructive) {
                        do {
                            try OnDeviceAdapter.shared.deleteInstalled(id: .gemma270_q8)
                            installed = false
                            progress = 0
                            status = "삭제됨"
                        } catch {
                            status = "삭제 오류: \(error.localizedDescription)"
                        }
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .task { await refresh() }
    }

    @MainActor
    private func update(_ state: BackgroundAssetState) {
        switch state {
        case .installed:
            installed = true
            installing = false
            progress = 1.0
            status = "설치됨"
        case .installing(let p):
            installing = true
            installed = false
            progress = max(0, min(1, p))
            status = "다운로드 중 \(Int(progress * 100))%"
        case .notInstalled:
            installing = false
            installed = false
            progress = 0
            status = "설치되지 않음"
        case .failed(let desc):
            installing = false
            installed = false
            progress = 0
            status = "실패: \(desc)"
        }
    }

    private func refresh() async {
        let st = await OnDeviceAdapter.shared.status(for: .gemma270_q8)
        await MainActor.run { update(st) }
    }

    private func startInstall() {
        installing = true
        status = "다운로드 시작"
        Task {
            do {
                let _ = try await OnDeviceAdapter.shared.ensureInstalled(id: .gemma270_q8) { p in
                    Task { @MainActor in
                        installing = true
                        progress = max(0, min(1, p))
                        status = "다운로드 중 \(Int(progress * 100))%"
                    }
                }
                await MainActor.run {
                    installed = true
                    installing = false
                    progress = 1.0
                    status = "설치됨"
                }
            } catch {
                await MainActor.run {
                    installing = false
                    status = "오류: \(error.localizedDescription)"
                }
            }
        }
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
