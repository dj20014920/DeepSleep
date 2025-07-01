//
//  FeedbackVisualizationCharts.swift
//  DeepSleep
//
//  Created by AI Assistant on 2024/12/19.
//

import SwiftUI
import Charts

@available(iOS 16.0, *)
struct SatisfactionTrendChart: View {
    let data: [SatisfactionDataPoint]
    
    var body: some View {
        Chart(data, id: \.date) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Satisfaction", point.satisfaction)
            )
            .foregroundStyle(.blue)
            .symbol(.circle)
        }
        .chartYAxis {
            AxisMarks(values: [0.0, 0.5, 1.0]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let floatValue = value.as(Double.self) {
                        Text("\(Int(floatValue * 100))%")
                            .font(.caption)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    Text(value.as(String.self) ?? "")
                        .font(.caption)
                        .rotationEffect(.degrees(-45))
                }
            }
        }
        .frame(height: 200)
        .padding()
    }
}

@available(iOS 16.0, *)
struct SoundPreferenceBarChart: View {
    let data: [SoundPreferenceData]
    
    var body: some View {
        Chart(data.prefix(8), id: \.soundName) { item in
            BarMark(
                x: .value("Preference", item.preference),
                y: .value("Sound", item.soundName)
            )
            .foregroundStyle(colorForPreference(item.preference))
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let soundName = value.as(String.self) {
                        Text(soundName)
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: [0.0, 0.5, 1.0]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let floatValue = value.as(Double.self) {
                        Text("\(Int(floatValue * 100))%")
                            .font(.caption)
                    }
                }
            }
        }
        .frame(height: 300)
        .padding()
    }
    
    private func colorForPreference(_ preference: Float) -> Color {
        switch preference {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .gray
        }
    }
}

@available(iOS 16.0, *)
struct TimePatternHeatmapChart: View {
    let data: [TimePatternData]
    
    var body: some View {
        Chart(data, id: \.hour) { item in
            RectangleMark(
                x: .value("Hour", item.hour),
                y: .value("Day", 1),
                width: .fixed(20),
                height: .fixed(30)
            )
            .foregroundStyle(colorForUsage(item.usage))
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let hour = value.as(Int.self) {
                        Text("\(hour)시")
                            .font(.caption)
                    }
                }
            }
        }
        .frame(height: 100)
        .padding()
        
        VStack(alignment: .leading, spacing: 8) {
            Text("사용량 범례")
                .font(.caption)
                .fontWeight(.semibold)
            
            HStack(spacing: 4) {
                ForEach(0..<5) { level in
                    Rectangle()
                        .frame(width: 15, height: 15)
                        .foregroundColor(colorForUsage(Float(level) / 4.0))
                    
                    if level == 0 {
                        Text("낮음")
                            .font(.caption2)
                    } else if level == 4 {
                        Text("높음")
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func colorForUsage(_ usage: Float) -> Color {
        switch usage {
        case 0.8...1.0: return .red
        case 0.6..<0.8: return .orange
        case 0.4..<0.6: return .yellow
        case 0.2..<0.4: return .green
        default: return .blue
        }
    }
}

@available(iOS 16.0, *)
struct AILearningProgressView: View {
    let metrics: AILearningMetrics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let metrics = metrics {
                // 학습 정확도
                HStack {
                    VStack(alignment: .leading) {
                        Text("학습 정확도")
                            .font(.headline)
                        Text("\(String(format: "%.1f", metrics.learningAccuracy * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(colorForAccuracy(metrics.learningAccuracy))
                    }
                    Spacer()
                    
                    // 원형 진행률 표시
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(metrics.learningAccuracy))
                            .stroke(colorForAccuracy(metrics.learningAccuracy), lineWidth: 8)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: metrics.learningAccuracy)
                    }
                    .frame(width: 60, height: 60)
                }
                
                // 추천 성공률
                HStack {
                    Text("추천 성공률")
                        .font(.subheadline)
                    Spacer()
                    Text("\(String(format: "%.1f", metrics.recommendationSuccess * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                // 총 세션 수
                HStack {
                    Text("총 학습 세션")
                        .font(.subheadline)
                    Spacer()
                    Text("\(metrics.totalSessions)회")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                // 최근 업데이트
                HStack {
                    Text("마지막 학습")
                        .font(.subheadline)
                    Spacer()
                    Text(timeAgoString(from: metrics.lastLearningUpdate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("학습 데이터를 불러오는 중...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private func colorForAccuracy(_ accuracy: Float) -> Color {
        switch accuracy {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "방금 전"
        } else if interval < 3600 {
            return "\(Int(interval / 60))분 전"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))시간 전"
        } else {
            return "\(Int(interval / 86400))일 전"
        }
    }
}

@available(iOS 16.0, *)
struct AIInsightsView: View {
    let insights: [AIInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(insights.indices, id: \.self) { index in
                let insight = insights[index]
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(insight.title)
                            .font(.headline)
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                            Text("\(String(format: "%.0f", insight.confidence * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(insight.description)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("영향도: \(insight.impact)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(backgroundColorForImpact(insight.impact))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        
                        Spacer()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                if index < insights.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
    }
    
    private func backgroundColorForImpact(_ impact: String) -> Color {
        switch impact {
        case "높음": return .red
        case "중간": return .orange
        case "보통": return .blue
        default: return .gray
        }
    }
}

@available(iOS 16.0, *)
struct RecommendationReasonsView: View {
    let reasons: [RecommendationReason]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(reasons.indices, id: \.self) { index in
                let reason = reasons[index]
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(reason.presetName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // 만족도 별점 표시
                        HStack(spacing: 2) {
                            ForEach(0..<5) { star in
                                Image(systemName: star < Int(reason.satisfaction * 5) ? "star.fill" : "star")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Text(reason.reason)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                    
                    HStack {
                        Text(timeAgoString(from: reason.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("만족도: \(String(format: "%.1f", reason.satisfaction * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                
                if index < reasons.count - 1 {
                    Divider()
                }
            }
        }
        .padding()
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "방금 전"
        } else if interval < 3600 {
            return "\(Int(interval / 60))분 전"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))시간 전"
        } else {
            return "\(Int(interval / 86400))일 전"
        }
    }
} 
