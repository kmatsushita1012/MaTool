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
