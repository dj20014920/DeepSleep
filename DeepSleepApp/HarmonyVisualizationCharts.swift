import SwiftUI
import Charts

/// 🌈 조화도 트렌드 차트 - 시간에 따른 조화 점수 변화
@available(iOS 16.0, *)
struct HarmonyTrendChart: View {
    @State private var trendData: [HarmonyTrendPoint] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("조화도 트렌드")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("최근 7일")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if trendData.isEmpty {
                // 샘플 데이터 생성
                Chart(generateSampleTrendData()) { point in
                    LineMark(
                        x: .value("날짜", point.date),
                        y: .value("점수", point.score)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("날짜", point.date),
                        y: .value("점수", point.score)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                    
                    PointMark(
                        x: .value("날짜", point.date),
                        y: .value("점수", point.score)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(30)
                }
            } else {
                Chart(trendData) { point in
                    LineMark(
                        x: .value("날짜", point.date),
                        y: .value("점수", point.score)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("날짜", point.date),
                        y: .value("점수", point.score)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                    
                    PointMark(
                        x: .value("날짜", point.date),
                        y: .value("점수", point.score)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(30)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadTrendData()
        }
    }
    
    private func generateSampleTrendData() -> [HarmonyTrendPoint] {
        let calendar = Calendar.current
        let now = Date()
        
        return (0..<7).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { return nil }
            let score = Float.random(in: 60...95)
            return HarmonyTrendPoint(date: date, score: score)
        }.reversed()
    }
    
    private func loadTrendData() {
        // 실제 데이터 로딩 로직
        if #available(iOS 17.0, *) {
            trendData = PersonalizedHarmonyLearner.shared.getHarmonyTrendData()
        }
    }
}

/// 🎯 충돌 레이더 차트 - 다양한 충돌 타입별 심각도
@available(iOS 16.0, *)
struct ConflictRadarChart: View {
    @State private var conflictData: [ConflictRadarPoint] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "radar")
                    .foregroundColor(.red)
                Text("충돌 분석")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("현재 프리셋")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if conflictData.isEmpty {
                Chart(generateSampleConflictData()) { point in
                    BarMark(
                        x: .value("충돌 타입", point.conflictType),
                        y: .value("심각도", point.severity)
                    )
                    .foregroundStyle(getConflictColor(severity: point.severity))
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let severity = value.as(Double.self) {
                                Text("\(Int(severity * 100))%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let conflictType = value.as(String.self) {
                                Text(getConflictEmoji(type: conflictType))
                                    .font(.caption)
                            }
                        }
                    }
                }
            } else {
                Chart(conflictData) { point in
                    BarMark(
                        x: .value("충돌 타입", point.conflictType),
                        y: .value("심각도", point.severity)
                    )
                    .foregroundStyle(getConflictColor(severity: point.severity))
                    .cornerRadius(4)
                }
            }
            
            // 범례
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(generateSampleConflictData(), id: \.conflictType) { point in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(getConflictColor(severity: point.severity))
                            .frame(width: 8, height: 8)
                        Text(getConflictShortName(type: point.conflictType))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadConflictData()
        }
    }
    
    private func generateSampleConflictData() -> [ConflictRadarPoint] {
        let conflictTypes = [
            "주파수 마스킹", "리듬 충돌", "감정적 부조화", 
            "다이나믹 레인지", "길이 불일치", "시간적 부적합"
        ]
        
        return conflictTypes.map { type in
            ConflictRadarPoint(
                conflictType: type,
                severity: Double.random(in: 0.0...0.8)
            )
        }
    }
    
    private func getConflictColor(severity: Double) -> Color {
        switch severity {
        case 0.0..<0.2:
            return .green
        case 0.2..<0.4:
            return .yellow
        case 0.4..<0.6:
            return .orange
        default:
            return .red
        }
    }
    
    private func getConflictEmoji(type: String) -> String {
        switch type {
        case "주파수 마스킹": return "🎵"
        case "리듬 충돌": return "🥁"
        case "감정적 부조화": return "😰"
        case "다이나믹 레인지": return "📊"
        case "길이 불일치": return "⏱️"
        case "시간적 부적합": return "🕐"
        default: return "⚠️"
        }
    }
    
    private func getConflictShortName(type: String) -> String {
        switch type {
        case "주파수 마스킹": return "주파수"
        case "리듬 충돌": return "리듬"
        case "감정적 부조화": return "감정"
        case "다이나믹 레인지": return "음량"
        case "길이 불일치": return "길이"
        case "시간적 부적합": return "시간"
        default: return type
        }
    }
    
    private func loadConflictData() {
        // 실제 충돌 데이터 로딩 로직
        if #available(iOS 17.0, *) {
            conflictData = PersonalizedHarmonyLearner.shared.getCurrentConflictData()
        }
    }
}

