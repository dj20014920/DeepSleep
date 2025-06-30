import Foundation

/// 🆕 사운드 카탈로그 확장성 및 버전 관리 매니저
/// 새로운 음원 추가, 버전 업데이트, 하위 호환성 보장을 담당
class SoundCatalogManager {
    static let shared = SoundCatalogManager()
    
    private let catalogFileName = "sound_catalog.json"
    private let backupFileName = "sound_catalog_backup.json"
    
    private init() {}
    
    // MARK: - 🆕 카탈로그 확장 메서드
    
    /// 새로운 사운드 카테고리 추가
    /// - Parameters:
    ///   - id: 고유 식별자
    ///   - baseName: 기본 이름
    ///   - emoji: 이모지
    ///   - fileName: 파일명
    ///   - description: 설명
    /// - Returns: 성공 여부
    func addNewSoundCategory(
        id: String,
        baseName: String,
        emoji: String,
        fileName: String,
        description: String
    ) -> Bool {
        guard let currentCatalog = loadCurrentCatalog() else {
            print("⚠️ 현재 카탈로그를 로드할 수 없습니다.")
            return false
        }
        
        // 중복 ID 체크
        if currentCatalog.contains(where: { $0.id == id }) {
            print("⚠️ 이미 존재하는 ID입니다: \(id)")
            return false
        }
        
        // 파일 존재 여부 확인
        guard Bundle.main.url(forResource: fileName, withExtension: nil) != nil else {
            print("⚠️ 음원 파일을 찾을 수 없습니다: \(fileName)")
            return false
        }
        
        // 새 카테고리 생성
        let newVersion = SoundVersion(
            version: "1.0",
            fileName: fileName,
            displayName: "\(emoji) \(baseName)",
            emoji: emoji,
            description: description,
            isDefault: true
        )
        
        let newCategory = SoundCatalog(
            id: id,
            baseName: baseName,
            categoryIndex: currentCatalog.count, // 마지막에 추가
            versions: [newVersion]
        )
        
        // 카탈로그 업데이트
        var updatedCatalog = currentCatalog
        updatedCatalog.append(newCategory)
        
        return saveCatalog(updatedCatalog)
    }
    
    /// 기존 카테고리에 새 버전 추가
    /// - Parameters:
    ///   - categoryId: 카테고리 ID
    ///   - version: 버전 문자열
    ///   - fileName: 파일명
    ///   - displayName: 표시명
    ///   - description: 설명
    ///   - setAsDefault: 기본 버전으로 설정할지 여부
    /// - Returns: 성공 여부
    func addVersionToCategory(
        categoryId: String,
        version: String,
        fileName: String,
        displayName: String,
        description: String,
        setAsDefault: Bool = false
    ) -> Bool {
        guard var currentCatalog = loadCurrentCatalog() else {
            print("⚠️ 현재 카탈로그를 로드할 수 없습니다.")
            return false
        }
        
        // 카테고리 찾기
        guard let categoryIndex = currentCatalog.firstIndex(where: { $0.id == categoryId }) else {
            print("⚠️ 카테고리를 찾을 수 없습니다: \(categoryId)")
            return false
        }
        
        // 파일 존재 여부 확인
        guard Bundle.main.url(forResource: fileName, withExtension: nil) != nil else {
            print("⚠️ 음원 파일을 찾을 수 없습니다: \(fileName)")
            return false
        }
        
        var category = currentCatalog[categoryIndex]
        
        // 중복 버전 체크
        if category.versions.contains(where: { $0.version == version }) {
            print("⚠️ 이미 존재하는 버전입니다: \(version)")
            return false
        }
        
        // 기본 버전 설정 처리
        var updatedVersions = category.versions
        if setAsDefault {
            // 기존 기본 버전들을 false로 변경
            updatedVersions = updatedVersions.map { version in
                SoundVersion(
                    version: version.version,
                    fileName: version.fileName,
                    displayName: version.displayName,
                    emoji: version.emoji,
                    description: version.description,
                    isDefault: false
                )
            }
        }
        
        // 새 버전 추가
        let newVersion = SoundVersion(
            version: version,
            fileName: fileName,
            displayName: displayName,
            emoji: category.versions.first?.emoji ?? "🎵",
            description: description,
            isDefault: setAsDefault
        )
        
        updatedVersions.append(newVersion)
        
        // 카테고리 업데이트
        let updatedCategory = SoundCatalog(
            id: category.id,
            baseName: category.baseName,
            categoryIndex: category.categoryIndex,
            versions: updatedVersions
        )
        
        currentCatalog[categoryIndex] = updatedCategory
        
        return saveCatalog(currentCatalog)
    }
    
    // MARK: - 🆕 버전 관리
    
