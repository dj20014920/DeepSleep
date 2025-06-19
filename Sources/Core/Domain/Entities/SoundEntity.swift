import Foundation

// MARK: - Sound Domain Entities

public struct SoundEntity: Codable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let fileName: String
    public let category: SoundCategory
    public let duration: TimeInterval
    public let description: String?
    public let tags: [String]
    public let fileSize: Int // bytes
    public let isLoopable: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        fileName: String,
        category: SoundCategory,
        duration: TimeInterval,
        description: String? = nil,
        tags: [String] = [],
        fileSize: Int = 0,
        isLoopable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.category = category
        self.duration = duration
        self.description = description
        self.tags = tags
        self.fileSize = fileSize
        self.isLoopable = isLoopable
    }
    
    public static func == (lhs: SoundEntity, rhs: SoundEntity) -> Bool {
        return lhs.id == rhs.id
    }
}

public enum SoundCategory: String, CaseIterable, Codable {
    case nature = "자연"
    case urban = "도시"
    case ambient = "앰비언트"
    case water = "물소리"
    case fire = "불소리"
    case wind = "바람"
    case animal = "동물"
    case mechanical = "기계"
    case custom = "커스텀"
    
    public var description: String {
        return self.rawValue
    }
    
    public var systemIcon: String {
        switch self {
        case .nature: return "leaf.fill"
        case .urban: return "building.2.fill"
        case .ambient: return "speaker.wave.3.fill"
        case .water: return "drop.fill"
        case .fire: return "flame.fill"
        case .wind: return "wind"
        case .animal: return "pawprint.fill"
        case .mechanical: return "gear"
        case .custom: return "square.and.pencil"
        }
    }
}

// MARK: - Sound Preset Entity
public struct SoundPresetEntity: Codable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let sounds: [SoundLayerEntity]
    public let totalDuration: TimeInterval?
    public let tags: [String]
    public let emotionalContext: String? // 감정적 맥락을 문자열로 저장
    public let createdAt: Date
    public let updatedAt: Date
    public let isDefault: Bool
    public let usageCount: Int
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        sounds: [SoundLayerEntity] = [],
        totalDuration: TimeInterval? = nil,
        tags: [String] = [],
        emotionalContext: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDefault: Bool = false,
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.sounds = sounds
        self.totalDuration = totalDuration
        self.tags = tags
        self.emotionalContext = emotionalContext
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDefault = isDefault
        self.usageCount = usageCount
    }
    
    public static func == (lhs: SoundPresetEntity, rhs: SoundPresetEntity) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Sound Layer Entity (for mixing multiple sounds)
public struct SoundLayerEntity: Codable, Identifiable, Equatable {
    public let id: UUID
    public let sound: SoundEntity
    public let volume: Float // 0.0 ~ 1.0
    public let pan: Float // -1.0 (left) ~ 1.0 (right)
    public let startTime: TimeInterval
    public let fadeInDuration: TimeInterval
    public let fadeOutDuration: TimeInterval
    public let isEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        sound: SoundEntity,
        volume: Float = 1.0,
        pan: Float = 0.0,
        startTime: TimeInterval = 0.0,
        fadeInDuration: TimeInterval = 0.0,
        fadeOutDuration: TimeInterval = 0.0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.sound = sound
        self.volume = max(0.0, min(1.0, volume))
        self.pan = max(-1.0, min(1.0, pan))
        self.startTime = max(0.0, startTime)
        self.fadeInDuration = max(0.0, fadeInDuration)
        self.fadeOutDuration = max(0.0, fadeOutDuration)
        self.isEnabled = isEnabled
    }
    
    public static func == (lhs: SoundLayerEntity, rhs: SoundLayerEntity) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Audio Session Entity
public struct AudioSessionEntity: Codable, Identifiable {
    public let id: UUID
    public let preset: SoundPresetEntity
    public let startTime: Date
    public let endTime: Date?
    public let totalDuration: TimeInterval
    public let userRating: Int? // 1-5 stars
    public let feedback: String?
    
    public init(
        id: UUID = UUID(),
        preset: SoundPresetEntity,
        startTime: Date = Date(),
        endTime: Date? = nil,
        totalDuration: TimeInterval = 0,
        userRating: Int? = nil,
        feedback: String? = nil
    ) {
        self.id = id
        self.preset = preset
        self.startTime = startTime
        self.endTime = endTime
        self.totalDuration = totalDuration
        self.userRating = userRating
        self.feedback = feedback
    }
} 