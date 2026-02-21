public extension Array where Element: Equatable {
    mutating func removeAll(of element: Element) {
        removeAll(where: { $0 == element })
    }
}

public extension Array {
    mutating func insert(_ value: Element, before index: Int) {
        let i = Swift.max(0, Swift.min(index, count))
        insert(value, at: i)
    }

    mutating func insert(_ value: Element, after index: Int) {
        let i = Swift.max(0, Swift.min(index + 1, count))
        insert(value, at: i)
    }
}
