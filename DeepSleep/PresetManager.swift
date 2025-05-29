import Foundation

// 기존 Preset 구조체 (호환성 유지)
struct Preset: Codable {
    let name: String
    let volumes: [Float]
}

class PresetManager {
    static let shared = PresetManager()
    private let legacyPresetKey = "presets" // 기존 키 유지

    private init() {}

    // MARK: - SoundPreset 관련 메서드 (SettingsManager 위임)
    func saveSoundPreset(_ preset: SoundPreset) {
        SettingsManager.shared.saveSoundPreset(preset)
    }

    func loadSoundPresets() -> [SoundPreset] {
        return SettingsManager.shared.loadSoundPresets()
    }
    
    func deleteSoundPreset(named name: String) {
        let presets = loadSoundPresets()
        if let preset = presets.first(where: { $0.name == name }) {
            SettingsManager.shared.deleteSoundPreset(id: preset.id)
        }
    }

    func renameSoundPreset(oldName: String, newName: String) {
        let presets = loadSoundPresets()
        if let oldPreset = presets.first(where: { $0.name == oldName }) {
            let newPreset = SoundPreset(
                name: newName,
                volumes: oldPreset.volumes,
                emotion: oldPreset.emotion,
                isAIGenerated: oldPreset.isAIGenerated,
                description: oldPreset.description
            )
            SettingsManager.shared.deleteSoundPreset(id: oldPreset.id)
            SettingsManager.shared.saveSoundPreset(newPreset)
        }
    }
    
    func getSoundPreset(named name: String) -> SoundPreset? {
        return loadSoundPresets().first { $0.name == name }
    }

    // MARK: - 기존 Preset 메서드들 (호환성 유지)
    func savePreset(name: String, volumes: [Float]) {
        let soundPreset = SoundPreset(
            name: name,
            volumes: volumes,
            emotion: nil,
            isAIGenerated: false,
            description: "사용자 저장 프리셋"
        )
        saveSoundPreset(soundPreset)
    }

    func loadPresets() -> [Preset] {
        return loadSoundPresets().map { soundPreset in
            Preset(name: soundPreset.name, volumes: soundPreset.volumes)
        }
    }
    
    private func loadLegacyPresets() -> [Preset] {
        guard let data = UserDefaults.standard.data(forKey: legacyPresetKey),
              let presets = try? JSONDecoder().decode([Preset].self, from: data) else {
            return []
        }
        return presets
    }
    
    // 기존 데이터를 새로운 형식으로 마이그레이션
    func migrateLegacyPresetsIfNeeded() {
        let legacyPresets = loadLegacyPresets()
        let existingPresets = loadSoundPresets()
        
        // 기존 데이터가 있고, 새로운 형식의 데이터가 비어있다면 마이그레이션 수행
        if !legacyPresets.isEmpty && existingPresets.isEmpty {
            print("기존 프리셋 데이터를 마이그레이션합니다...")
            
            for legacyPreset in legacyPresets {
                let soundPreset = SoundPreset(
                    name: legacyPreset.name,
                    volumes: legacyPreset.volumes,
                    emotion: nil,
                    isAIGenerated: false,
                    description: "기존 프리셋에서 마이그레이션됨"
                )
                saveSoundPreset(soundPreset)
            }
            
            print("마이그레이션 완료: \(legacyPresets.count)개의 프리셋")
        }
    }

    func deletePreset(named name: String) {
        deleteSoundPreset(named: name)
    }

    func renamePreset(oldName: String, newName: String) {
        renameSoundPreset(oldName: oldName, newName: newName)
    }
    
    func getPreset(named name: String) -> Preset? {
        guard let soundPreset = getSoundPreset(named: name) else { return nil }
        return Preset(name: soundPreset.name, volumes: soundPreset.volumes)
    }
}
