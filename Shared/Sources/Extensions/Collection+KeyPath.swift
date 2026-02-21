public extension Collection {
    func first<Value: Equatable>(where keyPath: KeyPath<Element, Value>, equals value: Value) -> Element? {
        first { $0[keyPath: keyPath] == value }
    }
}