/// 🚀 개선 제안 뷰 - AI 기반 조화도 향상 제안
@available(iOS 16.0, *)
struct ImprovementSuggestionView: View {
    @State private var suggestions: [ImprovementSuggestion] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("스마트 개선 제안")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                    Text("AI 분석")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if suggestions.isEmpty {
                        ForEach(generateSampleSuggestions(), id: \.id) { suggestion in
                            SuggestionCard(suggestion: suggestion)
                        }
                    } else {
                        ForEach(suggestions, id: \.id) { suggestion in
                            SuggestionCard(suggestion: suggestion)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            loadSuggestions()
        }
    }
    
    private func generateSampleSuggestions() -> [ImprovementSuggestion] {
        return [
            ImprovementSuggestion(
                id: "1",
                title: "음원 교체",
                description: "\"파도\" → \"우주\" 사운드로 변경",
                improvementScore: 6,
                confidence: 0.85,
                type: .replacement
            ),
            ImprovementSuggestion(
                id: "2",
                title: "볼륨 조정",
                description: "새 소리 볼륨을 30% 낮추기",
                improvementScore: 3,
                confidence: 0.92,
                type: .volumeAdjustment
            ),
            ImprovementSuggestion(
                id: "3",
                title: "시간 조정",
                description: "밤 시간대에 더 적합한 조합",
                improvementScore: 4,
                confidence: 0.78,
                type: .timing
            )
        ]
    }
    
    private func loadSuggestions() {
        // 실제 AI 기반 제안 로딩
        if #available(iOS 17.0, *) {
            suggestions = PersonalizedHarmonyLearner.shared.generateImprovementSuggestions()
        }
    }
}

/// 🎴 개선 제안 카드 컴포넌트
struct SuggestionCard: View {
    let suggestion: ImprovementSuggestion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.type.emoji)
                    .font(.title2)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("+\(suggestion.improvementScore)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("\(Int(suggestion.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(suggestion.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text(suggestion.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Spacer()
                Button("적용") {
                    applySuggestion(suggestion)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(12)
        .frame(width: 160, height: 120)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func applySuggestion(_ suggestion: ImprovementSuggestion) {
        print("🚀 [ImprovementSuggestion] 제안 적용: \(suggestion.title)")
        
        // 제안 적용 로직
        if #available(iOS 17.0, *) {
            PersonalizedHarmonyLearner.shared.applySuggestion(suggestion)
        }
        
        // 햅틱 피드백
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// MARK: - Data Models

struct HarmonyTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Float
}

struct ConflictRadarPoint: Identifiable {
    var id: String { conflictType }
    let conflictType: String
    let severity: Double
}

struct ImprovementSuggestion {
    let id: String
    let title: String
    let description: String
    let improvementScore: Int // 예상 개선 점수
    let confidence: Double // AI 신뢰도 (0.0 ~ 1.0)
    let type: SuggestionType
}

enum SuggestionType {
    case replacement    // 음원 교체
    case volumeAdjustment // 볼륨 조정
    case timing         // 시간대 조정
    case combination    // 조합 변경
    
    var emoji: String {
        switch self {
        case .replacement: return "🔄"
        case .volumeAdjustment: return "🔊"
        case .timing: return "🕐"
        case .combination: return "��"
        }
    }
} 