    /// 특정 버전을 기본값으로 설정
    /// - Parameters:
    ///   - categoryId: 카테고리 ID
    ///   - version: 기본으로 설정할 버전
    /// - Returns: 성공 여부
    func setDefaultVersion(categoryId: String, version: String) -> Bool {
        guard var currentCatalog = loadCurrentCatalog() else { return false }
        
        guard let categoryIndex = currentCatalog.firstIndex(where: { $0.id == categoryId }) else {
            print("⚠️ 카테고리를 찾을 수 없습니다: \(categoryId)")
            return false
        }
        
        var category = currentCatalog[categoryIndex]
        
        // 모든 버전을 false로 설정 후 지정된 버전만 true로
        let updatedVersions = category.versions.map { v in
            SoundVersion(
                version: v.version,
                fileName: v.fileName,
                displayName: v.displayName,
                emoji: v.emoji,
                description: v.description,
                isDefault: v.version == version
            )
        }
        
        let updatedCategory = SoundCatalog(
            id: category.id,
            baseName: category.baseName,
            categoryIndex: category.categoryIndex,
            versions: updatedVersions
        )
        
        currentCatalog[categoryIndex] = updatedCategory
        
        return saveCatalog(currentCatalog)
    }
    
    /// 사용하지 않는 버전 제거
    /// - Parameters:
    ///   - categoryId: 카테고리 ID
    ///   - version: 제거할 버전
    /// - Returns: 성공 여부
    func removeVersion(categoryId: String, version: String) -> Bool {
        guard var currentCatalog = loadCurrentCatalog() else { return false }
        
        guard let categoryIndex = currentCatalog.firstIndex(where: { $0.id == categoryId }) else {
            print("⚠️ 카테고리를 찾을 수 없습니다: \(categoryId)")
            return false
        }
        
        var category = currentCatalog[categoryIndex]
        
        // 최소 1개 버전은 유지해야 함
        if category.versions.count <= 1 {
            print("⚠️ 최소 1개 버전은 유지해야 합니다.")
            return false
        }
        
        // 기본 버전 제거 시 다른 버전을 기본으로 설정
        let versionToRemove = category.versions.first { $0.version == version }
        let isRemovingDefault = versionToRemove?.isDefault == true
        
        // 버전 제거
        var updatedVersions = category.versions.filter { $0.version != version }
        
        // 기본 버전이 제거된 경우 첫 번째 버전을 기본으로 설정
        if isRemovingDefault && !updatedVersions.isEmpty {
            updatedVersions[0] = SoundVersion(
                version: updatedVersions[0].version,
                fileName: updatedVersions[0].fileName,
                displayName: updatedVersions[0].displayName,
                emoji: updatedVersions[0].emoji,
                description: updatedVersions[0].description,
                isDefault: true
            )
        }
        
        let updatedCategory = SoundCatalog(
            id: category.id,
            baseName: category.baseName,
            categoryIndex: category.categoryIndex,
            versions: updatedVersions
        )
        
        currentCatalog[categoryIndex] = updatedCategory
        
        return saveCatalog(currentCatalog)
    }
    
    // MARK: - 🆕 하위 호환성 관리
    
    /// 카탈로그 버전 호환성 체크
    /// - Parameter catalog: 체크할 카탈로그
    /// - Returns: 호환성 결과
    func checkCompatibility(catalog: [SoundCatalog]) -> CompatibilityResult {
        var issues: [String] = []
        var warnings: [String] = []
        
        // 1. 필수 파일 존재 여부 확인
        for category in catalog {
            for version in category.versions {
                if Bundle.main.url(forResource: version.fileName, withExtension: nil) == nil {
                    issues.append("누락된 파일: \(version.fileName)")
                }
            }
        }
        
        // 2. 기본 버전 설정 확인
        for category in catalog {
            let defaultVersions = category.versions.filter { $0.isDefault }
            if defaultVersions.isEmpty {
                warnings.append("기본 버전이 설정되지 않음: \(category.baseName)")
            } else if defaultVersions.count > 1 {
                issues.append("여러 기본 버전 설정됨: \(category.baseName)")
            }
        }
        
        // 3. 카테고리 인덱스 중복 확인
        let indices = catalog.map { $0.categoryIndex }
        let uniqueIndices = Set(indices)
        if indices.count != uniqueIndices.count {
            issues.append("카테고리 인덱스 중복 발견")
        }
        
        return CompatibilityResult(
            isCompatible: issues.isEmpty,
            issues: issues,
            warnings: warnings
        )
    }
    
