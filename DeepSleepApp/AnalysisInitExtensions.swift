import Foundation

// MARK: - 분석 결과 구조체 확장 (파라미터 이니셜라이저 추가)

extension TemporalContextAnalysis {
    init(currentTimeContext: String,
         recentUsagePattern: String,
         seasonalInfluence: String) {
        self.currentTimeContext = currentTimeContext
        self.recentUsagePattern = recentUsagePattern
        self.seasonalInfluence = seasonalInfluence
    }
}

extension EnvironmentalContextAnalysis {
    init(ambientNoiseLevel: Float,
         deviceContext: String,
         locationContext: String) {
        self.ambientNoiseLevel = ambientNoiseLevel
        self.deviceContext = deviceContext
        self.locationContext = locationContext
    }
}

extension PersonalizationProfileAnalysis {
    init(personalizationLevel: Float,
         adaptationHistory: [String],
         preferenceStability: Float) {
        self.personalizationLevel = personalizationLevel
        self.adaptationHistory = adaptationHistory
        self.preferenceStability = preferenceStability
    }
}

extension PerformanceMetricsAnalysis {
    init(recentSatisfactionTrend: Float,
         usageFrequency: Float,
         engagementLevel: Float) {
        self.recentSatisfactionTrend = recentSatisfactionTrend
        self.usageFrequency = usageFrequency
        self.engagementLevel = engagementLevel
    }
}

extension EmotionalDimensionAnalysis {
    init(dominantEmotion: String,
         emotionStability: Float,
         intensityLevel: Float) {
        self.dominantEmotion = dominantEmotion
        self.emotionStability = emotionStability
        self.intensityLevel = intensityLevel
    }
}

extension TemporalDimensionAnalysis {
    init(timeOfDay: String,
         dayOfWeek: String,
         seasonalContext: String) {
        self.timeOfDay = timeOfDay
        self.dayOfWeek = dayOfWeek
        self.seasonalContext = seasonalContext
    }
}

extension BehavioralDimensionAnalysis {
    init(usagePattern: String,
         interactionStyle: String,
         adaptationSpeed: Float) {
        self.usagePattern = usagePattern
        self.interactionStyle = interactionStyle
        self.adaptationSpeed = adaptationSpeed
    }
}

extension ContextualDimensionAnalysis {
    init(environmentalFactors: [String],
         socialContext: String,
         deviceUsage: String) {
        self.environmentalFactors = environmentalFactors
        self.socialContext = socialContext
        self.deviceUsage = deviceUsage
    }
}

extension PersonalizationDimensionAnalysis {
    init(customizationLevel: Float,
         preferenceClarity: Float,
         learningProgress: Float) {
        self.customizationLevel = customizationLevel
        self.preferenceClarity = preferenceClarity
        self.learningProgress = learningProgress
    }
} 