import XCTest
@testable import DeepSleep

final class LRUCacheTests: XCTestCase {
    func testPutAndGet() {
        let cache = LRUCache<String, Int>(capacity: 2)
        cache.set("a", value: 1)
        cache.set("b", value: 2)
        XCTAssertEqual(cache.get("a"), 1, "a의 값은 1이어야 함")
        XCTAssertEqual(cache.get("b"), 2, "b의 값은 2이어야 함")
    }

    func testEvictionOrder() {
        let cache = LRUCache<String, Int>(capacity: 2)
        cache.set("a", value: 1) // [a]
        cache.set("b", value: 2) // [a, b]
        _ = cache.get("a")       // [b, a] (a가 최근)
        cache.set("c", value: 3) // [a, c] (b evict)
        XCTAssertNil(cache.get("b"), "b는 evict되어야 함")
        XCTAssertEqual(cache.get("a"), 1, "a는 남아있어야 함")
        XCTAssertEqual(cache.get("c"), 3, "c는 남아있어야 함")
    }

    func testCapacityLimit() {
        let cache = LRUCache<String, Int>(capacity: 3)
        cache.set("a", value: 1)
        cache.set("b", value: 2)
        cache.set("c", value: 3)
        cache.set("d", value: 4) // [b, c, d] (a evict)
        XCTAssertNil(cache.get("a"), "a는 evict되어야 함")
        XCTAssertEqual(cache.get("b"), 2, "b는 남아있어야 함")
        XCTAssertEqual(cache.get("c"), 3, "c는 남아있어야 함")
        XCTAssertEqual(cache.get("d"), 4, "d는 남아있어야 함")
    }

    func testPutSameKeyUpdatesValue() {
        let cache = LRUCache<String, Int>(capacity: 2)
        cache.set("a", value: 1)
        cache.set("a", value: 99)
        XCTAssertEqual(cache.get("a"), 99, "동일 키 put 시 값이 갱신되어야 함")
    }

    func testRemove() {
        let cache = LRUCache<String, Int>(capacity: 2)
        cache.set("x", value: 10)
        cache.remove("x")
        XCTAssertNil(cache.get("x"), "remove 후 nil이어야 함")
    }
} 