    /// 자동 마이그레이션 수행
    /// - Parameter catalog: 마이그레이션할 카탈로그
    /// - Returns: 마이그레이션된 카탈로그
    func performAutoMigration(catalog: [SoundCatalog]) -> [SoundCatalog] {
        var migratedCatalog = catalog
        
        // 1. 기본 버전 자동 설정
        for (index, category) in migratedCatalog.enumerated() {
            let defaultVersions = category.versions.filter { $0.isDefault }
            
            if defaultVersions.isEmpty && !category.versions.isEmpty {
                // 첫 번째 버전을 기본으로 설정
                var updatedVersions = category.versions
                updatedVersions[0] = SoundVersion(
                    version: updatedVersions[0].version,
                    fileName: updatedVersions[0].fileName,
                    displayName: updatedVersions[0].displayName,
                    emoji: updatedVersions[0].emoji,
                    description: updatedVersions[0].description,
                    isDefault: true
                )
                
                migratedCatalog[index] = SoundCatalog(
                    id: category.id,
                    baseName: category.baseName,
                    categoryIndex: category.categoryIndex,
                    versions: updatedVersions
                )
            }
        }
        
        // 2. 카테고리 인덱스 재정렬
        migratedCatalog = migratedCatalog.enumerated().map { index, category in
            SoundCatalog(
                id: category.id,
                baseName: category.baseName,
                categoryIndex: index,
                versions: category.versions
            )
        }
        
        return migratedCatalog
    }
    
    // MARK: - 🆕 파일 I/O
    
    /// 현재 카탈로그 로드
    private func loadCurrentCatalog() -> [SoundCatalog]? {
        guard let url = Bundle.main.url(forResource: "sound_catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ sound_catalog.json 파일을 찾을 수 없습니다.")
            return nil
        }
        
        do {
            let catalog = try JSONDecoder().decode([SoundCatalog].self, from: data)
            return catalog.sorted { $0.categoryIndex < $1.categoryIndex }
        } catch {
            print("⚠️ 카탈로그 파싱 실패: \(error)")
            return nil
        }
    }
    
    /// 카탈로그 저장
    private func saveCatalog(_ catalog: [SoundCatalog]) -> Bool {
        do {
            // 백업 생성
            createBackup()
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(catalog.sorted { $0.categoryIndex < $1.categoryIndex })
            
            // Documents 디렉토리에 저장 (Bundle은 읽기 전용)
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("⚠️ Documents 디렉토리를 찾을 수 없습니다.")
                return false
            }
            
            let fileURL = documentsURL.appendingPathComponent(catalogFileName)
            try data.write(to: fileURL)
            
            print("✅ 카탈로그 저장 완료: \(fileURL.path)")
            
            // SoundManager 재로드 트리거
            NotificationCenter.default.post(name: .soundCatalogUpdated, object: nil)
            
            return true
        } catch {
            print("⚠️ 카탈로그 저장 실패: \(error)")
            return false
        }
    }
    
    /// 백업 생성
    private func createBackup() {
        guard let currentCatalog = loadCurrentCatalog() else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(currentCatalog)
            
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            
            let backupURL = documentsURL.appendingPathComponent(backupFileName)
            try data.write(to: backupURL)
            
            print("✅ 백업 생성 완료: \(backupURL.path)")
        } catch {
            print("⚠️ 백업 생성 실패: \(error)")
        }
    }
    
    // MARK: - 🆕 유틸리티
    
    /// 카탈로그 정보 출력
    func printCatalogInfo() {
        guard let catalog = loadCurrentCatalog() else {
            print("❌ 카탈로그를 로드할 수 없습니다.")
            return
        }
        
        print("📊 사운드 카탈로그 정보")
        print("총 카테고리 수: \(catalog.count)")
        
        for category in catalog {
            print("  \(category.categoryIndex): \(category.baseName) (\(category.id))")
            for version in category.versions {
                let defaultMark = version.isDefault ? " [기본]" : ""
                print("    - \(version.version): \(version.fileName)\(defaultMark)")
            }
        }
    }
    
    // MARK: - Helper methods
    
    /// 특정 사운드 ID 및 버전에 해당하는 SoundVersion을 반환
    func findVersion(soundId: String, version: String) -> SoundVersion? {
        guard let catalog = loadCurrentCatalog() else { return nil }
        // 카테고리 찾기
        guard let category = catalog.first(where: { $0.id == soundId }) else { return nil }
        // 버전 찾기
        return category.versions.first(where: { $0.version == version })
    }
}

// MARK: - 🆕 지원 구조체

struct CompatibilityResult {
    let isCompatible: Bool
    let issues: [String]
    let warnings: [String]
}

// MARK: - 🆕 알림

extension Notification.Name {
    static let soundCatalogUpdated = Notification.Name("soundCatalogUpdated")
} 