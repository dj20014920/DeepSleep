import Foundation

struct Preset: Codable {
    let name: String
    let volumes: [Float]
}

class PresetManager {
    static let shared = PresetManager()
    private let key = "presets"

    private init() {}

    func savePreset(name: String, volumes: [Float]) {
        var current = loadPresets()
        current.removeAll { $0.name == name } // 중복 제거 후 덮어쓰기
        current.append(Preset(name: name, volumes: volumes))
        if let encoded = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    func loadPresets() -> [Preset] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let presets = try? JSONDecoder().decode([Preset].self, from: data) else {
            return []
        }
        return presets
    }
    func deletePreset(named name: String) {
        var current = loadPresets()
        current.removeAll { $0.name == name }
        if let encoded = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    func renamePreset(oldName: String, newName: String) {
        var current = loadPresets()
        if let index = current.firstIndex(where: { $0.name == oldName }) {
            let volumes = current[index].volumes
            current[index] = Preset(name: newName, volumes: volumes)
            if let encoded = try? JSONEncoder().encode(current) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }
    func getPreset(named name: String) -> Preset? {
        return loadPresets().first { $0.name == name }
    }
}
