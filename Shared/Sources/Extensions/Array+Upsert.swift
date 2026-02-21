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
