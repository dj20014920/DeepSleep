import Foundation

// SharedModels.swift에서 타입들을 import해서 사용

// MARK: - UserDefaults 안전한 저장/로드 확장
extension UserDefaults {
    
    /// 안전한 객체 저장 (JSON 인코딩 사용)
    func safeSetObject<T: Codable>(_ object: T, forKey key: String) -> Bool {
        do {
            let encoded = try JSONEncoder().encode(object)
            self.set(encoded, forKey: key)
            return true
        } catch {
            #if DEBUG
            print("❌ UserDefaults 저장 실패 [\(key)]: \(error.localizedDescription)")
            #endif
            return false
        }
    }
    
    /// 안전한 객체 로드 (JSON 디코딩 사용)
    func safeObject<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = self.data(forKey: key) else {
            #if DEBUG
            print("ℹ️ UserDefaults 데이터 없음 [\(key)]")
            #endif
            return nil
        }
        
        do {
            let decoded = try JSONDecoder().decode(type, from: data)
            return decoded
        } catch {
            #if DEBUG
            print("❌ UserDefaults 로드 실패 [\(key)]: \(error.localizedDescription)")
            #endif
            // 손상된 데이터 제거
            self.removeObject(forKey: key)
            return nil
        }
    }
    
    /// 배열 형태의 객체 안전 저장
    func safeSetArray<T: Codable>(_ array: [T], forKey key: String) -> Bool {
        return safeSetObject(array, forKey: key)
    }
    
    /// 배열 형태의 객체 안전 로드
    func safeArray<T: Codable>(_ type: T.Type, forKey key: String) -> [T]? {
        return safeObject([T].self, forKey: key)
    }
    
    /// 딕셔너리 형태의 객체 안전 저장
    func safeSetDictionary<K: Codable & Hashable, V: Codable>(_ dictionary: [K: V], forKey key: String) -> Bool {
        return safeSetObject(dictionary, forKey: key)
    }
    
    /// 딕셔너리 형태의 객체 안전 로드
    func safeDictionary<K: Codable & Hashable, V: Codable>(_ keyType: K.Type, _ valueType: V.Type, forKey key: String) -> [K: V]? {
        return safeObject([K: V].self, forKey: key)
    }
}

// MARK: - 캐시 전용 UserDefaults 확장
extension UserDefaults {
    
    /// 캐시 데이터 저장 (TTL 포함)
    func setCacheData<T: Codable>(_ object: T, forKey key: String, ttl: TimeInterval = 300) -> Bool {
        let cacheWrapper = CacheWrapper(data: object, expiration: Date().addingTimeInterval(ttl))
        return safeSetObject(cacheWrapper, forKey: key)
    }
    
    /// 캐시 데이터 로드 (TTL 확인)
    func getCacheData<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let wrapper: CacheWrapper<T> = safeObject(CacheWrapper<T>.self, forKey: key) else {
            return nil
        }
        
        // TTL 확인
        if wrapper.expiration < Date() {
            #if DEBUG
            print("⏰ 캐시 만료됨 [\(key)]")
            #endif
            removeObject(forKey: key)
            return nil
        }
        
        return wrapper.data
    }
    
    /// 캐시 만료 시간 확인
    func getCacheExpiration(forKey key: String) -> Date? {
        guard let data = self.data(forKey: key) else { return nil }
        
        do {
            let wrapper = try JSONDecoder().decode(CacheWrapperBase.self, from: data)
            return wrapper.expiration
        } catch {
            return nil
        }
    }
    
    // cleanExpiredCaches()는 SharedCore.swift에 정의되어 있음
}

// MARK: - 대화 관련 UserDefaults 확장
extension UserDefaults {
    
    /// 일일 메시지 저장
    func saveDailyMessages(_ messages: [ChatMessage], for date: Date) -> Bool {
        let dateKey = formatDateKey(date)
        let dictionaries = messages.map { $0.toDictionary() }
        set(dictionaries, forKey: "daily_\(dateKey)")
        return true
    }
    
    /// 일일 메시지 로드
    func loadDailyMessages(for date: Date) -> [ChatMessage] {
        let dateKey = formatDateKey(date)
        guard let dictionaries = array(forKey: "daily_\(dateKey)") as? [[String: Any]] else {
            return []
        }
        return dictionaries.compactMap { ChatMessage.from(dictionary: $0) }
    }
    
    /// 주간 메시지 로드
    func loadWeeklyMessages() -> [ChatMessage] {
        var weeklyMessages: [ChatMessage] = []
        let calendar = Calendar.current
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            weeklyMessages.append(contentsOf: loadDailyMessages(for: date))
        }
        
        return weeklyMessages
    }
    
    /// 대화 히스토리 압축 저장
    func saveCompressedHistory(_ summary: String, for date: Date) -> Bool {
        let dateKey = formatDateKey(date)
        return safeSetObject(summary, forKey: "compressed_\(dateKey)")
    }
    
    /// 압축된 히스토리 로드
    func loadCompressedHistory(for date: Date) -> String? {
        let dateKey = formatDateKey(date)
        return safeObject(String.self, forKey: "compressed_\(dateKey)")
    }
    
    /// 날짜를 키 형식으로 변환
    private func formatDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - 데이터 크기 관리 확장
extension UserDefaults {
    
    /// UserDefaults 총 사용 용량 계산 (근사치)
    func getTotalSize() -> Int {
        let dictionary = UserDefaults.standard.dictionaryRepresentation()
        var totalSize = 0
        
        for (_, value) in dictionary {
            if let data = value as? Data {
                totalSize += data.count
            } else if let string = value as? String {
                totalSize += string.data(using: .utf8)?.count ?? 0
            } else {
                // 다른 타입들의 대략적인 크기
                totalSize += 8 // 추정치
            }
        }
        
        return totalSize
    }
    
