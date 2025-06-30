import Foundation
import CoreData

// MARK: - Value Transformers for Array Types
@objc(FloatArrayTransformer)
final class FloatArrayTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass { NSData.self }
    override class func allowsReverseTransformation() -> Bool { true }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let array = value as? [Float] else { return nil }
        return try? JSONEncoder().encode(array)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode([Float].self, from: data)
    }
}

@objc(IntArrayTransformer)
final class IntArrayTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass { NSData.self }
    override class func allowsReverseTransformation() -> Bool { true }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let array = value as? [Int] else { return nil }
        return try? JSONEncoder().encode(array)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode([Int].self, from: data)
    }
} 