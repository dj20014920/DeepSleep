//
//  UserSettingsView.swift
//  DeepSleep
//
//  Created by AI on 2025/07/10.
//

import SwiftUI

/// 사용자 설정 화면
public struct UserSettingsView: View {
    
    // MARK: - Properties
    
    @StateObject private var settingsManager = UserSettingsManager.shared
    @State private var showExportAlert = false
    @State private var showImportAlert = false
    @State private var importText = ""
    @State private var exportText = ""
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            Form {
                // AI 모델 선택 섹션
                aiModelSection
                
                // 개인화 설정 섹션
                personalizationSection
                
                // 수면 정보 섹션
                sleepInfoSection
                
                // 고급 설정 섹션
                advancedSection
                
                // 설정 관리 섹션
                settingsManagementSection
            }
            .navigationTitle("개인 설정")
            .navigationBarItems(trailing: Button("저장") {
                settingsManager.saveSettings()
            })
            .alert("설정 내보내기", isPresented: $showExportAlert) {
                Button("복사") {
                    UIPasteboard.general.string = exportText
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("아래 텍스트를 복사하여 설정을 백업하세요:\n\n\(exportText)")
            }
            .alert("설정 가져오기", isPresented: $showImportAlert) {
                TextField("설정 텍스트", text: $importText)
                Button("가져오기") {
                    if settingsManager.importSettings(from: importText) {
                        importText = ""
                    }
                }
                Button("취소", role: .cancel) {
                    importText = ""
                }
            } message: {
                Text("백업된 설정 텍스트를 입력하세요")
            }
        }
    }
    
    // MARK: - AI 모델 선택 섹션
    
    private var aiModelSection: some View {
        Section(header: Text("🤖 AI 모델 설정")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("기본 AI 모델")
                    .font(.headline)
                
                Picker("AI 모델", selection: $settingsManager.settings.preferredAIModel) {
                    ForEach(LLMServiceType.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("모델 우선순위")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("첫 번째 모델이 실패할 경우 순서대로 대체됩니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // TODO: 드래그 앤 드롭으로 순서 변경 가능하도록 개선
                ForEach(settingsManager.settings.modelPriority, id: \.self) { model in
                    HStack {
                        Text("\\(settingsManager.settings.modelPriority.firstIndex(of: model)! + 1). \\(model.displayName)")
                        Spacer()
                        Text("\\(model.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 개인화 설정 섹션
    
    private var personalizationSection: some View {
        Section(header: Text("👤 개인화 설정")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("페르소나 (성격, 성향)")
                    .font(.headline)
                
                TextEditor(text: $settingsManager.settings.userPersona)
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                Text("예: 내성적이고 신중한 성격, 완벽주의 성향, 변화를 어려워함")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("AI가 기억할 개인 정보")
                    .font(.headline)
                
                TextEditor(text: $settingsManager.settings.personalInfo)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                Text("예: 직업, 라이프스타일, 건강 상태, 가족 관계 등 수면에 영향을 주는 정보")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("대화 톤")
                    .font(.headline)
                
                Picker("대화 톤", selection: $settingsManager.settings.conversationTone) {
                    ForEach(ConversationTone.allCases, id: \.self) { tone in
                        VStack(alignment: .leading) {
                            Text(tone.displayName)
                        }.tag(tone)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("개인화 수준")
                    .font(.headline)
                
                Picker("개인화 수준", selection: $settingsManager.settings.personalizationLevel) {
                    ForEach(PersonalizationLevel.allCases, id: \.self) { level in
                        VStack(alignment: .leading) {
                            Text(level.displayName)
                            Text(level.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }.tag(level)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
    
    // MARK: - 수면 정보 섹션
    
    private var sleepInfoSection: some View {
        Section(header: Text("😴 수면 정보")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("목표 수면시간")
                    .font(.headline)
                
                HStack {
                    Slider(
                        value: $settingsManager.settings.targetSleepHours,
                        in: 6...10,
                        step: 0.5
                    )
                    Text("\\(settingsManager.settings.targetSleepHours, specifier: "%.1f")시간")
                        .frame(width: 60)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("평소 취침 시간")
                    .font(.headline)
                
                TextField("예: 23:00", text: $settingsManager.settings.usualBedtime)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("평소 기상 시간")
                    .font(.headline)
                
                TextField("예: 07:00", text: $settingsManager.settings.usualWakeTime)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("주요 수면 고민")
                    .font(.headline)
                
                Text("해당하는 항목을 선택하세요 (복수 선택 가능)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                    ForEach(SleepConcern.allCases, id: \.self) { concern in
                        Button(action: {
                            toggleSleepConcern(concern)
                        }) {
                            HStack {
                                Image(systemName: settingsManager.settings.mainSleepConcerns.contains(concern.rawValue) ? "checkmark.square.fill" : "square")
                                Text(concern.displayName)
                                    .font(.caption)
                                Spacer()
                            }
                            .foregroundColor(settingsManager.settings.mainSleepConcerns.contains(concern.rawValue) ? .blue : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
    
    // MARK: - 고급 설정 섹션
    
    private var advancedSection: some View {
        Section(header: Text("⚙️ 고급 설정")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("대화 기억 범위")
                    .font(.headline)
                
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(settingsManager.settings.memoryDays) },
                            set: { settingsManager.settings.memoryDays = Int($0) }
                        ),
                        in: 1...14,
                        step: 1
                    )
                    Text("\\(settingsManager.settings.memoryDays)일")
                        .frame(width: 40)
                }
                
                Text("최근 \\(settingsManager.settings.memoryDays)일간의 대화를 기억합니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("커스텀 시스템 프롬프트")
                    .font(.headline)
                
                TextEditor(text: $settingsManager.settings.customSystemPrompt)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                Text("AI에게 추가로 전달할 지침이나 요청사항을 입력하세요")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 생성된 시스템 프롬프트 미리보기
            VStack(alignment: .leading, spacing: 8) {
                Text("생성된 시스템 프롬프트 미리보기")
                    .font(.headline)
                
                ScrollView {
                    Text(settingsManager.generateSystemPrompt())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 150)
            }
        }
    }
    
    // MARK: - 설정 관리 섹션
    
    private var settingsManagementSection: some View {
        Section(header: Text("📱 설정 관리")) {
            Button("설정 내보내기") {
                exportText = settingsManager.exportSettings()
                showExportAlert = true
            }
            
            Button("설정 가져오기") {
                showImportAlert = true
            }
            
            Button("설정 초기화") {
                settingsManager.resetSettings()
            }
            .foregroundColor(.red)
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleSleepConcern(_ concern: SleepConcern) {
        if let index = settingsManager.settings.mainSleepConcerns.firstIndex(of: concern.rawValue) {
            settingsManager.settings.mainSleepConcerns.remove(at: index)
        } else {
            settingsManager.settings.mainSleepConcerns.append(concern.rawValue)
        }
    }
}

// MARK: - Preview

struct UserSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        UserSettingsView()
    }
}