    /// 큰 데이터 항목들 찾기 (1KB 이상)
    func findLargeDataItems() -> [(key: String, size: Int)] {
        let dictionary = UserDefaults.standard.dictionaryRepresentation()
        var largeItems: [(String, Int)] = []
        
        for (key, value) in dictionary {
            var size = 0
            
            if let data = value as? Data {
                size = data.count
            } else if let string = value as? String {
                size = string.data(using: .utf8)?.count ?? 0
            }
            
            if size > 1024 { // 1KB 이상
                largeItems.append((key, size))
            }
        }
        
        // ✅ 정렬 오류 수정: 명시적 타입 지정
        return largeItems.sorted { (item1: (String, Int), item2: (String, Int)) -> Bool in
            return item1.1 > item2.1
        }
    }
    
    /// TLB식 오래된 데이터 정리 (14일 기준)
    func cleanOldData(olderThanDays days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let cutoffDateString = formatDateKey(cutoffDate)
        
        let allKeys = Array(UserDefaults.standard.dictionaryRepresentation().keys)
        let dateKeys = allKeys.filter { key in
            // "daily_", "compressed_", "ConversationCache_" 등 캐시 관련 키들  
            return (key.hasPrefix("daily_") || 
                   key.hasPrefix("compressed_") || 
                   key.hasPrefix("ConversationCache_")) &&
                   key.contains("-") // 날짜 형식 포함
        }
        
        var cleanedCount = 0
        for key in dateKeys {
            var shouldClean = false
            
                         if key.hasPrefix("ConversationCache_") {
                 // 대화 캐시는 생성 시간 기준 정리 (타임스탬프 기반)
                 if let cacheTimestamp = self.object(forKey: "\(key)_timestamp") as? Date {
                     let timeSince = Date().timeIntervalSince(cacheTimestamp)
                     shouldClean = timeSince > TimeInterval(days * 24 * 60 * 60)
                 } else {
                     // 타임스탬프가 없는 오래된 캐시는 삭제
                     shouldClean = true
                 }
             } else {
                // 일반 날짜 키는 문자열 비교
                if let underscoreIndex = key.firstIndex(of: "_") {
                    let dateString = String(key[key.index(after: underscoreIndex)...])
                    shouldClean = dateString < cutoffDateString
                }
            }
            
            if shouldClean {
                removeObject(forKey: key)
                cleanedCount += 1
            }
        }
        
        #if DEBUG
        if cleanedCount > 0 {
            print("🧹 TLB식: \(days)일 이전 데이터 \(cleanedCount)개 정리 완료")
        }
        #endif
    }
}

// MARK: - 지원 구조체들
private struct CacheWrapperBase: Codable {
    let expiration: Date
}

private struct CacheWrapper<T: Codable>: Codable {
    let data: T
    let expiration: Date
}

// MARK: - 디버그 유틸리티
#if DEBUG
extension UserDefaults {
    
    /// 모든 키와 타입 출력 (디버그용)
    func debugPrintAllKeys() {
        let dictionary = UserDefaults.standard.dictionaryRepresentation()
        
        print("📊 UserDefaults 전체 키 목록:")
        print("┌─────────────────────────────────────────────────")
        
        let sortedKeys = dictionary.keys.sorted()
        for key in sortedKeys {
            let value = dictionary[key]
            let type = String(describing: type(of: value))
            
            var sizeInfo = ""
            if let data = value as? Data {
                sizeInfo = " (\(data.count) bytes)"
            } else if let string = value as? String {
                sizeInfo = " (\(string.count) chars)"
            }
            
            print("│ \(key): \(type)\(sizeInfo)")
        }
        
        print("└─────────────────────────────────────────────────")
        print("총 \(dictionary.count)개 키, 약 \(getTotalSize()) bytes")
    }
    
    /// 캐시 관련 키들만 출력
    func debugPrintCacheKeys() {
        let dictionary = UserDefaults.standard.dictionaryRepresentation()
        let cacheKeys = dictionary.keys.filter {
            $0.contains("cache") || $0.contains("Cache") || $0.hasPrefix("daily_") || $0.hasPrefix("compressed_")
        }.sorted()
        
        print("🗄️ 캐시 관련 키 목록:")
        print("┌─────────────────────────────────────────────────")
        
        for key in cacheKeys {
            let value = dictionary[key]
            var info = ""
            
            if let expiration = getCacheExpiration(forKey: key) {
                let timeLeft = expiration.timeIntervalSinceNow
                info = timeLeft > 0 ? " (남은시간: \(Int(timeLeft))초)" : " (만료됨)"
            }
            
            if let data = value as? Data {
                info += " (\(data.count) bytes)"
            }
            
            print("│ \(key)\(info)")
        }
        
        print("└─────────────────────────────────────────────────")
        print("총 \(cacheKeys.count)개 캐시 키")
    }
    
    /// UserDefaults 초기화 (개발용)
    func debugClearAll() {
        let dictionary = UserDefaults.standard.dictionaryRepresentation()
        for key in dictionary.keys {
            removeObject(forKey: key)
        }
        print("🗑️ UserDefaults 전체 초기화 완료")
    }
    
    /// 특정 패턴의 키들만 삭제
    func debugClearKeys(matching pattern: String) {
        let dictionary = UserDefaults.standard.dictionaryRepresentation()
        let matchingKeys = dictionary.keys.filter { $0.contains(pattern) }
        
        for key in matchingKeys {
            removeObject(forKey: key)
        }
        
        print("🗑️ '\(pattern)' 패턴 키 \(matchingKeys.count)개 삭제 완료")
    }
}
#endif
