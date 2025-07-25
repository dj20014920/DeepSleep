import SwiftUI

/// 사용자 페르소나 및 AI 설정 화면
@available(iOS 17.0, *)
struct PersonaSettingsView: View {
    @ObservedObject var personaManager: PersonaMemoryManager
    @State private var isEditing = false
    @State private var editingPersona: AdvancedUserPersona?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("AI 페르소나 설정")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("당신의 AI 어시스턴트를 개인화하세요")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // 메모리 시스템 상태
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                            Text("메모리 시스템 상태")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        VStack(spacing: 8) {
                            MemoryStatusRow(
                                title: "메모리 건강도",
                                value: String(format: "%.1f%%", personaManager.memoryHealth * 100),
                                icon: "heart.circle.fill",
                                color: personaManager.memoryHealth > 0.8 ? .green : (personaManager.memoryHealth > 0.6 ? .orange : .red)
                            )
                            
                            MemoryStatusRow(
                                title: "시간적 일관성",
                                value: String(format: "%.1f%%", personaManager.temporalCoherenceScore * 100),
                                icon: "clock.circle.fill",
                                color: .blue
                            )
                            
                            MemoryStatusRow(
                                title: "인지 부하",
                                value: String(format: "%.1f%%", personaManager.cognitiveLoadIndex * 100),
                                icon: "brain.circle.fill",
                                color: personaManager.cognitiveLoadIndex < 0.5 ? .green : (personaManager.cognitiveLoadIndex < 0.8 ? .orange : .red)
                            )
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // 메모리 통계
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                            Text("메모리 통계")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        HStack(spacing: 20) {
                            MemoryCountCard(
                                title: "에피소드 메모리",
                                count: personaManager.episodicMemoryCount,
                                icon: "memories",
                                color: .purple
                            )
                            
                            MemoryCountCard(
                                title: "의미적 지식",
                                count: personaManager.semanticMemoryCount,
                                icon: "book.fill",
                                color: .blue
                            )
                            
                            MemoryCountCard(
                                title: "절차적 기억",
                                count: personaManager.proceduralMemoryCount,
                                icon: "gearshape.fill",
                                color: .green
                            )
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // 페르소나 설정
                    if let persona = currentPersona {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.blue)
                                Text("페르소나 설정")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            // 인지 프로필
                            VStack(alignment: .leading, spacing: 12) {
                                Text("인지 프로필")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                CognitiveProfileSlider(
                                    title: "처리 속도",
                                    value: .constant(persona.cognitiveProfile.processingSpeed),
                                    isEditing: isEditing
                                )
                                
                                CognitiveProfileSlider(
                                    title: "메모리 용량",
                                    value: .constant(persona.cognitiveProfile.memoryCapacity),
                                    isEditing: isEditing
                                )
                                
                                CognitiveProfileSlider(
                                    title: "주의 집중 시간",
                                    value: .constant(persona.cognitiveProfile.attentionSpan),
                                    isEditing: isEditing
                                )
                            }
                            
                            Divider()
                            
                            // 메모리 선호도
                            VStack(alignment: .leading, spacing: 12) {
                                Text("메모리 선호도")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                MemoryPreferenceSlider(
                                    title: "망각률",
                                    value: .constant(persona.memoryPreferences.forgettingRate),
                                    range: 0...1,
                                    isEditing: isEditing
                                )
                                
                                MemoryPreferenceSlider(
                                    title: "중요도 임계값",
                                    value: .constant(persona.memoryPreferences.importanceThreshold),
                                    range: 0...1,
                                    isEditing: isEditing
                                )
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // 시스템 진단
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "stethoscope")
                                .foregroundColor(.blue)
                            Text("시스템 진단")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        let diagnostics = personaManager.getMemorySystemDiagnostics()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("시스템 버전: \(diagnostics.systemVersion)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("총 메모리: \(diagnostics.totalMemories)개")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if personaManager.memoryConsolidationProgress > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("메모리 통합 진행 중...")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    
                                    ProgressView(value: personaManager.memoryConsolidationProgress)
                                        .progressViewStyle(LinearProgressViewStyle())
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // AI 모델 설정
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "square.3.stack.3d.top.filled")
                                .foregroundColor(.blue)
                            Text("AI 엔진 설정")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        NavigationLink(destination: Text("AI 모델 설정 (준비 중)")) {
                            HStack {
                                Text("사용 모델 변경")
                                Spacer()
                                // 현재 선택된 모델을 표시하여 사용자에게 정보를 제공
                                Text(SettingsManager.shared.selectedLLM.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // 액션 버튼들
                    VStack(spacing: 12) {
                        Button("메모리 시스템 최적화") {
                            Task {
                                await personaManager.optimizeMemorySystem()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(personaManager.isProcessing)
                        
                        if personaManager.isProcessing {
                            ProgressView("처리 중...")
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("페르소나")
        }
    }
    
    // MARK: - Helper Properties
    
    private var currentPersona: AdvancedUserPersona? {
        editingPersona ?? personaManager.currentPersona
    }
}

// MARK: - Supporting Views

struct MemoryStatusRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct MemoryCountCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

struct CognitiveProfileSlider: View {
    let title: String
    @Binding var value: Double
    let isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1f%%", value * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if isEditing {
                Slider(value: $value, in: 0...1)
                    .accentColor(.blue)
            } else {
                ProgressView(value: value)
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
    }
}

struct MemoryPreferenceSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let isEditing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1f%%", value * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if isEditing {
                Slider(value: $value, in: range)
                    .accentColor(.blue)
            } else {
                ProgressView(value: value)
                    .progressViewStyle(LinearProgressViewStyle())
            }
        }
    }
}

// MARK: - Preview

@available(iOS 17.0, *)
struct PersonaSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // ✅ ChatManager 기반으로 변경됨 - 파라미터 없는 초기화
        PersonaSettingsView(personaManager: PersonaMemoryManager())
    }
} 
