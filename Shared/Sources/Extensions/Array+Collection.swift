public extension Array where Element: Equatable & Hashable {
    func diff(with newElements: [Element]) -> (insertions: [Element], deletions: [Element]) {
        let oldSet = Set(self)
        let newSet = Set(newElements)

        let deletions = Array(oldSet.subtracting(newSet))
        let insertions = newElements.filter { !oldSet.contains($0) }

        return (insertions: insertions, deletions: deletions)
    }
}

public extension Array where Element: Equatable & Hashable & Identifiable {
    func diff(with newElements: [Element]) -> (insertions: [Element], deletionIds: [Element.ID]) {
        let oldSet = Set(self)
        let newSet = Set(newElements)

        let deletions = Array(oldSet.subtracting(newSet))
        let insertions = newElements.filter { !oldSet.contains($0) }

        return (insertions: insertions, deletionIds: deletions.map(\.id))
    }
}

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

public extension Array where Element: Identifiable & Equatable {
    mutating func upsert(_ element: Element) {
        if let index = firstIndex(where: { $0.id == element.id }) {
            self[index] = element
        } else {
            append(element)
        }
    }

    func prioritizing<Value: Equatable>(
        by keyPath: KeyPath<Element, Value>,
        match value: Value
    ) -> [Element] {
        guard let matchedIndex = firstIndex(where: { $0[keyPath: keyPath] == value }) else {
            return self
        }
        var reordered = self
        let matched = reordered.remove(at: matchedIndex)
        reordered.insert(matched, at: 0)
        return reordered
    }
}
