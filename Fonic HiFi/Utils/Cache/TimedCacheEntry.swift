import Foundation

struct TimedCacheEntry<Value>: Sendable where Value: Sendable {
    let value: Value
    private let expiresAt: Date

    init(value: Value, ttl: TimeInterval, now: Date = Date()) {
        self.value = value
        expiresAt = now.addingTimeInterval(ttl)
    }

    func isValid(now: Date = Date()) -> Bool {
        now < expiresAt
    }
}
