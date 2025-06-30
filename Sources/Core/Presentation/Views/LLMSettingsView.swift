import SwiftUI

/// LLM 설정 화면
public struct LLMSettingsView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel: LLMSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    
    public init(viewModel: LLMSettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            List {
                subscriptionSection
                serviceSelectionSection
                configurationSection
                usageStatsSection
            }
            .navigationTitle("AI 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                viewModel.refreshServiceStatus()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .alert("오류", isPresented: .constant(viewModel.error != nil)) {
                Button("확인") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
        }
    }
    
    // MARK: - Sections
    
    private var subscriptionSection: some View {
        Section("구독") {
            HStack {
                Text(viewModel.isPremium ? "프리미엄" : "무료")
                    .foregroundColor(viewModel.isPremium ? .green : .secondary)
                
                Spacer()
                
                if !viewModel.isPremium {
                    NavigationLink("업그레이드") {
                        Text("구독 화면")
                    }
                }
            }
        }
    }
    
    private var serviceSelectionSection: some View {
        Section("AI 서비스") {
            ForEach(LLMServiceType.allCases, id: \.self) { service in
                HStack {
                    VStack(alignment: .leading) {
                        Text(service.displayName)
                        
                        if let status = viewModel.serviceStatus[service] {
                            Text(status.statusDescription)
                                .font(.caption)
                                .foregroundColor(status.isAvailable ? .green : .red)
                        }
                    }
                    
                    Spacer()
                    
                    if viewModel.selectedService == service {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectService(service)
                }
            }
        }
    }
    
    private var configurationSection: some View {
        Section("설정") {
            VStack(alignment: .leading) {
                Text("최대 토큰")
                Slider(
                    value: .init(
                        get: { Double(viewModel.requestConfig.maxTokens) },
                        set: { viewModel.updateRequestConfig(maxTokens: Int($0)) }
                    ),
                    in: 100...4096,
                    step: 100
                )
                Text("\(viewModel.requestConfig.maxTokens)")
                    .font(.caption)
            }
            
            VStack(alignment: .leading) {
                Text("온도")
                Slider(
                    value: .init(
                        get: { viewModel.requestConfig.temperature },
                        set: { viewModel.updateRequestConfig(temperature: $0) }
                    ),
                    in: 0...1,
                    step: 0.1
                )
                Text(String(format: "%.1f", viewModel.requestConfig.temperature))
                    .font(.caption)
            }
            
            VStack(alignment: .leading) {
                Text("Top-P")
                Slider(
                    value: .init(
                        get: { viewModel.requestConfig.topP },
                        set: { viewModel.updateRequestConfig(topP: $0) }
                    ),
                    in: 0...1,
                    step: 0.1
                )
                Text(String(format: "%.1f", viewModel.requestConfig.topP))
                    .font(.caption)
            }
        }
    }
    
    private var usageStatsSection: some View {
        Section("사용량 통계") {
            if let stats = viewModel.usageStats[viewModel.selectedService] {
                VStack(alignment: .leading, spacing: 8) {
                    Text("총 요청: \(stats.requestCount)회")
                    Text("총 사용 토큰: \(stats.totalTokens)개")
                    Text("마지막 사용: \(stats.formattedLastUsed)")
                }
                
                Button("통계 초기화") {
                    viewModel.resetUsageStats(for: viewModel.selectedService)
                }
                .foregroundColor(.red)
            } else {
                Text("통계 정보가 없습니다.")
                    .foregroundColor(.secondary)
            }
        }
    }
} 