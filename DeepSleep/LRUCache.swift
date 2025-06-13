import Foundation

/// LRU(Least Recently Used) 메모리 캐시
final class LRUCache<Key: Hashable, Value> {
    private let capacity: Int
    private var dict: [Key: Value] = [:]
    private var order: [Key] = []
    
    init(capacity: Int) {
        self.capacity = capacity
    }
    
    func set(_ key: Key, value: Value) {
        if dict[key] != nil {
            order.removeAll { $0 == key }
        } else if dict.count >= capacity, let old = order.first {
            dict.removeValue(forKey: old)
            order.removeFirst()
        }
        dict[key] = value
        order.append(key)
    }
    func get(_ key: Key) -> Value? {
        guard let value = dict[key] else { return nil }
        order.removeAll { $0 == key }
        order.append(key)
        return value
    }
    func remove(_ key: Key) {
        dict.removeValue(forKey: key)
        order.removeAll { $0 == key }
    }
    func removeAll() {
        dict.removeAll()
        order.removeAll()
    }
} 