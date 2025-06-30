import SwiftUI

struct AIModelSettingsView: View {
    
    @StateObject private var viewModel = AIModelSettingsViewModel()
    
    var body: some View {
        Form {
            Section(header: Text(viewModel.selectionSectionTitle)) {
                Picker("모델 선택", selection: $viewModel.selectedModel) {
                    ForEach(viewModel.availableModels, id: \.self) { model in
                        VStack(alignment: .leading) {
                            Text(model.displayName).tag(model)
                            Text(model.description)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            
            // iOS 18 이상에서만 온디바이스 설정 섹션을 표시
            if #available(iOS 18.0, *) {
                Section(footer: Text(viewModel.onDeviceSectionFooter)) {
                    Toggle("온디바이스 AI 우선 사용", isOn: $viewModel.useOnDeviceModel)
                }
            }
        }
        .navigationTitle("AI 모델 설정")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AIModelSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AIModelSettingsView()
        }
    }
} 